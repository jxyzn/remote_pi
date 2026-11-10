import 'package:app/data/actions/actions_repository.dart';
import 'package:app/protocol/protocol.dart';
import 'package:app/ui/core/themes/themes.dart';
import 'package:app/ui/chat/quick_actions/viewmodels/quick_actions_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

/// Plan/28 Wave C — Model sub-picker pushed from the Quick Actions sheet.
/// Lists every model the Pi reports as available, optionally filtered by
/// provider. Tapping a row dispatches `model_set` via the parent
/// [QuickActionsViewModel] and closes the sub-picker on success.
Future<void> showModelPickerSheet(
  BuildContext context, {
  required QuickActionsViewModel vm,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.colors.bg,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    isScrollControlled: true,
    showDragHandle: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return ChangeNotifierProvider<QuickActionsViewModel>.value(
        value: vm,
        child: const _ModelPickerBody(),
      );
    },
  );
}

class _ModelPickerBody extends StatefulWidget {
  const _ModelPickerBody();

  @override
  State<_ModelPickerBody> createState() => _ModelPickerBodyState();
}

class _ModelPickerBodyState extends State<_ModelPickerBody> {
  late Future<ModelsCatalogue> _future;
  String? _providerFilter;

  @override
  void initState() {
    super.initState();
    _future = _load(forceRefresh: false);
  }

  Future<ModelsCatalogue> _load({required bool forceRefresh}) {
    final vm = context.read<QuickActionsViewModel>();
    return vm.loadModels(forceRefresh: forceRefresh);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load(forceRefresh: true);
    });
    await _future.catchError((Object _) => const ModelsCatalogue(models: []));
  }

  Future<void> _onPick(WireModel model) async {
    final vm = context.read<QuickActionsViewModel>();
    try {
      await vm.setModel(model);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      // Error is surfaced as a snackbar via the parent sheet's listener.
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final mq = MediaQuery.of(context);
    final maxHeight = mq.size.height * 0.78;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Padding(
          padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              _DragHandle(),
              const SizedBox(height: 8),
              _Header(onRefresh: _refresh),
              Divider(color: colors.border, height: 1, thickness: 1),
              Flexible(
                child: FutureBuilder<ModelsCatalogue>(
                  future: _future,
                  builder: (ctx, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const _LoadingState();
                    }
                    if (snap.hasError) {
                      return _ErrorState(
                        message: snap.error is ActionFailure
                            ? (snap.error as ActionFailure).message
                            : 'Failed to load models',
                        onRetry: _refresh,
                      );
                    }
                    final cat = snap.data!;
                    if (cat.models.isEmpty) {
                      return const _EmptyState();
                    }
                    return _ProviderTabs(
                      catalogue: cat,
                      selectedProvider: _providerFilter,
                      onProviderTap: (p) =>
                          setState(() => _providerFilter = p),
                      onModelPick: _onPick,
                    );
                  },
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

class _DragHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: context.colors.border,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onRefresh;
  const _Header({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 8, 6),
      child: Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(LucideIcons.arrowLeft, size: 18, color: colors.muted2),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Back',
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              'Choose a model',
              style: typo.sansTitle.copyWith(fontSize: 14.5),
            ),
          ),
          IconButton(
            key: const Key('model-picker-refresh'),
            visualDensity: VisualDensity.compact,
            icon: Icon(LucideIcons.refreshCw, size: 18, color: colors.muted2),
            onPressed: onRefresh,
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }
}

class _ProviderTabs extends StatelessWidget {
  final ModelsCatalogue catalogue;
  final String? selectedProvider;
  final ValueChanged<String?> onProviderTap;
  final ValueChanged<WireModel> onModelPick;
  const _ProviderTabs({
    required this.catalogue,
    required this.selectedProvider,
    required this.onProviderTap,
    required this.onModelPick,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final providers = <String>{
      for (final m in catalogue.models) m.provider,
    }.toList()
      ..sort();
    final filtered = selectedProvider == null
        ? catalogue.models
        : catalogue.models
            .where((m) => m.provider == selectedProvider)
            .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (providers.length > 1)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _Chip(
                  label: 'all',
                  selected: selectedProvider == null,
                  onTap: () => onProviderTap(null),
                ),
                const SizedBox(width: 6),
                for (final p in providers) ...[
                  _Chip(
                    label: p,
                    selected: selectedProvider == p,
                    onTap: () => onProviderTap(p),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
        Flexible(
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: 18),
            shrinkWrap: true,
            itemCount: filtered.length,
            separatorBuilder: (_, _) =>
                Divider(color: colors.border, height: 1, thickness: 1),
            itemBuilder: (_, i) {
              final m = filtered[i];
              final isCurrent = catalogue.current?.id == m.id &&
                  catalogue.current?.provider == m.provider;
              return _ModelTile(
                model: m,
                current: isCurrent,
                onTap: () => onModelPick(m),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          border: Border.all(
            color: colors.border,
            width: 1.4,
          ),
          color: selected ? colors.accent : colors.surface,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: typo.badge.copyWith(
            fontSize: 10.5,
            color: selected ? colors.onAccent : colors.muted2,
          ),
        ),
      ),
    );
  }
}

class _ModelTile extends StatelessWidget {
  final WireModel model;
  final bool current;
  final VoidCallback onTap;
  const _ModelTile({
    required this.model,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          model.name,
                          overflow: TextOverflow.ellipsis,
                          style: typo.mono.copyWith(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: current ? colors.accent : colors.text,
                          ),
                        ),
                      ),
                      if (model.reasoning) ...[
                        const SizedBox(width: 6),
                        const _Badge(label: 'reasoning'),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _subtitle(model),
                    style: typo.sansSmall.copyWith(
                      fontSize: 11,
                      color: colors.muted2,
                    ),
                  ),
                ],
              ),
            ),
            if (current)
              Icon(LucideIcons.check, color: colors.accent, size: 18),
          ],
        ),
      ),
    );
  }

  static String _subtitle(WireModel m) {
    final ctx = m.contextWindow;
    if (ctx <= 0) return m.provider;
    final humanized = ctx >= 1000 ? '${(ctx / 1000).round()}k' : '$ctx';
    return '${m.provider} · ctx $humanized';
  }
}

class _Badge extends StatelessWidget {
  final String label;
  const _Badge({required this.label});
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: colors.modelBadgeBg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: colors.modelBadgeBorder),
      ),
      child: Text(
        label,
        style: typo.badge.copyWith(
          fontSize: 9,
          color: colors.text,
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 1.6,
            color: context.colors.accent,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: Center(
        child: Text(
          'No models available',
          style: context.typo.sansBody.copyWith(color: context.colors.muted2),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: typo.sansBody.copyWith(color: colors.error),
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
