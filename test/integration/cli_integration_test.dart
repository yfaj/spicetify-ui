import 'dart:io';

import 'package:spicetify_ui/core/cli/cli_bridge.dart';
import 'package:spicetify_ui/core/cli/cli_locator.dart';
import 'package:spicetify_ui/core/cli/process_runner.dart';
import 'package:spicetify_ui/core/platform/platform_paths.dart';
import 'package:test/test.dart';

void main() {
  final enabled = Platform.environment['SPICETIFY_INTEGRATION'] == '1';

  test('locates the real CLI and reads its version', () async {
    final env = Platform.environment;
    final home = env['HOME'] ?? env['USERPROFILE'] ?? '';
    final isWindows = Platform.isWindows;

    final locator = CliLocator(
      probe: const RealFileProbe(),
      runnerFactory: (executable) => SystemCommandRunner(executable),
      knownPaths: knownCliPaths(
        isWindows: isWindows,
        isMacOS: Platform.isMacOS,
        isLinux: Platform.isLinux,
        home: home,
        env: env,
      ),
      environment: env,
      executableName: cliExecutableName(isWindows: isWindows),
    );

    final candidate = await locator.locate();
    expect(candidate, isNotNull);

    final bridge = CliBridge(SystemCommandRunner(candidate!.path));
    expect(await bridge.version(), isNotEmpty);
  }, skip: enabled ? null : 'SPICETIFY_INTEGRATION is not set to 1');
}
