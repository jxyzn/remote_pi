import 'package:app/ui/core/themes/themes.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Onboarding step 1 — welcome. Static, no animations (per plan 14 D2 —
/// "Welcome conservador (sem animações)").
class WelcomeStep extends StatelessWidget {
  final VoidCallback onNext;
  const WelcomeStep({super.key, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: colors.highlight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.border, width: 2),
                boxShadow: colors.retroShadow,
              ),
              alignment: Alignment.center,
              child: Icon(
                LucideIcons.gamepad2,
                color: colors.onAccent,
                size: 38,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Remote Pi',
            textAlign: TextAlign.center,
            style: typo.display.copyWith(
              fontSize: 24,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Control your Pi agent from anywhere',
            textAlign: TextAlign.center,
            style: typo.sansTitle.copyWith(
              fontSize: 15,
              color: colors.accent,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.border, width: 1.5),
              boxShadow: colors.retroShadowSm,
            ),
            child: Text(
              'Pair this app with the Pi agent running on your host '
              'machine so you can chat with it even '
              'when you\'re away from home.',
              textAlign: TextAlign.center,
              style: typo.sansBody.copyWith(
                fontSize: 13.5,
                color: colors.muted2,
              ),
            ),
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: onNext,
            child: const Text('Get started'),
          ),
        ],
      ),
    );
  }
}
