import 'package:flutter/material.dart';
import 'package:spicetify_ui/core/config/keys.dart';
import 'package:spicetify_ui/ui/app_controller.dart';
import 'package:spicetify_ui/ui/widgets/field_row.dart';

class ConfigScreen extends StatefulWidget {
  const ConfigScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  List<String> _themes = const [];
  List<String> _schemes = const [];
  bool _advancedOpen = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final themes = await widget.controller.themes();
    final theme =
        widget.controller.config?.value('Setting', 'current_theme') ?? '';
    final schemes = theme.isEmpty
        ? <String>[]
        : await widget.controller.colorSchemes(theme);
    if (!mounted) return;
    setState(() {
      _themes = themes;
      _schemes = schemes;
    });
  }

  String _current(ConfigKey field) {
    final staged = widget.controller.stagedValue(field.key);
    if (staged != null) return staged;
    return widget.controller.config?.value(field.section, field.key) ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        // Every control below reads its value from the config. With no config
        // loaded, rendering them would show a page of toggles all reading
        // "off" — a value we do not actually know.
        if (widget.controller.config == null) {
          final reason = widget.controller.cliStatus == CliStatus.found
              ? 'Spicetify is installed, but it did not report a readable '
                    'config file.'
              : 'Spicetify is not installed. Set it up on the Setup tab first.';

          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Configuration is not available.\n\n$reason',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final group in configGroups)
                if (group != 'Advanced') ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 6),
                    child: Text(
                      group.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  for (final field in configKeys.where((k) => k.group == group))
                    _buildField(field),
                ],
              const SizedBox(height: 16),
              InkWell(
                onTap: () => setState(() => _advancedOpen = !_advancedOpen),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        'ADVANCED',
                        style: theme.textTheme.labelSmall?.copyWith(
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        _advancedOpen ? Icons.expand_more : Icons.chevron_right,
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ),
              if (_advancedOpen)
                for (final field in configKeys.where(
                  (k) => k.group == 'Advanced',
                ))
                  _buildField(field),
              if (_advancedOpen) _buildCliPath(theme),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCliPath(ThemeData theme) {
    final path = widget.controller.cliPath ?? 'not found';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text('Spicetify CLI', style: theme.textTheme.bodySmall),
        Text(
          path,
          style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildField(ConfigKey field) {
    final current = _current(field);

    switch (field.kind) {
      case FieldKind.toggle:
        return FieldRow(
          label: field.label,
          child: Switch(
            key: Key('toggle_${field.key}'),
            value: current == '1',
            onChanged: (value) =>
                widget.controller.stage(field.key, value ? '1' : '0'),
          ),
        );

      case FieldKind.dropdownTheme:
        final items = {..._themes, if (current.isNotEmpty) current}.toList()
          ..sort();
        return FieldRow(
          label: field.label,
          child: DropdownButton<String>(
            key: Key('dropdown_${field.key}'),
            value: current.isEmpty ? null : current,
            items: [
              for (final item in items)
                DropdownMenuItem(value: item, child: Text(item)),
            ],
            onChanged: (value) {
              if (value == null) return;
              widget.controller.stage(field.key, value);
              widget.controller.colorSchemes(value).then((schemes) {
                if (mounted) setState(() => _schemes = schemes);
              });
            },
          ),
        );

      case FieldKind.dropdownScheme:
        final items = {..._schemes, if (current.isNotEmpty) current}.toList()
          ..sort();
        return FieldRow(
          label: field.label,
          child: DropdownButton<String>(
            key: Key('dropdown_${field.key}'),
            value: current.isEmpty ? null : current,
            items: [
              for (final item in items)
                DropdownMenuItem(value: item, child: Text(item)),
            ],
            onChanged: (value) {
              if (value != null) widget.controller.stage(field.key, value);
            },
          ),
        );

      case FieldKind.text:
        return FieldRow(
          label: field.label,
          child: SizedBox(
            width: 260,
            child: TextFormField(
              key: Key('text_${field.key}'),
              initialValue: current,
              style: const TextStyle(fontSize: 12),
              onChanged: (value) => widget.controller.stage(field.key, value),
            ),
          ),
        );

      case FieldKind.path:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(field.label, style: Theme.of(context).textTheme.bodySmall),
            Text(
              current.isEmpty ? 'not set' : current,
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        );
    }
  }
}
