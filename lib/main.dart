import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:spicetify_ui/core/cli/cli_locator.dart';
import 'package:spicetify_ui/core/cli/process_runner.dart';
import 'package:spicetify_ui/core/platform/platform_paths.dart';
import 'package:spicetify_ui/core/platform/spotify_version.dart';
import 'package:spicetify_ui/ui/app_controller.dart';
import 'package:spicetify_ui/ui/screens/config_screen.dart';
import 'package:spicetify_ui/ui/screens/setup_screen.dart';
import 'package:spicetify_ui/ui/shell/app_window.dart';
import 'package:spicetify_ui/ui/shell/tabs.dart';
import 'package:spicetify_ui/ui/shell/titlebar.dart';
import 'package:spicetify_ui/ui/widgets/bottom_bar.dart';
import 'package:spicetify_ui/ui/widgets/status_dot.dart';
import 'package:window_manager/window_manager.dart';

// Source of truth: the version field in pubspec.yaml.
const String appVersion = '1.0.0';

AppController buildProductionController() {
  final env = Platform.environment;
  final home = env['HOME'] ?? env['USERPROFILE'] ?? '';
  final isWindows = Platform.isWindows;

  CommandRunner makeRunner(String executable) =>
      SystemCommandRunner(executable);

  return AppController(
    locator: CliLocator(
      probe: const RealFileProbe(),
      runnerFactory: makeRunner,
      knownPaths: knownCliPaths(
        isWindows: isWindows,
        isMacOS: Platform.isMacOS,
        isLinux: Platform.isLinux,
        home: home,
        env: env,
      ),
      environment: env,
      executableName: cliExecutableName(isWindows: isWindows),
    ),
    runnerFactory: makeRunner,
    configFileReader: (path) {
      final file = File(path);
      return file.existsSync() ? file.readAsStringSync() : '';
    },
    directoryLister: (path) {
      final dir = Directory(path);
      if (!dir.existsSync()) return const [];
      final names = dir
          .listSync()
          .whereType<Directory>()
          .map((entry) => p.basename(entry.path))
          .toList();
      names.sort();
      return names;
    },
    spotifyVersionDetector: () => detectSpotifyVersion(
      isWindows: isWindows,
      isMacOS: Platform.isMacOS,
      isLinux: Platform.isLinux,
      runnerFactory: (executable, args) =>
          SystemCommandRunner(executable, baseArgs: args),
      env: env,
    ),
  );
}

Widget buildApp() => SpicetifyApp(controller: buildProductionController());

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureWindow();
  runApp(buildApp());
}

class SpicetifyApp extends StatefulWidget {
  const SpicetifyApp({super.key, required this.controller});

  final AppController controller;

  @override
  State<SpicetifyApp> createState() => _SpicetifyAppState();
}

class _SpicetifyAppState extends State<SpicetifyApp> {
  int _tab = 0;
  bool _noticeOpen = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    widget.controller.refresh();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    final notice = widget.controller.notice;
    if (notice == null || _noticeOpen) return;

    _noticeOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: Text(notice.title),
          content: SelectableText(notice.message),
          actions: [
            if (notice.offerQuit)
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  windowManager.close();
                },
                child: const Text('Quit'),
              ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      _noticeOpen = false;
      widget.controller.dismissNotice();
    });
  }

  DotState _dotState(AppController controller) =>
      switch (controller.cliStatus) {
        CliStatus.found =>
          controller.needsReapply ? DotState.warn : DotState.ok,
        CliStatus.missing => DotState.missing,
        CliStatus.unknown => DotState.warn,
      };

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        visualDensity: VisualDensity.compact,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFF97316),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      home: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final controller = widget.controller;

          return Scaffold(
            body: Column(
              children: [
                if (usesCustomShell)
                  Titlebar(
                    appVersion: appVersion,
                    cliVersion: controller.cliVersion,
                    state: _dotState(controller),
                  ),
                const SizedBox(height: 8),
                TabStrip(
                  index: _tab,
                  onChanged: (i) => setState(() => _tab = i),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _tab == 0
                      ? SetupScreen(controller: controller)
                      : ConfigScreen(controller: controller),
                ),
                BottomBar(controller: controller),
              ],
            ),
          );
        },
      ),
    );
  }
}
