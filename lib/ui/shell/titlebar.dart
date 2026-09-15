import 'package:flutter/material.dart';
import 'package:spicetify_ui/ui/widgets/status_dot.dart';
import 'package:window_manager/window_manager.dart';

class Titlebar extends StatelessWidget {
  const Titlebar({
    super.key,
    required this.appVersion,
    required this.cliVersion,
    required this.state,
  });

  final String appVersion;
  final String? cliVersion;
  final DotState state;

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
