import 'package:app/pairing/storage.dart';
import 'package:app/ui/core/themes/themes.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// One row in the paired-peers list (Settings).
///
/// - Swipe end-to-start → [onRevokeRequested]. Caller confirms + deletes.
/// - Pencil icon → [onEditNickname].
/// - Title is `peer.nickname` when set, otherwise `peer.sessionName`. When
///   a nickname is present, the original session name appears beneath it
///   in muted style.
///
/// Settings does NOT switch the active peer anymore — Home does that via
/// [Preferences.selectedPeerEpk]. This widget is pure config.
class PeerListItem extends StatelessWidget {
  final PeerRecord peer;
  final Future<bool> Function() onRevokeRequested;
  final VoidCallback onEditNickname;

  const PeerListItem({
    super.key,
    required this.peer,
    required this.onRevokeRequested,
    required this.onEditNickname,
  });

  /// Platform hint for the secondary line (Mac / Linux / Windows / Pi
  /// OS). Pi-extension hasn't surfaced this yet; once it does
  /// (PairOk extension or a new field on PeerRecord), wire here and
  /// the slot lights up. Until then returns null and the row stays
  /// title-only.
  static String? _platformLabel(PeerRecord peer) {
    // ignore: dead_code
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final nickname = peer.nickname;
    final hasNickname = nickname != null && nickname.isNotEmpty;

    return Dismissible(
      key: ValueKey('peer-${peer.remoteEpk}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        color: colors.error,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.trash2, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Text(
              'Revoke',
              style: typo.sansTitle.copyWith(
                color: Colors.white,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (_) => onRevokeRequested(),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 6, 10),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(bottom: BorderSide(color: colors.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasNickname ? nickname : peer.sessionName,
                    style: typo.sansTitle.copyWith(fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (hasNickname) ...[
                    const SizedBox(height: 2),
                    Text(
                      peer.sessionName,
                      style: typo.sansSmall.copyWith(color: colors.muted2),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (_platformLabel(peer) != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _platformLabel(peer)!,
                      style: typo.monoSmall.copyWith(color: colors.muted),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: 'Edit nickname',
              visualDensity: VisualDensity.compact,
              icon: const Icon(LucideIcons.pencil, size: 17),
              color: colors.muted2,
              onPressed: onEditNickname,
            ),
          ],
        ),
      ),
    );
  }
}
