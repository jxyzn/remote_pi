import 'package:app/ui/core/themes/themes.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Estado vazio do painel detail no modo tablet — mostrado enquanto
/// nenhuma sessão foi selecionada (o app inicia assim, de propósito).
class DetailPlaceholder extends StatelessWidget {
  const DetailPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    return Scaffold(
      backgroundColor: colors.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.border, width: 1.5),
                boxShadow: colors.retroShadowSm,
              ),
              alignment: Alignment.center,
              child: Icon(
                LucideIcons.messagesSquare,
                color: colors.accent,
                size: 28,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Select a session',
              style: typo.display.copyWith(fontSize: 15, color: colors.text),
            ),
            const SizedBox(height: 4),
            Text(
              'Pick a session on the left to open its chat.',
              textAlign: TextAlign.center,
              style: typo.sansSmall.copyWith(color: colors.muted2),
            ),
          ],
        ),
      ),
    );
  }
}
