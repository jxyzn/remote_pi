import 'package:app/pairing/storage.dart';
import 'package:app/protocol/protocol.dart';
import 'package:app/ui/core/themes/themes.dart';
import 'package:flutter/material.dart';

/// A row in the Home list.
///
/// Renders an inline presence dot (plano 12) driven by
/// [ConnectionManager.presenceStream]: green = online, grey = offline,
/// no dot = relay hasn't reported yet.
class SessionTile extends StatelessWidget {
  final PeerRecord peer;
  /// `true` when the room is announced live on the relay AND the
  /// relay itself is reachable. Drives the green dot.
  final bool isLive;
  /// `true` when the WS to the relay is currently retrying / down.
  /// Overrides `isLive` and renders an amber "reconnecting" dot —
  /// the app has no fresh signal on any room right now.
  final bool isReconnecting;
  /// Plan-18 follow-up — `true` when the agent in this room is
  /// currently producing a response. Highest-priority colour (blue).
  final bool isWorking;
  final RoomInfo? room;
  final VoidCallback onOpen;
  /// Plan/tablet — `true` when this is the session shown in the tablet's
  /// detail pane. Paints the accent left-bar + faint fill from the mock.
  /// Always `false` on phone (no persistent selection there).
  final bool isSelected;
  /// Plan-17 follow-up — long-press context menu. Caller wires the
  /// dialog (rename + delete-offline). Optional; when null the tile
  /// only responds to tap.
  final VoidCallback? onLongPress;

  const SessionTile({
    super.key,
    required this.peer,
    required this.isLive,
    required this.onOpen,
    this.room,
    this.isReconnecting = false,
    this.isWorking = false,
    this.isSelected = false,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.surface,
      child: InkWell(
        onTap: onOpen,
        onLongPress: onLongPress,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isSelected
                ? colors.accent.withValues(alpha: 0.12)
                : colors.surface,
            border: Border(
              left: BorderSide(
                color: isSelected ? colors.accent : Colors.transparent,
                width: 4,
              ),
            ),
          ),
          child: Padding(
            // Compact vertical inset so more sessions fit on screen.
            padding: EdgeInsets.fromLTRB(isSelected ? 8 : 12, 9, 12, 9),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _Avatar(name: _avatarName()),
                const SizedBox(width: 11),
                Expanded(
                  child: _TitleBlock(peer: peer, room: room),
                ),
                const SizedBox(width: 8),
                _PresenceDot(
                  isLive: isLive,
                  isReconnecting: isReconnecting,
                  isWorking: isWorking,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _avatarName() {
    final r = room;
    if (r != null) {
      if (r.name != null && r.name!.isNotEmpty) return r.name!;
      final cwd = r.cwd;
      if (cwd != null && cwd.isNotEmpty) {
        final segs = cwd.split('/').where((s) => s.isNotEmpty).toList();
        if (segs.isNotEmpty) return segs.last;
      }
    }
    if (peer.nickname?.isNotEmpty == true) return peer.nickname!;
    return peer.sessionName;
  }
}

class _PresenceDot extends StatelessWidget {
  final bool isLive;
  final bool isReconnecting;
  final bool isWorking;
  const _PresenceDot({
    required this.isLive,
    required this.isReconnecting,
    this.isWorking = false,
  });

  @override
  Widget build(BuildContext context) {
    // Plan-18 follow-up — 4-state dot. Priority high → low:
    //   working (agent streaming)   → blue
    //   reconnecting (relay down)   → amber
    //   live (relay up + announced) → green
    //   else (cached / offline)     → grey
    final colors = context.colors;
    final Color color = isWorking
        ? colors.working
        : isReconnecting
            ? colors.warning
            : isLive
                ? colors.success
                : colors.muted;
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        color: color,
        border: Border.all(color: colors.border, width: 1.2),
      ),
    );
  }
}

class _TitleBlock extends StatelessWidget {
  final PeerRecord peer;
  final RoomInfo? room;
  const _TitleBlock({required this.peer, required this.room});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final r = room;
    // Title preference: explicit room.name → cwd basename → peer
    // nickname → session name.
    final String title;
    if (r != null) {
      if (r.name != null && r.name!.isNotEmpty) {
        title = r.name!;
      } else if (r.cwd != null && r.cwd!.isNotEmpty) {
        final segs = r.cwd!.split('/').where((s) => s.isNotEmpty).toList();
        title = segs.isNotEmpty ? segs.last : r.cwd!;
      } else if (peer.nickname?.isNotEmpty == true) {
        title = peer.nickname!;
      } else {
        title = peer.sessionName;
      }
    } else {
      title =
          peer.nickname?.isNotEmpty == true ? peer.nickname! : peer.sessionName;
    }

    final model = room?.model;
    final hasModel = model != null && model.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: typo.sansTitle.copyWith(
            color: colors.text,
            fontSize: 14.5,
          ),
        ),
        const SizedBox(height: 3),
        if (hasModel)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
            decoration: BoxDecoration(
              color: colors.modelBadgeBg,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: colors.modelBadgeBorder, width: 1),
            ),
            child: Text(
              _truncateModel(model),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: typo.monoSmall.copyWith(
                color: colors.text,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        else
          Text(
            'Last paired: ${_relativeTime(peer.pairedAt)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: typo.sansSmall.copyWith(
              color: colors.muted,
              fontSize: 11.5,
            ),
          ),
      ],
    );
  }
}

String _truncateModel(String name) =>
    name.length <= 24 ? name : '${name.substring(0, 21)}…';

class _Avatar extends StatelessWidget {
  final String name;
  const _Avatar({required this.name});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final initial = _initial(name);
    final badgeColor = colors.avatarColorFor(name);
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7),
        color: badgeColor.withValues(alpha: 0.18),
        border: Border.all(color: colors.border, width: 1.5),
        boxShadow: colors.retroShadowSm,
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: typo.display.copyWith(
          color: badgeColor,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _initial(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '?';
  return trimmed.characters.first.toUpperCase();
}

String _relativeTime(String isoUtc) {
  final parsed = DateTime.tryParse(isoUtc);
  if (parsed == null) return isoUtc;
  final now = DateTime.now().toUtc();
  final diff = now.difference(parsed);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 30) return '${diff.inDays}d ago';
  return isoUtc.substring(0, 10);
}
