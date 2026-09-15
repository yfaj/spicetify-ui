List<String> knownCliPaths({
  required bool isWindows,
  required bool isMacOS,
  required bool isLinux,
  required String home,
  required Map<String, String> env,
}) {
  final paths = <String>[];

  if (isWindows) {
    final localAppData = env['LOCALAPPDATA'];
    if (localAppData != null && localAppData.isNotEmpty) {
      paths.add('$localAppData\\spicetify\\spicetify.exe');
    }
    if (home.isNotEmpty) {
      paths.add('$home\\.spicetify\\spicetify.exe');
    }
    return paths;
  }

  if (home.isNotEmpty) {
    paths.add('$home/.spicetify/spicetify');
  }
  if (isMacOS) {
    paths.add('/opt/homebrew/bin/spicetify');
  }
  paths.add('/usr/local/bin/spicetify');
  paths.add('/usr/bin/spicetify');

  return paths;
}

String cliExecutableName({required bool isWindows}) =>
    isWindows ? 'spicetify.exe' : 'spicetify';

/// Where the CLI keeps its backup and extracted app files.
///
/// Not the userdata directory: `path-utils.go:127-147` puts the state folder
/// under `%APPDATA%` on Windows but under `XDG_STATE_HOME` (falling back to
/// `~/.local/state`) on Linux and macOS.
String stateDirectory({
  required bool isWindows,
  required String home,
  required Map<String, String> env,
}) {
  if (isWindows) {
    final appData = env['APPDATA'];
    if (appData != null && appData.isNotEmpty) return appData;
    return '$home\\AppData\\Roaming';
  }

  final xdg = env['XDG_STATE_HOME'];
  if (xdg != null && xdg.isNotEmpty) return xdg;
  return '$home/.local/state';
}

String backupDirectory({
  required bool isWindows,
  required String home,
  required Map<String, String> env,
}) {
  final separator = isWindows ? '\\' : '/';
  return '${stateDirectory(isWindows: isWindows, home: home, env: env)}'
      '${separator}spicetify${separator}Backup';
}
