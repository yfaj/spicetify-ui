import 'package:flutter/material.dart';
import 'package:spicetify_ui/ui/app_controller.dart';
import 'package:spicetify_ui/ui/widgets/log_drawer.dart';

class BottomBar extends StatefulWidget {
  const BottomBar({super.key, required this.controller});

  final AppController controller;

  @override
  State<BottomBar> createState() => _BottomBarState();
}

class _BottomBarState extends State<BottomBar> {
  bool _logOpen = false;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final canRun = controller.cliStatus == CliStatus.found && !controller.busy;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_logOpen) LogDrawer(lines: controller.log),
            Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(_logOpen ? Icons.expand_more : Icons.expand_less, size: 18),
                    onPressed: () => setState(() => _logOpen = !_logOpen),
                    tooltip: 'Log',
                  ),
                  const Spacer(),
                  Checkbox(
                    value: controller.adminEnabled,
                    onChanged: (value) => controller.setAdmin(value ?? false),
                  ),
                  const Text('admin'),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: canRun ? controller.applyChanges : null,
                    child: const Text('Apply'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: canRun ? controller.restore : null,
                    child: const Text('Restore'),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
