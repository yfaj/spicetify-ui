import 'package:flutter/material.dart';
import 'package:spicetify_ui/core/cli/process_runner.dart';

class LogDrawer extends StatelessWidget {
  const LogDrawer({super.key, required this.lines, this.height = 150});

  final List<LogLine> lines;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: height,
      width: double.infinity,
      color: const Color(0xFF0A0A0A),
      child: lines.isEmpty
          ? Center(
              child: Text('no output yet', style: theme.textTheme.bodySmall),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: lines.length,
              itemBuilder: (context, index) {
                final line = lines[index];
                return Text(
                  line.text,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    color: line.stream == LogStream.stderr
                        ? const Color(0xFFEF4444)
                        : null,
                  ),
                );
              },
            ),
    );
  }
}
