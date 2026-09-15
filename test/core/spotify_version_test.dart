import 'dart:io';

import 'package:spicetify_ui/core/cli/cli_locator.dart';
import 'package:spicetify_ui/core/cli/process_runner.dart';
import 'package:spicetify_ui/core/platform/elevation.dart';
import 'package:spicetify_ui/core/platform/spotify_version.dart';
import 'package:test/test.dart';

class StubRunner implements CommandRunner {
  StubRunner(this.output, {this.exitCode = 0});
  final String output;
  final int exitCode;

  @override
  Future<CommandResult> run(
    List<String> args, {
    void Function(LogLine line)? onLine,
  }) async {
    return CommandResult(
      exitCode: exitCode,
      lines: output.isEmpty ? const [] : [LogLine(output, LogStream.stdout)],
    );
  }
}

void main() {
  group('detectSpotifyVersion', () {
    test('reads a Windows product version', () async {
      final version = await detectSpotifyVersion(
        isWindows: true,
        isMacOS: false,
        isLinux: false,
        env: const {'APPDATA': r'C:\Users\me\AppData\Roaming'},
        runnerFactory: (_, _) => StubRunner('1.3.0.277\r\n'),
      );
      expect(version, '1.3.0.277');
    });

    test('returns null on Windows when APPDATA is absent', () async {
      final version = await detectSpotifyVersion(
        isWindows: true,
        isMacOS: false,
        isLinux: false,
        env: const {},
        runnerFactory: (_, _) => StubRunner('1.3.0.277'),
      );
      expect(version, isNull);
    });

    test('reads a macOS bundle version', () async {
      final version = await detectSpotifyVersion(
        isWindows: false,
        isMacOS: true,
        isLinux: false,
        env: const {},
        runnerFactory: (_, _) => StubRunner('1.3.0.277'),
      );
      expect(version, '1.3.0.277');
    });

    test('returns null on Linux when undetectable', () async {
      final version = await detectSpotifyVersion(
        isWindows: false,
        isMacOS: false,
        isLinux: true,
        env: const {},
        runnerFactory: (_, _) => StubRunner('', exitCode: 1),
      );
      expect(version, isNull);
    });

    test('returns null when the output holds no version', () async {
      final version = await detectSpotifyVersion(
        isWindows: false,
        isMacOS: true,
        isLinux: false,
        env: const {},
        runnerFactory: (_, _) => StubRunner('command not found'),
      );
      expect(version, isNull);
    });
  });

  group('windowsSpotifyVersionArgs', () {
    test(r'inlines the quoted path instead of relying on $args', () {
      final args = windowsSpotifyVersionArgs(
        r'C:\Users\me\Spotify\Spotify.exe',
      );

      expect(args, contains('-NoProfile'));
      expect(args, contains('-Command'));
      expect(args.last, isNot(contains(r'$args')));
      expect(args.last, contains(r"'C:\Users\me\Spotify\Spotify.exe'"));
    });

    test('escapes apostrophes in the path', () {
      final args = windowsSpotifyVersionArgs(r"C:\it's here\Spotify.exe");

      expect(args.last, contains(r"'C:\it''s here\Spotify.exe'"));
    });

    test('runs through PowerShell without a parse error', () async {
      if (!Platform.isWindows) return;

      final runner = SystemCommandRunner(
        'powershell',
        baseArgs: windowsSpotifyVersionArgs(Platform.resolvedExecutable),
      );

      final result = await runner.run(const []);

      // The original bug appended the path positionally, so PowerShell parsed
      // it as part of the script and failed with "Unexpected token".
      expect(result.ok, isTrue, reason: result.output);
      expect(result.output, isNot(contains('Unexpected token')));
      expect(result.output, isNot(contains('ParserError')));
    });

    test('reads a real version from an executable', () async {
      if (!Platform.isWindows) return;

      final systemRoot = Platform.environment['SystemRoot'] ?? r'C:\Windows';
      final runner = SystemCommandRunner(
        'powershell',
        baseArgs: windowsSpotifyVersionArgs(
          '$systemRoot\\System32\\notepad.exe',
        ),
      );

      final result = await runner.run(const []);

      expect(parseVersion(result.output), isNotEmpty, reason: result.output);
    });
  });

  group('parseIsElevated', () {
    test('detects an elevated Windows token', () {
      expect(
        parseIsElevated(
          r'Mandatory Label\High Mandatory Level',
          isWindows: true,
        ),
        isTrue,
      );
    });

    test('detects a normal Windows token', () {
      expect(
        parseIsElevated(
          r'Mandatory Label\Medium Mandatory Level',
          isWindows: true,
        ),
        isFalse,
      );
    });

    test('detects root on unix', () {
      expect(parseIsElevated('0', isWindows: false), isTrue);
      expect(parseIsElevated('1000', isWindows: false), isFalse);
    });
  });

  group('elevateArgs', () {
    test('builds a Windows runas invocation', () {
      final args = elevateArgs(
        isWindows: true,
        isMacOS: false,
        isLinux: false,
        executable: r'C:\app\spicetify_ui.exe',
        args: const [],
      );
      expect(args.first, 'Start-Process');
      expect(args, contains('-Verb'));
      expect(args, contains('RunAs'));
    });

    test('forwards Windows arguments', () {
      final args = elevateArgs(
        isWindows: true,
        isMacOS: false,
        isLinux: false,
        executable: 'spicetify',
        args: const ['apply'],
      );
      expect(args, contains('-ArgumentList'));
      expect(args, contains('apply'));
    });

    test('builds a Linux pkexec invocation', () {
      final args = elevateArgs(
        isWindows: false,
        isMacOS: false,
        isLinux: true,
        executable: '/usr/bin/spicetify',
        args: const ['apply'],
      );
      expect(args, ['pkexec', '/usr/bin/spicetify', 'apply']);
    });

    test('builds a macOS osascript invocation', () {
      final args = elevateArgs(
        isWindows: false,
        isMacOS: true,
        isLinux: false,
        executable: '/usr/local/bin/spicetify',
        args: const ['apply'],
      );
      expect(args.first, '-e');
      expect(args.last, contains('administrator privileges'));
    });
  });
}
