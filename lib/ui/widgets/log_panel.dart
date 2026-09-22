import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/services.dart';
import 'package:spicetify_ui/core/cli/process_runner.dart';

/// A log view that floats above the content as its own small window: a fixed
/// card, elevated, with a title bar you can drag it around by.
class LogPanel extends StatefulWidget {
  const LogPanel({
    super.key,
    required this.lines,
    required this.onClear,
    required this.busy,
    this.historyBoundary,
    this.width = 220,
  });

  final List<LogLine> lines;
  final VoidCallback onClear;

  /// True while a command is running.
  final bool busy;

  /// Index in [lines] where the running task's output begins. Lines before it
  /// are the previous task's history and render faded while a task runs.
  final int? historyBoundary;

  final double width;

  @override
  State<LogPanel> createState() => _LogPanelState();
}

class _LogPanelState extends State<LogPanel> {
  final ScrollController _scroll = ScrollController();

  /// True while the view sits at the bottom. The controller hands us the
  /// same growing list instance every rebuild, so a length comparison can
  /// never detect new lines; instead we chase the end on every rebuild and
  /// release the chase only when the user scrolls up themselves.
  bool _pinned = true;

  @override
  void didUpdateWidget(LogPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_pinned) {
      _scrollToEnd();
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  /// Tracks whether the user scrolled away from the bottom on purpose.
  bool _onScrollNotification(ScrollNotification notification) {
    if (notification is! UserScrollNotification) return false;
    final user = notification;
    switch (user.direction) {
      case ScrollDirection.forward:
        setState(() => _pinned = true);
        _scrollToEnd();
      case ScrollDirection.reverse:
        _pinned = false;
      case ScrollDirection.idle:
        break;
    }
    return false;
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
      padding: const EdgeInsets.fromLTRB(10, 10, 0, 10),
      child: SizedBox(
        width: widget.width,
        child: AnimatedOpacity(
          // Dim while a command runs, restore when it finishes.
          duration: const Duration(milliseconds: 300),
          opacity: widget.busy ? 0.45 : 1.0,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF141414),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF3A3A3A)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(17),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 38,
                    child: Row(
                      children: [
                        const SizedBox(width: 12),
                        Icon(Icons.subject, size: 14, color: theme.hintColor),
                        const SizedBox(width: 8),
                        Text('Log', style: theme.textTheme.bodyMedium),
                        const SizedBox(width: 8),
                        Text(
                          '${widget.lines.length}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.hintColor,
                          ),
                        ),
                        const Spacer(),
                        if (widget.lines.isNotEmpty)
                          _PanelButton(
                            icon: Icons.copy_all_outlined,
                            tooltip: 'Copy all',
                            onTap: () => Clipboard.setData(
                              ClipboardData(
                                text: widget.lines
                                    .map((line) => line.text)
                                    .join('\n'),
                              ),
                            ),
                          ),
                        if (widget.lines.isNotEmpty)
                          _PanelButton(
                            icon: Icons.delete_outline,
                            tooltip: 'Clear log',
                            onTap: widget.onClear,
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
                        : SelectionArea(
                            child: NotificationListener<ScrollNotification>(
                              onNotification: _onScrollNotification,
                              child: ListView.builder(
                                controller: _scroll,
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  8,
                                  12,
                                  12,
                                ),
                                itemCount: widget.lines.length,
                                itemBuilder: (context, index) {
                                  final line = widget.lines[index];
                                  final color = switch (line.stream) {
                                    LogStream.stderr ||
                                    LogStream.error => const Color(0xFFEF4444),
                                    LogStream.success => const Color(
                                      0xFF4ADE80,
                                    ),
                                    LogStream.stdout => null,
                                  };
                                  // While a task runs, everything from the
                                  // previous task sinks into the background so
                                  // the new output reads as the live one.
                                  final isHistory =
                                      widget.busy &&
                                      widget.historyBoundary != null &&
                                      index < widget.historyBoundary!;
                                  return AnimatedOpacity(
                                    duration: const Duration(milliseconds: 300),
                                    opacity: isHistory ? 0.35 : 1.0,
                                    child: Text(
                                      line.text,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            fontFamily: 'monospace',
                                            fontSize: 10.5,
                                            color: color,
                                          ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PanelButton extends StatelessWidget {
  const _PanelButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(width: 34, height: 38, child: Icon(icon, size: 14)),
      ),
    );
  }
}
