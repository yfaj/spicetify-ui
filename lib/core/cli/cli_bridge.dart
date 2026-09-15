import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:spicetify_ui/core/cli/process_runner.dart';
import 'package:spicetify_ui/core/config/config_parser.dart';

List<String> buildSetArgs(String key, String value) {
  if (key == 'spotify_launch_flags') {
    return ['config', key, '--', value];
  }
  return ['config', key, value];
}

List<String> parseColorSchemes(String colorIniText) {
  final schemes = <String>[];
  for (final raw in colorIniText.split('\n')) {
    final line = raw.trim();
    if (line.startsWith('[') && line.endsWith(']')) {
      final name = line.substring(1, line.length - 1).trim();
      if (name.isNotEmpty) schemes.add(name);
    }
  }
  return schemes;
}

class CliBridge {
  CliBridge(
    this.runner, {
    String Function(String path)? configFileReader,
    List<String> Function(String path)? directoryLister,
  }) : _configFileReader = configFileReader ?? _readFileOrEmpty,
       _directoryLister = directoryLister ?? _listDirectories;

  final CommandRunner runner;
  final String Function(String path) _configFileReader;
  final List<String> Function(String path) _directoryLister;

  static String _readFileOrEmpty(String path) {
    final file = File(path);
    return file.existsSync() ? file.readAsStringSync() : '';
  }

  static List<String> _listDirectories(String path) {
    final dir = Directory(path);
    if (!dir.existsSync()) return const [];
    final names = dir
        .listSync()
        .whereType<Directory>()
        .map((entry) => p.basename(entry.path))
        .toList();
    names.sort();
    return names;
  }

  Future<CommandResult> run(
    List<String> args, {
    void Function(LogLine line)? onLine,
  }) => runner.run(args, onLine: onLine);

  Future<CommandResult> runBare() => runner.run(const []);

  Future<String?> version() async {
    final result = await runner.run(const ['--version']);
    if (!result.ok) return null;
    final match = RegExp(r'(\d+\.\d+\.\d+)').firstMatch(result.output);
    return match?.group(1);
  }

  Future<String?> configFilePath() async {
    final result = await runner.run(const ['-c']);
    if (!result.ok) return null;
    return _stdoutPath(result);
  }

  Future<String?> userdataPath() async {
    final result = await runner.run(const ['path', 'userdata']);
    if (!result.ok) return null;
    return _stdoutPath(result);
  }

  static String? _stdoutPath(CommandResult result) {
    final value = result.lines
        .where((line) => line.stream == LogStream.stdout)
        .map((line) => line.text)
        .join('\n')
        .trim();
    return value.isEmpty ? null : value;
  }

  Future<SpicetifyConfig?> readConfig() async {
    final path = await configFilePath();
    if (path == null) return null;
    final text = _configFileReader(path);
    if (text.isEmpty) return null;
    return ConfigParser.parse(text);
  }

  Future<CommandResult> setValue(String key, String value) =>
      runner.run(buildSetArgs(key, value));

  Future<CommandResult> apply() => runner.run(const ['apply']);
  Future<CommandResult> restore() => runner.run(const ['restore']);
  Future<CommandResult> backup() => runner.run(const ['backup']);
  Future<CommandResult> clearBackup() => runner.run(const ['clear']);
  Future<CommandResult> enableDevtools() =>
      runner.run(const ['enable-devtools']);
  Future<CommandResult> restart() => runner.run(const ['restart']);
  Future<CommandResult> refresh() => runner.run(const ['refresh']);
  Future<CommandResult> upgrade() => runner.run(const ['upgrade']);
  Future<CommandResult> blockUpdates() =>
      runner.run(const ['spotify-updates', 'block']);
  Future<CommandResult> unblockUpdates() =>
      runner.run(const ['spotify-updates', 'unblock']);

  Future<List<String>> listThemes() async {
    final userdata = await userdataPath();
    if (userdata == null) return const [];
    return _directoryLister(p.join(userdata, 'Themes'));
  }

  Future<List<String>> listColorSchemes(String theme) async {
    final userdata = await userdataPath();
    if (userdata == null) return const [];
    return parseColorSchemes(
      _configFileReader(p.join(userdata, 'Themes', theme, 'color.ini')),
    );
  }
}
