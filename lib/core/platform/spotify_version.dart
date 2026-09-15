import 'package:spicetify_ui/core/cli/process_runner.dart';

final _versionPattern = RegExp(r'(\d+\.\d+\.\d+(?:\.\d+)?)');

String _psQuote(String value) => "'${value.replaceAll("'", "''")}'";

/// PowerShell binds nothing to `$args` when `-Command` is given a script and
/// the value is passed positionally: the argument is appended to the command
/// text and fails to parse. The path has to be inlined, single-quoted.
List<String> windowsSpotifyVersionArgs(String executable) => [
  '-NoProfile',
  '-Command',
  '(Get-Item -LiteralPath ${_psQuote(executable)}).VersionInfo.ProductVersion',
];

Future<String?> detectSpotifyVersion({
  required bool isWindows,
  required bool isMacOS,
  required bool isLinux,
  required CommandRunner Function(String executable, List<String> args)
  runnerFactory,
  required Map<String, String> env,
}) async {
  if (isWindows) {
    final appData = env['APPDATA'];
    if (appData == null || appData.isEmpty) return null;
    final runner = runnerFactory(
      'powershell',
      windowsSpotifyVersionArgs('$appData\\Spotify\\Spotify.exe'),
    );
    final result = await runner.run(const []);
    return _firstVersion(result.output);
  }

  if (isMacOS) {
    final runner = runnerFactory('defaults', const [
      'read',
      '/Applications/Spotify.app/Contents/Info.plist',
      'CFBundleShortVersionString',
    ]);
    final result = await runner.run(const []);
    return _firstVersion(result.output);
  }

  if (isLinux) {
    final runner = runnerFactory('spotify', const ['--version']);
    final result = await runner.run(const []);
    return _firstVersion(result.output);
  }

  return null;
}

String? _firstVersion(String output) {
  final match = _versionPattern.firstMatch(output);
  return match?.group(1);
}
