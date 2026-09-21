import 'dart:io';

import 'package:spicetify_ui/core/cli/process_runner.dart';

const String autoReapplyTaskName = 'Spicetify UI Auto Reapply';
const int autoReapplyIntervalMinutes = 15;

abstract interface class TaskScheduler {
  /// False where no supported scheduler exists, so the UI can hide the
  /// control rather than show an off toggle for a feature that is absent.
  bool get isSupported;

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

  @override
  bool get isSupported => true;

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
  bool get isSupported => false;

  @override
  Future<bool> isRegistered() async => false;

  @override
  Future<bool> register(String executable) async => false;

  @override
  Future<bool> unregister() async => false;
}

TaskScheduler taskSchedulerFor({
  required bool isWindows,
  bool? isLinux,
  CommandRunner Function(String executable)? runnerFactory,
  String? home,
}) {
  if (isWindows) {
    return WindowsTaskScheduler(runnerFactory: runnerFactory);
  }
  if (isLinux ?? Platform.isLinux) {
    return SystemdTaskScheduler(runnerFactory: runnerFactory, home: home);
  }
  return const UnsupportedTaskScheduler();
}

/// Per-user systemd timer. Two unit files under the user's config directory
/// and `systemctl --user` to enable them, so no elevation is ever involved.
class SystemdTaskScheduler implements TaskScheduler {
  SystemdTaskScheduler({
    CommandRunner Function(String executable)? runnerFactory,
    String? home,
  }) : _runnerFactory = runnerFactory ?? SystemCommandRunner.new,
       _home = home ??
           Platform.environment['HOME'] ??
           Platform.environment['USERPROFILE'] ??
           '.';

  final CommandRunner Function(String executable) _runnerFactory;
  final String _home;

  static const String unitName = 'spicetify-ui-autoreapply';

  String get _servicePath =>
      '$_home/.config/systemd/user/$unitName.service';
  String get _timerPath => '$_home/.config/systemd/user/$unitName.timer';

  String serviceUnit(String executable) =>
      '[Unit]\n'
      'Description=Spicetify UI auto re-apply check\n\n'
      '[Service]\n'
      'Type=oneshot\n'
      'ExecStart="$executable" --check\n';

  String timerUnit() =>
      '[Unit]\n'
      'Description=Re-apply the Spicetify patch every '
      '$autoReapplyIntervalMinutes minutes\n\n'
      '[Timer]\n'
      'OnBootSec=${autoReapplyIntervalMinutes}min\n'
      'OnUnitActiveSec=${autoReapplyIntervalMinutes}min\n\n'
      '[Install]\n'
      'WantedBy=timers.target\n';

  Future<bool> _systemctl(List<String> args) async {
    final result = await _runnerFactory(
      'systemctl',
    ).run(['--user', ...args]);
    return result.ok;
  }

  @override
  bool get isSupported =>
      Directory('/run/systemd/system').existsSync() ||
      Directory('/run/user/${Platform.environment['UID'] ?? ''}')
          .existsSync();

  @override
  Future<bool> isRegistered() async => _systemctl([
    'is-enabled',
    '$unitName.timer',
  ]);

  @override
  Future<bool> register(String executablePath) async {
    try {
      final dir = Directory('$_home/.config/systemd/user');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      File(_servicePath).writeAsStringSync(serviceUnit(executablePath));
      File(_timerPath).writeAsStringSync(timerUnit());
    } on FileSystemException {
      return false;
    }

    final reloaded = await _systemctl(['daemon-reload']);
    final enabled = await _systemctl(['enable', '--now', '$unitName.timer']);
    return reloaded && enabled;
  }

  @override
  Future<bool> unregister() async {
    final disabled = await _systemctl(['disable', '--now', '$unitName.timer']);
    try {
      final service = File(_servicePath);
      final timer = File(_timerPath);
      if (service.existsSync()) service.deleteSync();
      if (timer.existsSync()) timer.deleteSync();
    } on FileSystemException {
      return false;
    }
    await _systemctl(['daemon-reload']);
    return disabled;
  }
}

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
