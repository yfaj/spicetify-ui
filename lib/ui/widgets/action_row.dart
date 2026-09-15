import 'package:flutter/material.dart';

/// `InkWell` paints its hover and splash on the nearest `Material` ancestor.
/// Without a local one that is the Scaffold body, and the highlight is drawn
/// against the wrong box. Every row carries its own transparent Material so
/// the ink is clipped to the row it belongs to.
class _RowInk extends StatelessWidget {
  const _RowInk({required this.onTap, required this.child});

  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: child,
      ),
    );
  }
}

class ActionRow extends StatelessWidget {
  const ActionRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.busy = false,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onTap != null;

    return _RowInk(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: enabled ? null : theme.disabledColor,
                        ),
                      ),
                      if (busy) ...[
                        const SizedBox(width: 8),
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 1.8),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: enabled ? theme.hintColor : theme.disabledColor,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 16,
              color: enabled ? theme.hintColor : theme.disabledColor,
            ),
          ],
        ),
      ),
    );
  }
}

class ActionToggle extends StatelessWidget {
  const ActionToggle({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onChanged != null;

    return _RowInk(
      onTap: enabled ? () => onChanged!(!value) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: enabled ? null : theme.disabledColor,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: enabled ? theme.hintColor : theme.disabledColor,
                    ),
                  ),
                ],
              ),
            ),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

/// A row whose action has no readable state, so it offers explicit choices
/// instead of a toggle that would have to invent its own value.
class ActionChoice extends StatelessWidget {
  const ActionChoice({
    super.key,
    required this.title,
    required this.subtitle,
    required this.actions,
  });

  final String title;
  final String subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.bodyMedium),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
              ],
            ),
          ),
          for (final action in actions) ...[const SizedBox(width: 8), action],
        ],
      ),
    );
  }
}

class ActionGroup extends StatelessWidget {
  const ActionGroup({
    super.key,
    required this.label,
    required this.children,
    this.centerLabel = false,
  });

  final String label;
  final List<Widget> children;
  final bool centerLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 2),
          child: Align(
            alignment: centerLabel ? Alignment.center : Alignment.centerLeft,
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.1),
            ),
          ),
        ),
        for (final child in children) child,
      ],
    );
  }
}
