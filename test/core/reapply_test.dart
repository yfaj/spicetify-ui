import 'package:spicetify_ui/core/config/reapply.dart';
import 'package:test/test.dart';

void main() {
  group('stripGitHash', () {
    test('removes the .g suffix', () {
      expect(stripGitHash('1.3.0.277.g5441bb3e'), '1.3.0.277');
    });

    test('leaves a plain version alone', () {
      expect(stripGitHash('1.3.0.277'), '1.3.0.277');
    });
  });

  group('needsReapply', () {
    test('is false when versions match', () {
      expect(
        needsReapply(backupVersion: '1.3.0.277.g5441bb3e', spotifyVersion: '1.3.0.277'),
        isFalse,
      );
    });

    test('is true when versions differ', () {
      expect(
        needsReapply(backupVersion: '1.3.0.200.gabc', spotifyVersion: '1.3.0.277'),
        isTrue,
      );
    });

    test('is false when either side is unknown', () {
      expect(needsReapply(backupVersion: null, spotifyVersion: '1.3.0.277'), isFalse);
      expect(needsReapply(backupVersion: '1.3.0.277', spotifyVersion: null), isFalse);
    });

    test('is false for an empty backup version', () {
      expect(needsReapply(backupVersion: '', spotifyVersion: '1.3.0.277'), isFalse);
    });
  });
}
