import 'dart:io';

import 'package:spicetify_ui/core/config/reapply.dart';

enum BackupState {
  /// No backup recorded, or the directory holds no files.
  none,

  /// Recorded by a different Spicetify build than the one that would apply.
  /// `apply.go:20-23` exits 1 in this case, so it blocks applying outright.
  wrongTool,

  /// Taken from a Spotify build that is no longer the installed one.
  stale,

  /// Matches both the installed Spotify and the running CLI.
  current,
}

class BackupFile {
  const BackupFile({
    required this.name,
    required this.size,
    required this.modified,
  });

  final String name;
  final int size;
  final DateTime modified;
}

class BackupStatus {
  const BackupStatus({
    required this.state,
    this.backupVersion,
    this.backupWith,
    this.spotifyVersion,
    this.cliVersion,
    this.files = const [],
  });

  final BackupState state;
  final String? backupVersion;
  final String? backupWith;
  final String? spotifyVersion;
  final String? cliVersion;
  final List<BackupFile> files;

  int get totalBytes => files.fold(0, (sum, file) => sum + file.size);

  String get spotifyLabel => backupVersion == null || backupVersion!.isEmpty
      ? 'unknown'
      : stripGitHash(backupVersion!);
}

/// Precedence matters. `wrongTool` wins because the CLI refuses to apply with
/// it; `stale` is next because the patch would be written against the wrong
/// build; `none` covers an empty or missing backup.
BackupStatus evaluateBackup({
  required String? backupVersion,
  required String? backupWith,
  required String? spotifyVersion,
  required String? cliVersion,
  required List<BackupFile> files,
}) {
  final hasVersion = backupVersion != null && backupVersion.isNotEmpty;

  if (!hasVersion || files.isEmpty) {
    return BackupStatus(
      state: BackupState.none,
      backupVersion: backupVersion,
      backupWith: backupWith,
      spotifyVersion: spotifyVersion,
      cliVersion: cliVersion,
      files: files,
    );
  }

  final state = _state(
    backupVersion: backupVersion,
    backupWith: backupWith,
    spotifyVersion: spotifyVersion,
    cliVersion: cliVersion,
  );

  return BackupStatus(
    state: state,
    backupVersion: backupVersion,
    backupWith: backupWith,
    spotifyVersion: spotifyVersion,
    cliVersion: cliVersion,
    files: files,
  );
}

BackupState _state({
  required String backupVersion,
  required String? backupWith,
  required String? spotifyVersion,
  required String? cliVersion,
}) {
  if (backupWith != null &&
      backupWith.isNotEmpty &&
      cliVersion != null &&
      cliVersion.isNotEmpty &&
      backupWith != cliVersion) {
    return BackupState.wrongTool;
  }

  final stale = needsReapply(
    backupVersion: backupVersion,
    spotifyVersion: spotifyVersion,
  );

  return stale ? BackupState.stale : BackupState.current;
}

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';

  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';

  final mb = kb / 1024;
  return '${mb.toStringAsFixed(1)} MB';
}

/// Reads the backup directory. Returns empty when it is missing, so a machine
/// that has never backed up reports `none` rather than failing.
List<BackupFile> listBackupFiles(String directory) {
  final dir = Directory(directory);
  if (!dir.existsSync()) return const [];

  final files = <BackupFile>[];
  for (final entity in dir.listSync()) {
    if (entity is! File) continue;
    final stat = entity.statSync();
    files.add(
      BackupFile(
        name: entity.uri.pathSegments.last,
        size: stat.size,
        modified: stat.modified,
      ),
    );
  }

  files.sort((a, b) => a.name.compareTo(b.name));
  return files;
}
