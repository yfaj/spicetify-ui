import 'package:flutter/foundation.dart';
import 'package:spicetify_ui/core/cli/cli_bridge.dart';
import 'package:spicetify_ui/core/cli/cli_locator.dart';
import 'package:spicetify_ui/core/cli/process_runner.dart';
import 'package:spicetify_ui/core/config/config_parser.dart';
import 'package:spicetify_ui/core/config/reapply.dart' as reapply;

enum CliStatus { unknown, missing, found }

class AppController extends ChangeNotifier {
  AppController({
    required this._locator,
    required this._runnerFactory,
    required this._configFileReader,
    this._directoryLister,
    Future<String?> Function()? spotifyVersionDetector,
  }) : _spotifyVersionDetector = spotifyVersionDetector ?? (() async => null);

  final CliLocator _locator;
  final CommandRunner Function(String executable) _runnerFactory;
  final String Function(String path) _configFileReader;
  final List<String> Function(String path)? _directoryLister;
  final Future<String?> Function() _spotifyVersionDetector;

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

  final List<LogLine> log = [];
  final Map<String, String> _staged = {};

  Set<String> get pendingChanges => _staged.keys.toSet();

  void _appendLog(LogLine line) {
    log.add(line);
    notifyListeners();
  }

  Future<void> refresh() async {
    busy = true;
    notifyListeners();

    final candidate = await _locator.locate();

    if (candidate == null) {
      cliStatus = CliStatus.missing;
      cliVersion = null;
      cliPath = null;
      cliSource = null;
      config = null;
      _bridge = null;
      busy = false;
      notifyListeners();
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

    busy = false;
    notifyListeners();
  }

  String? _currentValue(String key) {
    for (final section in const ['Setting', 'Preprocesses', 'AdditionalOptions']) {
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
    notifyListeners();

    await bridge.run(args, onLine: _appendLog);

    busy = false;
    notifyListeners();
  }

  Future<void> applyChanges() async {
    final bridge = _bridge;
    if (bridge == null) return;

    busy = true;
    notifyListeners();

    for (final entry in _staged.entries) {
      final result = await bridge.run(
        buildSetArgs(entry.key, entry.value),
        onLine: _appendLog,
      );
      if (!result.ok) {
        busy = false;
        notifyListeners();
        return;
      }
    }

    _staged.clear();
    await bridge.run(const ['apply'], onLine: _appendLog);

    busy = false;
    notifyListeners();
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

  void clearLog() {
    log.clear();
    notifyListeners();
  }

  Future<List<String>> themes() async => _bridge?.listThemes() ?? const [];

  Future<List<String>> colorSchemes(String theme) async =>
      _bridge?.listColorSchemes(theme) ?? const [];
}
