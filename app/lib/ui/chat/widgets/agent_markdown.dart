import 'dart:async';

import 'package:app/ui/core/themes/themes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gpt_markdown/custom_widgets/markdown_config.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

/// Plan/32b — renders the agent's Markdown reply (GFM + code) themed to the
/// app's dark/mono look. Links open in the system browser (url_launcher);
/// code blocks get a copy button. Tolerant of partial markdown so it can also
/// drive the live streaming bubble.
class AgentMarkdown extends StatelessWidget {
  const AgentMarkdown(this.data, {super.key, this.selectable = false});

  final String data;

  /// Wrap in a [SelectionArea] so prose/code can be selected + copied. Off for
  /// the streaming bubble (content changes every frame).
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final markdown = GptMarkdown(
      data,
      style: typo.mono,
      onLinkTap: (url, _) => _openLink(context, url),
      // Inline `code` — subtle highlight, keeps the baseline.
      highlightBuilder: (context, text, style) => Text(
        text,
        style: typo.mono.copyWith(
          color: colors.highlight,
          backgroundColor: colors.codeBg,
        ),
      ),
      // Fenced ``` blocks — dark card + copy button.
      codeBuilder: (context, name, code, closed) =>
          _CodeBlock(language: name, code: code),
      // GFM tables — fit available chat width and word-wrap cells instead of
      // forcing horizontal scrolling on long sentences.
      tableBuilder: _buildTable,
    );
    final baseHeading = typo.mono.copyWith(
      color: colors.text,
      fontWeight: FontWeight.w700,
    );
    final gptTheme = Theme.of(context).extension<GptMarkdownThemeData>() ??
        GptMarkdownThemeData(
          brightness: Theme.of(context).brightness,
          h1: baseHeading.copyWith(fontSize: 18, height: 1.3),
          h2: baseHeading.copyWith(fontSize: 16, height: 1.35),
          h3: baseHeading.copyWith(fontSize: 14.5, height: 1.4),
          h4: baseHeading.copyWith(fontSize: 13.5, height: 1.4),
          h5: baseHeading.copyWith(fontSize: 12.5, height: 1.45),
          h6: baseHeading.copyWith(
            fontSize: 11.5,
            color: colors.muted2,
            height: 1.45,
          ),
          linkColor: colors.accent,
          hrLineColor: colors.border,
        );
    final themedMarkdown = GptMarkdownTheme(
      gptThemeData: gptTheme,
      child: markdown,
    );
    return selectable ? SelectionArea(child: themedMarkdown) : themedMarkdown;
  }

  static Widget _buildTable(
    BuildContext context,
    List<CustomTableRow> tableRows,
    TextStyle textStyle,
    GptMarkdownConfig config,
  ) {
    if (tableRows.isEmpty) return const SizedBox.shrink();
    final colCount = tableRows.fold<int>(
      0,
      (maxCols, r) => r.fields.length > maxCols ? r.fields.length : maxCols,
    );
    if (colCount == 0) return const SizedBox.shrink();

    final colors = context.colors;
    final typo = context.typo;

    // Weight each column proportionally by its longest cell (clamped so short
    // label/ID columns stay compact while prose columns get room to wrap).
    final columnWidths = <int, TableColumnWidth>{
      for (var c = 0; c < colCount; c++)
        c: FlexColumnWidth(
          tableRows
              .fold<int>(4, (maxLen, r) {
                final len = c < r.fields.length
                    ? r.fields[c].data.trim().length
                    : 0;
                return len > maxLen ? len : maxLen;
              })
              .clamp(6, 54)
              .toDouble(),
        ),
    };

    final table = Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Table(
        textDirection: config.textDirection,
        columnWidths: columnWidths,
        defaultVerticalAlignment: TableCellVerticalAlignment.top,
        border: TableBorder.symmetric(
          inside: BorderSide(color: colors.border),
        ),
        children: [
          for (final row in tableRows)
            TableRow(
              decoration: row.isHeader
                  ? BoxDecoration(color: colors.userBubble)
                  : null,
              children: List<Widget>.generate(colCount, (c) {
                final field = c < row.fields.length ? row.fields[c] : null;
                final raw = field?.data.trim() ?? '';
                if (raw.isEmpty) {
                  return const SizedBox.shrink();
                }
                final cellStyle = row.isHeader
                    ? typo.monoSmall.copyWith(
                        fontSize: 12.0,
                        fontWeight: FontWeight.w700,
                        color: colors.text,
                      )
                    : typo.mono.copyWith(
                        fontSize: 12.0,
                        color: colors.text,
                        height: 1.4,
                      );
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: GptMarkdown(
                    raw,
                    style: cellStyle,
                    textAlign: field?.alignment ?? TextAlign.left,
                    onLinkTap: config.onLinkTap,
                    highlightBuilder: config.highlightBuilder,
                  ),
                );
              }),
            ),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (ctx, constraints) {
        // Only fall back to horizontal scroll if a table has so many columns
        // that each column would be crushed below ~64dp.
        final minTableWidth = colCount * 64.0;
        if (constraints.hasBoundedWidth &&
            constraints.maxWidth < minTableWidth &&
            colCount > 4) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(width: minTableWidth, child: table),
          );
        }
        return table;
      },
    );
  }

  static Future<void> _openLink(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        messenger?.showSnackBar(SnackBar(content: Text("Couldn't open $url")));
      }
    } catch (_) {
      messenger?.showSnackBar(SnackBar(content: Text("Couldn't open $url")));
    }
  }
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.language, required this.code});

  final String language;
  final String code;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: colors.codeBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 6, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    language.isEmpty ? 'code' : language,
                    style: TextStyle(
                      fontFamily: kMonoFamily,
                      fontSize: 10,
                      color: colors.muted,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                _CopyButton(code: code),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: Text(
              code,
              style: typo.mono.copyWith(color: colors.text, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _CopyButton extends StatefulWidget {
  const _CopyButton({required this.code});

  final String code;

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;
  Timer? _reset;

  @override
  void dispose() {
    _reset?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!mounted) return;
    setState(() => _copied = true);
    _reset?.cancel();
    _reset = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return IconButton(
      key: const Key('code-copy'),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      iconSize: 15,
      splashRadius: 16,
      tooltip: 'Copy code',
      onPressed: _copy,
      icon: Icon(
        _copied ? LucideIcons.check : LucideIcons.copy,
        color: _copied ? colors.success : colors.muted,
      ),
    );
  }
}
