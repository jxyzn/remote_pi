import 'package:app/data/preferences/preferences.dart';
import 'package:app/domain/session_state.dart';
import 'package:app/pairing/storage.dart';
import 'package:app/protocol/protocol.dart';
import 'package:app/routing/adaptive.dart';
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

  /// Initial model name known before ViewModel bootstrap (from Home / SessionSelection).
  final String? initialModel;

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
    this.initialModel,
    this.initialOnline = false,
    this.showBack = true,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  bool _isSearching = false;
  bool _filterOnlyMatches = false;
  int _activeMatchIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

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
    if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? true)) return false;
    if (event is KeyDownEvent) {
      final isCtrlOrMeta = HardwareKeyboard.instance.isControlPressed ||
          HardwareKeyboard.instance.isMetaPressed;
      if (isCtrlOrMeta && event.logicalKey == LogicalKeyboardKey.keyF) {
        _toggleSearch();
        return true;
      }
      if (event.logicalKey == LogicalKeyboardKey.escape && _isSearching) {
        _closeSearch();
        return true;
      }
    }
    return false;
  }

  void _openSearch() {
    setState(() {
      _isSearching = true;
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
      _isSearching = false;
      _filterOnlyMatches = false;
      _searchController.clear();
      _activeMatchIndex = 0;
    });
  }

  void _toggleSearch() {
    if (_isSearching) {
      _closeSearch();
    } else {
      _openSearch();
    }
  }

  void _nextMatch(int total, List<ChatMessage> visible, List<String> matchingIds) {
    if (total == 0) return;
    setState(() {
      _activeMatchIndex = (_activeMatchIndex + 1) % total;
    });
    _scrollToActiveMatch(visible, matchingIds[_activeMatchIndex]);
  }

  void _prevMatch(int total, List<ChatMessage> visible, List<String> matchingIds) {
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

  static bool _messageMatchesQuery(ChatMessage msg, String query) {
    return msg.matchesSearchQuery(query);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ChatViewModel>();
    final state = vm.state;
    final prefs = context.watch<Preferences>();
    final colors = context.colors;
    final typo = context.typo;

    final List<ChatMessage> visibleMessages = switch (state) {
      ChatReady(:final messages) => prefs.hideToolCalls
          ? messages.where((m) => m is! ToolEvent).toList()
          : messages,
      _ => const [],
    };

    final query = _searchController.text.trim();
    final matchingIds = <String>[];
    if (query.isNotEmpty) {
      for (final m in visibleMessages) {
        if (_messageMatchesQuery(m, query)) {
          matchingIds.add(m.id);
        }
      }
    }

    if (matchingIds.isNotEmpty && _activeMatchIndex >= matchingIds.length) {
      _activeMatchIndex = matchingIds.length - 1;
    }
    final activeMatchId =
        (matchingIds.isNotEmpty && _activeMatchIndex < matchingIds.length)
            ? matchingIds[_activeMatchIndex]
            : null;

    final scaffold = Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Pairing revocation is the only banner kept — it's a hard
            // failure (can't proceed without re-pairing), red, with an
            // explicit action. Plain offline / Pi-gone / presence-off
            // banners were removed: the status line already surfaces
            // those, and stacking duplicates noise the surface.
            if (state is ChatReady && state.pairingRevoked)
              _RevokedBanner(onRePair: () => context.go('/pair')),
            if (_isSearching)
              _buildSearchBar(
                context: context,
                colors: colors,
                typo: typo,
                visibleMessages: visibleMessages,
                matchingIds: matchingIds,
                query: query,
              ),
            Expanded(
              child: _buildBody(
                context,
                state,
                vm,
                visibleMessages,
                matchingIds,
                query,
                activeMatchId,
              ),
            ),
            _buildInput(context, state, vm),
            _buildBottomBar(context, state),
          ],
        ),
      ),
    );

    // An interactive extension_ui_request (ask_user via pi-ask) renders
    // inline inside [_MessageList] directly above the input bar, allowing the
    // user to scroll up freely through the chat context while answering.
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): _toggleSearch,
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true): _toggleSearch,
        const SingleActivator(LogicalKeyboardKey.escape): _closeSearch,
      },
      child: scaffold,
    );
  }

  Widget _buildSearchBar({
    required BuildContext context,
    required AppColors colors,
    required AppTypography typo,
    required List<ChatMessage> visibleMessages,
    required List<String> matchingIds,
    required String query,
  }) {
    final hasMatches = matchingIds.isNotEmpty;
    final hasQuery = query.isNotEmpty;
    final matchText = !hasQuery
        ? ''
        : hasMatches
        ? '${_activeMatchIndex + 1} of ${matchingIds.length}'
        : '0 of 0';

    return Container(
      key: const Key('chat-search-bar'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          bottom: BorderSide(color: colors.border, width: 1.5),
        ),
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
              style: typo.sansBody.copyWith(
                fontSize: 13,
                color: colors.text,
              ),
              decoration: InputDecoration(
                hintText: 'Search chat…',
                hintStyle: typo.sansBody.copyWith(
                  fontSize: 13,
                  color: colors.muted,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
              ),
              onChanged: (text) {
                setState(() {
                  _activeMatchIndex = 0;
                });
                if (text.trim().isNotEmpty) {
                  final newMatches = visibleMessages
                      .where((m) => _messageMatchesQuery(m, text.trim()))
                      .map((m) => m.id)
                      .toList();
                  if (newMatches.isNotEmpty) {
                    _scrollToActiveMatch(visibleMessages, newMatches.first);
                  }
                }
              },
              onSubmitted: (_) {
                if (hasMatches) {
                  _nextMatch(matchingIds.length, visibleMessages, matchingIds);
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
                    ? colors.surface2
                    : colors.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: hasMatches ? colors.border : colors.error,
                  width: 1,
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
            tooltip: 'Previous match (Shift+Enter)',
            onPressed: hasMatches
                ? () => _prevMatch(matchingIds.length, visibleMessages, matchingIds)
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
                ? () => _nextMatch(matchingIds.length, visibleMessages, matchingIds)
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

  Widget _buildBottomBar(BuildContext context, ChatState state) {
    // Two-line status footer below the input box:
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
    final isReady = state is ChatReady;
    final isOffline = isReady && state.isOffline;
    final isRevoked = isReady && state.pairingRevoked;
    final isPeerOffline = isReady && state.peerOfflineReason != null;
    final isPresenceOffline = isReady && state.peerPresence is PresenceOffline;
    final actionsEnabled =
        isReady &&
        !isOffline &&
        !isRevoked &&
        !isPeerOffline &&
        !isPresenceOffline;

    // Plan/24-fix-title: pass the navigation hint into the helpers so
    // either line of the status bar (room or peer) shows it instead of
    // the generic placeholders when the ViewModel hasn't finished
    // bootstrapping yet.
    final roomName = _roomDisplayName(room, state, widget.initialTitle);
    // Plan/32g — line 2 (device) falls back to `initialDevice` (the Mac name
    // Home passed), NOT `initialTitle` (the room name) — so it shows the right
    // device from frame 1 and doesn't flip when the PeerRecord loads.
    final peerLabel = _peerDisplayName(peer, widget.initialDevice);

    final typo = context.typo;
    final shell = context.watch<ShellLayout?>();
    final sidebarCollapsed = shell?.isSidebarCollapsed ?? false;

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: colors.bg,
        border: Border(
          top: BorderSide(color: colors.border, width: 1.5),
        ),
      ),
      child: Row(
        children: [
          if (widget.showBack)
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(LucideIcons.chevronLeft, size: 19, color: colors.text),
              tooltip: 'Back',
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go('/home'),
            )
          else if (shell != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(
                sidebarCollapsed
                    ? LucideIcons.panelLeftOpen
                    : LucideIcons.panelLeftClose,
                size: 19,
                color: colors.text,
              ),
              tooltip: sidebarCollapsed ? 'Show sessions' : 'Hide sessions',
              onPressed: shell.toggleSidebar,
            )
          else
            const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _truncate(roomName, 32),
                  style: typo.sansTitle.copyWith(
                    fontSize: 14.5,
                    color: colors.text,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _truncate(peerLabel, 26),
                        overflow: TextOverflow.ellipsis,
                        style: typo.sansSmall.copyWith(
                          fontSize: 11,
                          color: colors.muted2,
                          fontWeight: FontWeight.w600,
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
                        final rawModel = (room?.model ?? widget.initialModel)?.trim();
                        final hasModel =
                            rawModel != null && rawModel.isNotEmpty;
                        final canTap = actionsEnabled && !isWorking;
                        final tooltipMessage = hasModel
                            ? (canTap
                                  ? '$label · $rawModel (tap for quick actions)'
                                  : '$label · $rawModel')
                            : label;

                        final pill = Container(
                          key: const Key('chat-status-pill'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: colors.border, width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(1.5),
                                  color: color,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                label,
                                style: typo.sansSmall.copyWith(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: color,
                                ),
                              ),
                              if (hasModel) ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  child: Text(
                                    '·',
                                    style: typo.sansSmall.copyWith(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: colors.muted,
                                    ),
                                  ),
                                ),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 180,
                                  ),
                                  child: Text(
                                    rawModel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: typo.monoSmall.copyWith(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w600,
                                      color: colors.text,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );

                        return Tooltip(
                          message: tooltipMessage,
                          child: InkWell(
                            onTap: canTap
                                ? () => showQuickActionsSheet(context)
                                : null,
                            borderRadius: BorderRadius.circular(4),
                            child: pill,
                          ),
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
            visualDensity: VisualDensity.compact,
            icon: Icon(
              _isSearching ? LucideIcons.searchX : LucideIcons.search,
              size: 18,
              color: _isSearching ? colors.accent : colors.muted2,
            ),
            tooltip: _isSearching ? 'Close search (Esc)' : 'Search chat (Ctrl+F)',
            onPressed: _toggleSearch,
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
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
        final typo = dCtx.typo;
        return AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: colors.border, width: 2),
          ),
          title: Text('Session info', style: typo.display),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoRow(label: 'Name', value: name),
              _InfoRow(label: 'Path', value: room?.cwd ?? '—', mono: true),
              _InfoRow(label: 'Owner', value: owner),
              if (model != null && model.isNotEmpty)
                _InfoRow(label: 'Model', value: model, mono: true),
              _InfoRow(label: 'Room', value: room?.roomId ?? '—', mono: true),
              _InfoRow(label: 'Paired', value: paired, mono: true),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dCtx).pop(),
              child: Text(
                'Close',
                style: typo.sansTitle.copyWith(color: colors.accent),
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
    List<String> matchingIds,
    String query,
    String? activeMatchId,
  ) {
    final prefs = context.watch<Preferences>();
    final verbosity = prefs.sessionVerbosity;
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
      ChatReady(
        :final streaming,
        :final pendingUiRequest,
        :final pendingUiError,
      ) => () {
        // Empty body → the default placeholder (Pi brand icon + "Nothing
        // here"), shown whenever there's nothing to render — including while
        // reconnecting (the reconnect handshake never swaps the body).
        if (visibleMessages.isEmpty && streaming == null && pendingUiRequest == null) {
          return const _EmptyState(
            icon: LucideIcons.terminal,
            message: 'Nothing here',
          );
        }

        final displayed = (_isSearching && _filterOnlyMatches && query.isNotEmpty)
            ? visibleMessages.where((m) => matchingIds.contains(m.id)).toList()
            : visibleMessages;

        if (_isSearching && _filterOnlyMatches && query.isNotEmpty && displayed.isEmpty) {
          return _EmptyState(
            icon: LucideIcons.searchX,
            message: 'No messages match "$query"',
          );
        }

        return _MessageList(
          messages: displayed,
          streaming: (_isSearching && _filterOnlyMatches && query.isNotEmpty) ? null : streaming,
          pendingUiRequest: (_isSearching && _filterOnlyMatches && query.isNotEmpty) ? null : pendingUiRequest,
          pendingUiError: pendingUiError,
          verbosity: verbosity,
          onRespondUi: vm.respondExtensionUi,
          onDecide: (id, decision) => vm.approveTool(id, decision),
          scrollController: _scrollController,
          activeMatchId: activeMatchId,
          matchedIds: matchingIds.toSet(),
        );
      }(),
    };
  }

  Widget _buildInput(BuildContext context, ChatState state, ChatViewModel vm) {
    final isReady = state is ChatReady;
    final isOffline = isReady && state.isOffline;
    final isRevoked = isReady && state.pairingRevoked;
    final isPeerOffline = isReady && state.peerOfflineReason != null;
    // Live relay-reported offline (no `bye`): Pi is just not reachable.
    final isPresenceOffline = isReady && state.peerPresence is PresenceOffline;
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
    final actionsEnabled =
        isReady &&
        !isOffline &&
        !isRevoked &&
        !isPeerOffline &&
        !isPresenceOffline;

    return InputBar(
      disabled:
          !isReady ||
          isOffline ||
          isRevoked ||
          isPeerOffline ||
          isPresenceOffline,
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
  final ExtensionUiRequest? pendingUiRequest;
  final String? pendingUiError;
  final SessionVerbosity verbosity;
  final Future<void> Function(ExtensionUiResponse)? onRespondUi;
  final void Function(String, ApproveDecision) onDecide;
  final ScrollController? scrollController;
  final String? activeMatchId;
  final Set<String> matchedIds;

  const _MessageList({
    required this.messages,
    required this.streaming,
    this.pendingUiRequest,
    this.pendingUiError,
    this.verbosity = SessionVerbosity.defaultLevel,
    this.onRespondUi,
    required this.onDecide,
    this.scrollController,
    this.activeMatchId,
    this.matchedIds = const {},
  });

  @override
  Widget build(BuildContext context) {
    final hasUi = pendingUiRequest != null;
    final hasStreaming = streaming != null;
    final uiOffset = hasUi ? 1 : 0;
    final streamingOffset = hasStreaming ? 1 : 0;
    final extraCount = uiOffset + streamingOffset;
    final itemCount = messages.length + extraCount;
    final mostRecentToolId = _findMostRecentToolCallId(messages);

    // `reverse: true` anchors the viewport to the bottom (offset 0 = newest)
    // and keeps it there as content arrives — no manual scroll-to-bottom is
    // needed. The previous animateTo-on-every-rebuild fought this and caused
    // overlapping animations (flicker / runaway scroll) during streaming.
    return ListView.separated(
      controller: scrollController,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      itemCount: itemCount,
      separatorBuilder: (context, idx) => const SizedBox(height: 9),
      itemBuilder: (_, i) {
        // Index 0 = bottom = newest. Stable keys are REQUIRED here: when the
        // pending UI card or streaming bubble appears/disappears at index 0 every
        // other item's index shifts, and without keys Flutter re-matches
        // elements by position. Keying by id makes it match by identity.
        if (hasUi && i == 0) {
          return KeyedSubtree(
            key: ValueKey(pendingUiRequest!.id),
            child: ExtensionUiSheet(
              request: pendingUiRequest!,
              error: pendingUiError,
              onRespond: onRespondUi ?? (_) async {},
            ),
          );
        }
        if (hasStreaming && i == uiOffset) {
          return KeyedSubtree(
            key: const ValueKey('streaming'),
            child: StreamingBubble(streaming!),
          );
        }
        final msgIdx = messages.length - 1 - (i - extraCount);
        final msg = messages[msgIdx];
        final isMatch = matchedIds.contains(msg.id);
        final isActiveMatch = msg.id == activeMatchId;

        final bubble = switch (msg) {
          UserMsg() => UserBubble(msg),
          AssistantMsg() => AssistantBubble(msg),
          ToolEvent() => ToolRequestCard(
            tool: msg,
            verbosity: verbosity,
            isRecent: msg.id == mostRecentToolId,
            onDecide: onDecide,
          ),
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

  /// Identifies the ID of the single most recent tool call in the session.
  static String? _findMostRecentToolCallId(List<ChatMessage> messages) {
    for (int i = messages.length - 1; i >= 0; i--) {
      if (messages[i] is ToolEvent) {
        return messages[i].id;
      }
    }
    return null;
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
    final typo = context.typo;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.border, width: 1.5),
              boxShadow: colors.retroShadowSm,
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: colors.accent, size: 26),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: typo.sansBody.copyWith(color: colors.muted2),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 18),
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
    final colors = context.colors;
    final typo = context.typo;
    return Container(
      width: double.infinity,
      color: colors.error,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: Row(
        children: [
          const Icon(LucideIcons.unlink, color: Colors.white, size: 15),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Pairing revoked by host — re-pair to continue',
              style: typo.sansSmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          GestureDetector(
            onTap: onRePair,
            child: Text(
              'Re-pair',
              style: typo.sansSmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
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
  final bool mono;
  const _InfoRow({
    required this.label,
    required this.value,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: typo.badge.copyWith(color: colors.muted),
          ),
          const SizedBox(height: 2),
          SelectableText(
            value,
            style: mono ? typo.mono : typo.sansBody,
          ),
        ],
      ),
    );
  }
}
