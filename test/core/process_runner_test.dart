import 'dart:io';

import 'package:spicetify_ui/core/cli/process_runner.dart';
import 'package:test/test.dart';

void main() {
  group('SystemCommandRunner', () {
    test('captures stdout and a zero exit code', () async {
      final runner = SystemCommandRunner(
        Platform.isWindows ? 'cmd.exe' : 'echo',
        baseArgs: Platform.isWindows
            ? const ['/c', 'echo hello']
            : const ['hello'],
      );

      final result = await runner.run(const []);

      expect(result.exitCode, 0);
      expect(result.output, contains('hello'));
    });

    test('captures a non-zero exit code', () async {
      if (!Platform.isWindows) return;
      final runner = SystemCommandRunner(
        'cmd.exe',
        baseArgs: const ['/c', 'exit 3'],
      );

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

    test('returns a complete, unmodifiable multi-line result', () async {
      final runner = Platform.isWindows
          ? SystemCommandRunner(
              'cmd.exe',
              baseArgs: const ['/c', 'echo a&echo b&echo c'],
            )
          : SystemCommandRunner(
              '/bin/sh',
              baseArgs: const ['-c', 'printf "a\\nb\\nc\\n"'],
            );

      final result = await runner.run(const []);

      expect(result.lines.map((l) => l.text), ['a', 'b', 'c']);
      expect(
        () => result.lines.add(const LogLine('x', LogStream.stdout)),
        throwsUnsupportedError,
      );
    });

    test('strips ANSI escape sequences from captured lines', () async {
      final runner = Platform.isWindows
          ? SystemCommandRunner(
              'cmd.exe',
              baseArgs: const [
                '/c',
                'echo \x1B[96m\x1B[96m-\x1B[0m\x1B[0m \x1B[97mok\x1B[0m',
              ],
            )
          : SystemCommandRunner(
              '/bin/sh',
              baseArgs: const [
                '-c',
                r'printf "\033[96m\033[96m-\033[0m\033[0m \033[97mok\033[0m\n"',
              ],
            );

      final result = await runner.run(const []);

      expect(result.output, '- ok');
      expect(result.output, isNot(contains('\x1B')));
    });
  });

  group('stripAnsi', () {
    test('removes CSI colour codes', () {
      expect(
        stripAnsi('\x1B[96m\x1B[96m-\x1B[0m\x1B[0m \x1B[97mApplying\x1B[0m'),
        '- Applying',
      );
    });

    test('removes a leading success marker and keeps the message', () {
      expect(
        stripAnsi(
          '\x1B[32m\x1B[32m success \x1B[0m\x1B[0m Applied additional modifications',
        ),
        ' success  Applied additional modifications',
      );
    });

    test('leaves plain text untouched', () {
      expect(stripAnsi('plain text'), 'plain text');
    });

    test('removes an OSC sequence terminated by BEL', () {
      expect(stripAnsi('\x1B]0;title\x07after'), 'after');
    });
  });
}
