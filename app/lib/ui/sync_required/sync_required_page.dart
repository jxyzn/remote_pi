import 'dart:io' show Platform;

import 'package:app/config/dependencies.dart';
import 'package:app/pairing/owner_identity_bridge.dart';
import 'package:app/ui/core/themes/themes.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Plan 23 — first-launch gate when the platform's key-sync surface
/// (iCloud Keychain on iOS, Google Backup / Block Store on Android) is
/// not available. The app cannot proceed without it because the Owner
/// Ed25519 keypair has no other persistence path.
class SyncRequiredPage extends StatefulWidget {
  const SyncRequiredPage({super.key});

  @override
  State<SyncRequiredPage> createState() => _SyncRequiredPageState();
}

class _SyncRequiredPageState extends State<SyncRequiredPage> {
  bool _checking = false;

  Future<void> _recheck() async {
    if (_checking) return;
    setState(() => _checking = true);
    final result = await injector.get<OwnerIdentityBridge>().boot();
    if (!mounted) return;
    setState(() => _checking = false);
    if (result is! SyncUnavailableResult) {
      // Bounce through /boot so the router's redirect logic re-evaluates
      // (pairs-empty → /onboarding, pairs-non-empty → /home).
      context.go('/boot');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIOS = Platform.isIOS;
    final requirements = isIOS ? _iosRequirements : _androidRequirements;
    final why = isIOS
        ? 'Remote Pi keeps your Ed25519 owner key in iCloud Keychain so '
              'you can switch iPhones or pair your iPad without scanning '
              'a new QR.'
        : 'Remote Pi keeps your Ed25519 owner key in Google Block Store '
              'so you can restore it on a new device through Google '
              'Backup without losing your paired Pis.';

    final colors = context.colors;
    final typo = context.typo;
    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Icon(
                isIOS ? LucideIcons.cloudOff : LucideIcons.cloudUpload,
                color: colors.accent,
                size: 40,
              ),
              const SizedBox(height: 16),
              Text(
                'Sync required',
                style: typo.display.copyWith(fontSize: 20),
              ),
              const SizedBox(height: 8),
              Text(
                why,
                style: typo.sansBody.copyWith(color: colors.muted2),
              ),
              const SizedBox(height: 18),
              Text(
                'TO ENABLE, ON THIS DEVICE:',
                style: typo.badge.copyWith(color: colors.muted2),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  itemCount: requirements.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _RequirementCard(
                    index: i + 1,
                    requirement: requirements[i],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _checking ? null : _recheck,
                child: _checking
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: colors.onAccent,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Check again'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _Requirement {
  final String title;
  final String path;
  final String? note;
  const _Requirement({required this.title, required this.path, this.note});
}

const _androidRequirements = <_Requirement>[
  _Requirement(
    title: 'Set up a screen lock',
    path: 'Settings › Security › Screen lock',
    note: 'PIN, pattern or biometrics — required by Block Store.',
  ),
  _Requirement(
    title: 'Turn on Google Backup',
    path: 'Settings › System › Backup\n'
        '(Samsung: Settings › Accounts and backup › Backup data)',
  ),
  _Requirement(
    title: 'Sign in to a Google account',
    path: 'Settings › Passwords & accounts › Add account › Google',
  ),
];

const _iosRequirements = <_Requirement>[
  _Requirement(
    title: 'Sign in to iCloud',
    path: 'Settings › [your name]',
    note: 'If you see "Sign in to your iPhone" at the top, tap it.',
  ),
  _Requirement(
    title: 'Turn on iCloud Keychain',
    path: 'Settings › [your name] › iCloud › Passwords and Keychain',
    note: 'Toggle "Sync this iPhone" on.',
  ),
];

class _RequirementCard extends StatelessWidget {
  final int index;
  final _Requirement requirement;
  const _RequirementCard({required this.index, required this.requirement});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border, width: 1.5),
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        boxShadow: colors.retroShadowSm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.accent,
              borderRadius: const BorderRadius.all(Radius.circular(6)),
              border: Border.all(color: colors.border),
            ),
            child: Text(
              '$index',
              style: typo.badge.copyWith(
                fontSize: 11,
                color: colors.onAccent,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  requirement.title,
                  style: typo.sansTitle.copyWith(fontSize: 13.5),
                ),
                const SizedBox(height: 2),
                Text(
                  requirement.path,
                  style: typo.sansSmall.copyWith(color: colors.muted2),
                ),
                if (requirement.note != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    requirement.note!,
                    style: typo.sansSmall.copyWith(
                      fontSize: 11,
                      color: colors.muted,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
