import 'package:flutter/material.dart';
import 'package:spicetify_ui/ui/app_controller.dart';

class BottomBar extends StatelessWidget {
  const BottomBar({
    super.key,
    required this.controller,
    required this.logOpen,
    required this.onToggleLog,
  });

  final AppController controller;
  final bool logOpen;
  final VoidCallback onToggleLog;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final canRun =
            controller.cliStatus == CliStatus.found && !controller.busy;

        return Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  logOpen ? Icons.chevron_left : Icons.chevron_right,
                  size: 18,
                ),
                onPressed: onToggleLog,
                tooltip: logOpen ? 'Hide log' : 'Show log',
              ),
              const Spacer(),
              FilledButton(
                onPressed: canRun ? controller.applyChanges : null,
                child: _ButtonLabel(
                  'Apply',
                  busy: controller.isRunning(const ['apply']),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: canRun ? controller.restore : null,
                child: _ButtonLabel(
                  'Restore',
                  busy: controller.isRunning(const ['restore']),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ButtonLabel extends StatelessWidget {
  const _ButtonLabel(this.text, {required this.busy});

  final String text;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text),
        if (busy) ...[
          const SizedBox(width: 8),
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 1.8),
          ),
        ],
      ],
    );
  }
}
