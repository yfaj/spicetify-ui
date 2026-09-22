import 'package:flutter/material.dart';
import 'package:spicetify_ui/ui/widgets/status_dot.dart';
import 'package:window_manager/window_manager.dart';

class Titlebar extends StatelessWidget {
  const Titlebar({
    super.key,
    required this.appVersion,
    required this.cliVersion,
    required this.state,
    this.updateTag,
    this.onUpdateTap,
  });

  final String appVersion;
  final String? cliVersion;
  final DotState state;

  /// Tag of a newer release (e.g. "v1.2.0"), or null when up to date.
  final String? updateTag;
  final VoidCallback? onUpdateTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onPanStart: (_) => windowManager.startDragging(),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            const SizedBox(width: 14),
            // No app icon exists, so this slot is the update indicator:
            // an orange badge when a newer release is out, plain icon otherwise.
            if (updateTag != null && onUpdateTap != null)
              GestureDetector(
                onTap: onUpdateTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFF59E0B),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.upgrade,
                        size: 12,
                        color: Color(0xFFF59E0B),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Update available',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFFF59E0B),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              const Icon(Icons.album_outlined, size: 16),
            const SizedBox(width: 8),
            Text('Spicetify UI', style: theme.textTheme.bodyMedium),
            const SizedBox(width: 8),
            Text(appVersion, style: theme.textTheme.bodySmall),
            const SizedBox(width: 12),
            Container(width: 1, height: 14, color: theme.dividerColor),
            const SizedBox(width: 12),
            StatusDot(state: state),
            const SizedBox(width: 6),
            Text(cliVersion ?? 'not found', style: theme.textTheme.bodySmall),
            const Spacer(),
            _WindowButton(icon: Icons.remove, onTap: windowManager.minimize),
            _WindowButton(icon: Icons.close, onTap: windowManager.close),
          ],
        ),
      ),
    );
  }
}

class _WindowButton extends StatelessWidget {
  const _WindowButton({required this.icon, required this.onTap});

  final IconData icon;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onTap(),
      child: SizedBox(width: 44, height: 44, child: Icon(icon, size: 16)),
    );
  }
}
