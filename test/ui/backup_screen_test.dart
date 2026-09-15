import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spicetify_ui/core/backup_status.dart';
import 'package:spicetify_ui/core/cli/cli_locator.dart';
import 'package:spicetify_ui/core/cli/process_runner.dart';
import 'package:spicetify_ui/core/platform/scheduler.dart';
import 'package:spicetify_ui/ui/app_controller.dart';
import 'package:spicetify_ui/ui/screens/backup_screen.dart';

class FakeProbe implements FileProbe {
  FakeProbe(this.existing);
  final Set<String> existing;

  @override
  bool exists(String path) => existing.contains(path);
}

class RecordingRunner implements CommandRunner {
  final List<List<String>> calls = [];

  @override
  Future<CommandResult> run(
    List<String> args, {
    void Function(LogLine line)? onLine,
  }) async {
    calls.add(List.of(args));
    final key = args.join(' ');
    final output = switch (key) {
      '--version' => 'spicetify v2.45.0',
      '-c' => r'C:\cfg\config-xpui.ini',
      _ => 'ok',
    };
    return CommandResult(
      exitCode: 0,
      lines: [LogLine(output, LogStream.stdout)],
    );
  }
}

const _config = '''
[Setting]
current_theme = marketplace

[Backup]
version = 1.3.0.277.g5441bb3e
with    = 2.45.0
''';

final _files = [
  BackupFile(
    name: 'login.spa',
    size: 4034322,
    modified: DateTime(2026, 9, 14, 18, 52),
  ),
  BackupFile(
    name: 'xpui.spa',
    size: 10892998,
    modified: DateTime(2026, 9, 14, 18, 52),
  ),
];

Future<({AppController controller, RecordingRunner runner})> build({
  String config = _config,
  List<BackupFile>? files,
  String spotifyVersion = '1.3.0.277',
}) async {
  final runner = RecordingRunner();
  final controller = AppController(
    locator: CliLocator(
      probe: FakeProbe({r'C:\bin\spicetify.exe'}),
      runnerFactory: (_) => runner,
      knownPaths: const [r'C:\bin\spicetify.exe'],
      environment: const {'PATH': ''},
      executableName: 'spicetify.exe',
    ),
    runnerFactory: (_) => runner,
    configFileReader: (_) => config,
    directoryLister: (_) => const [],
    spotifyVersionDetector: () async => spotifyVersion,
    scheduler: const UnsupportedTaskScheduler(),
    readBlockedState: () => null,
    writeBlockedState: (_) {},
    backupFileLister: (_) => files ?? _files,
  );

  await controller.refresh();
  return (controller: controller, runner: runner);
}

Future<void> pump(WidgetTester tester, AppController controller) =>
    tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: BackupScreen(controller: controller)),
      ),
    );

void main() {
  testWidgets('reports a current backup with its files', (tester) async {
    final fixture = await build();
    await pump(tester, fixture.controller);

    expect(find.text('Current'), findsOneWidget);
    expect(find.textContaining('Spotify 1.3.0.277'), findsOneWidget);
    expect(find.textContaining('made with Spicetify 2.45.0'), findsOneWidget);
    expect(find.text('login.spa'), findsOneWidget);
    expect(find.text('3.8 MB'), findsOneWidget);
  });

  testWidgets('reports a stale backup when Spotify moved on', (tester) async {
    final fixture = await build(spotifyVersion: '1.3.0.300');
    await pump(tester, fixture.controller);

    expect(find.text('Stale'), findsOneWidget);
    expect(find.textContaining('no longer matches it'), findsOneWidget);
  });

  testWidgets('reports a backup made by another Spicetify', (tester) async {
    final fixture = await build(
      config: _config.replaceAll('with    = 2.45.0', 'with    = 2.44.0'),
    );
    await pump(tester, fixture.controller);

    expect(find.text('Made by another Spicetify version'), findsOneWidget);
    expect(find.textContaining('Applying is refused'), findsOneWidget);
  });

  testWidgets('reports no backup when none is recorded', (tester) async {
    final fixture = await build(config: '[Setting]\n', files: const []);
    await pump(tester, fixture.controller);

    expect(find.text('No backup yet'), findsOneWidget);
  });

  testWidgets('clear asks for confirmation before running anything', (
    tester,
  ) async {
    final fixture = await build();
    await pump(tester, fixture.controller);
    fixture.runner.calls.clear();

    await tester.tap(find.text('Clear backup'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Delete the backup?'), findsOneWidget);
    expect(
      fixture.runner.calls,
      isNot(contains(equals(['clear']))),
      reason: 'the command must not run before confirmation',
    );
  });

  testWidgets('cancelling the clear dialog runs nothing', (tester) async {
    final fixture = await build();
    await pump(tester, fixture.controller);
    fixture.runner.calls.clear();

    await tester.tap(find.text('Clear backup'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(fixture.runner.calls, isEmpty);
  });

  testWidgets('confirming the clear dialog runs the command', (tester) async {
    final fixture = await build();
    await pump(tester, fixture.controller);
    fixture.runner.calls.clear();

    await tester.tap(find.text('Clear backup'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(fixture.runner.calls, contains(equals(['clear'])));
  });

  testWidgets('create warns that it overwrites the existing backup', (
    tester,
  ) async {
    final fixture = await build();
    await pump(tester, fixture.controller);
    fixture.runner.calls.clear();

    await tester.tap(find.text('Create backup'));
    await tester.pumpAndSettle();

    expect(find.text('Create a new backup?'), findsOneWidget);
    expect(find.textContaining('deletes the current backup'), findsOneWidget);
    expect(fixture.runner.calls, isEmpty);
  });
}
