import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spicetify_ui/core/cli/cli_locator.dart';
import 'package:spicetify_ui/core/cli/process_runner.dart';
import 'package:spicetify_ui/ui/app_controller.dart';
import 'package:spicetify_ui/ui/widgets/bottom_bar.dart';
import 'package:spicetify_ui/ui/widgets/log_panel.dart';

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

Widget bar(AppController controller, {bool logOpen = false}) => MaterialApp(
  home: Scaffold(
    body: BottomBar(
      controller: controller,
      logOpen: logOpen,
      onToggleLog: () {},
    ),
  ),
);

void main() {
  testWidgets('always shows apply and restore', (tester) async {
    final controller = buildController(found: true);
    await controller.refresh();

    await tester.pumpWidget(bar(controller));

    expect(find.text('Apply'), findsOneWidget);
    expect(find.text('Restore'), findsOneWidget);
  });

  testWidgets('apply and restore are disabled while the CLI is missing', (
    tester,
  ) async {
    final controller = buildController(found: false);
    await controller.refresh();

    await tester.pumpWidget(bar(controller));

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

    await tester.pumpWidget(bar(controller));

    final apply = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Apply'),
    );
    expect(apply.onPressed, isNotNull);
  });

  testWidgets('the toggle reports taps', (tester) async {
    var toggled = 0;
    final controller = buildController(found: true);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BottomBar(
            controller: controller,
            logOpen: false,
            onToggleLog: () => toggled++,
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump();

    expect(toggled, 1);
  });

  testWidgets('the toggle points the way the panel will open', (tester) async {
    final controller = buildController(found: true);

    await tester.pumpWidget(bar(controller, logOpen: true));
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);

    await tester.pumpWidget(bar(controller));
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets('the log panel shows an empty state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LogPanel(lines: const [], onClose: () {}, onClear: () {}),
        ),
      ),
    );

    expect(find.text('no output yet'), findsOneWidget);
  });

  testWidgets('the log panel renders lines and counts them', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LogPanel(
            lines: const [
              LogLine('applied', LogStream.stdout),
              LogLine('boom', LogStream.stderr),
            ],
            onClose: () {},
            onClear: () {},
          ),
        ),
      ),
    );

    expect(find.text('applied'), findsOneWidget);
    expect(find.text('boom'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('the log panel closes when asked', (tester) async {
    var closed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LogPanel(
            lines: const [],
            onClose: () => closed++,
            onClear: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(closed, 1);
  });
  testWidgets('the log panel clears when asked', (tester) async {
    var cleared = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LogPanel(
            lines: const [LogLine('applied', LogStream.stdout)],
            onClose: () {},
            onClear: () => cleared++,
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pump();

    expect(cleared, 1);
  });

  testWidgets('copy and clear only appear once there is output', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LogPanel(lines: const [], onClose: () {}, onClear: () {}),
        ),
      ),
    );

    expect(find.byIcon(Icons.copy_all_outlined), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });

  testWidgets('copy is offered once there is output', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LogPanel(
            lines: const [LogLine('applied', LogStream.stdout)],
            onClose: () {},
            onClear: () {},
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.copy_all_outlined), findsOneWidget);
  });
}
