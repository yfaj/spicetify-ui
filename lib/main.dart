import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:spicetify_ui/core/auto_reapply.dart';
import 'package:spicetify_ui/core/cli/cli_bridge.dart';
import 'package:spicetify_ui/core/cli/cli_locator.dart';
import 'package:spicetify_ui/core/cli/process_runner.dart';
import 'package:spicetify_ui/core/platform/platform_paths.dart';
import 'package:spicetify_ui/core/platform/scheduler.dart';
import 'package:spicetify_ui/core/platform/spotify_version.dart';
import 'package:spicetify_ui/ui/app_controller.dart';
import 'package:spicetify_ui/ui/screens/backup_screen.dart';
import 'package:spicetify_ui/ui/screens/config_screen.dart';
import 'package:spicetify_ui/ui/screens/setup_screen.dart';
import 'package:spicetify_ui/ui/shell/app_window.dart';
import 'package:spicetify_ui/ui/shell/tabs.dart';
import 'package:spicetify_ui/ui/shell/titlebar.dart';
import 'package:spicetify_ui/ui/widgets/bottom_bar.dart';
import 'package:spicetify_ui/ui/widgets/log_panel.dart';
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

Future<void> main(List<String> args) async {
  if (args.contains('--check')) {
    await runHeadlessAutoReapply();
    return;
  }

  WidgetsFlutterBinding.ensureInitialized();
  await configureWindow();
  runApp(buildApp());
}

/// Scheduled-task entry point. Runs without a window, re-applies the patch if
/// Spotify has moved on, writes one log line, and exits.
Future<void> runHeadlessAutoReapply() async {
  final env = Platform.environment;
  final home = env['HOME'] ?? env['USERPROFILE'] ?? '';
  final isWindows = Platform.isWindows;

  CommandRunner makeRunner(String executable) =>
      SystemCommandRunner(executable);

  final candidate = await CliLocator(
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
  ).locate();

  if (candidate == null) {
    await appendAutoReapplyLog('cli not found');
    exit(0);
  }

  final result = await checkAndReapply(
    bridge: CliBridge(makeRunner(candidate.path)),
    spotifyVersion: () => detectSpotifyVersion(
      isWindows: isWindows,
      isMacOS: Platform.isMacOS,
      isLinux: Platform.isLinux,
      runnerFactory: (executable, args) =>
          SystemCommandRunner(executable, baseArgs: args),
      env: env,
    ),
  );

  await appendAutoReapplyLog(result.message);

  // The Flutter Windows runner keeps the process alive even though no window
  // was ever shown, so a scheduled run has to end the process explicitly.
  exit(0);
}

class SpicetifyApp extends StatefulWidget {
  const SpicetifyApp({super.key, required this.controller});

  final AppController controller;

  @override
  State<SpicetifyApp> createState() => _SpicetifyAppState();
}

class _SpicetifyAppState extends State<SpicetifyApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  int _tab = 0;
  bool _logOpen = false;
  bool _noticeOpen = false;
  bool _lastCommandFailedSeen = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    widget.controller.refresh();
    widget.controller.refreshAutoReapply();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    final failed = widget.controller.lastCommandFailed;
    if (failed && !_lastCommandFailedSeen && !_logOpen) {
      setState(() => _logOpen = true);
    }
    _lastCommandFailedSeen = failed;

    final notice = widget.controller.notice;
    if (notice == null || _noticeOpen) return;

    _noticeOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // `showDialog` needs a context below the MaterialApp, because that is
      // where the Navigator lives. This State's own context sits above it, so
      // the navigator key is what makes the dialog reachable at all.
      final navigator = _navigatorKey.currentState;
      if (!mounted || navigator == null) {
        _noticeOpen = false;
        return;
      }

      try {
        await showDialog<void>(
          context: navigator.context,
          // Dismissible on purpose. A modal that cannot be dismissed is a trap
          // if anything about it goes wrong — which is exactly what happened
          // when this dialog could not find a Navigator at all.
          barrierDismissible: true,
          builder: (dialogContext) => AlertDialog(
            title: Text(notice.title),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: SingleChildScrollView(
                child: SelectableText(notice.message),
              ),
            ),
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
      } finally {
        _noticeOpen = false;
        widget.controller.dismissNotice();
      }
    });
  }

  void _setLogOpen(bool open) {
    setState(() => _logOpen = open);
    setLogPanelVisible(open);
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
      navigatorKey: _navigatorKey,
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
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Outside the main window's own chrome: the log has its own
                // title bar, and the main title bar must not span both.
                if (_logOpen)
                  LogPanel(
                    lines: controller.log,
                    onClose: () => _setLogOpen(false),
                    onClear: controller.clearLog,
                  ),
                Expanded(
                  child: Column(
                    children: [
                      if (usesCustomShell)
                        Titlebar(
                          appVersion: appVersion,
                          cliVersion: controller.cliVersion,
                          state: _dotState(controller),
                        ),
                      Expanded(
                        child: Column(
                          children: [
                            const SizedBox(height: 8),
                            TabStrip(
                              index: _tab,
                              onChanged: (i) => setState(() => _tab = i),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: switch (_tab) {
                                0 => SetupScreen(controller: controller),
                                1 => ConfigScreen(controller: controller),
                                _ => BackupScreen(controller: controller),
                              },
                            ),
                          ],
                        ),
                      ),
                      BottomBar(
                        controller: controller,
                        logOpen: _logOpen,
                        onToggleLog: () => setState(() => _logOpen = !_logOpen),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
