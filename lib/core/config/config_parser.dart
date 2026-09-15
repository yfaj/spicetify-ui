import 'dart:convert';

class ConfigEntry {
  const ConfigEntry({
    required this.section,
    required this.key,
    required this.value,
  });

  final String section;
  final String key;
  final String value;
}

class SpicetifyConfig {
  const SpicetifyConfig(this.entries);

  final List<ConfigEntry> entries;

  static const _aliases = {'AdditionalFeatures': 'AdditionalOptions'};

  static String normalizeSection(String section) =>
      _aliases[section] ?? section;

  String? value(String section, String key) {
    for (final entry in entries) {
      if (normalizeSection(entry.section) == normalizeSection(section) &&
          entry.key == key) {
        return entry.value;
      }
    }
    return null;
  }
}

class ConfigParser {
  static SpicetifyConfig parse(String text) {
    final entries = <ConfigEntry>[];
    var section = '';

    for (final raw in const LineSplitter().convert(text)) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith(';') || line.startsWith('#')) {
        continue;
      }

      if (line.startsWith('[') && line.endsWith(']')) {
        section = line.substring(1, line.length - 1).trim();
        continue;
      }

      final equals = line.indexOf('=');
      if (equals <= 0) continue;

      entries.add(
        ConfigEntry(
          section: section,
          key: line.substring(0, equals).trim(),
          value: line.substring(equals + 1).trim(),
        ),
      );
    }

    return SpicetifyConfig(entries);
  }
}
