import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spicetify_ui/core/cli/cli_locator.dart';
import 'package:spicetify_ui/core/cli/process_runner.dart';
import 'package:spicetify_ui/ui/app_controller.dart';
import 'package:spicetify_ui/ui/screens/setup_screen.dart';

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
  Future<CommandResult> run(
    List<String> args, {
    void Function(LogLine line)? onLine,
  }) async {
    calls.add(List.of(args));
    final output = responses[args.join(' ')];
    if (output == null) return const CommandResult(exitCode: 1, lines: []);
    return CommandResult(
      exitCode: 0,
      lines: [LogLine(output, LogStream.stdout)],
    );
  }
}

({AppController controller, ScriptedRunner runner}) buildFixture({
  required bool found,
}) {
  final runner = ScriptedRunner(const {
    '--version': 'spicetify v2.45.0',
    '-c': r'C:\cfg\config-xpui.ini',
  });

  final controller = AppController(
    locator: CliLocator(
      probe: FakeProbe(found ? {r'C:\bin\spicetify.exe'} : const {}),
      runnerFactory: (_) => runner,
      knownPaths: const [r'C:\bin\spicetify.exe'],
      environment: const {'PATH': ''},
      executableName: 'spicetify.exe',
    ),
    runnerFactory: (_) => runner,
    configFileReader: (_) => '',
    directoryLister: (_) => const [],
    spotifyVersionDetector: () async => null,
  );

  return (controller: controller, runner: runner);
}

AppController buildController({required bool found}) =>
    buildFixture(found: found).controller;

void main() {
  test('installLinesFor returns Windows lines on Windows', () {
    expect(
      installLinesFor(isWindows: true).first,
      'winget install Spicetify.Spicetify',
    );
  });

  test('installLinesFor returns unix lines elsewhere', () {
    expect(
      installLinesFor(isWindows: false).first,
      'brew install spicetify-cli',
    );
  });

  testWidgets('shows install lines when the CLI is missing', (tester) async {
    final controller = buildController(found: false);
    await controller.refresh();
    expect(controller.cliStatus, CliStatus.missing);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SetupScreen(controller: controller, isWindows: true),
        ),
      ),
    );

    expect(find.text('Spicetify not found'), findsOneWidget);
    expect(find.text('winget install Spicetify.Spicetify'), findsOneWidget);
    expect(find.text('Re-check'), findsOneWidget);
  });

  testWidgets('shows a neutral placeholder while the CLI status is unknown', (
    tester,
  ) async {
    final controller = buildController(found: true);
    expect(controller.cliStatus, CliStatus.unknown);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SetupScreen(controller: controller, isWindows: true),
        ),
      ),
    );

    expect(find.text('Checking for Spicetify...'), findsOneWidget);
    expect(find.text('Spicetify not found'), findsNothing);
    expect(find.text('winget install Spicetify.Spicetify'), findsNothing);
  });

  testWidgets('shows the actions when the CLI is found', (tester) async {
    final controller = buildController(found: true);
    await controller.refresh();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SetupScreen(controller: controller, isWindows: true),
        ),
      ),
    );

    expect(find.text('Backup'), findsOneWidget);
    expect(find.text('Clear backup'), findsOneWidget);
    expect(find.text('Restart'), findsOneWidget);
    expect(find.text('Block updates'), findsOneWidget);
    expect(find.text('Unblock updates'), findsOneWidget);
  });

  testWidgets('does not duplicate the devtools toggle that lives in config', (
    tester,
  ) async {
    final controller = buildController(found: true);
    await controller.refresh();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SetupScreen(controller: controller, isWindows: true),
        ),
      ),
    );

    expect(find.text('Enable devtools'), findsNothing);
  });

  testWidgets('does not repeat the CLI version the titlebar already shows', (
    tester,
  ) async {
    final controller = buildController(found: true);
    await controller.refresh();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SetupScreen(controller: controller, isWindows: true),
        ),
      ),
    );

    expect(find.textContaining('Spicetify 2.45.0'), findsNothing);
  });

  testWidgets('offers a bare run when the config file is missing', (
    tester,
  ) async {
    final fixture = buildFixture(found: true);
    await fixture.controller.refresh();
    expect(fixture.controller.config, isNull);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SetupScreen(controller: fixture.controller, isWindows: true),
        ),
      ),
    );

    expect(find.textContaining('Config file not found'), findsOneWidget);

    await tester.tap(find.text('Run Spicetify'));
    await tester.pumpAndSettle();

    expect(fixture.runner.calls.any((args) => args.isEmpty), isTrue);
  });

  testWidgets('block and unblock both reach the controller', (tester) async {
    final fixture = buildFixture(found: true);
    await fixture.controller.refresh();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SetupScreen(controller: fixture.controller, isWindows: true),
        ),
      ),
    );

    await tester.ensureVisible(find.text('Unblock updates'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unblock updates'));
    await tester.pumpAndSettle();

    expect(
      fixture.runner.calls,
      contains(equals(['spotify-updates', 'unblock'])),
    );

    await tester.ensureVisible(find.text('Block updates'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Block updates'));
    await tester.pumpAndSettle();

    expect(
      fixture.runner.calls,
      contains(equals(['spotify-updates', 'block'])),
    );
  });
}
