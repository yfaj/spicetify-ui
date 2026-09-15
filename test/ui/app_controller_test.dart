import 'package:spicetify_ui/core/cli/cli_locator.dart';
import 'package:spicetify_ui/core/cli/process_runner.dart';
import 'package:spicetify_ui/ui/app_controller.dart';
import 'package:test/test.dart';

class FakeProbe implements FileProbe {
  FakeProbe(this.existing);
  final Set<String> existing;

  @override
  bool exists(String path) => existing.contains(path);
}

class ScriptedRunner implements CommandRunner {
  ScriptedRunner(this.responses);
  final Map<String, String> responses;
  final List<List<String>> calls = [];

  @override
  Future<CommandResult> run(List<String> args, {void Function(LogLine line)? onLine}) async {
    calls.add(args);
    final output = responses[args.join(' ')];
    if (output == null) return const CommandResult(exitCode: 1, lines: []);
    final line = LogLine(output, LogStream.stdout);
    onLine?.call(line);
    return CommandResult(exitCode: 0, lines: [line]);
  }
}

class ThrowingRunner implements CommandRunner {
  ThrowingRunner({this.throwOn = const {}});
  final Set<String> throwOn;

  @override
  Future<CommandResult> run(List<String> args, {void Function(LogLine line)? onLine}) async {
    if (throwOn.contains(args.join(' '))) {
      throw StateError('runner failure');
    }
    final line = LogLine(
      args.join(' ') == '--version' ? '2.45.0' : r'C:\cfg\config-xpui.ini',
      LogStream.stdout,
    );
    onLine?.call(line);
    return CommandResult(exitCode: 0, lines: [line]);
  }
}

AppController buildController(CommandRunner runner, {String config = '', Set<String> found = const {r'C:\bin\spicetify.exe'}}) {
  return AppController(
    locator: CliLocator(
      probe: FakeProbe(found),
      runnerFactory: (_) => runner,
      knownPaths: const [r'C:\bin\spicetify.exe'],
      environment: const {'PATH': ''},
      executableName: 'spicetify.exe',
    ),
    runnerFactory: (_) => runner,
    configFileReader: (_) => config,
    directoryLister: (_) => const [],
    spotifyVersionDetector: () async => null,
  );
}

void main() {
  test('reports a found CLI with its version', () async {
    final controller = buildController(ScriptedRunner(const {
      '--version': 'spicetify v2.45.0',
      '-c': r'C:\cfg\config-xpui.ini',
      'path userdata': r'C:\cfg',
    }));

    await controller.refresh();

    expect(controller.cliStatus, CliStatus.found);
    expect(controller.cliVersion, '2.45.0');
    expect(controller.cliSource, CliSource.knownLocation);
  });

  test('reports a missing CLI', () async {
    final controller = buildController(ScriptedRunner(const {}), found: const {});

    await controller.refresh();

    expect(controller.cliStatus, CliStatus.missing);
    expect(controller.cliVersion, isNull);
  });

  test('reads config and detects a re-apply need', () async {
    final runner = ScriptedRunner(const {
      '--version': '2.45.0',
      '-c': r'C:\cfg\config-xpui.ini',
    });
    final controller = AppController(
      locator: CliLocator(
        probe: FakeProbe({r'C:\bin\spicetify.exe'}),
        runnerFactory: (_) => runner,
        knownPaths: const [r'C:\bin\spicetify.exe'],
        environment: const {'PATH': ''},
        executableName: 'spicetify.exe',
      ),
      runnerFactory: (_) => runner,
      configFileReader: (_) => '[Backup]\nversion = 1.3.0.200.gabc\nwith = 2.45.0\n',
      directoryLister: (_) => const [],
      spotifyVersionDetector: () async => '1.3.0.277',
    );

    await controller.refresh();

    expect(controller.needsReapply, isTrue);
    expect(controller.config!.value('Backup', 'with'), '2.45.0');
  });

  test('staging a change does not call the CLI', () async {
    final runner = ScriptedRunner(const {
      '--version': '2.45.0',
      '-c': r'C:\cfg\config-xpui.ini',
    });
    final controller = buildController(runner, config: '[Setting]\ninject_css = 1\n');
    await controller.refresh();
    runner.calls.clear();

    controller.stage('inject_css', '0');

    expect(controller.pendingChanges, contains('inject_css'));
    expect(runner.calls, isEmpty);
  });

  test('staging the current value clears the pending change', () async {
    final runner = ScriptedRunner(const {
      '--version': '2.45.0',
      '-c': r'C:\cfg\config-xpui.ini',
    });
    final controller = buildController(runner, config: '[Setting]\ninject_css = 1\n');
    await controller.refresh();

    controller.stage('inject_css', '0');
    controller.stage('inject_css', '1');

    expect(controller.pendingChanges, isEmpty);
  });

  test('applyChanges writes staged values then applies', () async {
    final runner = ScriptedRunner(const {
      '--version': '2.45.0',
      '-c': r'C:\cfg\config-xpui.ini',
      'config inject_css 0': 'ok',
      'apply': 'applied',
    });
    final controller = buildController(runner, config: '[Setting]\ninject_css = 1\n');
    await controller.refresh();

    controller.stage('inject_css', '0');
    await controller.applyChanges();

    expect(runner.calls, contains(equals(['config', 'inject_css', '0'])));
    expect(runner.calls, contains(equals(['apply'])));
    expect(controller.pendingChanges, isEmpty);
  });

  test('applyChanges stops when a config write fails', () async {
    final runner = ScriptedRunner(const {
      '--version': '2.45.0',
      '-c': r'C:\cfg\config-xpui.ini',
    });
    final controller = buildController(runner, config: '[Setting]\ninject_css = 1\n');
    await controller.refresh();
    runner.calls.clear();

    controller.stage('inject_css', '0');
    await controller.applyChanges();

    expect(runner.calls, contains(equals(['config', 'inject_css', '0'])));
    expect(runner.calls, isNot(contains(equals(['apply']))));
  });

  test('setBlockUpdates issues the right subcommand', () async {
    final runner = ScriptedRunner(const {
      '--version': '2.45.0',
      '-c': r'C:\cfg\config-xpui.ini',
      'spotify-updates block': 'ok',
    });
    final controller = buildController(runner);
    await controller.refresh();
    runner.calls.clear();

    await controller.setBlockUpdates(true);

    expect(runner.calls.single, ['spotify-updates', 'block']);
  });

  test('admin starts disabled', () {
    final controller = buildController(ScriptedRunner(const {}));
    expect(controller.adminEnabled, isFalse);
  });

  test('a throwing command clears busy and still propagates', () async {
    final runner = ThrowingRunner(throwOn: const {'restore', 'apply'});
    final controller = buildController(runner, config: '[Setting]\ninject_css = 1\n');
    await controller.refresh();

    controller.stage('inject_css', '0');
    await expectLater(controller.applyChanges(), throwsStateError);
    expect(controller.busy, isFalse);

    await expectLater(controller.restore(), throwsStateError);
    expect(controller.busy, isFalse);

    final refreshController = buildController(ThrowingRunner(throwOn: const {'--version'}));
    await expectLater(refreshController.refresh(), throwsStateError);
    expect(refreshController.busy, isFalse);
  });
}
