import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:spicetify_ui/core/cli/process_runner.dart';
import 'package:spicetify_ui/ui/shell/app_window.dart';

/// A log view that floats above the content as its own small window: a fixed
/// card, elevated, with a title bar you can drag it around by.
class LogPanel extends StatefulWidget {
  const LogPanel({
    super.key,
    required this.lines,
    required this.onClose,
    required this.onClear,
    this.width = 220,
  });

  final List<LogLine> lines;
  final VoidCallback onClose;
  final VoidCallback onClear;
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
    final divider = theme.dividerColor.withValues(alpha: 0.5);

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 0, 10),
      child: SizedBox(
        width: widget.width,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF141414),
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [
              BoxShadow(
                color: cardShadow,
                blurRadius: 14,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9),
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
                      _PanelButton(
                        icon: Icons.close,
                        tooltip: 'Hide log',
                        onTap: widget.onClose,
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: divider),
                Expanded(
                  child: widget.lines.isEmpty
                      ? Center(
                          child: Text(
                            'no output yet',
                            style: theme.textTheme.bodySmall,
                          ),
                        )
                      : SelectionArea(
                          child: ListView.builder(
                            controller: _scroll,
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
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
                ),
              ],
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
