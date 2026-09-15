import 'package:spicetify_ui/core/config/keys.dart';
import 'package:test/test.dart';

void main() {
  test('every section and key pair is unique', () {
    final seen = <String>{};
    for (final entry in configKeys) {
      expect(
        seen.add('${entry.section}.${entry.key}'),
        isTrue,
        reason: 'duplicate ${entry.section}.${entry.key}',
      );
    }
  });

  test('every group used by a key is declared', () {
    for (final entry in configKeys) {
      expect(configGroups, contains(entry.group));
    }
  });

  test('covers the documented Setting keys', () {
    final actual = configKeys
        .where((k) => k.section == 'Setting')
        .map((k) => k.key)
        .toList();
    expect(
      actual,
      containsAll([
        'spotify_path',
        'prefs_path',
        'current_theme',
        'color_scheme',
        'inject_css',
        'inject_theme_js',
        'replace_colors',
        'overwrite_assets',
        'spotify_launch_flags',
        'check_spicetify_update',
      ]),
    );
  });

  test('covers the documented Preprocesses keys', () {
    final actual = configKeys
        .where((k) => k.section == 'Preprocesses')
        .map((k) => k.key)
        .toList();
    expect(
      actual,
      containsAll([
        'disable_sentry',
        'disable_ui_logging',
        'remove_rtl_rule',
        'expose_apis',
      ]),
    );
  });

  test('covers the documented AdditionalOptions keys', () {
    final actual = configKeys
        .where((k) => k.section == 'AdditionalOptions')
        .map((k) => k.key)
        .toList();
    expect(
      actual,
      containsAll([
        'custom_apps',
        'extensions',
        'experimental_features',
        'home_config',
        'sidebar_config',
      ]),
    );
  });
}
