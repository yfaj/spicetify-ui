import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spicetify_ui/core/cli/cli_locator.dart';
import 'package:spicetify_ui/core/cli/process_runner.dart';
import 'package:spicetify_ui/ui/app_controller.dart';
import 'package:spicetify_ui/ui/screens/config_screen.dart';

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
    return CommandResult(
      exitCode: 0,
      lines: [LogLine(output, LogStream.stdout)],
    );
  }
}

Future<AppController> buildController({bool withConfig = true}) async {
  final runner = ScriptedRunner(const {
    '--version': '2.45.0',
    '-c': r'C:\cfg\config-xpui.ini',
    'path userdata': r'C:\cfg',
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
    configFileReader: (_) => withConfig ? '[Setting]\ninject_css = 1\n' : '',
    directoryLister: (path) =>
        path.endsWith('Themes') ? const ['Sleek'] : const [],
    spotifyVersionDetector: () async => null,
  );

  await controller.refresh();
  return controller;
}

void main() {
  testWidgets('renders groups and fields', (tester) async {
    final controller = await buildController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ConfigScreen(controller: controller)),
      ),
    );

    expect(find.text('THEME'), findsOneWidget);
    expect(find.text('PRIVACY'), findsOneWidget);
    expect(find.text('FEATURES'), findsOneWidget);
    expect(find.text('Inject CSS'), findsOneWidget);
    expect(find.text('Disable sentry'), findsOneWidget);
  });

  testWidgets('the active toggle reflects the config value', (tester) async {
    final controller = await buildController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ConfigScreen(controller: controller)),
      ),
    );

    final toggle = tester.widget<Switch>(
      find.byKey(const Key('toggle_inject_css')),
    );
    expect(toggle.value, isTrue);
  });

  testWidgets('flipping a toggle stages the change', (tester) async {
    final controller = await buildController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ConfigScreen(controller: controller)),
      ),
    );

    await tester.tap(find.byKey(const Key('toggle_inject_css')));
    await tester.pump();

    expect(controller.pendingChanges, contains('inject_css'));
    expect(controller.stagedValue('inject_css'), '0');
  });

  testWidgets('advanced fields are hidden until expanded', (tester) async {
    final controller = await buildController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ConfigScreen(controller: controller)),
      ),
    );

    expect(find.text('Launch flags'), findsNothing);

    await tester.ensureVisible(find.text('ADVANCED'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ADVANCED'));
    await tester.pumpAndSettle();

    expect(find.text('Launch flags'), findsOneWidget);
    expect(find.text('Extensions'), findsOneWidget);
    expect(find.text('Custom apps'), findsOneWidget);
  });

  testWidgets('the theme dropdown lists discovered themes', (tester) async {
    final controller = await buildController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ConfigScreen(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dropdown_current_theme')), findsOneWidget);
  });
  testWidgets('shows no controls at all when the config is unavailable', (
    tester,
  ) async {
    final controller = await buildController(withConfig: false);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ConfigScreen(controller: controller)),
      ),
    );

    expect(controller.config, isNull);
    expect(
      find.textContaining('Configuration is not available'),
      findsOneWidget,
    );
    expect(find.byType(Switch), findsNothing);
    expect(find.byType(DropdownButton<String>), findsNothing);
  });
}
