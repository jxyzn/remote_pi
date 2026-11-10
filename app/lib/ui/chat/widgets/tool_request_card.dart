import 'package:app/domain/session_state.dart';
import 'package:app/protocol/protocol.dart';
import 'package:app/ui/core/themes/themes.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

// Inline tool execution card that appears in the chat flow.
//
// Supports three session verbosity levels:
// - terse: all tool calls initially collapsed into a single line; tap to expand.
// - default: active and most recent tool calls are expanded, older completed calls
//   auto-collapse, failed calls stay open.
// - verbose: all tool calls are left expanded unless their header is clicked.
//
// `onDecide` is kept on the API for forward compat — when the Pi adds a
// real approval pause we can re-enable the controls. Today it is unused.

class ToolRequestCard extends StatefulWidget {
  final ToolEvent tool;
  final SessionVerbosity verbosity;
  final bool isRecent;
  final bool? initiallyExpanded;
  final ValueChanged<bool>? onExpandedChanged;
  final void Function(String toolCallId, ApproveDecision decision)? onDecide;

  const ToolRequestCard({
    super.key,
    required this.tool,
    this.verbosity = SessionVerbosity.defaultLevel,
    this.isRecent = true,
    this.initiallyExpanded,
    this.onExpandedChanged,
    this.onDecide,
  });

  @override
  State<ToolRequestCard> createState() => _ToolRequestCardState();
}

class _ToolRequestCardState extends State<ToolRequestCard> {
  bool? _userExpanded;

  @override
  void initState() {
    super.initState();
    _userExpanded = widget.initiallyExpanded;
  }

  static bool defaultExpanded(
    ToolEventStatus status,
    SessionVerbosity verbosity, {
    bool isRecent = true,
  }) {
    return switch (verbosity) {
      SessionVerbosity.terse => false,
      SessionVerbosity.verbose => true,
      SessionVerbosity.defaultLevel => switch (status) {
        ToolEventStatus.pending || ToolEventStatus.allowed => true,
        ToolEventStatus.completed => isRecent,
        ToolEventStatus.failed ||
        ToolEventStatus.denied ||
        ToolEventStatus.expired => true,
      },
    };
  }

  bool get _isExpanded =>
      _userExpanded ??
      defaultExpanded(
        widget.tool.status,
        widget.verbosity,
        isRecent: widget.isRecent,
      );

  @override
  void didUpdateWidget(covariant ToolRequestCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the global verbosity setting changed or this card was rebound to
    // a different tool ID, reset any manual user twiddle to follow the new mode.
    if (oldWidget.verbosity != widget.verbosity ||
        oldWidget.tool.id != widget.tool.id) {
      _userExpanded = widget.initiallyExpanded;
    } else if (oldWidget.initiallyExpanded != widget.initiallyExpanded) {
      _userExpanded = widget.initiallyExpanded;
    }
  }

  void _toggleExpanded() {
    final next = !_isExpanded;
    setState(() {
      _userExpanded = next;
    });
    widget.onExpandedChanged?.call(next);
  }

  /// Plan/32 — one color drives the whole card so the outcome is unmistakable:
  /// running → blue, done → green, failed → red, denied/expired → grey.
  Color _statusColor(BuildContext context) {
    final colors = context.colors;
    return switch (widget.tool.status) {
      ToolEventStatus.pending || ToolEventStatus.allowed => colors.accent,
      ToolEventStatus.completed => colors.success,
      ToolEventStatus.failed => colors.error,
      ToolEventStatus.denied || ToolEventStatus.expired => colors.muted,
    };
  }

  String _statusLabel() {
    return switch (widget.tool.status) {
      ToolEventStatus.pending || ToolEventStatus.allowed => 'RUNNING',
      ToolEventStatus.completed => 'DONE',
      ToolEventStatus.failed => 'FAILED',
      ToolEventStatus.denied => 'DENIED',
      ToolEventStatus.expired => 'EXPIRED',
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(context);
    // Dim only the inert states (denied/expired); keep done/failed at full
    // opacity so their green/red read clearly.
    final dimmed =
        widget.tool.status == ToolEventStatus.denied ||
        widget.tool.status == ToolEventStatus.expired;
    final expanded = _isExpanded;

    return Opacity(
      opacity: dimmed ? 0.65 : 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          border: Border.all(color: color, width: 1),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.13),
              blurRadius: 20,
              spreadRadius: 1,
            ),
          ],
        ),
        padding: EdgeInsets.symmetric(
          horizontal: 14,
          vertical: expanded ? 14 : 10,
        ),
        child: expanded
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(context, color, expanded: true),
                  const SizedBox(height: 10),
                  _buildCodeBlock(context),
                  const SizedBox(height: 8),
                  _buildOutcome(color),
                ],
              )
            : _buildHeader(context, color, expanded: false),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    Color color, {
    required bool expanded,
  }) {
    final typo = context.typo;
    final colors = context.colors;
    final summary = expanded
        ? ''
        : _formatOneLineSummary(widget.tool.tool, widget.tool.args);

    return InkWell(
      onTap: _toggleExpanded,
      borderRadius: BorderRadius.circular(6),
      child: Row(
        children: [
          CustomPaint(
            size: const Size(14, 14),
            painter: _TerminalIconPainter(color: color),
          ),
          const SizedBox(width: 8),
          Text(
            widget.tool.tool.toUpperCase(),
            style: TextStyle(
              fontFamily: kMonoFamily,
              fontSize: 11.5,
              color: color,
              letterSpacing: 0.6,
            ),
          ),
          if (summary.isNotEmpty) ...[
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                summary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: typo.monoSmall.copyWith(
                  color: colors.muted2,
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(width: 6),
          ] else
            const Spacer(),
          Text(
            _statusLabel(),
            style: TextStyle(
              fontFamily: kMonoFamily,
              fontSize: 10,
              color: color,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            expanded ? LucideIcons.chevronDown : LucideIcons.chevronRight,
            size: 14,
            color: color.withValues(alpha: 0.7),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeBlock(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final content = _buildToolSummary(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.codeBg,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(r'$ ', style: typo.mono.copyWith(color: colors.muted)),
          Expanded(child: content),
        ],
      ),
    );
  }

  Widget _buildToolSummary(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final display = _formatToolDisplay(widget.tool.tool, widget.tool.args);
    if (display == null) {
      return Text(_formatArgs(widget.tool.tool, widget.tool.args), style: typo.mono);
    }

    return Text.rich(
      TextSpan(
        style: typo.mono,
        children: [
          TextSpan(text: display.command),
          for (final line in display.lines) ...[
            const TextSpan(text: '\n'),
            TextSpan(
              text: line.text,
              style: TextStyle(color: line.color(colors)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOutcome(Color color) {
    final text = switch (widget.tool.status) {
      ToolEventStatus.pending || ToolEventStatus.allowed => '⏳ Running…',
      ToolEventStatus.completed => '✓ Done',
      ToolEventStatus.failed => '✗ ${widget.tool.error ?? "Failed"}',
      ToolEventStatus.denied => '✗ ${widget.tool.error ?? "Denied"}',
      ToolEventStatus.expired => '✗ Expired',
    };
    return Text(
      text,
      style: TextStyle(fontFamily: kMonoFamily, fontSize: 12, color: color),
    );
  }

  static String _formatOneLineSummary(String tool, dynamic args) {
    if (args is Map &&
        (tool.toLowerCase() == 'edit' || tool.toLowerCase() == 'write')) {
      return _stringArg(args, const ['file_path', 'path']);
    }
    return _formatArgs(tool, args).replaceAll('\n', ' ').trim();
  }

  static String _formatArgs(String tool, dynamic args) {
    if (args == null) return '';
    final normalizedTool = tool.toLowerCase();
    if (args is Map) {
      return switch (normalizedTool) {
        'bash' => (args['command'] as String?) ?? '',
        'edit' || 'write' =>
          '$normalizedTool ${_stringArg(args, const ['file_path', 'path'])}',
        _ => args.entries.map((e) => '${e.key}=${e.value}').join(' '),
      };
    }
    return args.toString();
  }

  static _ToolDisplay? _formatToolDisplay(String tool, dynamic args) {
    if (args is! Map) return null;
    return switch (tool.toLowerCase()) {
      'edit' => _formatEditDisplay(args),
      _ => null,
    };
  }

  static _ToolDisplay? _formatEditDisplay(Map args) {
    final filePath = _stringArg(args, const ['file_path', 'path']);
    final lines = <_DiffLine>[];
    final hunks = args['hunks'];
    if (hunks is! Iterable) return null;

    for (final hunk in hunks) {
      if (hunk is! Map || hunk['lines'] is! Iterable) continue;
      if (lines.isNotEmpty) lines.add(_DiffLine.context('      ...'));
      for (final rawLine in hunk['lines'] as Iterable) {
        if (rawLine is! Map) continue;
        final text = _lineText(rawLine);
        switch (rawLine['kind']) {
          case 'context':
            lines.add(_DiffLine.context(text));
          case 'remove':
            lines.add(_DiffLine.removed(text));
          case 'add':
            lines.add(_DiffLine.added(text));
          case 'ellipsis':
            lines.add(_DiffLine.context('      ...'));
        }
      }
    }

    if (lines.isEmpty) return null;
    return _ToolDisplay(command: 'edit $filePath', lines: lines);
  }

  static String _lineText(Map rawLine) {
    final sign = switch (rawLine['kind']) {
      'remove' => '-',
      'add' => '+',
      _ => ' ',
    };
    final lineNumber = rawLine['oldLine'] ?? rawLine['newLine'];
    final number = lineNumber is int ? lineNumber.toString().padLeft(3) : '   ';
    return '$sign $number ${rawLine['text'] ?? ''}';
  }

  static String _stringArg(Map args, List<String> keys) {
    for (final key in keys) {
      final value = args[key];
      if (value is String) return value;
    }
    return '';
  }
}

class _ToolDisplay {
  final String command;
  final List<_DiffLine> lines;

  const _ToolDisplay({required this.command, required this.lines});
}

class _DiffLine {
  final String text;
  final Color Function(AppColors colors) color;

  const _DiffLine._(this.text, this.color);

  factory _DiffLine.removed(String text) =>
      _DiffLine._(text, (colors) => colors.error);

  factory _DiffLine.added(String text) =>
      _DiffLine._(text, (colors) => colors.success);

  factory _DiffLine.context(String text) =>
      _DiffLine._(text, (colors) => colors.text);
}

// Minimal terminal icon (rectangle + > and —)
class _TerminalIconPainter extends CustomPainter {
  final Color color;
  const _TerminalIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0.5, 1, size.width - 1, size.height - 2),
        const Radius.circular(1.6),
      ),
      paint,
    );
    final path = Path()
      ..moveTo(3, 4.5)
      ..lineTo(5.5, 7)
      ..lineTo(3, 9.5);
    canvas.drawPath(path, paint);
    canvas.drawLine(
      Offset(6.5, size.height / 2),
      Offset(size.width - 2, size.height / 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(_TerminalIconPainter old) => old.color != color;
}
