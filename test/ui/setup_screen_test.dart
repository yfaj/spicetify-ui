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

  @override
  Future<CommandResult> run(List<String> args, {void Function(LogLine line)? onLine}) async {
    final output = responses[args.join(' ')];
    if (output == null) return const CommandResult(exitCode: 1, lines: []);
    return CommandResult(exitCode: 0, lines: [LogLine(output, LogStream.stdout)]);
  }
}

AppController buildController({required bool found}) {
  final runner = ScriptedRunner(const {
    '--version': 'spicetify v2.45.0',
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
  test('installLinesFor returns Windows lines on Windows', () {
    expect(installLinesFor(isWindows: true).first, 'winget install Spicetify.Spicetify');
  });

  test('installLinesFor returns unix lines elsewhere', () {
    expect(installLinesFor(isWindows: false).first, 'brew install spicetify-cli');
  });

  testWidgets('shows install lines when the CLI is missing', (tester) async {
    final controller = buildController(found: false);
    await controller.refresh();

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SetupScreen(controller: controller, isWindows: true)),
    ));

    expect(find.text('Spicetify not found'), findsOneWidget);
    expect(find.text('winget install Spicetify.Spicetify'), findsOneWidget);
    expect(find.text('Re-check'), findsOneWidget);
  });

  testWidgets('shows version, path, and actions when the CLI is found', (tester) async {
    final controller = buildController(found: true);
    await controller.refresh();

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SetupScreen(controller: controller, isWindows: true)),
    ));

    expect(find.textContaining('2.45.0'), findsOneWidget);
    expect(find.text('Backup'), findsOneWidget);
    expect(find.text('Clear backup'), findsOneWidget);
    expect(find.text('Enable devtools'), findsOneWidget);
    expect(find.text('Restart'), findsOneWidget);
    expect(find.text('Block Spotify updates'), findsOneWidget);
    expect(find.text('Watch for changes'), findsOneWidget);
  });
}
