import 'package:app/routing/adaptive.dart';
import 'package:app/ui/core/themes/themes.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

/// Estado vazio do painel detail no modo tablet — mostrado enquanto
/// nenhuma sessão foi selecionada (o app inicia assim, de propósito).
class DetailPlaceholder extends StatelessWidget {
  const DetailPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final shell = context.watch<ShellLayout?>();
    final collapsed = shell?.isSidebarCollapsed ?? false;
    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Stack(
          children: [
            if (collapsed && shell != null)
              Positioned(
                top: 4,
                left: 4,
                child: IconButton(
                  tooltip: 'Show sessions',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    LucideIcons.panelLeftOpen,
                    size: 19,
                    color: colors.text,
                  ),
                  onPressed: () => shell.setSidebarCollapsed(false),
                ),
              ),
            Center(
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
                    style: typo.display.copyWith(
                      fontSize: 15,
                      color: colors.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    collapsed
                        ? 'Open the session list to pick a chat.'
                        : 'Pick a session on the left to open its chat.',
                    textAlign: TextAlign.center,
                    style: typo.sansSmall.copyWith(color: colors.muted2),
                  ),
                  if (collapsed && shell != null) ...[
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: () => shell.setSidebarCollapsed(false),
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.accent,
                        foregroundColor: colors.onAccent,
                      ),
                      icon: const Icon(LucideIcons.panelLeftOpen, size: 16),
                      label: const Text('Show sessions'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
