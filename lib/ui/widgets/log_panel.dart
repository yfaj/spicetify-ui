import 'package:flutter/material.dart';
import 'package:spicetify_ui/core/cli/process_runner.dart';

/// A log view that reads as a second floating window docked to the left of
/// the content, rather than a drawer inside it. Same window, own chrome.
class LogPanel extends StatefulWidget {
  const LogPanel({
    super.key,
    required this.lines,
    required this.onClose,
    this.width = 250,
  });

  final List<LogLine> lines;
  final VoidCallback onClose;
  final double width;

  @override
  State<LogPanel> createState() => _LogPanelState();
}

class _LogPanelState extends State<LogPanel> {
  final ScrollController _scroll = ScrollController();

  @override
  void didUpdateWidget(LogPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.lines.length != oldWidget.lines.length) {
      _scrollToEnd();
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 0, 0),
      child: Container(
        width: widget.width,
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A0A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 4),
              child: Row(
                children: [
                  Text(
                    'LOG',
                    style: theme.textTheme.labelSmall?.copyWith(
                      letterSpacing: 1.1,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${widget.lines.length}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 14),
                    tooltip: 'Hide log',
                    visualDensity: VisualDensity.compact,
                    onPressed: widget.onClose,
                  ),
                ],
              ),
            ),
            Expanded(
              child: widget.lines.isEmpty
                  ? Center(
                      child: Text(
                        'no output yet',
                        style: theme.textTheme.bodySmall,
                      ),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                      itemCount: widget.lines.length,
                      itemBuilder: (context, index) {
                        final line = widget.lines[index];
                        return Text(
                          line.text,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                            fontSize: 10.5,
                            color: line.stream == LogStream.stderr
                                ? const Color(0xFFEF4444)
                                : null,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
