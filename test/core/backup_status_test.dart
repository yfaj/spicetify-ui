import 'package:spicetify_ui/core/backup_status.dart';
import 'package:test/test.dart';

List<BackupFile> get files => [
  BackupFile(name: 'login.spa', size: 4034322, modified: DateTime(2026, 9, 14)),
];

void main() {
  group('evaluateBackup', () {
    test('reports none when no version is recorded', () {
      final status = evaluateBackup(
        backupVersion: '',
        backupWith: '2.45.0',
        spotifyVersion: '1.3.0.277',
        cliVersion: '2.45.0',
        files: files,
      );

      expect(status.state, BackupState.none);
    });

    test('reports none when the directory holds no files', () {
      final status = evaluateBackup(
        backupVersion: '1.3.0.277.g5441bb3e',
        backupWith: '2.45.0',
        spotifyVersion: '1.3.0.277',
        cliVersion: '2.45.0',
        files: const [],
      );

      expect(status.state, BackupState.none);
    });

    test('reports current when both versions match', () {
      final status = evaluateBackup(
        backupVersion: '1.3.0.277.g5441bb3e',
        backupWith: '2.45.0',
        spotifyVersion: '1.3.0.277',
        cliVersion: '2.45.0',
        files: files,
      );

      expect(status.state, BackupState.current);
      expect(status.spotifyLabel, '1.3.0.277');
    });

    test('reports stale when Spotify moved on', () {
      final status = evaluateBackup(
        backupVersion: '1.3.0.200.gabc',
        backupWith: '2.45.0',
        spotifyVersion: '1.3.0.277',
        cliVersion: '2.45.0',
        files: files,
      );

      expect(status.state, BackupState.stale);
    });

    test('reports wrongTool when another Spicetify made the backup', () {
      final status = evaluateBackup(
        backupVersion: '1.3.0.277.g5441bb3e',
        backupWith: '2.44.0',
        spotifyVersion: '1.3.0.277',
        cliVersion: '2.45.0',
        files: files,
      );

      expect(status.state, BackupState.wrongTool);
    });

    test('wrongTool wins over stale, because apply refuses outright', () {
      final status = evaluateBackup(
        backupVersion: '1.3.0.200.gabc',
        backupWith: '2.44.0',
        spotifyVersion: '1.3.0.277',
        cliVersion: '2.45.0',
        files: files,
      );

      expect(status.state, BackupState.wrongTool);
    });

    test('does not invent wrongTool when a version is unreadable', () {
      final status = evaluateBackup(
        backupVersion: '1.3.0.277.g5441bb3e',
        backupWith: null,
        spotifyVersion: '1.3.0.277',
        cliVersion: null,
        files: files,
      );

      expect(status.state, BackupState.current);
    });

    test('totals the file sizes', () {
      final status = evaluateBackup(
        backupVersion: '1.3.0.277.g5441bb3e',
        backupWith: '2.45.0',
        spotifyVersion: '1.3.0.277',
        cliVersion: '2.45.0',
        files: files,
      );

      expect(status.totalBytes, 4034322);
    });
  });

  group('formatBytes', () {
    test('renders bytes, kilobytes and megabytes', () {
      expect(formatBytes(512), '512 B');
      expect(formatBytes(2048), '2.0 KB');
      expect(formatBytes(4034322), '3.8 MB');
    });
  });

  group('listBackupFiles', () {
    test('returns nothing for a directory that does not exist', () {
      expect(listBackupFiles(r'Z:\definitely\not\here'), isEmpty);
    });
  });
}
