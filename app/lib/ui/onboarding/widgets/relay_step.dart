import 'package:app/data/transport/relay_config.dart';
import 'package:app/ui/core/themes/themes.dart';
import 'package:app/ui/onboarding/states/onboarding_state.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Empty custom URL is allowed — onboarding treats it as "use default
/// community relay" (saves null in Preferences, falls back to
/// [kDefaultRelayUrl] via [resolveRelayUrl]).

/// Onboarding step 2 — relay choice. Two vertical cards: self-hosted
/// (recommended for the privacy story) vs community (convenience).
/// The custom card carries a URL field with inline validation; leaving
/// it empty falls back to the default community relay.
class RelayStep extends StatelessWidget {
  final OnboardingInProgress state;
  final ValueChanged<RelayChoice> onChoice;
  final ValueChanged<String> onCustomUrl;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const RelayStep({
    super.key,
    required this.state,
    required this.onChoice,
    required this.onCustomUrl,
    required this.onBack,
    required this.onNext,
  });

  bool get _canContinue {
    if (state.relayChoice == RelayChoice.community) return true;
    // Empty custom URL is allowed (treated as default community relay).
    if (state.customRelayUrl.isEmpty) return true;
    return isValidRelayUrl(state.customRelayUrl);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                Text(
                  'Choose a relay',
                  style: typo.display.copyWith(fontSize: 18),
                ),
                const SizedBox(height: 4),
                Text(
                  'Where the app and your host meet.',
                  style: typo.sansBody.copyWith(color: colors.muted2),
                ),
                const SizedBox(height: 18),
                _CustomRelayCard(
                  badge: 'recommended',
                  description: 'Self-hosted. Best privacy.',
                  selected: state.relayChoice == RelayChoice.custom,
                  customUrl: state.customRelayUrl,
                  error: state.customRelayError,
                  onTap: () => onChoice(RelayChoice.custom),
                  onUrlChanged: onCustomUrl,
                  onSubmitted: () {
                    if (_canContinue) onNext();
                  },
                ),
                const SizedBox(height: 10),
                _RelayCard(
                  title: 'Community relay',
                  description: 'Hosted by us. Quick to start.',
                  footer: kDefaultRelayUrl,
                  selected: state.relayChoice == RelayChoice.community,
                  onTap: () => onChoice(RelayChoice.community),
                ),
                const Spacer(),
                const SizedBox(height: 16),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: onBack,
                      child: const Text('Back'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _canContinue ? onNext : null,
                        child: const Text('Continue'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RelayCard extends StatelessWidget {
  final String title;
  final String description;
  final String? footer;
  final bool selected;
  final VoidCallback onTap;
  const _RelayCard({
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(
            color: selected ? colors.accent : colors.border,
            width: selected ? 2.0 : 1.5,
          ),
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          boxShadow: selected ? colors.retroShadowSm : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  selected ? LucideIcons.circleDot : LucideIcons.circle,
                  size: 16,
                  color: selected ? colors.accent : colors.muted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: typo.sansTitle.copyWith(fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 26),
              child: Text(
                description,
                style: typo.sansSmall.copyWith(color: colors.muted2),
              ),
            ),
            if (footer != null) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 26),
                child: Text(
                  footer!,
                  style: typo.monoSmall.copyWith(
                    fontSize: 10.5,
                    color: colors.muted,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CustomRelayCard extends StatefulWidget {
  final bool selected;
  final String customUrl;
  final String? error;
  final String? badge;
  final String? description;
  final VoidCallback onTap;
  final ValueChanged<String> onUrlChanged;
  final VoidCallback? onSubmitted;
  const _CustomRelayCard({
    required this.selected,
    required this.customUrl,
    required this.error,
    required this.onTap,
    required this.onUrlChanged,
    this.onSubmitted,
    this.badge,
    this.description,
  });

  @override
  State<_CustomRelayCard> createState() => _CustomRelayCardState();
}

class _CustomRelayCardState extends State<_CustomRelayCard> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.customUrl);
  }

  @override
  void didUpdateWidget(covariant _CustomRelayCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.customUrl != _ctrl.text) {
      _ctrl.value = TextEditingValue(
        text: widget.customUrl,
        selection: TextSelection.collapsed(offset: widget.customUrl.length),
      );
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final selected = widget.selected;
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(
            color: selected ? colors.accent : colors.border,
            width: selected ? 2.0 : 1.5,
          ),
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          boxShadow: selected ? colors.retroShadowSm : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  selected ? LucideIcons.circleDot : LucideIcons.circle,
                  size: 16,
                  color: selected ? colors.accent : colors.muted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Use my own server',
                    style: typo.sansTitle.copyWith(fontSize: 14),
                  ),
                ),
                if (widget.badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colors.modelBadgeBg,
                      borderRadius: const BorderRadius.all(Radius.circular(4)),
                      border: Border.all(color: colors.modelBadgeBorder),
                    ),
                    child: Text(
                      widget.badge!,
                      style: typo.badge.copyWith(
                        fontSize: 9,
                        color: colors.text,
                      ),
                    ),
                  ),
              ],
            ),
            if (widget.description != null) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 26),
                child: Text(
                  widget.description!,
                  style: typo.sansSmall.copyWith(color: colors.muted2),
                ),
              ),
            ],
            if (selected) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 26),
                child: TextField(
                  controller: _ctrl,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.done,
                  onChanged: widget.onUrlChanged,
                  onSubmitted: (_) => widget.onSubmitted?.call(),
                  style: typo.mono.copyWith(
                    fontSize: 12,
                    color: colors.text,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'https://my-relay.example.com',
                    hintStyle: typo.mono.copyWith(
                      fontSize: 12,
                      color: colors.muted,
                    ),
                    errorText: widget.error,
                    errorStyle: typo.sansSmall.copyWith(
                      fontSize: 11,
                      color: colors.error,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

