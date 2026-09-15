import 'dart:io';

import 'package:spicetify_ui/core/cli/process_runner.dart';

const String autoReapplyTaskName = 'Spicetify UI Auto Reapply';
const int autoReapplyIntervalMinutes = 15;

abstract interface class TaskScheduler {
  Future<bool> isRegistered();

  Future<bool> register(String executable);

  Future<bool> unregister();
}

/// Per-user scheduled task. No `/RU` and no elevation, so registering it never
/// prompts for administrator rights.
class WindowsTaskScheduler implements TaskScheduler {
  WindowsTaskScheduler({
    CommandRunner Function(String executable)? runnerFactory,
  }) : _runnerFactory = runnerFactory ?? SystemCommandRunner.new;

  final CommandRunner Function(String executable) _runnerFactory;

  List<String> get _createArgs => [
    '/Create',
    '/TN',
    autoReapplyTaskName,
    '/TR',
    '"$executable" --check',
    '/SC',
    'MINUTE',
    '/MO',
    '$autoReapplyIntervalMinutes',
    '/F',
  ];

  String executable = '';

  @override
  Future<bool> isRegistered() async {
    final result = await _runnerFactory('schtasks')
        .run(['/Query', '/TN', autoReapplyTaskName]);
    return result.ok;
  }

  @override
  Future<bool> register(String executablePath) async {
    executable = executablePath;
    final result = await _runnerFactory('schtasks').run(_createArgs);
    return result.ok;
  }

  @override
  Future<bool> unregister() async {
    final result = await _runnerFactory('schtasks')
        .run(['/Delete', '/TN', autoReapplyTaskName, '/F']);
    return result.ok;
  }
}

class UnsupportedTaskScheduler implements TaskScheduler {
  const UnsupportedTaskScheduler();

  @override
  Future<bool> isRegistered() async => false;

  @override
  Future<bool> register(String executable) async => false;

  @override
  Future<bool> unregister() async => false;
}

TaskScheduler taskSchedulerFor({
  required bool isWindows,
  CommandRunner Function(String executable)? runnerFactory,
}) => isWindows
    ? WindowsTaskScheduler(runnerFactory: runnerFactory)
    : const UnsupportedTaskScheduler();

/// Appends one line per headless run so the UI can report the last outcome.
Future<void> appendAutoReapplyLog(String line) async {
  try {
    final dir = Directory(
      '${Platform.environment['APPDATA'] ?? Platform.environment['HOME'] ?? '.'}'
      '${Platform.pathSeparator}spicetify-ui',
    );
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final file = File('${dir.path}${Platform.pathSeparator}auto-reapply.log');
    file.writeAsStringSync(
      '${DateTime.now().toIso8601String()}  $line\n',
      mode: FileMode.append,
    );
  } on FileSystemException {
    // A log write failure must never take the scheduled run down.
  }
}

Future<String?> readLastAutoReapply() async {
  try {
    final dir = Directory(
      '${Platform.environment['APPDATA'] ?? Platform.environment['HOME'] ?? '.'}'
      '${Platform.pathSeparator}spicetify-ui',
    );
    final file = File('${dir.path}${Platform.pathSeparator}auto-reapply.log');
    if (!file.existsSync()) return null;
    final lines = file.readAsLinesSync();
    return lines.isEmpty ? null : lines.last;
  } on FileSystemException {
    return null;
  }
}
