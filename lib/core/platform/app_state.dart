import 'dart:convert';
import 'dart:io';

/// Values the app has to remember itself, because the CLI cannot report them.
///
/// `spotify-updates` accepts only `block` or `unblock` and has no query mode,
/// so the only truthful thing a toggle can show is what this app last set.
File appStateFile() {
  final base =
      Platform.environment['APPDATA'] ??
      Platform.environment['HOME'] ??
      Platform.environment['USERPROFILE'] ??
      '.';
  return File(
    '$base${Platform.pathSeparator}spicetify-ui'
    '${Platform.pathSeparator}state.json',
  );
}

Map<String, Object?> readAppState() {
  try {
    final file = appStateFile();
    if (!file.existsSync()) return const {};
    final decoded = jsonDecode(file.readAsStringSync());
    return decoded is Map<String, Object?> ? decoded : const {};
  } on Object {
    return const {};
  }
}

void writeAppStateValue(String key, Object? value) {
  try {
    final values = Map<String, Object?>.from(readAppState());
    values[key] = value;
    final file = appStateFile();
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(jsonEncode(values));
  } on FileSystemException {
    // Best effort: a state write must never fail a command.
  }
}

bool? readUpdatesBlocked() {
  final value = readAppState()['updatesBlocked'];
  return value is bool ? value : null;
}

void writeUpdatesBlocked(bool value) =>
    writeAppStateValue('updatesBlocked', value);
