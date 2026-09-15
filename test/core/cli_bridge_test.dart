import 'package:spicetify_ui/core/cli/cli_bridge.dart';
import 'package:spicetify_ui/core/cli/process_runner.dart';
import 'package:test/test.dart';

class RecordingRunner implements CommandRunner {
  RecordingRunner(this.response);
  final String response;
  final List<List<String>> calls = [];

  @override
  Future<CommandResult> run(List<String> args, {void Function(LogLine line)? onLine}) async {
    calls.add(args);
    return CommandResult(
      exitCode: 0,
      lines: response.isEmpty ? const [] : [LogLine(response, LogStream.stdout)],
    );
  }
}

void main() {
  group('buildSetArgs', () {
    test('uses a plain key value pair for normal keys', () {
      expect(buildSetArgs('inject_css', '1'), ['config', 'inject_css', '1']);
    });

    test('inserts -- before spotify_launch_flags values', () {
      expect(
        buildSetArgs('spotify_launch_flags', '--remote-debugging-port=9222'),
        ['config', 'spotify_launch_flags', '--', '--remote-debugging-port=9222'],
      );
    });

    test('inserts -- even for an empty launch flags value', () {
      expect(buildSetArgs('spotify_launch_flags', ''), ['config', 'spotify_launch_flags', '--', '']);
    });
  });

  group('parseColorSchemes', () {
    test('reads section names from a color.ini', () {
      const text = '[Dark]\nmain = ff0000\n\n[Light]\nmain = ffffff\n';
      expect(parseColorSchemes(text), ['Dark', 'Light']);
    });

    test('returns empty for an empty file', () {
      expect(parseColorSchemes(''), isEmpty);
    });
  });

  group('CliBridge', () {
    test('reads a config from the file the CLI points at', () async {
      final runner = RecordingRunner(r'/tmp/config.ini');
      final bridge = CliBridge(
        runner,
        configFileReader: (_) => '[Setting]\ncurrent_theme = marketplace\n',
      );

      final config = await bridge.readConfig();

      expect(config!.value('Setting', 'current_theme'), 'marketplace');
    });

    test('returns null when the CLI reports no config path', () async {
      final runner = RecordingRunner('');
      final bridge = CliBridge(runner, configFileReader: (_) => 'x');

      expect(await bridge.readConfig(), isNull);
    });

    test('sets a value through the CLI', () async {
      final runner = RecordingRunner('');
      final bridge = CliBridge(runner);

      await bridge.setValue('current_theme', 'Sleek');

      expect(runner.calls.single, ['config', 'current_theme', 'Sleek']);
    });

    test('runs apply with no extra arguments', () async {
      final runner = RecordingRunner('');
      final bridge = CliBridge(runner);

      await bridge.apply();

      expect(runner.calls.single, ['apply']);
    });

    test('blocks and unblocks updates through the CLI', () async {
      final runner = RecordingRunner('');
      final bridge = CliBridge(runner);

      await bridge.blockUpdates();
      await bridge.unblockUpdates();

      expect(runner.calls, [
        ['spotify-updates', 'block'],
        ['spotify-updates', 'unblock'],
      ]);
    });

    test('parses a version out of --version output', () async {
      final runner = RecordingRunner('spicetify v2.45.0');
      final bridge = CliBridge(runner);

      expect(await bridge.version(), '2.45.0');
    });

    test('lists themes from the userdata directory', () async {
      final runner = RecordingRunner(r'/tmp/userdata');
      final bridge = CliBridge(
        runner,
        directoryLister: (path) => path.endsWith('Themes') ? ['Sleek', 'Bloom'] : const [],
      );

      expect(await bridge.listThemes(), ['Sleek', 'Bloom']);
    });

    test('lists color schemes for a theme', () async {
      final runner = RecordingRunner('/tmp/userdata');
      final bridge = CliBridge(
        runner,
        configFileReader: (path) =>
            path.endsWith('color.ini') ? '[Dark]\nmain = ff0000\n' : '',
      );

      expect(await bridge.listColorSchemes('Sleek'), ['Dark']);
    });
  });
}
