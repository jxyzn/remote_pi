import 'package:app/data/transport/epk_encoding.dart';
import 'package:app/pairing/storage.dart';
import 'package:app/protocol/protocol.dart' show RoomInfo;
import 'package:app/routing/adaptive.dart';
import 'package:app/ui/core/themes/themes.dart';
import 'package:app/ui/home/states/home_state.dart';
import 'package:app/ui/settings/settings_sheet.dart';
import 'package:app/ui/home/viewmodels/home_viewmodel.dart';
import 'package:app/ui/home/widgets/widgets.dart';
import 'package:app/ui/update/widgets/update_banner.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

/// Plan-18 follow-up — iOS-style large title that collapses into a
/// compact bar when scrolled. Built with `SliverAppBar +
/// FlexibleSpaceBar`. Subtitle shows the first paired Mac + relay
/// status. Body is sectioned by pairing always (single peer also
/// gets the pairing header, per the mock).
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final vm = context.watch<HomeViewModel>();
    final state = vm.state;

    // Plan/tablet — tell the adaptive shell whether Home has anything to
    // list. On a zero-state (no Pi paired / empty list) the shell drops
    // the two-pane split and shows this page full-width + centered. Done
    // post-frame so we never notify mid-build.
    final isZeroState = switch (state) {
      HomeLoading() => false,
      HomeNoPeer() => true,
      HomeList() => state.items(normalizeEpk: toStandardB64).isEmpty,
    };
    final shell = context.read<ShellLayout>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      shell.setZeroState(isZeroState);
    });

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            _buildLargeTitleBar(context, vm, state),
            // Plan 44 — Android-only update notice. Sits at the top of the
            // scroll content (below the title, above the list); shrinks to
            // zero height when there's nothing to announce, so it's invisible
            // on iOS and when no newer version exists.
            const SliverToBoxAdapter(child: UpdateBanner()),
            switch (state) {
              HomeLoading() => SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(color: colors.accent),
                ),
              ),
              HomeNoPeer() => const SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(),
              ),
              HomeList() => _buildListSlivers(context, vm, state),
            },
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Compact retro console header bar
  // ---------------------------------------------------------------------------

  Widget _buildLargeTitleBar(
    BuildContext context,
    HomeViewModel vm,
    HomeState state,
  ) {
    final colors = context.colors;
    final subtitle = _subtitleFor(context, vm, state);
    return SliverAppBar(
      backgroundColor: colors.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      pinned: true,
      stretch: false,
      expandedHeight: 54,
      collapsedHeight: 54,
      toolbarHeight: 54,
      automaticallyImplyLeading: false,
      titleSpacing: 12,
      title: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: colors.highlight,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: colors.border, width: 1.5),
              boxShadow: colors.retroShadowSm,
            ),
            alignment: Alignment.center,
            child: Icon(
              LucideIcons.gamepad2,
              size: 16,
              color: colors.onAccent,
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              'Remote Pi',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.typo.display.copyWith(
                fontSize: 17,
                color: colors.text,
              ),
            ),
          ),
          const SizedBox(width: 10),
          subtitle,
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Pair new Pi',
          visualDensity: VisualDensity.compact,
          icon: Icon(LucideIcons.scanQrCode, size: 19, color: colors.text),
          onPressed: () => context.push('/pair'),
        ),
        IconButton(
          tooltip: 'Settings',
          visualDensity: VisualDensity.compact,
          icon: Icon(LucideIcons.settings, size: 19, color: colors.text),
          onPressed: () => openSettings(context),
        ),
        if (isWideLayout(context))
          IconButton(
            tooltip: 'Collapse session list',
            visualDensity: VisualDensity.compact,
            icon: Icon(
              LucideIcons.panelLeftClose,
              size: 19,
              color: colors.text,
            ),
            onPressed: () =>
                context.read<ShellLayout>().setSidebarCollapsed(true),
          ),
        const SizedBox(width: 6),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1.5),
        child: Container(height: 1.5, color: colors.border),
      ),
    );
  }

  /// Inline status badge: ● Relay · [Connected|Awaiting pairing|Offline].
  /// Reflects the app→relay WS state (not per-Pi presence) so the
  /// user always knows whether the app itself is reachable.
  Widget _subtitleFor(BuildContext context, HomeViewModel vm, HomeState state) {
    final colors = context.colors;
    final typo = context.typo;
    final connected = vm.isRelayConnected;
    final awaitingPairing = state is HomeNoPeer;
    final Color dotColor;
    final String statusLabel;
    final Color statusColor;
    if (connected) {
      dotColor = colors.success;
      statusLabel = 'Connected';
      statusColor = colors.muted2;
    } else if (awaitingPairing) {
      dotColor = colors.muted;
      statusLabel = 'Awaiting pairing';
      statusColor = colors.muted;
    } else {
      dotColor = colors.warning;
      statusLabel = 'Offline';
      statusColor = colors.warning;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colors.border, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: dotColor,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            'Relay',
            style: typo.sansSmall.copyWith(
              color: colors.text,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '·',
            style: typo.sansSmall.copyWith(
              color: colors.muted,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            statusLabel,
            style: typo.sansSmall.copyWith(
              color: statusColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // List body
  // ---------------------------------------------------------------------------

  Widget _buildListSlivers(
    BuildContext context,
    HomeViewModel vm,
    HomeList state,
  ) {
    final counts = vm.counts;
    // Globally empty (paired Pi, no rooms at all): keep the original lonely
    // state and DON'T show the tabs — there's nothing to filter.
    if (counts.all == 0) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: _LonelyEmptyState(),
      );
    }

    // Plan-38 Fase 3 — presence filter at the top of the list. Pure view:
    // tapping a tab only swaps `state.filter` → `vm.visibleItems` re-derives.
    final tabs = SliverToBoxAdapter(
      child: HomeFilterTabs(
        filter: state.filter,
        counts: counts,
        onSelected: vm.setFilter,
      ),
    );

    final visible = vm.visibleItems;
    if (visible.isEmpty) {
      // Items exist, but none match this tab → per-tab empty state beneath
      // the tabs (which stay visible so the user can switch back).
      return SliverMainAxisGroup(
        slivers: [
          tabs,
          SliverFillRemaining(
            hasScrollBody: false,
            child: HomeFilterEmptyState(filter: state.filter),
          ),
        ],
      );
    }

    // Build the per-peer groups over the VISIBLE items: each group is
    // [header, tile, tile, …]. Plan-18 follow-up — always include a header
    // even when there's a single Mac, per the mock. A peer with no visible
    // item in this filter contributes no header (the `lastEpk` cursor only
    // advances on rows we actually render).
    final children = <Widget>[];
    String? lastEpk;
    for (final it in visible) {
      if (it.peer.remoteEpk != lastEpk) {
        children.add(PeerSectionHeader(peer: it.peer));
        lastEpk = it.peer.remoteEpk;
      }
      children.add(_buildItemRowAt(context, vm, state, it));
    }
    return SliverMainAxisGroup(
      slivers: [
        tabs,
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => children[i],
              childCount: children.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildItemRowAt(
    BuildContext context,
    HomeViewModel vm,
    HomeList state,
    HomeItem it,
  ) {
    final colors = context.colors;
    final isLive = vm.isRoomLive(it.peer.remoteEpk, it.room.roomId);
    final isReconnecting = !vm.isRelayConnected;
    final isWorking = vm.isRoomWorking(it.peer.remoteEpk, it.room.roomId);
    // Plan/tablet — highlight the open session, but only in the two-pane
    // layout (on phone the list is covered by the pushed chat, so a
    // persistent highlight would be meaningless).
    final isSelected =
        isWideLayout(context) &&
        context.watch<SessionSelection>().matches(
          it.peer.remoteEpk,
          it.room.roomId,
        );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SessionTile(
          peer: it.peer,
          isLive: isLive,
          isReconnecting: isReconnecting,
          isWorking: isWorking,
          isSelected: isSelected,
          room: it.room,
          onOpen: () => _open(context, vm, it.peer, it.room),
          onLongPress: () => _showSessionMenu(context, vm, it, isLive: isLive),
        ),
        Divider(color: colors.border, height: 1),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Long-press menu (preserved from prior plan-17 wiring)
  // ---------------------------------------------------------------------------

  void _showSessionMenu(
    BuildContext context,
    HomeViewModel vm,
    HomeItem it, {
    required bool isLive,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.colors.surface,
      builder: (sheetCtx) {
        final colors = sheetCtx.colors;
        final typo = sheetCtx.typo;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                dense: true,
                leading: Icon(LucideIcons.pencil, color: colors.accent),
                title: Text(
                  'Rename session',
                  style: typo.sansBody.copyWith(fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  _promptRename(context, vm, it);
                },
              ),
              ListTile(
                dense: true,
                leading: Icon(
                  LucideIcons.trash2,
                  color: isLive ? colors.muted : colors.error,
                ),
                enabled: !isLive,
                title: Text(
                  'Delete session (local only)',
                  style: typo.sansBody.copyWith(
                    color: isLive ? colors.muted : colors.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: isLive
                    ? Text(
                        'Only available when the room is offline',
                        style: typo.sansSmall.copyWith(color: colors.muted),
                      )
                    : null,
                onTap: isLive
                    ? null
                    : () {
                        Navigator.of(sheetCtx).pop();
                        _confirmDelete(context, vm, it);
                      },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _promptRename(
    BuildContext context,
    HomeViewModel vm,
    HomeItem it,
  ) async {
    final controller = TextEditingController(text: it.room.name ?? '');
    final result = await showDialog<String?>(
      context: context,
      builder: (dCtx) {
        final colors = dCtx.colors;
        final typo = dCtx.typo;
        return AlertDialog(
          backgroundColor: colors.surface,
          title: Text('Rename session', style: typo.sansTitle),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: typo.sansBody,
            decoration: InputDecoration(
              hintText: it.room.cwd ?? 'Session',
              hintStyle: typo.sansBody.copyWith(color: colors.muted),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dCtx).pop(null),
              child: Text(
                'Cancel',
                style: typo.sansBody.copyWith(color: colors.muted2),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dCtx).pop(controller.text.trim()),
              child: Text(
                'Save',
                style: typo.sansTitle.copyWith(color: colors.accent),
              ),
            ),
          ],
        );
      },
    );
    if (result == null) return;
    await vm.renameRoom(it.peer.remoteEpk, it.room.roomId, result);
  }

  Future<void> _confirmDelete(
    BuildContext context,
    HomeViewModel vm,
    HomeItem it,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) {
        final colors = dCtx.colors;
        final typo = dCtx.typo;
        return AlertDialog(
          backgroundColor: colors.surface,
          title: Text('Delete session?', style: typo.sansTitle),
          content: Text(
            'Removes locally only. If the session comes back online on '
            'the Pi, it reappears in the list.',
            style: typo.sansSmall.copyWith(color: colors.muted2),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dCtx).pop(false),
              child: Text(
                'Cancel',
                style: typo.sansBody.copyWith(color: colors.muted2),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dCtx).pop(true),
              child: Text(
                'Delete',
                style: typo.sansTitle.copyWith(color: colors.error),
              ),
            ),
          ],
        );
      },
    );
    if (ok != true) return;
    await vm.deleteRoom(it.peer.remoteEpk, it.room.roomId);
  }

  static Future<void> _open(
    BuildContext context,
    HomeViewModel vm,
    PeerRecord peer,
    RoomInfo room,
  ) async {
    // Sets prefs (selectedPeerEpk + room) + switchRoom so a fresh
    // ChatViewModel binds to this session.
    await vm.openSession(peer.remoteEpk, roomId: room.roomId);
    if (!context.mounted) return;
    final title = _titleFor(peer, room);
    // Plan/32g — the device (Mac) name we already know here. The Chat AppBar's
    // line 2 renders this immediately instead of flickering empty/room-title
    // until the PeerRecord loads async.
    final device = _deviceFor(peer);
    // Plan/32g — the live state of this tile (the green dot). Passed so the
    // Chat AppBar's status dot starts correct instead of flashing
    // "reconnecting" before the runtime is read.
    final online = vm.isRoomLive(peer.remoteEpk, room.roomId);
    // Mark the UI selection — drives the tablet detail pane AND the
    // highlighted tile. Set AFTER openSession so the detail's fresh
    // ChatViewModel reads the already-updated prefs.
    context.read<SessionSelection>().select(
      peer.remoteEpk,
      room.roomId,
      title,
      device,
      online,
      room.model,
    );
    // Phone: full-screen chat (root push → native back/swipe). Tablet:
    // the detail pane reacts to the selection above — no nav needed.
    if (!isWideLayout(context)) {
      context.push(
        '/chat',
        extra: {
          'title': title,
          'device': device,
          'online': online,
          'model': room.model,
        },
      );
    }
  }

  /// Plan/32g — the paired-device label for the Chat AppBar's line 2
  /// (nickname → sessionName → epk prefix). Mirrors [ChatPage]'s own peer
  /// resolution so there's no change when the PeerRecord finishes loading.
  static String _deviceFor(PeerRecord peer) =>
      (peer.nickname?.isNotEmpty ?? false)
      ? peer.nickname!
      : peer.sessionName.isNotEmpty
      ? peer.sessionName
      : peer.remoteEpk.substring(0, 8);

  /// Plan/24-fix-title: the peer/room label we already know here, so the
  /// Chat AppBar doesn't show '—' / 'Remote Pi' until the ChatViewModel
  /// loads the PeerRecord + the first room_meta_updated arrives. Prefers
  /// room.name (per-cwd title) → cwd tail → nickname → sessionName.
  static String _titleFor(PeerRecord peer, RoomInfo room) {
    final roomCwdTail = room.cwd
        ?.split('/')
        .where((s) => s.isNotEmpty)
        .lastOrNull;
    return (room.name?.isNotEmpty ?? false)
        ? room.name!
        : (roomCwdTail != null && roomCwdTail.isNotEmpty)
        ? roomCwdTail
        : (peer.nickname?.isNotEmpty ?? false)
        ? peer.nickname!
        : peer.sessionName.isNotEmpty
        ? peer.sessionName
        : peer.remoteEpk.substring(0, 8);
  }
}

/// Plan-17 follow-up — soft empty state for paired-but-no-rooms.
class _LonelyEmptyState extends StatelessWidget {
  const _LonelyEmptyState();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
        child: Padding(
          padding: const EdgeInsets.all(24),
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
                child: Icon(LucideIcons.moon, color: colors.accent, size: 28),
              ),
              const SizedBox(height: 14),
              Text(
                'Nothing here…',
                style: typo.sansTitle.copyWith(color: colors.text),
              ),
              const SizedBox(height: 4),
              Text(
                'When a paired Pi opens a session, it shows up here.',
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border, width: 2),
              boxShadow: colors.retroShadow,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: colors.modelBadgeBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: colors.border, width: 1.5),
                    boxShadow: colors.retroShadowSm,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    LucideIcons.scanQrCode,
                    color: colors.text,
                    size: 26,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'No pairings yet',
                  style: typo.display.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 6),
                Text(
                  'Scan a QR from your host to start.',
                  textAlign: TextAlign.center,
                  style: typo.sansBody.copyWith(color: colors.muted2),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () => context.push('/pair'),
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.accent,
                    foregroundColor: colors.onAccent,
                  ),
                  icon: const Icon(LucideIcons.scanQrCode, size: 18),
                  label: const Text('Scan QR'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
