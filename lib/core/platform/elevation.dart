bool parseIsElevated(String output, {required bool isWindows}) {
  if (isWindows) {
    return output.contains('High Mandatory Level') ||
        output.contains('System Mandatory Level');
  }
  return output.trim() == '0';
}

List<String> elevateArgs({
  required bool isWindows,
  required bool isMacOS,
  required bool isLinux,
  required String executable,
  required List<String> args,
}) {
  if (isWindows) {
    return [
      'Start-Process',
      '-FilePath',
      executable,
      if (args.isNotEmpty) ...['-ArgumentList', args.join(' ')],
      '-Verb',
      'RunAs',
    ];
  }

  if (isMacOS) {
    final command = [executable, ...args].map(_quote).join(' ');
    return ['-e', 'do shell script "$command" with administrator privileges'];
  }

  if (isLinux) {
    return ['pkexec', executable, ...args];
  }

  return [executable, ...args];
}

String _quote(String value) => "'${value.replaceAll("'", "'\\''")}'";
