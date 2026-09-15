import 'package:spicetify_ui/core/cli/cli_bridge.dart';
import 'package:spicetify_ui/core/cli/process_runner.dart';
import 'package:spicetify_ui/core/config/reapply.dart';

enum AutoReapplyOutcome { upToDate, reapplied, failed, unavailable }

class AutoReapplyResult {
  const AutoReapplyResult(this.outcome, this.message);

  final AutoReapplyOutcome outcome;
  final String message;

  bool get isFailure =>
      outcome == AutoReapplyOutcome.failed ||
      outcome == AutoReapplyOutcome.unavailable;
}

/// Compares the Spotify build the patch was applied to against the installed
/// one, and re-applies when they differ.
///
/// `-n` (`--no-restart`) is passed so the chain never kills a running Spotify.
/// `spicetify.go:368` checks that flag once, after every command has run, so it
/// covers the whole `backup apply` chain. The patch therefore lands on disk and
/// takes effect the next time Spotify starts.
Future<AutoReapplyResult> checkAndReapply({
  required CliBridge bridge,
  required Future<String?> Function() spotifyVersion,
  void Function(LogLine line)? onLine,
}) async {
  final config = await bridge.readConfig();
  if (config == null) {
    return const AutoReapplyResult(
      AutoReapplyOutcome.unavailable,
      'config file not readable',
    );
  }

  final installed = await spotifyVersion();
  final backupVersion = config.value('Backup', 'version');

  if (!needsReapply(backupVersion: backupVersion, spotifyVersion: installed)) {
    return AutoReapplyResult(
      AutoReapplyOutcome.upToDate,
      'no re-apply needed (spotify ${installed ?? 'unknown'})',
    );
  }

  final result = await bridge.run(const [
    '-n',
    'backup',
    'apply',
  ], onLine: onLine);

  if (!result.ok) {
    return AutoReapplyResult(
      AutoReapplyOutcome.failed,
      'backup apply exited ${result.exitCode}',
    );
  }

  return AutoReapplyResult(
    AutoReapplyOutcome.reapplied,
    're-applied for spotify $installed',
  );
}
