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
