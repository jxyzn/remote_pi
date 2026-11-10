import 'package:app/data/preferences/preferences.dart';
import 'package:app/domain/session_state.dart';
import 'package:app/pairing/storage.dart';
import 'package:app/protocol/protocol.dart';
import 'package:app/ui/core/themes/themes.dart';
import 'package:app/ui/chat/quick_actions/widgets/quick_actions_sheet.dart';
import 'package:app/ui/chat/attachment/states/attachment_state.dart';
import 'package:app/ui/chat/attachment/viewmodels/attachment_viewmodel.dart';
import 'package:app/ui/chat/states/chat_state.dart';
import 'package:app/ui/chat/viewmodels/chat_viewmodel.dart';
import 'package:app/ui/chat/voice/viewmodels/voice_input_viewmodel.dart';
import 'package:app/ui/chat/widgets/attach_sheet.dart';
import 'package:app/ui/chat/widgets/input_bar.dart';
import 'package:app/ui/chat/widgets/message_bubble.dart';
import 'package:app/ui/chat/widgets/streaming_bubble.dart';
import 'package:app/ui/chat/widgets/tool_request_card.dart';
import 'package:app/ui/chat/widgets/extension_ui_sheet.dart';
import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

class ChatPage extends StatefulWidget {
  /// Plan/24-fix-title: optional title hint passed via `go_router`
  /// `extra` from the Home tile. Used as the peer-label fallback in
  /// the AppBar so the user sees the right name *immediately* on
  /// navigation, instead of "—" / "Remote Pi" until the PeerRecord
  /// is loaded by the ViewModel and the first `room_meta_updated`
  /// arrives.
  final String? initialTitle;

  /// Plan/32g — the paired-device (Mac) label Home already knows, passed via
  /// `extra` / [SessionSelection]. Drives the AppBar's line 2 immediately so
  /// it never flickers empty/room-title while the PeerRecord loads async.
  /// When the PeerRecord arrives it resolves to the same string, so there's no
  /// visible change.
  final String? initialDevice;

  /// Plan/32g — the live state of the tile Home tapped (its green dot). Seeds
  /// the AppBar status dot so it doesn't flash "reconnecting" before the VM
  /// reads the real runtime. Superseded by the live signal once it resolves
  /// ([ChatViewModel.connectionResolved]).
  final bool initialOnline;

  /// Plan/tablet — `false` when the chat is embedded as the tablet's
  /// detail pane (no navigation stack to pop back to). Hides the back
  /// arrow; defaults to `true` for the phone full-screen route.
  final bool showBack;

  const ChatPage({
    super.key,
    this.initialTitle,
    this.initialDevice,
    this.initialOnline = false,
    this.showBack = true,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  bool _searchOpen = false;
  bool _filterOnlyMatches = false;
  int _activeMatchIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  String get _searchQuery => _searchController.text;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? true)) {
      return false;
    }
    if (event is KeyDownEvent) {
      final isCtrlOrMeta = HardwareKeyboard.instance.isControlPressed ||
          HardwareKeyboard.instance.isMetaPressed;
      if (isCtrlOrMeta && event.logicalKey == LogicalKeyboardKey.keyF) {
        _toggleSearch();
        return true;
      }
      if (isCtrlOrMeta && event.logicalKey == LogicalKeyboardKey.keyK) {
        _openQuickActionsIfEnabled();
        return true;
      }
      if (event.logicalKey == LogicalKeyboardKey.escape && _searchOpen) {
        _closeSearch();
        return true;
      }
    }
    return false;
  }

  static bool _isActionsEnabled(ChatState state) {
    if (state is! ChatReady) return false;
    return !state.isOffline &&
        !state.pairingRevoked &&
        state.peerOfflineReason == null &&
        state.peerPresence is! PresenceOffline;
  }

  void _openQuickActionsIfEnabled() {
    if (!mounted) return;
    final state = context.read<ChatViewModel>().state;
    if (_isActionsEnabled(state)) {
      showQuickActionsSheet(context);
    }
  }

  void _openSearch() {
    setState(() {
      _searchOpen = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_searchFocusNode.canRequestFocus) {
        _searchFocusNode.requestFocus();
        _searchController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _searchController.text.length,
        );
      }
    });
  }

  void _closeSearch() {
    setState(() {
      _searchOpen = false;
      _filterOnlyMatches = false;
      _searchController.clear();
      _activeMatchIndex = 0;
    });
  }

  void _toggleSearch() {
    if (_searchOpen) {
      _closeSearch();
    } else {
      _openSearch();
    }
  }

  void _nextMatch(
    int total,
    List<ChatMessage> visible,
    List<String> matchingIds,
  ) {
    if (total == 0) return;
    setState(() {
      _activeMatchIndex = (_activeMatchIndex + 1) % total;
    });
    _scrollToActiveMatch(visible, matchingIds[_activeMatchIndex]);
  }

  void _prevMatch(
    int total,
    List<ChatMessage> visible,
    List<String> matchingIds,
  ) {
    if (total == 0) return;
    setState(() {
      _activeMatchIndex = (_activeMatchIndex - 1 + total) % total;
    });
    _scrollToActiveMatch(visible, matchingIds[_activeMatchIndex]);
  }

  void _scrollToActiveMatch(List<ChatMessage> visible, String targetId) {
    final msgIdx = visible.indexWhere((m) => m.id == targetId);
    if (msgIdx == -1) return;
    if (!_scrollController.hasClients) return;

    final total = visible.length;
    if (total <= 1) return;

    final listIdx = total - 1 - msgIdx;
    final maxExtent = _scrollController.position.maxScrollExtent;
    if (maxExtent <= 0.0) return;

    final targetOffset = (listIdx / (total - 1)).clamp(0.0, 1.0) * maxExtent;
    if ((targetOffset - _scrollController.offset).abs() < 1.0) return;

    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ChatViewModel>();
    final state = vm.state;
    final hideToolCalls = context.watch<Preferences>().hideToolCalls;
    final colors = context.colors;
    final typo = context.typo;

    final List<ChatMessage> visibleMessages = switch (state) {
      ChatReady(:final messages) => hideToolCalls
          ? messages.where((m) => m is! ToolEvent).toList()
          : messages,
      _ => const [],
    };

    final query = _searchQuery.trim();
    final matchingIds = <String>[];
    final matchedIdSet = <String>{};
    if (query.isNotEmpty) {
      for (final m in visibleMessages) {
        if (m.matchesSearchQuery(query)) {
          matchingIds.add(m.id);
          matchedIdSet.add(m.id);
        }
      }
    }

    final effectiveMatchIndex = matchingIds.isEmpty
        ? 0
        : _activeMatchIndex.clamp(0, matchingIds.length - 1);
    final activeMatchId = matchingIds.isNotEmpty
        ? matchingIds[effectiveMatchIndex]
        : null;
    final filterActive =
        _searchOpen && _filterOnlyMatches && query.isNotEmpty;
    final displayedMessages = filterActive
        ? visibleMessages.where((m) => matchedIdSet.contains(m.id)).toList()
        : visibleMessages;

    final scaffold = Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context, state),
            // Pairing revocation is the only banner kept — it's a hard
            // failure (can't proceed without re-pairing), red, with an
            // explicit action. Plain offline / Pi-gone / presence-off
            // banners were removed: the AppBar status line already
            // surfaces those, and stacking duplicates noise the surface.
            if (state is ChatReady && state.pairingRevoked)
              _RevokedBanner(onRePair: () => context.go('/pair')),
            if (_searchOpen)
              _buildSearchBar(
                colors: colors,
                typo: typo,
                visibleMessages: visibleMessages,
                displayedMessages: displayedMessages,
                matchingIds: matchingIds,
                effectiveMatchIndex: effectiveMatchIndex,
                query: query,
              ),
            Expanded(
              child: _buildBody(
                context,
                state,
                vm,
                visibleMessages,
                displayedMessages,
                matchedIdSet,
                filterActive,
                query,
                activeMatchId,
              ),
            ),
            _buildInput(context, state, vm),
          ],
        ),
      ),
    );

    final shortcutWrapped = CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            _toggleSearch,
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
            _toggleSearch,
        const SingleActivator(LogicalKeyboardKey.keyK, control: true):
            _openQuickActionsIfEnabled,
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
            _openQuickActionsIfEnabled,
        const SingleActivator(LogicalKeyboardKey.escape): _closeSearch,
      },
      child: scaffold,
    );

    // Plan/57 — an interactive extension_ui_request (ask_user via pi-ask)
    // renders as a full-screen modal layered ABOVE the Scaffold. Purely
    // reactive: the overlay leaves the tree when the pending request clears
    // (completed dismiss) — no route lifecycle to manage. `error` carries a
    // submit-result rejection so the modal can offer a retry instead of a dead
    // end.
    final ready = state is ChatReady ? state : null;
    final uiRequest = ready?.pendingUiRequest;
    if (uiRequest == null) return shortcutWrapped;
    return Stack(
      children: [
        shortcutWrapped,
        Positioned.fill(
          // Keyed by request id: a new flow must get a fresh State — question
          // ids repeat across flows (e.g. "goal"), so reusing the State would
          // leak old selections/custom text into the new modal.
          child: ExtensionUiSheet(
            key: ValueKey(uiRequest.id),
            request: uiRequest,
            error: ready?.pendingUiError,
            onRespond: vm.respondExtensionUi,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar({
    required AppColors colors,
    required AppTypography typo,
    required List<ChatMessage> visibleMessages,
    required List<ChatMessage> displayedMessages,
    required List<String> matchingIds,
    required int effectiveMatchIndex,
    required String query,
  }) {
    final hasMatches = matchingIds.isNotEmpty;
    final hasQuery = query.isNotEmpty;
    final matchText = !hasQuery
        ? ''
        : hasMatches
        ? '${effectiveMatchIndex + 1} of ${matchingIds.length}'
        : '0 of 0';

    return Container(
      key: const Key('chat-search-bar'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.search, size: 16, color: colors.accent),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              key: const Key('chat-search-textfield'),
              controller: _searchController,
              focusNode: _searchFocusNode,
              autofocus: true,
              style: typo.sansBody.copyWith(fontSize: 13, color: colors.text),
              decoration: InputDecoration(
                hintText: 'Search chat…',
                hintStyle: typo.sansBody.copyWith(
                  fontSize: 13,
                  color: colors.muted,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
              ),
              onChanged: (text) {
                setState(() {
                  _activeMatchIndex = 0;
                });
                final trimmed = text.trim();
                if (trimmed.isNotEmpty) {
                  final newMatches = visibleMessages
                      .where((m) => m.matchesSearchQuery(trimmed))
                      .toList();
                  if (newMatches.isNotEmpty) {
                    final listForScroll = _filterOnlyMatches
                        ? newMatches
                        : visibleMessages;
                    _scrollToActiveMatch(listForScroll, newMatches.first.id);
                  }
                }
              },
              onSubmitted: (_) {
                if (hasMatches) {
                  _nextMatch(
                    matchingIds.length,
                    displayedMessages,
                    matchingIds,
                  );
                }
              },
            ),
          ),
          if (hasQuery)
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(LucideIcons.circleX, size: 14, color: colors.muted),
              tooltip: 'Clear query',
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _activeMatchIndex = 0;
                });
              },
            ),
          if (hasQuery)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: hasMatches
                    ? colors.modelBadgeBg
                    : colors.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: hasMatches ? colors.border : colors.error,
                ),
              ),
              child: Text(
                matchText,
                style: typo.monoSmall.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: hasMatches ? colors.text : colors.error,
                ),
              ),
            ),
          const SizedBox(width: 4),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(
              _filterOnlyMatches ? LucideIcons.filterX : LucideIcons.filter,
              size: 16,
              color: _filterOnlyMatches ? colors.accent : colors.muted2,
            ),
            tooltip: _filterOnlyMatches
                ? 'Show full conversation'
                : 'Filter to matching messages only',
            onPressed: () {
              setState(() {
                _filterOnlyMatches = !_filterOnlyMatches;
              });
            },
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(
              LucideIcons.chevronUp,
              size: 18,
              color: hasMatches ? colors.text : colors.muted,
            ),
            tooltip: 'Previous match',
            onPressed: hasMatches
                ? () => _prevMatch(
                    matchingIds.length,
                    displayedMessages,
                    matchingIds,
                  )
                : null,
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(
              LucideIcons.chevronDown,
              size: 18,
              color: hasMatches ? colors.text : colors.muted,
            ),
            tooltip: 'Next match (Enter)',
            onPressed: hasMatches
                ? () => _nextMatch(
                    matchingIds.length,
                    displayedMessages,
                    matchingIds,
                  )
                : null,
          ),
          IconButton(
            key: const Key('chat-search-close-button'),
            visualDensity: VisualDensity.compact,
            icon: Icon(LucideIcons.x, size: 18, color: colors.text),
            tooltip: 'Close search (Esc)',
            onPressed: _closeSearch,
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, ChatState state) {
    // Plan-17 follow-up — two-line AppBar:
    //   Line 1: ROOM name (cwd basename / room.name / fallback).
    //   Line 2: peer (Mac nickname or sessionName) + presence dot.
    // The dot reads from the ChatReady.peerPresence flag (which the
    // ViewModel sources from `isRoomLive`).
    final colors = context.colors;
    final vm = context.watch<ChatViewModel>();
    final peer = vm.activePeer;
    final room = vm.activeRoom;
    // Plan/32g — until the VM has read a real runtime, trust the `initialOnline`
    // hint Home passed (the tile's live dot) so the status dot doesn't flash
    // "reconnecting" on the default runtime. The live signal takes over once
    // resolved.
    final resolved = vm.connectionResolved;
    final isOnline = resolved ? vm.isRoomLive : widget.initialOnline;
    // Plan-18 follow-up — when the chat is "offline" (WS to relay
    // down or retrying), prefer a "reconectando" amber pill so the
    // user knows it's the relay, not the Pi cwd, that's gone.
    final isReconnecting = resolved && state is ChatReady && (state).isOffline;
    // Plan-18 follow-up — when the agent is currently producing a
    // response, show "working…" instead of online/offline.
    final isWorking = vm.isWorking;

    // Plan/24-fix-title: pass the navigation hint into the helpers so
    // either line of the AppBar (room or peer) shows it instead of
    // the generic placeholders when the ViewModel hasn't finished
    // bootstrapping yet.
    final roomName = _roomDisplayName(room, state, widget.initialTitle);
    // Plan/32g — line 2 (device) falls back to `initialDevice` (the Mac name
    // Home passed), NOT `initialTitle` (the room name) — so it shows the right
    // device from frame 1 and doesn't flip when the PeerRecord loads.
    final peerLabel = _peerDisplayName(peer, widget.initialDevice);

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: colors.bg,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          if (widget.showBack)
            IconButton(
              icon: Icon(LucideIcons.chevronLeft, size: 18, color: colors.text),
              tooltip: 'Back',
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go('/home'),
            )
          else
            const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _truncate(roomName, 28),
                  style: TextStyle(
                    fontFamily: kMonoFamily,
                    fontSize: 13,
                    color: colors.text,
                    letterSpacing: -0.2,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _truncate(peerLabel, 24),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: kMonoFamily,
                          fontSize: 10,
                          color: colors.muted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Builder(
                      builder: (_) {
                        // Plan-18 follow-up — 4-state pill:
                        // working / reconnecting / online / offline.
                        // Priority: working > reconnecting > online > offline.
                        final color = isWorking
                            ? colors.working
                            : isReconnecting
                            ? colors.warning
                            : isOnline
                            ? colors.success
                            : colors.muted;
                        final label = isWorking
                            ? 'working…'
                            : isReconnecting
                            ? 'reconnecting…'
                            : isOnline
                            ? 'online'
                            : 'offline';
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: color,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              label,
                              style: TextStyle(
                                fontFamily: kMonoFamily,
                                fontSize: 10,
                                color: color,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            key: const Key('chat-search-button'),
            icon: Icon(
              _searchOpen ? LucideIcons.searchX : LucideIcons.search,
              size: 18,
              color: _searchOpen ? colors.accent : colors.muted2,
            ),
            tooltip: _searchOpen
                ? 'Close search (Esc)'
                : 'Search chat (Ctrl+F)',
            onPressed: _toggleSearch,
          ),
          // Plan/32g follow-up: ALWAYS render the info button. Gating it on the
          // async PeerRecord made it pop in on load → an AppBar layout shift
          // (the flicker the user saw). Title + device already render from the
          // nav hints, so the bar is stable from frame 1. The dialog needs the
          // loaded PeerRecord; we read it at tap time (loaded within ms of
          // mount for the connection) and no-op in the unlikely pre-load tap.
          IconButton(
            icon: Icon(LucideIcons.info, size: 18, color: colors.muted2),
            tooltip: 'Session info',
            onPressed: () {
              final p = vm.activePeer;
              if (p != null) {
                _showSessionInfo(context, p, vm.activeRoom, roomName);
              }
            },
          ),
        ],
      ),
    );
  }

  /// Session details dialog — surfaced from the AppBar info action.
  /// Shows the human name, the Pi-side path (cwd), the owning device,
  /// plus model/room/paired-date when known.
  static Future<void> _showSessionInfo(
    BuildContext context,
    PeerRecord peer,
    RoomInfo? room,
    String name,
  ) {
    final owner = (peer.nickname?.isNotEmpty ?? false)
        ? peer.nickname!
        : peer.sessionName.isNotEmpty
        ? peer.sessionName
        : peer.remoteEpk.substring(0, 8);
    final model = room?.model;
    final paired = peer.pairedAt.contains('T')
        ? peer.pairedAt.split('T').first
        : peer.pairedAt;
    return showDialog<void>(
      context: context,
      builder: (dCtx) {
        final colors = dCtx.colors;
        return AlertDialog(
          backgroundColor: colors.bg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: colors.border),
          ),
          title: Text(
            'Session info',
            style: TextStyle(
              fontFamily: kMonoFamily,
              fontSize: 15,
              color: colors.text,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoRow(label: 'Name', value: name),
              _InfoRow(label: 'Path', value: room?.cwd ?? '—'),
              _InfoRow(label: 'Owner', value: owner),
              if (model != null && model.isNotEmpty)
                _InfoRow(label: 'Model', value: model),
              _InfoRow(label: 'Room', value: room?.roomId ?? '—'),
              _InfoRow(label: 'Paired', value: paired),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dCtx).pop(),
              child: Text(
                'Close',
                style: TextStyle(fontFamily: kMonoFamily, color: colors.accent),
              ),
            ),
          ],
        );
      },
    );
  }

  static String _roomDisplayName(
    RoomInfo? room,
    ChatState state,
    String? initialTitle,
  ) {
    if (room != null) {
      if (room.name != null && room.name!.isNotEmpty) return room.name!;
      final cwd = room.cwd;
      if (cwd != null && cwd.isNotEmpty) {
        final segs = cwd.split('/').where((s) => s.isNotEmpty).toList();
        if (segs.isNotEmpty) return segs.last;
      }
    }
    if (state is ChatReady && state.messages.isNotEmpty) {
      return _inferSessionName(state.messages);
    }
    // Plan/24-fix-title: Home knows the peer label before /chat
    // mounts; use it instead of the generic 'Remote Pi' placeholder
    // while we wait for the first room_meta_updated to populate
    // `room.name`.
    if (initialTitle != null && initialTitle.isNotEmpty) return initialTitle;
    return 'Remote Pi';
  }

  static String _peerDisplayName(PeerRecord? peer, String? fallback) {
    if (peer == null) {
      // Plan/32g: while the ViewModel hasn't loaded the PeerRecord yet, fall
      // back to the device label Home passed (initialDevice) — same value the
      // PeerRecord resolves to, so no flicker on load.
      if (fallback != null && fallback.isNotEmpty) return fallback;
      return '—';
    }
    if (peer.nickname != null && peer.nickname!.isNotEmpty) {
      return peer.nickname!;
    }
    if (peer.sessionName.isNotEmpty) return peer.sessionName;
    return peer.remoteEpk.substring(0, 8);
  }

  static String _truncate(String s, int max) =>
      s.length <= max ? s : '${s.substring(0, max - 1)}…';

  Widget _buildBody(
    BuildContext context,
    ChatState state,
    ChatViewModel vm,
    List<ChatMessage> visibleMessages,
    List<ChatMessage> displayedMessages,
    Set<String> matchedIdSet,
    bool filterActive,
    String query,
    String? activeMatchId,
  ) {
    return switch (state) {
      // Edge case: opened /chat without a peer (e.g. peer revoked while
      // user was here). The chat is not the place to pair — render
      // a minimal empty state without an action. User navigates back
      // and uses Home / Settings → pairing.
      ChatNoPeer() => const _EmptyState(
        icon: LucideIcons.messageCircle,
        message: 'No active device',
      ),
      ChatConnecting() => const _EmptyState(
        icon: LucideIcons.refreshCw,
        message: 'Connecting…',
      ),
      ChatFatalError(:final message) => _EmptyState(
        icon: LucideIcons.circleAlert,
        message: message,
        actionLabel: 'Re-pair',
        onAction: () => context.go('/pair'),
      ),
      ChatReady(:final streaming) => () {
        // Empty body → the default placeholder (Pi brand icon + "Nothing
        // here"), shown whenever there's nothing to render — including while
        // reconnecting (the reconnect handshake never swaps the body).
        if (visibleMessages.isEmpty && streaming == null) {
          return const _EmptyState(
            icon: LucideIcons.terminal,
            message: 'Nothing here',
          );
        }

        if (filterActive && displayedMessages.isEmpty) {
          return _EmptyState(
            icon: LucideIcons.searchX,
            message: 'No messages match "$query"',
          );
        }

        return _MessageList(
          messages: displayedMessages,
          streaming: filterActive ? null : streaming,
          onDecide: (id, decision) => vm.approveTool(id, decision),
          scrollController: _scrollController,
          activeMatchId: activeMatchId,
          matchedIds: matchedIdSet,
        );
      }(),
    };
  }

  Widget _buildInput(BuildContext context, ChatState state, ChatViewModel vm) {
    final isReady = state is ChatReady;
    // Plan/31 — the composer is locked + the send button becomes "stop" for
    // the WHOLE working turn (send/echo → agent_done), not just the narrow
    // token-streaming window. Driven by the broad working signal so it matches
    // the AppBar/Home "working" indicator.
    final isWorking = isReady && vm.isWorking;
    final cancelId = vm.cancelTargetId;
    // Quick actions need an open channel to dispatch — only offer the
    // entry point when the chat input itself is enabled. Hiding the
    // ⚙ button on offline avoids a tap that would just throw inside
    // the sheet.
    final actionsEnabled = _isActionsEnabled(state);

    return InputBar(
      disabled: !actionsEnabled,
      streaming: isWorking,
      onCancel: cancelId != null ? () => vm.cancel(cancelId) : null,
      onOpenQuickActions: actionsEnabled
          ? () => showQuickActionsSheet(context)
          : null,
      queuedMessages: isReady ? state.queuedMessages : const [],
      onSetQueued: vm.queueMessage,
      onClearQueued: vm.clearQueuedMessage,
      // Plan/29 — hold-to-talk voice input. The VM is route-scoped (bound in
      // app_router alongside ChatViewModel); InputBar listens to it directly,
      // so a read() is enough here.
      voice: context.read<VoiceInputViewModel>(),
      onVoiceHint: (hint) => _handleVoiceHint(context, hint),
      // Plan/30 — image attachments. takeImageForSend() reads + clears the
      // attached image so the inline image rides along with the (optionally
      // empty) caption. Attach-button gating by vision / already-attached is
      // internal to InputBar; the host only gates by channel availability.
      attachment: context.read<AttachmentViewModel>(),
      onOpenAttach: actionsEnabled
          ? () => _openAttach(context, context.read<AttachmentViewModel>())
          : null,
      onSend: (text) {
        final image = context.read<AttachmentViewModel>().takeImageForSend();
        vm.sendMessage(text, image: image);
      },
    );
  }

  /// Open the Camera/Gallery sheet and drive the picker. Captures the
  /// messenger up front so a permission-denied hint can deep-link to Settings
  /// after the async pick.
  static Future<void> _openAttach(
    BuildContext context,
    AttachmentViewModel vm,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final source = await showAttachSheet(context);
    if (source == null) return;
    AttachHint? hint;
    final sub = vm.hints.listen((h) => hint = h);
    switch (source) {
      case AttachSource.camera:
        await vm.pickFromCamera();
      case AttachSource.gallery:
        await vm.pickFromGallery();
    }
    await Future<void>.delayed(Duration.zero); // flush the hint microtask
    await sub.cancel();
    if (hint != null) _handleAttachHint(messenger, hint!);
  }

  static void _handleAttachHint(
    ScaffoldMessengerState messenger,
    AttachHint hint,
  ) {
    messenger.hideCurrentSnackBar();
    switch (hint) {
      case AttachHint.cameraPermissionDenied:
        messenger.showSnackBar(
          SnackBar(
            content: const Text(
              'Camera access is off — enable it in Settings to attach a photo.',
            ),
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Settings',
              onPressed: AppSettings.openAppSettings,
            ),
          ),
        );
      case AttachHint.pickFailed:
        messenger.showSnackBar(
          const SnackBar(
            content: Text("Couldn't attach that image."),
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  /// Surfaces the InputBar's voice hints (decision #10 permission path +
  /// the "hold to talk" nudge) as snackbars. Captures the messenger up front
  /// so the settings deep-link is safe across the async permission round-trip.
  static void _handleVoiceHint(BuildContext context, VoiceHint hint) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    switch (hint) {
      case VoiceHint.holdToTalk:
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Hold the mic to talk'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      case VoiceHint.permissionDenied:
        messenger.showSnackBar(
          SnackBar(
            content: const Text(
              'Microphone access is off — enable it in Settings to dictate.',
            ),
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Settings',
              onPressed: AppSettings.openAppSettings,
            ),
          ),
        );
    }
  }

  static String _inferSessionName(List<ChatMessage> msgs) {
    for (final m in msgs) {
      if (m is UserMsg) return m.text.substring(0, m.text.length.clamp(0, 32));
    }
    return 'Remote Pi';
  }
}

// ---------------------------------------------------------------------------

class _MessageList extends StatelessWidget {
  final List<ChatMessage> messages;
  final StreamingMessage? streaming;
  final void Function(String, ApproveDecision) onDecide;
  final ScrollController? scrollController;
  final String? activeMatchId;
  final Set<String> matchedIds;

  const _MessageList({
    required this.messages,
    required this.streaming,
    required this.onDecide,
    this.scrollController,
    this.activeMatchId,
    this.matchedIds = const {},
  });

  @override
  Widget build(BuildContext context) {
    final itemCount = messages.length + (streaming != null ? 1 : 0);

    // `reverse: true` anchors the viewport to the bottom (offset 0 = newest)
    // and keeps it there as content arrives — no manual scroll-to-bottom is
    // needed. The previous animateTo-on-every-rebuild fought this and caused
    // overlapping animations (flicker / runaway scroll) during streaming.
    return ListView.separated(
      controller: scrollController,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
      itemCount: itemCount,
      separatorBuilder: (context, idx) => const SizedBox(height: 14),
      itemBuilder: (_, i) {
        // Index 0 = bottom = newest. Stable keys are REQUIRED here: when the
        // streaming bubble appears/disappears at index 0 every other item's
        // index shifts by 1, and without keys Flutter re-matches elements by
        // position — briefly painting the wrong message at a slot (the
        // momentary C/B/A → B/C/A reorder). Keying by message id makes it
        // match by identity instead.
        if (streaming != null && i == 0) {
          return KeyedSubtree(
            key: const ValueKey('streaming'),
            child: StreamingBubble(streaming!),
          );
        }
        final msgIdx = messages.length - 1 - (i - (streaming != null ? 1 : 0));
        final msg = messages[msgIdx];
        final isMatch = matchedIds.contains(msg.id);
        final isActiveMatch = msg.id == activeMatchId;

        final bubble = switch (msg) {
          UserMsg() => UserBubble(msg),
          AssistantMsg() => AssistantBubble(msg),
          ToolEvent() => ToolRequestCard(tool: msg, onDecide: onDecide),
          CompactionMsg() => CompactionBubble(msg),
        };

        final highlightedBubble = !isMatch
            ? bubble
            : _SearchMatchWrapper(
                isActive: isActiveMatch,
                child: bubble,
              );

        return KeyedSubtree(
          key: ValueKey(msg.id),
          child: highlightedBubble,
        );
      },
    );
  }
}

class _SearchMatchWrapper extends StatelessWidget {
  final bool isActive;
  final Widget child;

  const _SearchMatchWrapper({
    required this.isActive,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;

    if (!isActive) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: colors.accent.withValues(alpha: 0.35),
            width: 1.5,
          ),
        ),
        padding: const EdgeInsets.all(2),
        child: child,
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.accent, width: 2),
        boxShadow: [
          BoxShadow(
            color: colors.accent.withValues(alpha: 0.25),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      padding: const EdgeInsets.all(3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 4, left: 2, top: 2),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
            decoration: BoxDecoration(
              color: colors.accent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'MATCH',
              style: typo.monoSmall.copyWith(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: colors.bg,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _EmptyState({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: colors.muted, size: 48),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: colors.muted, fontSize: 14)),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: colors.accent,
                foregroundColor: colors.onAccent,
              ),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class _RevokedBanner extends StatelessWidget {
  final VoidCallback onRePair;
  const _RevokedBanner({required this.onRePair});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.red.shade900.withValues(alpha: 0.85),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(LucideIcons.unlink, color: Colors.white, size: 15),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Pairing revoked by Mac — re-pair to continue',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          GestureDetector(
            onTap: onRePair,
            child: const Text(
              'Re-pair',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One labelled key/value row in the session-info dialog. The value is
/// selectable so the user can copy the path / device name.
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontFamily: kMonoFamily,
              fontSize: 10,
              color: colors.muted,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 2),
          SelectableText(
            value,
            style: TextStyle(
              fontFamily: kMonoFamily,
              fontSize: 13,
              color: colors.text,
            ),
          ),
        ],
      ),
    );
  }
}
