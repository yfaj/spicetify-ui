import 'dart:io';

import 'package:spicetify_ui/core/config/config_parser.dart';
import 'package:test/test.dart';

void main() {
  late String fixture;

  setUpAll(() {
    fixture = File('test/fixtures/config-xpui.ini').readAsStringSync();
  });

  group('ConfigParser', () {
    test('reads values from the real fixture', () {
      final config = ConfigParser.parse(fixture);

      expect(config.value('Setting', 'current_theme'), 'marketplace');
      expect(config.value('Setting', 'inject_css'), '1');
      expect(config.value('AdditionalOptions', 'custom_apps'), 'marketplace');
      expect(config.value('Backup', 'with'), '2.45.0');
    });

    test('treats an empty value as an empty string, not null', () {
      final config = ConfigParser.parse(fixture);

      expect(config.value('Setting', 'color_scheme'), '');
      expect(config.value('Setting', 'nope'), isNull);
    });

    test('accepts the CLI spelling of AdditionalOptions', () {
      final config = ConfigParser.parse('[AdditionalFeatures]\nhome_config = 1\n');

      expect(config.value('AdditionalOptions', 'home_config'), '1');
    });

    test('skips comments and blank lines', () {
      final config = ConfigParser.parse('; note\n\n[Setting]\n; inner\na = b\n');

      expect(config.entries.length, 1);
      expect(config.value('Setting', 'a'), 'b');
    });

    test('handles CRLF line endings', () {
      final config = ConfigParser.parse('[Setting]\r\ninject_css = 1\r\n');

      expect(config.value('Setting', 'inject_css'), '1');
    });

    test('keeps values containing equals signs', () {
      final config = ConfigParser.parse('[Setting]\nspotify_launch_flags = --a=1|--b=2\n');

      expect(config.value('Setting', 'spotify_launch_flags'), '--a=1|--b=2');
    });
  });
}
