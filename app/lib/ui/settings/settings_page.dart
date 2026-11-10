import 'package:app/data/preferences/preferences.dart';
import 'package:app/data/transport/relay_config.dart';
import 'package:app/pairing/storage.dart';
import 'package:app/ui/core/themes/themes.dart';
import 'package:app/ui/settings/states/settings_state.dart';
import 'package:app/ui/settings/viewmodels/settings_viewmodel.dart';
import 'package:app/ui/settings/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

class SettingsPage extends StatelessWidget {
  /// Plan/tablet — `true` when presented as a modal bottom sheet (tablet)
  /// rather than a pushed full-screen route (phone). Swaps the back arrow
  /// for a close (X), since the sheet is dismissed, not popped to a parent.
  final bool embedded;

  const SettingsPage({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SettingsViewModel>();
    final state = vm.state;
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        title: const Text('Settings'),
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: Icon(
            embedded ? LucideIcons.x : LucideIcons.chevronLeft,
            size: embedded ? 22 : 18,
            color: colors.text,
          ),
          tooltip: embedded ? 'Close' : 'Back',
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(color: colors.border, height: 1),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const _RelaySection(),
          Divider(color: colors.border, height: 1),
          const _DisplaySection(),
          Divider(color: colors.border, height: 1),
          const _SectionHeader('Pairings'),
          switch (state) {
            SettingsLoading() => Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: CircularProgressIndicator(color: colors.accent),
              ),
            ),
            SettingsNoPeer() => const _EmptyState(),
            SettingsList(:final peers) => _PeerList(
              peers: peers,
              onRevoke: vm.revoke,
              onSetNickname: vm.setNickname,
            ),
          },
          // Plan-17 follow-up — entry point to pair an additional Pi.
          // The flow itself lives at /pair and survives whatever
          // peers/rooms already exist (PairingViewModel handles the
          // add path the same way as the first pair).
          const _AddPairingButton(),
        ],
      ),
    );
  }
}

class _AddPairingButton extends StatelessWidget {
  const _AddPairingButton();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: OutlinedButton.icon(
        onPressed: () => context.push('/pair'),
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.accent,
          backgroundColor: colors.surface,
          side: BorderSide(color: colors.border, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          minimumSize: const Size.fromHeight(0),
        ),
        icon: const Icon(LucideIcons.scanQrCode, size: 18),
        label: Text(
          'Add new pairing',
          style: typo.sansTitle.copyWith(fontSize: 13.5, color: colors.accent),
        ),
      ),
    );
  }
}

class _RelaySection extends StatefulWidget {
  const _RelaySection();
  @override
  State<_RelaySection> createState() => _RelaySectionState();
}

class _RelaySectionState extends State<_RelaySection> {
  late final TextEditingController _ctrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    final vm = context.read<SettingsViewModel>();
    _ctrl = TextEditingController(text: vm.relayUrlOverride);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final vm = context.read<SettingsViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    final err = await vm.saveRelayUrl(_ctrl.text);
    if (!mounted) return;
    setState(() {
      _error = err;
      if (err == null) {
        _ctrl.text = vm.relayUrlOverride;
      }
    });
    if (err == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Relay updated',
            style: context.typo.sansBody,
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SettingsViewModel>();
    final colors = context.colors;
    final typo = context.typo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeader('Relay'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _ctrl,
                keyboardType: TextInputType.url,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
                style: typo.mono.copyWith(
                  fontSize: 13,
                  color: colors.text,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'https://my-relay.example.com',
                  hintStyle: typo.mono.copyWith(
                    color: colors.muted,
                    fontSize: 12,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(LucideIcons.x, size: 15, color: colors.muted2),
                    tooltip: 'Clear URL',
                    onPressed: () => _ctrl.clear(),
                  ),
                  helperText: 'Current: ${vm.effectiveRelayUrl}',
                  helperStyle: typo.monoSmall.copyWith(
                    fontSize: 10.5,
                    color: colors.muted2,
                  ),
                  errorText: _error,
                  errorStyle: typo.sansSmall.copyWith(
                    fontSize: 11,
                    color: colors.error,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 9,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: colors.border, width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: colors.accent, width: 2.0),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton(
                    onPressed: _save,
                    child: const Text('Save'),
                  ),
                  TextButton(
                    onPressed: () {
                      _ctrl.text = kDefaultRelayUrl;
                      _save();
                    },
                    child: Text(
                      'Use default Relay',
                      style: typo.sansBody.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DisplaySection extends StatelessWidget {
  const _DisplaySection();

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<Preferences>();
    final colors = context.colors;
    final typo = context.typo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeader('Display'),
        // Theme preset — Classic (default monochrome) vs PICO-8 (fantasy console).
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Theme style',
                style: typo.sansTitle.copyWith(fontSize: 13.5),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<AppThemePreset>(
                  showSelectedIcon: false,
                  segments: [
                    for (final preset in AppThemePreset.values)
                      ButtonSegment(value: preset, label: Text(preset.label)),
                  ],
                  selected: {prefs.themePreset},
                  onSelectionChanged: (s) => prefs.setThemePreset(s.first),
                ),
              ),
            ],
          ),
        ),
        // Theme mode — System follows the OS; Light / Dark pin it.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Theme',
                style: typo.sansTitle.copyWith(fontSize: 13.5),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  segments: [
                    const ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('System'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text(
                        prefs.themePreset.isPico8 ? 'Arcade Light' : 'Light',
                      ),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text(
                        prefs.themePreset.isPico8 ? 'Console Dark' : 'Dark',
                      ),
                    ),
                  ],
                  selected: {prefs.themeMode},
                  onSelectionChanged: (s) => prefs.setThemeMode(s.first),
                ),
              ),
            ],
          ),
        ),
        // Retro header & badge typography — Arcade Pixel (Silkscreen) vs Clean Sans (Space Grotesk).
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Header & badge font',
                style: typo.sansTitle.copyWith(fontSize: 13.5),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<AppRetroFontMode>(
                  showSelectedIcon: false,
                  segments: [
                    for (final mode in AppRetroFontMode.values)
                      ButtonSegment(value: mode, label: Text(mode.label)),
                  ],
                  selected: {prefs.retroFontMode},
                  onSelectionChanged: (s) => prefs.setRetroFontMode(s.first),
                ),
              ),
            ],
          ),
        ),
        // Text size — the app hardcodes its font sizes and Flutter can't read
        // iOS's per-app Text Size, so without this the only way to enlarge chat
        // text is the OS-wide accessibility setting (issue #114).
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Text size',
                style: typo.sansTitle.copyWith(fontSize: 13.5),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<AppFontScale>(
                  showSelectedIcon: false,
                  segments: [
                    for (final scale in AppFontScale.values)
                      ButtonSegment(value: scale, label: Text(scale.label)),
                  ],
                  selected: {prefs.fontScale},
                  onSelectionChanged: (s) => prefs.setFontScale(s.first),
                ),
              ),
            ],
          ),
        ),
        // Session verbosity — Terse (collapsed), Default (auto-collapse on success), Verbose (expanded).
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Session verbosity',
                style: typo.sansTitle.copyWith(fontSize: 13.5),
              ),
              const SizedBox(height: 2),
              Text(
                switch (prefs.sessionVerbosity) {
                  SessionVerbosity.terse =>
                    'All tool calls initially collapsed into a single line.',
                  SessionVerbosity.defaultLevel =>
                    'Most recent tool call stays expanded; older completed tools collapse.',
                  SessionVerbosity.verbose =>
                    'All tool calls stay expanded unless clicked.',
                },
                style: typo.sansSmall.copyWith(color: colors.muted2),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<SessionVerbosity>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: SessionVerbosity.terse,
                      label: Text('Terse'),
                    ),
                    ButtonSegment(
                      value: SessionVerbosity.defaultLevel,
                      label: Text('Default'),
                    ),
                    ButtonSegment(
                      value: SessionVerbosity.verbose,
                      label: Text('Verbose'),
                    ),
                  ],
                  selected: {prefs.sessionVerbosity},
                  onSelectionChanged: (s) =>
                      prefs.setSessionVerbosity(s.first),
                ),
              ),
            ],
          ),
        ),
        SwitchListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          activeThumbColor: colors.accent,
          title: Text(
            'Hide tool calls in chat',
            style: typo.sansTitle.copyWith(fontSize: 13.5),
          ),
          subtitle: Text(
            'Only show your messages and the assistant replies.',
            style: typo.sansSmall.copyWith(color: colors.muted2),
          ),
          value: prefs.hideToolCalls,
          onChanged: (v) => prefs.setHideToolCalls(v),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader(this.label);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
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
          Text(
            label.toUpperCase(),
            style: typo.badge.copyWith(
              color: colors.muted2,
              letterSpacing: 0.9,
            ),
          ),
        ],
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
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.monitorSmartphone, color: colors.muted, size: 36),
          const SizedBox(height: 10),
          Text(
            'No pairings yet',
            style: typo.sansTitle.copyWith(color: colors.muted2),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap + to pair a new host.',
            style: typo.sansSmall.copyWith(color: colors.muted),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => context.push('/pair'),
            icon: const Icon(LucideIcons.scanQrCode, size: 18),
            label: const Text('Scan QR'),
          ),
        ],
      ),
    );
  }
}

class _PeerList extends StatelessWidget {
  final List<PeerRecord> peers;
  final Future<void> Function(String epk) onRevoke;
  final Future<void> Function(String epk, String? nickname) onSetNickname;

  const _PeerList({
    required this.peers,
    required this.onRevoke,
    required this.onSetNickname,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final peer in peers)
          PeerListItem(
            peer: peer,
            onEditNickname: () => _editNickname(context, peer),
            onRevokeRequested: () async {
              final confirmed = await showRevokeConfirmDialog(
                context,
                peer: peer,
              );
              if (!confirmed) return false;
              await onRevoke(peer.remoteEpk);
              return true;
            },
          ),
      ],
    );
  }

  Future<void> _editNickname(BuildContext context, PeerRecord peer) async {
    final result = await showNicknameEditor(
      context,
      defaultName: peer.sessionName,
      currentNickname: peer.nickname ?? '',
    );
    if (result == null) return; // canceled
    await onSetNickname(peer.remoteEpk, result.isEmpty ? null : result);
  }
}
