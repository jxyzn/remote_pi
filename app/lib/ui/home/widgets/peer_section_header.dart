import 'package:app/pairing/storage.dart';
import 'package:app/ui/core/themes/themes.dart';
import 'package:flutter/material.dart';

/// Per-pairing section header on the Home list (one per Pi). Shows the device
/// label (nickname → sessionName → epk prefix). The old `via <harness>`
/// subtitle was dropped as redundant.
class PeerSectionHeader extends StatelessWidget {
  final PeerRecord peer;
  const PeerSectionHeader({super.key, required this.peer});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final label = (peer.nickname?.isNotEmpty ?? false)
        ? peer.nickname!
        : peer.sessionName.isNotEmpty
            ? peer.sessionName
            : peer.remoteEpk.substring(0, 8);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: colors.highlight,
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: typo.badge.copyWith(
                color: colors.muted2,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
