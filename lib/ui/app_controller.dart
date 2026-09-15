import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:spicetify_ui/core/cli/cli_bridge.dart';
import 'package:spicetify_ui/core/cli/cli_locator.dart';
import 'package:spicetify_ui/core/cli/process_runner.dart';
import 'package:spicetify_ui/core/config/config_parser.dart';
import 'package:spicetify_ui/core/config/reapply.dart' as reapply;
import 'package:spicetify_ui/core/platform/scheduler.dart';

enum CliStatus { unknown, missing, found }

class CommandNotice {
  const CommandNotice({
    required this.title,
    required this.message,
    this.offerQuit = false,
  });

  final String title;
  final String message;
  final bool offerQuit;
}

class AppController extends ChangeNotifier {
  AppController({
    required this._locator,
    required this._runnerFactory,
    required this._configFileReader,
    this._directoryLister,
    Future<String?> Function()? spotifyVersionDetector,
    TaskScheduler? scheduler,
  }) : _spotifyVersionDetector = spotifyVersionDetector ?? (() async => null),
       _scheduler =
           scheduler ?? taskSchedulerFor(isWindows: Platform.isWindows);

  final CliLocator _locator;
  final CommandRunner Function(String executable) _runnerFactory;
  final String Function(String path) _configFileReader;
  final List<String> Function(String path)? _directoryLister;
  final Future<String?> Function() _spotifyVersionDetector;
  final TaskScheduler _scheduler;

  CliBridge? _bridge;

  CliStatus cliStatus = CliStatus.unknown;
  String? cliVersion;
  String? cliPath;
  CliSource? cliSource;

  SpicetifyConfig? config;
  String? spotifyVersion;
  bool needsReapply = false;

  bool adminEnabled = false;
  bool watchRunning = false;
  bool busy = false;
  bool lastCommandFailed = false;
  bool autoReapplyEnabled = false;
  String? lastAutoReapply;
  CommandNotice? notice;

  static const _adminMarker = 'administrator or root privileges';

  void dismissNotice() {
    notice = null;
    notifyListeners();
  }

  final List<LogLine> log = [];
  final Map<String, String> _staged = {};

  Set<String> get pendingChanges => _staged.keys.toSet();

  void _appendLog(LogLine line) {
    log.add(line);
    notifyListeners();
  }

  void _recordFailure(CommandResult result) {
    if (result.ok) return;
    lastCommandFailed = true;
    _appendLog(LogLine('exit ${result.exitCode}', LogStream.stderr));

    final output = result.output.trim();

    if (output.contains(_adminMarker)) {
      notice = const CommandNotice(
        title: 'Administrator privileges',
        message:
            'Spicetify refuses to run with administrator or root privileges. '
            'Close this app and open it normally, without "Run as administrator".',
        offerQuit: true,
      );
      return;
    }

    notice = CommandNotice(
      title: 'Command failed',
      message: output.isEmpty
          ? 'The command exited with code ${result.exitCode}. See the log for details.'
          : output,
    );
  }

  Future<void> refresh() async {
    busy = true;
    notifyListeners();

    try {
      final candidate = await _locator.locate();

      if (candidate == null) {
        cliStatus = CliStatus.missing;
        cliVersion = null;
        cliPath = null;
        cliSource = null;
        config = null;
        _bridge = null;
        return;
      }

      cliStatus = CliStatus.found;
      cliVersion = candidate.version;
      cliPath = candidate.path;
      cliSource = candidate.source;

      _bridge = CliBridge(
        _runnerFactory(candidate.path),
        configFileReader: _configFileReader,
        directoryLister: _directoryLister,
      );

      config = await _bridge!.readConfig();
      spotifyVersion = await _spotifyVersionDetector();
      needsReapply = reapply.needsReapply(
        backupVersion: config?.value('Backup', 'version'),
        spotifyVersion: spotifyVersion,
      );
    } catch (error) {
      if (cliStatus == CliStatus.unknown) {
        cliStatus = CliStatus.missing;
      }
      _appendLog(LogLine('$error', LogStream.stderr));
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  String? _currentValue(String key) {
    for (final section in const [
      'Setting',
      'Preprocesses',
      'AdditionalOptions',
    ]) {
      final value = config?.value(section, key);
      if (value != null) return value;
    }
    return null;
  }

  void stage(String key, String value) {
    if (_currentValue(key) == value) {
      _staged.remove(key);
    } else {
      _staged[key] = value;
    }
    notifyListeners();
  }

  String? stagedValue(String key) => _staged[key];

  Future<void> _run(List<String> args) async {
    final bridge = _bridge;
    if (bridge == null) return;

    busy = true;
    lastCommandFailed = false;
    notifyListeners();

    try {
      final result = await bridge.run(args, onLine: _appendLog);
      _recordFailure(result);
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> applyChanges() async {
    final bridge = _bridge;
    if (bridge == null) return;

    busy = true;
    lastCommandFailed = false;
    notifyListeners();

    try {
      for (final entry in _staged.entries) {
        final result = await bridge.run(
          buildSetArgs(entry.key, entry.value),
          onLine: _appendLog,
        );
        if (!result.ok) {
          _recordFailure(result);
          return;
        }
      }

      _staged.clear();
      _recordFailure(await bridge.run(const ['apply'], onLine: _appendLog));
    } finally {
      busy = false;
      notifyListeners();
    }

    await refresh();
  }

  Future<void> runBare() async {
    await _run(const []);
    await refresh();
  }

  Future<void> restore() => _run(const ['restore']);
  Future<void> backup() => _run(const ['backup']);
  Future<void> clearBackup() => _run(const ['clear']);
  Future<void> enableDevtools() => _run(const ['enable-devtools']);
  Future<void> restart() => _run(const ['restart']);
  Future<void> upgrade() => _run(const ['upgrade']);
  Future<void> refreshTheme() => _run(const ['refresh']);

  Future<void> setBlockUpdates(bool blocked) =>
      _run(['spotify-updates', blocked ? 'block' : 'unblock']);

  Future<void> setWatch(bool running) async {
    watchRunning = running;
    notifyListeners();
  }

  void setAdmin(bool value) {
    adminEnabled = value;
    notifyListeners();
  }

  Future<void> refreshAutoReapply() async {
    autoReapplyEnabled = await _scheduler.isRegistered();
    lastAutoReapply = await readLastAutoReapply();
    notifyListeners();
  }

  /// Registers or removes the per-user scheduled task. No elevation is
  /// involved: `schtasks` runs the task as the current user.
  Future<void> setAutoReapply(bool value) async {
    busy = true;
    notifyListeners();

    try {
      final ok = value
          ? await _scheduler.register(Platform.resolvedExecutable)
          : await _scheduler.unregister();

      if (!ok) {
        notice = CommandNotice(
          title: value
              ? 'Could not enable auto re-apply'
              : 'Could not disable auto re-apply',
          message:
              'The scheduled task could not be updated. Windows Task Scheduler '
              'refused the change.',
        );
      }

      autoReapplyEnabled = await _scheduler.isRegistered();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  void clearLog() {
    log.clear();
    notifyListeners();
  }

  Future<List<String>> themes() async => _bridge?.listThemes() ?? const [];

  Future<List<String>> colorSchemes(String theme) async =>
      _bridge?.listColorSchemes(theme) ?? const [];
}
