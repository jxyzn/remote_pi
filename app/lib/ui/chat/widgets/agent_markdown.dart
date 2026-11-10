import 'dart:async';

import 'package:app/ui/core/themes/themes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      style: typo.sansBody,
      onLinkTap: (url, _) => _openLink(context, url),
      // Inline `code` — monospace pill with retro berry/pink highlight.
      inlineCodeBuilder: (context, text, style, codeStyle) => TextSpan(
        text: text,
        style: typo.mono.copyWith(
          fontSize: 12.0,
          color: colors.highlight,
          backgroundColor: colors.codeBg,
          fontWeight: FontWeight.w600,
        ),
      ),
      // Fenced ``` blocks — retro console frame + copy button.
      codeBuilder: (context, name, code, closed) =>
          _CodeBlock(language: name, code: code),
      // GFM tables — fit available chat width and word-wrap cells instead of
      // forcing horizontal scrolling on long sentences.
      tableBuilder: _buildTable,
    );
    final gptTheme = Theme.of(context).extension<GptMarkdownThemeData>() ??
        GptMarkdownThemeData(
          brightness: Theme.of(context).brightness,
          h1: typo.headlineLarge,
          h2: typo.headlineMedium,
          h3: typo.headlineSmall,
          h4: typo.sansTitle,
          h5: typo.sansBody.copyWith(fontWeight: FontWeight.w700),
          h6: typo.sansSmall.copyWith(fontWeight: FontWeight.w700),
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
        border: Border.all(color: colors.border, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Table(
        textDirection: config.textDirection,
        columnWidths: columnWidths,
        defaultVerticalAlignment: TableCellVerticalAlignment.top,
        border: TableBorder.symmetric(
          inside: BorderSide(color: colors.border, width: 1),
        ),
        children: [
          for (final row in tableRows)
            TableRow(
              decoration: row.isHeader
                  ? BoxDecoration(color: colors.surface2)
                  : null,
              children: List<Widget>.generate(colCount, (c) {
                final field = c < row.fields.length ? row.fields[c] : null;
                final raw = field?.data.trim() ?? '';
                if (raw.isEmpty) {
                  return const SizedBox.shrink();
                }
                final cellStyle = row.isHeader
                    ? typo.sansSmall.copyWith(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: colors.text,
                      )
                    : typo.sansBody.copyWith(
                        fontSize: 13.0,
                        color: colors.text,
                        height: 1.38,
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
                    inlineCodeBuilder: config.inlineCodeBuilder,
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
      margin: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: colors.codeBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border, width: 1.5),
        boxShadow: colors.retroShadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(10, 2, 4, 2),
            decoration: BoxDecoration(
              color: colors.surface2,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(6.5),
              ),
              border: Border(
                bottom: BorderSide(color: colors.border, width: 1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    (language.isEmpty ? 'code' : language).toUpperCase(),
                    style: typo.badge.copyWith(
                      color: colors.muted2,
                      fontSize: 9.5,
                    ),
                  ),
                ),
                _CopyButton(code: code),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Text(
              code,
              style: typo.mono.copyWith(color: colors.text, height: 1.42),
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
    try {
      await Clipboard.setData(ClipboardData(text: widget.code));
      if (!mounted) return;
      setState(() => _copied = true);
      _reset?.cancel();
      _reset = Timer(const Duration(milliseconds: 1500), () {
        if (mounted) setState(() => _copied = false);
      });
    } catch (_) {}
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
