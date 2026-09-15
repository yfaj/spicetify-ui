import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spicetify_ui/core/cli/cli_locator.dart';
import 'package:spicetify_ui/core/cli/process_runner.dart';
import 'package:spicetify_ui/ui/app_controller.dart';
import 'package:spicetify_ui/ui/widgets/bottom_bar.dart';
import 'package:spicetify_ui/ui/widgets/log_drawer.dart';

class FakeProbe implements FileProbe {
  FakeProbe(this.existing);
  final Set<String> existing;

  @override
  bool exists(String path) => existing.contains(path);
}

class ScriptedRunner implements CommandRunner {
  ScriptedRunner(this.responses);
  final Map<String, String> responses;

  @override
  Future<CommandResult> run(
    List<String> args, {
    void Function(LogLine line)? onLine,
  }) async {
    final output = responses[args.join(' ')];
    if (output == null) return const CommandResult(exitCode: 1, lines: []);
    final line = LogLine(output, LogStream.stdout);
    onLine?.call(line);
    return CommandResult(exitCode: 0, lines: [line]);
  }
}

AppController buildController({required bool found}) {
  final runner = ScriptedRunner(const {
    '--version': '2.45.0',
    '-c': r'C:\cfg\config-xpui.ini',
  });

  return AppController(
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
}

void main() {
  testWidgets('always shows apply and restore', (tester) async {
    final controller = buildController(found: true);
    await controller.refresh();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: BottomBar(controller: controller)),
      ),
    );

    expect(find.text('Apply'), findsOneWidget);
    expect(find.text('Restore'), findsOneWidget);
  });

  testWidgets('apply and restore are disabled while the CLI is missing', (
    tester,
  ) async {
    final controller = buildController(found: false);
    await controller.refresh();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: BottomBar(controller: controller)),
      ),
    );

    final apply = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Apply'),
    );
    final restore = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Restore'),
    );

    expect(apply.onPressed, isNull);
    expect(restore.onPressed, isNull);
  });

  testWidgets('apply is enabled once the CLI is found', (tester) async {
    final controller = buildController(found: true);
    await controller.refresh();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: BottomBar(controller: controller)),
      ),
    );

    final apply = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Apply'),
    );
    expect(apply.onPressed, isNotNull);
  });

  testWidgets('a failing command opens the log drawer with the exit code', (
    tester,
  ) async {
    final controller = buildController(found: true);
    await controller.refresh();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: BottomBar(controller: controller)),
      ),
    );

    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();

    expect(controller.lastCommandFailed, isTrue);
    expect(find.byType(LogDrawer), findsOneWidget);
    expect(find.text('exit 1'), findsOneWidget);
  });

  testWidgets('the log drawer shows an empty state', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: LogDrawer(lines: [])),
      ),
    );

    expect(find.text('no output yet'), findsOneWidget);
  });

  testWidgets('the log drawer renders lines', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LogDrawer(lines: [LogLine('applied', LogStream.stdout)]),
        ),
      ),
    );

    expect(find.text('applied'), findsOneWidget);
  });
}
