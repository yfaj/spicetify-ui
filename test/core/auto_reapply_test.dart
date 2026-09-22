import 'dart:io';

import 'package:spicetify_ui/core/auto_reapply.dart';
import 'package:spicetify_ui/core/cli/cli_bridge.dart';
import 'package:spicetify_ui/core/cli/process_runner.dart';
import 'package:spicetify_ui/core/platform/scheduler.dart';

import 'package:test/test.dart';

class RecordingRunner implements CommandRunner {
  RecordingRunner(this.responses);
  final Map<String, String> responses;
  final List<List<String>> calls = [];

  @override
  Future<CommandResult> run(
    List<String> args, {
    void Function(LogLine line)? onLine,
  }) async {
    calls.add(args);
    final output = responses[args.join(' ')];
    if (output == null) return const CommandResult(exitCode: 1, lines: []);
    final line = LogLine(output, LogStream.stdout);
    onLine?.call(line);
    return CommandResult(exitCode: 0, lines: [line]);
  }
}

CliBridge bridgeWith(RecordingRunner runner, String config) =>
    CliBridge(runner, configFileReader: (_) => config);

void main() {
  group('checkAndReapply', () {
    test('does nothing when the backup matches the installed build', () async {
      final runner = RecordingRunner(const {'-c': r'C:\cfg\config-xpui.ini'});
      final bridge = bridgeWith(
        runner,
        '[Backup]\nversion = 1.3.0.277.g5441bb3e\n',
      );

      final result = await checkAndReapply(
        bridge: bridge,
        spotifyVersion: () async => '1.3.0.277',
      );

      expect(result.outcome, AutoReapplyOutcome.upToDate);
      expect(runner.calls, isNot(contains(equals(['-n', 'backup', 'apply']))));
    });

    test('re-applies with --no-restart when the build changed', () async {
      final runner = RecordingRunner(const {
        '-c': r'C:\cfg\config-xpui.ini',
        '-n backup apply': 'applied',
      });
      final bridge = bridgeWith(runner, '[Backup]\nversion = 1.3.0.200.gabc\n');

      final result = await checkAndReapply(
        bridge: bridge,
        spotifyVersion: () async => '1.3.0.277',
      );

      expect(result.outcome, AutoReapplyOutcome.reapplied);
      expect(runner.calls, contains(equals(['-n', 'backup', 'apply'])));
    });

    test('reports a failure when the re-apply exits non-zero', () async {
      final runner = RecordingRunner(const {'-c': r'C:\cfg\config-xpui.ini'});
      final bridge = bridgeWith(runner, '[Backup]\nversion = 1.3.0.200.gabc\n');

      final result = await checkAndReapply(
        bridge: bridge,
        spotifyVersion: () async => '1.3.0.277',
      );

      expect(result.outcome, AutoReapplyOutcome.failed);
      expect(result.message, contains('exit'));
    });

    test('reports unavailable when the config cannot be read', () async {
      final runner = RecordingRunner(const {});
      final bridge = CliBridge(runner, configFileReader: (_) => '');

      final result = await checkAndReapply(
        bridge: bridge,
        spotifyVersion: () async => '1.3.0.277',
      );

      expect(result.outcome, AutoReapplyOutcome.unavailable);
      expect(result.isFailure, isTrue);
    });

    test('never restarts Spotify', () async {
      final runner = RecordingRunner(const {
        '-c': r'C:\cfg\config-xpui.ini',
        '-n backup apply': 'applied',
      });
      final bridge = bridgeWith(runner, '[Backup]\nversion = 1.3.0.200.gabc\n');

      await checkAndReapply(
        bridge: bridge,
        spotifyVersion: () async => '1.3.0.277',
      );

      for (final call in runner.calls) {
        expect(call, isNot(contains('restart')));
      }
      expect(runner.calls, contains(equals(['-n', 'backup', 'apply'])));
    });
  });

  group('WindowsTaskScheduler', () {
    test('registers a per-user task that runs the check flag', () async {
      final runner = RecordingRunner(const {});
      final scheduler = WindowsTaskScheduler(runnerFactory: (_) => runner);

      await scheduler.register(r'C:\app\spicetify_ui.exe');

      final create = runner.calls.single;
      expect(create.first, '/Create');
      expect(create, contains('/TN'));
      expect(create, contains(autoReapplyTaskName));
      expect(create, contains('/TR'));
      expect(create, contains(r'"C:\app\spicetify_ui.exe" --check'));
      expect(create, contains('/SC'));
      expect(create, contains('MINUTE'));
      expect(create, contains('/MO'));
      expect(create, contains('$autoReapplyIntervalMinutes'));
      expect(create, contains('/F'));
    });

    test('never asks for elevation', () async {
      final runner = RecordingRunner(const {});
      final scheduler = WindowsTaskScheduler(runnerFactory: (_) => runner);

      await scheduler.register(r'C:\app\spicetify_ui.exe');

      expect(runner.calls.single, isNot(contains('/RU')));
      expect(runner.calls.single, isNot(contains('SYSTEM')));
      expect(runner.calls.single, isNot(contains('HIGHEST')));
    });

    test('unregisters by name', () async {
      final runner = RecordingRunner(const {});
      final scheduler = WindowsTaskScheduler(runnerFactory: (_) => runner);

      await scheduler.unregister();

      expect(runner.calls.single, [
        '/Delete',
        '/TN',
        autoReapplyTaskName,
        '/F',
      ]);
    });

    test('reports registration state from the query exit code', () async {
      final present = WindowsTaskScheduler(
        runnerFactory: (_) => RecordingRunner(const {
          '/Query /TN $autoReapplyTaskName': 'TaskName',
        }),
      );
      final absent = WindowsTaskScheduler(
        runnerFactory: (_) => RecordingRunner(const {}),
      );

      expect(await present.isRegistered(), isTrue);
      expect(await absent.isRegistered(), isFalse);
    });
  });

  group('SystemdTaskScheduler', () {
    test('writes user units that run the check flag and enables the timer', () async {
      final runner = RecordingRunner(const {
        '--user daemon-reload': 'ok',
        '--user enable --now ${SystemdTaskScheduler.unitName}.timer': 'ok',
      });
      final home = Directory.systemTemp.createTempSync('spui-test-');
      addTearDown(() => home.deleteSync(recursive: true));

      final scheduler = SystemdTaskScheduler(
        runnerFactory: (_) => runner,
        home: home.path,
      );

      final ok = await scheduler.register('/usr/bin/spicetify_ui');

      expect(ok, isTrue);
      final service = File(
        '${home.path}/.config/systemd/user/${SystemdTaskScheduler.unitName}.service',
      );
      final timer = File(
        '${home.path}/.config/systemd/user/${SystemdTaskScheduler.unitName}.timer',
      );
      expect(service.existsSync(), isTrue);
      expect(timer.existsSync(), isTrue);
      expect(service.readAsStringSync(), contains('--check'));
      expect(service.readAsStringSync(), isNot(contains('sudo')));
      expect(
        timer.readAsStringSync(),
        contains('${autoReapplyIntervalMinutes}min'),
      );
      expect(runner.calls, contains(equals(['--user', 'daemon-reload'])));
      expect(
        runner.calls,
        contains(
          equals([
            '--user',
            'enable',
            '--now',
            '${SystemdTaskScheduler.unitName}.timer',
          ]),
        ),
      );
    });

    test('unregisters by disabling the timer and removing the units', () async {
      final runner = RecordingRunner(const {
        '--user daemon-reload': 'ok',
        '--user enable --now ${SystemdTaskScheduler.unitName}.timer': 'ok',
        '--user disable --now ${SystemdTaskScheduler.unitName}.timer': 'ok',
      });
      final home = Directory.systemTemp.createTempSync('spui-test-');
      addTearDown(() => home.deleteSync(recursive: true));

      final scheduler = SystemdTaskScheduler(
        runnerFactory: (_) => runner,
        home: home.path,
      );
      await scheduler.register('/usr/bin/spicetify_ui');

      final ok = await scheduler.unregister();

      expect(ok, isTrue);
      expect(
        File(
          '${home.path}/.config/systemd/user/${SystemdTaskScheduler.unitName}.service',
        ).existsSync(),
        isFalse,
      );
      expect(
        File(
          '${home.path}/.config/systemd/user/${SystemdTaskScheduler.unitName}.timer',
        ).existsSync(),
        isFalse,
      );
      expect(
        runner.calls,
        contains(
          equals([
            '--user',
            'disable',
            '--now',
            '${SystemdTaskScheduler.unitName}.timer',
          ]),
        ),
      );
    });

    test('reports registration from systemctl is-enabled', () async {
      final enabled = SystemdTaskScheduler(
        runnerFactory: (_) => RecordingRunner(const {
          '--user is-enabled ${SystemdTaskScheduler.unitName}.timer': 'enabled',
        }),
        home: '/nonexistent-home-for-test',
      );
      final absent = SystemdTaskScheduler(
        runnerFactory: (_) => RecordingRunner(const {}),
        home: '/nonexistent-home-for-test',
      );

      expect(await enabled.isRegistered(), isTrue);
      expect(await absent.isRegistered(), isFalse);
    });

    test('reports itself as supported where systemd runs', () {
      final scheduler = SystemdTaskScheduler(
        runnerFactory: (_) => RecordingRunner(const {}),
        home: '/nonexistent-home-for-test',
      );

      // On a Windows dev machine this is false; the real assertion is that
      // it flips true only when the systemd runtime directory exists.
      expect(
        scheduler.isSupported,
        Directory('/run/systemd/system').existsSync(),
      );
    });
  });

  group('UnsupportedTaskScheduler', () {
    test('reports nothing and refuses every change', () async {
      const scheduler = UnsupportedTaskScheduler();

      expect(scheduler.isSupported, isFalse);
      expect(await scheduler.isRegistered(), isFalse);
      expect(await scheduler.register('/usr/bin/spicetify_ui'), isFalse);
      expect(await scheduler.unregister(), isFalse);
    });
  });

  group('WindowsTaskScheduler support', () {
    test('reports itself as supported', () {
      final scheduler = WindowsTaskScheduler(
        runnerFactory: (_) => RecordingRunner(const {}),
      );

      expect(scheduler.isSupported, isTrue);
    });
  });
}
