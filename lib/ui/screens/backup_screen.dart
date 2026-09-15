import 'package:flutter/material.dart';
import 'package:spicetify_ui/core/backup_status.dart';
import 'package:spicetify_ui/ui/app_controller.dart';
import 'package:spicetify_ui/ui/widgets/action_row.dart';

class BackupScreen extends StatelessWidget {
  const BackupScreen({super.key, required this.controller});

  final AppController controller;

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final answer = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return answer ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final status = controller.backupStatus;

        // Never render a state we have not read yet.
        if (status == null) {
          return const Center(child: Text('Reading the backup...'));
        }

        final canRun =
            controller.cliStatus == CliStatus.found && !controller.busy;

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatusCard(status: status),
              ActionGroup(
                label: 'ACTIONS',
                children: [
                  ActionRow(
                    title: 'Create backup',
                    subtitle: 'Overwrites the existing backup',
                    busy: controller.isRunning(const ['backup']),
                    onTap: canRun
                        ? () async {
                            final ok = await _confirm(
                              context,
                              title: 'Create a new backup?',
                              message:
                                  'This deletes the current backup and '
                                  'captures Spotify as it is right now. If '
                                  'Spotify is already patched, the backup will '
                                  'capture the patched files.',
                              confirmLabel: 'Create',
                            );
                            if (!ok) return;
                            await controller.backup();
                            await controller.refreshBackup();
                          }
                        : null,
                  ),
                  ActionRow(
                    title: 'Clear backup',
                    subtitle: 'Deletes the stored backup files',
                    busy: controller.isRunning(const ['clear']),
                    onTap: canRun
                        ? () async {
                            final ok = await _confirm(
                              context,
                              title: 'Delete the backup?',
                              message:
                                  'Spicetify cannot restore Spotify to vanilla '
                                  'without a backup.',
                              confirmLabel: 'Delete',
                            );
                            if (!ok) return;
                            await controller.clearBackup();
                            await controller.refreshBackup();
                          }
                        : null,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status});

  final BackupStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (icon, colour, headline) = switch (status.state) {
      BackupState.none => (
        Icons.remove_circle_outline,
        const Color(0xFFEF4444),
        'No backup yet',
      ),
      BackupState.current => (
        Icons.check_circle_outline,
        const Color(0xFF4ADE80),
        'Current',
      ),
      BackupState.stale => (
        Icons.warning_amber_outlined,
        const Color(0xFFFBBF24),
        'Stale',
      ),
      BackupState.wrongTool => (
        Icons.warning_amber_outlined,
        const Color(0xFFFBBF24),
        'Made by another Spicetify version',
      ),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: colour),
              const SizedBox(width: 8),
              Text(headline, style: theme.textTheme.bodyMedium),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _detail(),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
          if (status.state == BackupState.wrongTool)
            Text(
              'Applying is refused until a fresh backup is made.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
          if (status.state == BackupState.stale)
            Text(
              'Spotify updated, so this backup no longer matches it.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
          if (status.files.isNotEmpty) ...[
            const SizedBox(height: 18),
            for (final file in status.files)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        file.name,
                        style: const TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    Text(
                      formatBytes(file.size),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.hintColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _formatDate(file.modified),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.hintColor,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  String _detail() {
    if (status.state == BackupState.none) {
      return 'Create one before applying Spicetify.';
    }

    final spotify = status.spotifyLabel;
    final with_ = status.backupWith ?? 'unknown';
    return 'Spotify $spotify · made with Spicetify $with_';
  }
}

String _formatDate(DateTime value) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(value.day)}/${two(value.month)} '
      '${two(value.hour)}:${two(value.minute)}';
}
