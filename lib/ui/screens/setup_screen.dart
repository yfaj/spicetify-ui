import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:spicetify_ui/ui/app_controller.dart';

const List<String> windowsInstallLines = [
  'winget install Spicetify.Spicetify',
  r'iwr -useb https://raw.githubusercontent.com/spicetify/cli/main/install.ps1 | iex',
];

const List<String> unixInstallLines = [
  'brew install spicetify-cli',
  r'curl -fsSL https://raw.githubusercontent.com/spicetify/cli/main/install.sh | sh',
];

List<String> installLinesFor({required bool isWindows}) =>
    isWindows ? windowsInstallLines : unixInstallLines;

class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key, required this.controller, this.isWindows});

  final AppController controller;
  final bool? isWindows;

  @override
  Widget build(BuildContext context) {
    final windows = isWindows ?? Platform.isWindows;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final status = controller.cliStatus;
        if (status == CliStatus.unknown) {
          return const Center(child: Text('Checking for Spicetify...'));
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: status == CliStatus.found
              ? _Found(controller: controller)
              : _Missing(controller: controller, isWindows: windows),
        );
      },
    );
  }
}

class _Found extends StatelessWidget {
  const _Found({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canRun = !controller.busy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (controller.config == null) ...[
          Text(
            'Config file not found. Run Spicetify once to generate defaults.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: canRun ? controller.runBare : null,
            child: const Text('Run Spicetify'),
          ),
          const SizedBox(height: 12),
        ],
        Wrap(
          spacing: 8,
          children: [
            FilledButton.tonal(
              onPressed: canRun ? controller.refresh : null,
              child: const Text('Check for updates'),
            ),
            FilledButton.tonal(
              onPressed: canRun ? controller.upgrade : null,
              child: const Text('Upgrade'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: canRun ? controller.backup : null,
              child: const Text('Backup'),
            ),
            OutlinedButton(
              onPressed: canRun ? controller.clearBackup : null,
              child: const Text('Clear backup'),
            ),
            OutlinedButton(
              onPressed: canRun ? controller.enableDevtools : null,
              child: const Text('Enable devtools'),
            ),
            OutlinedButton(
              onPressed: canRun ? controller.restart : null,
              child: const Text('Restart'),
            ),
            OutlinedButton(
              onPressed: canRun ? () => controller.setBlockUpdates(true) : null,
              child: const Text('Block updates'),
            ),
            OutlinedButton(
              onPressed: canRun
                  ? () => controller.setBlockUpdates(false)
                  : null,
              child: const Text('Unblock updates'),
            ),
          ],
        ),
      ],
    );
  }
}

class _Missing extends StatelessWidget {
  const _Missing({required this.controller, required this.isWindows});

  final AppController controller;
  final bool isWindows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.cancel_outlined,
              size: 16,
              color: Color(0xFFEF4444),
            ),
            const SizedBox(width: 8),
            Text('Spicetify not found', style: theme.textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 8),
        Text('Install it, then re-check.', style: theme.textTheme.bodySmall),
        const SizedBox(height: 16),
        for (final line in installLinesFor(isWindows: isWindows))
          _CopyRow(command: line),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: controller.refresh,
          child: const Text('Re-check'),
        ),
      ],
    );
  }
}

class _CopyRow extends StatelessWidget {
  const _CopyRow({required this.command});

  final String command;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              command,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 14),
            tooltip: 'Copy',
            onPressed: () => Clipboard.setData(ClipboardData(text: command)),
          ),
        ],
      ),
    );
  }
}
