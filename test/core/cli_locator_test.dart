import 'dart:io';

import 'package:spicetify_ui/core/cli/cli_locator.dart';
import 'package:spicetify_ui/core/cli/process_runner.dart';
import 'package:spicetify_ui/core/platform/platform_paths.dart';
import 'package:test/test.dart';

class FakeProbe implements FileProbe {
  FakeProbe(this.existing);
  final Set<String> existing;

  @override
  bool exists(String path) => existing.contains(path);
}

class FakeRunner implements CommandRunner {
  FakeRunner(this.version, {this.exitCode = 0});
  final String version;
  final int exitCode;

  @override
  Future<CommandResult> run(
    List<String> args, {
    void Function(LogLine line)? onLine,
  }) async {
    return CommandResult(
      exitCode: exitCode,
      lines: [LogLine(version, LogStream.stdout)],
    );
  }
}

class ThrowingRunner implements CommandRunner {
  @override
  Future<CommandResult> run(
    List<String> args, {
    void Function(LogLine line)? onLine,
  }) async {
    throw ProcessException('spicetify', args, 'not executable');
  }
}

void main() {
  group('parseVersion', () {
    test('reads a plain version line', () {
      expect(parseVersion('2.45.0'), '2.45.0');
    });

    test('reads a prefixed version line', () {
      expect(parseVersion('spicetify v2.45.0'), '2.45.0');
    });

    test('returns empty when there is no version', () {
      expect(parseVersion('nope'), '');
    });
  });

  group('CliLocator', () {
    test('returns nothing when no candidate exists', () async {
      final locator = CliLocator(
        probe: FakeProbe({}),
        runnerFactory: (_) => FakeRunner('2.45.0'),
        knownPaths: const [r'C:\tools\spicetify.exe'],
        environment: const {'PATH': ''},
      );

      expect(await locator.locateAll(), isEmpty);
      expect(await locator.locate(), isNull);
    });

    test('finds a known location and reads its version', () async {
      final locator = CliLocator(
        probe: FakeProbe({r'C:\tools\spicetify.exe'}),
        runnerFactory: (_) => FakeRunner('spicetify v2.45.0'),
        knownPaths: const [r'C:\tools\spicetify.exe'],
        environment: const {'PATH': ''},
      );

      final candidates = await locator.locateAll();

      expect(candidates, hasLength(1));
      expect(candidates.single.source, CliSource.knownLocation);
      expect(candidates.single.version, '2.45.0');
    });

    test('finds a binary on PATH', () async {
      if (!Platform.isWindows) return;
      final locator = CliLocator(
        probe: FakeProbe({r'C:\bin\spicetify.exe'}),
        runnerFactory: (_) => FakeRunner('2.45.0'),
        knownPaths: const [],
        environment: const {'PATH': r'C:\other;C:\bin'},
        executableName: 'spicetify.exe',
      );

      final candidates = await locator.locateAll();

      expect(candidates.single.source, CliSource.path);
      expect(candidates.single.path, r'C:\bin\spicetify.exe');
    });

    test('prefers the override path', () async {
      final locator = CliLocator(
        probe: FakeProbe({r'C:\custom\spicetify.exe', r'C:\bin\spicetify.exe'}),
        runnerFactory: (_) => FakeRunner('2.45.0'),
        knownPaths: const [],
        environment: const {'PATH': r'C:\bin'},
        executableName: 'spicetify.exe',
        overridePath: r'C:\custom\spicetify.exe',
      );

      final candidates = await locator.locateAll();

      expect(candidates.first.source, CliSource.override);
      expect(candidates.first.path, r'C:\custom\spicetify.exe');
    });

    test('skips a candidate whose --version fails', () async {
      final locator = CliLocator(
        probe: FakeProbe({r'C:\tools\spicetify.exe'}),
        runnerFactory: (_) => FakeRunner('', exitCode: 1),
        knownPaths: const [r'C:\tools\spicetify.exe'],
        environment: const {'PATH': ''},
      );

      expect(await locator.locateAll(), isEmpty);
    });

    test('skips a throwing candidate and keeps scanning', () async {
      final locator = CliLocator(
        probe: FakeProbe({r'C:\bad\spicetify.exe', r'C:\good\spicetify.exe'}),
        runnerFactory: (executable) => executable.contains('bad')
            ? ThrowingRunner()
            : FakeRunner('2.45.0'),
        knownPaths: const [r'C:\bad\spicetify.exe', r'C:\good\spicetify.exe'],
        environment: const {'PATH': ''},
      );

      final candidates = await locator.locateAll();

      expect(candidates, hasLength(1));
      expect(candidates.single.path, r'C:\good\spicetify.exe');
      expect(candidates.single.version, '2.45.0');
    });

    test('does not report the same path twice', () async {
      final locator = CliLocator(
        probe: FakeProbe({r'C:\bin\spicetify.exe'}),
        runnerFactory: (_) => FakeRunner('2.45.0'),
        knownPaths: const [r'C:\bin\spicetify.exe'],
        environment: const {'PATH': r'C:\bin'},
        executableName: 'spicetify.exe',
      );

      expect(await locator.locateAll(), hasLength(1));
    });
  });

  group('knownCliPaths', () {
    test('lists Windows locations', () {
      final paths = knownCliPaths(
        isWindows: true,
        isMacOS: false,
        isLinux: false,
        home: r'C:\Users\me',
        env: const {'LOCALAPPDATA': r'C:\Users\me\AppData\Local'},
      );
      expect(
        paths,
        contains(r'C:\Users\me\AppData\Local\spicetify\spicetify.exe'),
      );
      expect(paths, contains(r'C:\Users\me\.spicetify\spicetify.exe'));
    });

    test('lists Linux locations', () {
      final paths = knownCliPaths(
        isWindows: false,
        isMacOS: false,
        isLinux: true,
        home: '/home/me',
        env: const {},
      );
      expect(paths, contains('/home/me/.spicetify/spicetify'));
      expect(paths, contains('/usr/local/bin/spicetify'));
      expect(paths, contains('/usr/bin/spicetify'));
      expect(paths, isNot(contains('/opt/homebrew/bin/spicetify')));
    });

    test('lists macOS locations', () {
      final paths = knownCliPaths(
        isWindows: false,
        isMacOS: true,
        isLinux: false,
        home: '/Users/me',
        env: const {},
      );
      expect(paths, contains('/opt/homebrew/bin/spicetify'));
      expect(paths, contains('/usr/local/bin/spicetify'));
    });
  });
}
