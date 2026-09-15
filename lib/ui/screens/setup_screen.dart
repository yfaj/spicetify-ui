import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:spicetify_ui/ui/app_controller.dart';
import 'package:spicetify_ui/ui/widgets/action_row.dart';

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
  const SetupScreen({
    super.key,
    required this.controller,
    this.isWindows,
    this.isLinux,
  });

  final AppController controller;
  final bool? isWindows;
  final bool? isLinux;

  @override
  Widget build(BuildContext context) {
    final windows = isWindows ?? Platform.isWindows;
    final linux = isLinux ?? Platform.isLinux;

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
              ? _Found(controller: controller, isLinux: linux)
              : _Missing(controller: controller, isWindows: windows),
        );
      },
    );
  }
}

class _Found extends StatelessWidget {
  const _Found({required this.controller, required this.isLinux});

  final AppController controller;
  final bool isLinux;

  bool get _alwaysDevtools {
    final staged = controller.stagedValue('always_enable_devtools');
    final raw =
        staged ??
        controller.config?.value('Setting', 'always_enable_devtools') ??
        '0';
    return raw == '1';
  }

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
        ActionGroup(
          label: 'UPDATES',
          children: [
            ActionRow(
              title: 'Check for updates',
              subtitle: 'Re-detect the Spicetify CLI',
              onTap: canRun ? controller.refresh : null,
            ),
            ActionRow(
              title: 'Upgrade',
              subtitle: 'Update Spicetify itself',
              onTap: canRun ? controller.upgrade : null,
              busy: controller.isRunning(const ['upgrade']),
            ),
          ],
        ),
        ActionGroup(
          label: 'MAINTENANCE',
          children: [
            ActionRow(
              title: 'Backup',
              subtitle: 'Store a clean copy of Spotify',
              onTap: canRun ? controller.backup : null,
              busy: controller.isRunning(const ['backup']),
            ),
            ActionRow(
              title: 'Clear backup',
              subtitle: 'Delete the stored backup files',
              onTap: canRun ? controller.clearBackup : null,
              busy: controller.isRunning(const ['clear']),
            ),
            ActionRow(
              title: 'Enable devtools',
              subtitle: 'Enable it now · Ctrl+Shift+I inside Spotify',
              onTap: canRun ? controller.enableDevtools : null,
              busy: controller.isRunning(const ['enable-devtools']),
            ),
            if (controller.config != null)
              ActionToggle(
                title: 'Always enable devtools',
                subtitle: 'Keep DevTools available on every launch',
                value: _alwaysDevtools,
                onChanged: canRun
                    ? (value) => controller.stage(
                        'always_enable_devtools',
                        value ? '1' : '0',
                      )
                    : null,
              ),
            ActionRow(
              title: 'Restart',
              subtitle: 'Restart the Spotify client',
              onTap: canRun ? controller.restart : null,
              busy: controller.isRunning(const ['restart']),
            ),
          ],
        ),
        if (controller.supportsAutoReapply &&
            controller.autoReapplyEnabled != null)
          ActionGroup(
            label: 'AUTOMATION',
            children: [
              ActionToggle(
                title: 'Re-apply after Spotify updates',
                subtitle: 'Checks every 15 minutes and restores the patch',
                value: controller.autoReapplyEnabled!,
                onChanged: canRun ? controller.setAutoReapply : null,
              ),
              if (controller.lastAutoReapply != null)
                Padding(
                  padding: const EdgeInsets.only(left: 10, bottom: 6),
                  child: Text(
                    'last: ${controller.lastAutoReapply}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
                ),
            ],
          ),
        if (!isLinux)
          ActionGroup(
            label: 'SPOTIFY UPDATES',
            children: [
              // The CLI has no query for this, so a toggle can only be
              // truthful once this app has set it. Until then, offer the
              // explicit choices.
              if (controller.updatesBlocked == null)
                ActionChoice(
                  title: 'Spotify updates',
                  subtitle: 'Blocking patches Spotify.exe · not yet set here',
                  actions: [
                    OutlinedButton(
                      onPressed: canRun
                          ? () => controller.setBlockUpdates(true)
                          : null,
                      child: const Text('Block'),
                    ),
                    OutlinedButton(
                      onPressed: canRun
                          ? () => controller.setBlockUpdates(false)
                          : null,
                      child: const Text('Unblock'),
                    ),
                  ],
                )
              else
                ActionToggle(
                  title: 'Block Spotify updates',
                  subtitle: 'Stops Spotify from updating itself',
                  value: controller.updatesBlocked!,
                  onChanged: canRun ? controller.setBlockUpdates : null,
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
