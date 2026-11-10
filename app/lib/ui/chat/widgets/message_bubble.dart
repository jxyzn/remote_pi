import 'dart:async';

import 'package:app/domain/session_state.dart';
import 'package:app/ui/chat/widgets/agent_markdown.dart';
import 'package:app/ui/chat/widgets/image_bubble.dart';
import 'package:app/ui/core/themes/themes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

// ---------------------------------------------------------------------------
// UserBubble — right-aligned dark card
// ---------------------------------------------------------------------------

class UserBubble extends StatefulWidget {
  final UserMsg message;
  const UserBubble(this.message, {super.key});

  @override
  State<UserBubble> createState() => _UserBubbleState();
}

class _UserBubbleState extends State<UserBubble> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    // Plan/24-fix-app-source-of-truth: render the lifecycle stage of
    // the bubble. `pending` (sent over WS, Pi hasn't echoed yet) gets
    // reduced opacity + a small spinner; `failed` (no echo in 15s) gets
    // a red exclamation badge so the user knows to retry.
    final isPending = message.status == UserMsgStatus.pending;
    final isFailed = message.status == UserMsgStatus.failed;
    final isSteering = message.steering;
    // Plan/30 — when an image is attached the bubble becomes an ImageBubble
    // (thumbnail + caption); otherwise the existing text card.
    final image = message.image;
    final colors = context.colors;
    final typo = context.typo;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (_hovered && !isPending && message.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: _BubbleCopyButton(
                    text: message.text,
                    tooltip: 'Copy prompt',
                  ),
                ),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Opacity(
                      opacity: isPending ? 0.65 : 1.0,
                      child: image != null
                          ? ImageBubble(
                              image: image,
                              caption: message.text,
                              isFailed: isFailed,
                            )
                          : Container(
                              decoration: BoxDecoration(
                                color: colors.userBubble,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isFailed
                                      ? colors.error
                                      : colors.userBubbleBorder,
                                  width: 1.5,
                                ),
                                boxShadow: colors.retroShadowSm,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                                vertical: 8,
                              ),
                              // Wrapped in SelectionArea (rather than SelectableText) so
                              // the user can smoothly drag-select prompt text without
                              // gesture conflicts with the parent ListView.
                              child: SelectionArea(
                                child: Text(
                                  message.text,
                                  style: typo.sansBody.copyWith(color: colors.text),
                                ),
                              ),
                            ),
                    ),
                    if (isPending || isSteering || isFailed)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, right: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isPending || isSteering) ...[
                              SizedBox(
                                width: 10,
                                height: 10,
                                child: CircularProgressIndicator(
                                  color: colors.muted2,
                                  strokeWidth: 1.4,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                isSteering ? 'steering…' : 'sending…',
                                style: typo.sansSmall.copyWith(
                                  color: colors.muted2,
                                  fontSize: 11,
                                ),
                              ),
                            ] else ...[
                              Icon(
                                LucideIcons.circleAlert,
                                size: 12,
                                color: colors.error,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'not delivered',
                                style: typo.sansSmall.copyWith(
                                  color: colors.error,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CompactionBubble — centered system card (plan/32)
// ---------------------------------------------------------------------------

/// A system message distinct from user/assistant: shows that the Pi compacted
/// the context, with the recap summary and the reclaimed token count. Mirrors
/// the TUI's CompactionSummaryMessageComponent.
class CompactionBubble extends StatelessWidget {
  final CompactionMsg message;
  const CompactionBubble(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = message.tokensBefore;
    final summary = message.summary;
    final colors = context.colors;
    final typo = context.typo;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.border, width: 1.5),
            boxShadow: colors.retroShadowSm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.check, size: 13, color: colors.success),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Context compacted',
                      style: typo.sansSmall.copyWith(
                        fontSize: 12,
                        color: colors.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (tokens != null)
                    Text(
                      '~$tokens tokens',
                      style: typo.monoSmall.copyWith(
                        fontSize: 11,
                        color: colors.muted2,
                      ),
                    ),
                ],
              ),
              if (summary.isNotEmpty) ...[
                const SizedBox(height: 4),
                SelectionArea(
                  child: Text(
                    summary,
                    style: typo.sansSmall.copyWith(
                      fontSize: 12,
                      color: colors.muted2,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// AssistantBubble — left-aligned monospace text with hover copy button
// ---------------------------------------------------------------------------

class AssistantBubble extends StatefulWidget {
  final AssistantMsg message;
  const AssistantBubble(this.message, {super.key});

  @override
  State<AssistantBubble> createState() => _AssistantBubbleState();
}

class _AssistantBubbleState extends State<AssistantBubble> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    // Plan/32b — agent output is rendered as Markdown (GFM + code blocks),
    // spanning the FULL content width (the message list already pads 16px on
    // each side) — unlike the user's right-aligned chat bubble, which stays
    // capped. Selectable so prose/code can be copied.
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AgentMarkdown(widget.message.text, selectable: true),
            AnimatedOpacity(
              opacity: _hovered ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 150),
              child: Align(
                alignment: Alignment.centerRight,
                child: _BubbleCopyButton(
                  text: widget.message.text,
                  tooltip: 'Copy response',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _BubbleCopyButton — subtle copy button with checkmark feedback
// ---------------------------------------------------------------------------

class _BubbleCopyButton extends StatefulWidget {
  final String text;
  final String tooltip;
  const _BubbleCopyButton({
    required this.text,
    this.tooltip = 'Copy text',
  });

  @override
  State<_BubbleCopyButton> createState() => _BubbleCopyButtonState();
}

class _BubbleCopyButtonState extends State<_BubbleCopyButton> {
  bool _copied = false;
  Timer? _reset;

  @override
  void dispose() {
    _reset?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    try {
      await Clipboard.setData(ClipboardData(text: widget.text));
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
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
      visualDensity: VisualDensity.compact,
      iconSize: 14,
      splashRadius: 14,
      tooltip: _copied ? 'Copied!' : widget.tooltip,
      onPressed: _copy,
      icon: Icon(
        _copied ? LucideIcons.check : LucideIcons.copy,
        color: _copied ? colors.success : colors.muted2,
      ),
    );
  }
}
