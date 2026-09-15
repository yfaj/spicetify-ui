import 'dart:io';

import 'package:spicetify_ui/core/cli/process_runner.dart';
import 'package:test/test.dart';

void main() {
  group('SystemCommandRunner', () {
    test('captures stdout and a zero exit code', () async {
      final runner = SystemCommandRunner(
        Platform.isWindows ? 'cmd.exe' : 'echo',
        baseArgs: Platform.isWindows ? const ['/c', 'echo hello'] : const ['hello'],
      );

      final result = await runner.run(const []);

      expect(result.exitCode, 0);
      expect(result.output, contains('hello'));
    });

    test('captures a non-zero exit code', () async {
      if (!Platform.isWindows) return;
      final runner = SystemCommandRunner('cmd.exe', baseArgs: const ['/c', 'exit 3']);

      final result = await runner.run(const []);

      expect(result.exitCode, 3);
      expect(result.ok, isFalse);
    });

    test('reports each line through onLine', () async {
      final runner = SystemCommandRunner(
        Platform.isWindows ? 'cmd.exe' : 'echo',
        baseArgs: Platform.isWindows ? const ['/c', 'echo a'] : const ['a'],
      );
      final seen = <String>[];

      await runner.run(const [], onLine: (line) => seen.add(line.text));

      expect(seen.any((t) => t.contains('a')), isTrue);
    });
  });
}
