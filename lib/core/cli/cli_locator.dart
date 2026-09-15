import 'dart:io';

import 'package:spicetify_ui/core/cli/process_runner.dart';

enum CliSource { override, path, knownLocation }

class CliCandidate {
  const CliCandidate({
    required this.path,
    required this.source,
    required this.version,
  });

  final String path;
  final CliSource source;
  final String version;
}

abstract interface class FileProbe {
  bool exists(String path);
}

class RealFileProbe implements FileProbe {
  const RealFileProbe();

  @override
  bool exists(String path) {
    final type = FileSystemEntity.typeSync(path);
    return type == FileSystemEntityType.file ||
        type == FileSystemEntityType.link;
  }
}

final _versionPattern = RegExp(r'(\d+\.\d+\.\d+)');

String parseVersion(String output) {
  final match = _versionPattern.firstMatch(output);
  return match?.group(1) ?? '';
}

class CliLocator {
  CliLocator({
    required this.probe,
    required this.runnerFactory,
    required this.knownPaths,
    required this.environment,
    this.executableName = 'spicetify',
    this.overridePath,
  });

  final FileProbe probe;
  final CommandRunner Function(String executable) runnerFactory;
  final List<String> knownPaths;
  final Map<String, String> environment;
  final String executableName;
  final String? overridePath;

  List<String> _pathEntries() {
    final raw = environment['PATH'] ?? environment['Path'] ?? '';
    if (raw.isEmpty) return const [];
    final separator = Platform.isWindows ? ';' : ':';
    return raw
        .split(separator)
        .where((entry) => entry.trim().isNotEmpty)
        .toList();
  }

  Future<CliCandidate?> _probe(String path, CliSource source) async {
    if (!probe.exists(path)) return null;

    final CommandResult result;
    try {
      result = await runnerFactory(path).run(const ['--version']);
    } catch (_) {
      return null;
    }
    if (!result.ok) return null;

    final version = parseVersion(result.output);
    if (version.isEmpty) return null;

    return CliCandidate(path: path, source: source, version: version);
  }

  Future<List<CliCandidate>> locateAll() async {
    final found = <CliCandidate>[];
    final seen = <String>{};

    Future<void> consider(String path, CliSource source) async {
      if (!seen.add(path)) return;
      final candidate = await _probe(path, source);
      if (candidate != null) found.add(candidate);
    }

    final override = overridePath;
    if (override != null && override.isNotEmpty) {
      await consider(override, CliSource.override);
    }

    final separator = Platform.isWindows ? '\\' : '/';
    for (final entry in _pathEntries()) {
      final dir = entry.trim().replaceAll(RegExp(r'[\\/]+$'), '');
      if (dir.isEmpty) continue;
      await consider('$dir$separator$executableName', CliSource.path);
    }

    for (final path in knownPaths) {
      await consider(path, CliSource.knownLocation);
    }

    return found;
  }

  Future<CliCandidate?> locate() async {
    final all = await locateAll();
    return all.isEmpty ? null : all.first;
  }
}
