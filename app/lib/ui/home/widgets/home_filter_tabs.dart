import 'package:app/routing/adaptive.dart' show kMaxContentWidth;
import 'package:app/ui/core/themes/themes.dart';
import 'package:app/ui/home/states/home_state.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Plan-38 Fase 3 — presence filter for the Home list. A 3-pill segmented
/// control (All · Online · Offline) the user taps to slice the existing
/// (peer → room) list by liveness. Pure view filter: tapping a tab never
/// reloads data, it only narrows [HomeViewModel.visibleItems]. The default
/// tab is Online (set by [HomeList.filter]).
class HomeFilterTabs extends StatelessWidget {
  final HomeFilter filter;

  /// Per-tab counts for the badges (each tab shows its own slice's size).
  final ({int all, int online, int offline}) counts;
  final ValueChanged<HomeFilter> onSelected;

  const HomeFilterTabs({
    super.key,
    required this.filter,
    required this.counts,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.border, width: 1.5),
          boxShadow: colors.retroShadowSm,
        ),
        padding: const EdgeInsets.all(3),
        child: Row(
          children: [
            _segment(context, HomeFilter.all, 'All', counts.all),
            _segment(context, HomeFilter.online, 'Online', counts.online),
            _segment(context, HomeFilter.offline, 'Offline', counts.offline),
          ],
        ),
      ),
    );
  }

  Widget _segment(
    BuildContext context,
    HomeFilter value,
    String label,
    int count,
  ) {
    final colors = context.colors;
    final typo = context.typo;
    final selected = filter == value;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onSelected(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
          decoration: BoxDecoration(
            color: selected ? colors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
            border: selected
                ? Border.all(color: colors.border, width: 1.2)
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typo.sansBody.copyWith(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: selected ? colors.onAccent : colors.muted2,
                  ),
                ),
              ),
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? colors.onAccent.withValues(alpha: 0.22)
                      : colors.surface2,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$count',
                  style: typo.monoSmall.copyWith(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: selected ? colors.onAccent : colors.muted2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Plan-38 Fase 3 — empty state shown BELOW the tabs when the current tab
/// has no matching sessions but the list isn't globally empty (the
/// globally-empty case keeps the existing "Nothing here…" lonely state and
/// hides the tabs entirely). Copy varies per tab so the user understands
/// it's a filter, not a dead end. [HomeFilter.all] is included for
/// completeness but in practice never renders empty while items exist.
class HomeFilterEmptyState extends StatelessWidget {
  final HomeFilter filter;
  const HomeFilterEmptyState({super.key, required this.filter});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final (String title, String subtitle) = switch (filter) {
      HomeFilter.online => (
        'No sessions online',
        'Live sessions appear here when a paired Pi is active.',
      ),
      HomeFilter.offline => (
        'No offline sessions',
        'Sessions you’ve seen before that aren’t live show up here.',
      ),
      HomeFilter.all => (
        'Nothing here…',
        'When a paired Pi opens a session, it shows up here.',
      ),
    };
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.border, width: 1.5),
                  boxShadow: colors.retroShadowSm,
                ),
                alignment: Alignment.center,
                child: Icon(LucideIcons.moon, color: colors.muted2, size: 24),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: typo.sansTitle.copyWith(color: colors.text),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: typo.sansSmall.copyWith(color: colors.muted2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
