import 'dart:convert';
import 'dart:io';

enum LogStream { stdout, stderr }

class LogLine {
  const LogLine(this.text, this.stream);

  final String text;
  final LogStream stream;

  @override
  String toString() => text;
}

class CommandResult {
  const CommandResult({required this.exitCode, required this.lines});

  final int exitCode;
  final List<LogLine> lines;

  bool get ok => exitCode == 0;

  String get output => lines.map((l) => l.text).join('\n');
}

abstract interface class CommandRunner {
  Future<CommandResult> run(List<String> args, {void Function(LogLine line)? onLine});
}

class SystemCommandRunner implements CommandRunner {
  SystemCommandRunner(this.executable, {this.baseArgs = const []});

  final String executable;
  final List<String> baseArgs;

  @override
  Future<CommandResult> run(List<String> args, {void Function(LogLine line)? onLine}) async {
    final process = await Process.start(
      executable,
      [...baseArgs, ...args],
      runInShell: false,
    );

    final lines = <LogLine>[];

    void collect(Stream<List<int>> source, LogStream kind) {
      source
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((text) {
        final line = LogLine(text, kind);
        lines.add(line);
        onLine?.call(line);
      });
    }

    collect(process.stdout, LogStream.stdout);
    collect(process.stderr, LogStream.stderr);

    final code = await process.exitCode;
    return CommandResult(exitCode: code, lines: lines);
  }
}
