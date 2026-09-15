enum FieldKind { toggle, text, dropdownTheme, dropdownScheme, path }

class ConfigKey {
  const ConfigKey({
    required this.section,
    required this.key,
    required this.label,
    required this.group,
    required this.kind,
  });

  final String section;
  final String key;
  final String label;
  final String group;
  final FieldKind kind;
}

const List<String> configGroups = ['Spotify', 'Theme', 'Privacy', 'Features', 'Advanced'];

const List<ConfigKey> configKeys = [
  ConfigKey(section: 'Setting', key: 'spotify_path', label: 'Spotify path', group: 'Spotify', kind: FieldKind.path),
  ConfigKey(section: 'Setting', key: 'prefs_path', label: 'Prefs path', group: 'Spotify', kind: FieldKind.path),

  ConfigKey(section: 'Setting', key: 'current_theme', label: 'Theme', group: 'Theme', kind: FieldKind.dropdownTheme),
  ConfigKey(section: 'Setting', key: 'color_scheme', label: 'Color scheme', group: 'Theme', kind: FieldKind.dropdownScheme),
  ConfigKey(section: 'Setting', key: 'inject_css', label: 'Inject CSS', group: 'Theme', kind: FieldKind.toggle),
  ConfigKey(section: 'Setting', key: 'inject_theme_js', label: 'Inject theme JS', group: 'Theme', kind: FieldKind.toggle),
  ConfigKey(section: 'Setting', key: 'replace_colors', label: 'Replace colors', group: 'Theme', kind: FieldKind.toggle),
  ConfigKey(section: 'Setting', key: 'overwrite_assets', label: 'Overwrite assets', group: 'Theme', kind: FieldKind.toggle),

  ConfigKey(section: 'Preprocesses', key: 'disable_sentry', label: 'Disable sentry', group: 'Privacy', kind: FieldKind.toggle),
  ConfigKey(section: 'Preprocesses', key: 'disable_ui_logging', label: 'Disable UI logging', group: 'Privacy', kind: FieldKind.toggle),
  ConfigKey(section: 'Preprocesses', key: 'remove_rtl_rule', label: 'Remove RTL rules', group: 'Privacy', kind: FieldKind.toggle),
  ConfigKey(section: 'Preprocesses', key: 'expose_apis', label: 'Expose APIs', group: 'Privacy', kind: FieldKind.toggle),

  ConfigKey(section: 'AdditionalOptions', key: 'experimental_features', label: 'Experimental features', group: 'Features', kind: FieldKind.toggle),
  ConfigKey(section: 'AdditionalOptions', key: 'home_config', label: 'Home config', group: 'Features', kind: FieldKind.toggle),
  ConfigKey(section: 'AdditionalOptions', key: 'sidebar_config', label: 'Sidebar config', group: 'Features', kind: FieldKind.toggle),
  ConfigKey(section: 'Setting', key: 'always_enable_devtools', label: 'Always enable devtools', group: 'Features', kind: FieldKind.toggle),
  ConfigKey(section: 'Setting', key: 'check_spicetify_update', label: 'Check for updates', group: 'Features', kind: FieldKind.toggle),

  ConfigKey(section: 'Setting', key: 'spotify_launch_flags', label: 'Launch flags', group: 'Advanced', kind: FieldKind.text),
  ConfigKey(section: 'AdditionalOptions', key: 'extensions', label: 'Extensions', group: 'Advanced', kind: FieldKind.text),
  ConfigKey(section: 'AdditionalOptions', key: 'custom_apps', label: 'Custom apps', group: 'Advanced', kind: FieldKind.text),
];
