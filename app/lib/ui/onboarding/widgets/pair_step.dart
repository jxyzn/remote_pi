import 'package:app/ui/core/themes/themes.dart';
import 'package:app/ui/pairing/states/pairing_state.dart';
import 'package:app/ui/pairing/viewmodels/pairing_viewmodel.dart';
import 'package:app/ui/pairing/widgets/paste_qr_sheet.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

/// Onboarding step 3 — embeds the existing pairing flow. Watches the
/// already-registered `PairingViewModel` (Provider) and notifies the
/// onboarding flow when `pair_ok` lands.
class PairStep extends StatefulWidget {
  final VoidCallback onPaired;
  final VoidCallback onBack;
  final VoidCallback onSkip;
  const PairStep({
    super.key,
    required this.onPaired,
    required this.onBack,
    required this.onSkip,
  });

  @override
  State<PairStep> createState() => _PairStepState();
}

class _PairStepState extends State<PairStep> {
  final _scanner = MobileScannerController();
  bool _scannerActive = true;
  PairingState? _lastObserved;

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture, PairingViewModel vm) {
    if (!_scannerActive) return;
    for (final code in capture.barcodes) {
      final raw = code.rawValue;
      if (raw == null) continue;
      _submitRaw(raw, vm);
      break;
    }
  }

  /// Shared path between camera scan and manual paste. Disarms the
  /// scanner so the camera doesn't double-fire if both happen to
  /// resolve the QR at the same time.
  void _submitRaw(String raw, PairingViewModel vm) {
    if (!_scannerActive) return;
    _scannerActive = false;
    // ignore: unawaited_futures
    _scanner.stop();
    vm.onQrScanned(raw);
  }

  Future<void> _openPasteSheet(PairingViewModel vm) async {
    await showPasteQrSheet(context, onSubmit: (raw) => _submitRaw(raw, vm));
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PairingViewModel>();
    final state = vm.state;

    // Detect transition into PairingPaired and notify parent. Done once.
    if (state is PairingPaired && _lastObserved is! PairingPaired) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onPaired();
      });
    }
    _lastObserved = state;

    final colors = context.colors;
    final typo = context.typo;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          Text(
            'Connect to your device',
            style: typo.display.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            'On your host machine, open Pi and run:',
            style: typo.sansBody.copyWith(color: colors.muted2),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: colors.codeBg,
              border: Border.all(color: colors.border, width: 1.5),
              borderRadius: const BorderRadius.all(Radius.circular(8)),
              boxShadow: colors.retroShadowSm,
            ),
            child: Text(
              '/remote-pi pair',
              style: typo.mono.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.highlight,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Scan the QR code that appears:',
            style: typo.sansBody.copyWith(color: colors.muted2),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(8)),
              child: _buildScannerBody(state, vm),
            ),
          ),
          const SizedBox(height: 10),
          // Camera-less fallback: paste the QR payload as text.
          if (state is PairingScanning || state is PairingIdle)
            TextButton.icon(
              onPressed: () => _openPasteSheet(vm),
              icon: Icon(
                LucideIcons.clipboardPaste,
                size: 16,
                color: colors.accent,
              ),
              label: Text(
                "Can't scan? Paste code instead",
                style: typo.sansBody.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.accent,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              OutlinedButton(
                onPressed: widget.onBack,
                child: const Text('Back'),
              ),
              const Spacer(),
              TextButton(
                onPressed: widget.onSkip,
                style: TextButton.styleFrom(
                  foregroundColor: colors.accent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                child: Text(
                  'Scan later',
                  style: typo.sansTitle.copyWith(
                    fontSize: 13.5,
                    color: colors.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildScannerBody(PairingState state, PairingViewModel vm) {
    if (state is PairingScanning) {
      return Stack(
        children: [
          MobileScanner(
            controller: _scanner,
            onDetect: (capture) => _onDetect(capture, vm),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: context.colors.accent, width: 2),
              borderRadius: const BorderRadius.all(Radius.circular(8)),
            ),
          ),
        ],
      );
    }
    if (state is PairingConnecting) {
      return _StatusOverlay(
        icon: LucideIcons.refreshCw,
        message: 'Pairing…',
      );
    }
    if (state is PairingError) {
      return _StatusOverlay(
        icon: LucideIcons.circleAlert,
        message: state.message,
        actionLabel: state.canRetry ? 'Try again' : null,
        onAction: state.canRetry
            ? () {
                _scannerActive = true;
                _scanner.start();
                vm.retry();
              }
            : null,
      );
    }
    if (state is PairingPaired) {
      return _StatusOverlay(
        icon: LucideIcons.circleCheck,
        message: 'Paired!',
      );
    }
    return const SizedBox.shrink();
  }
}

class _StatusOverlay extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  const _StatusOverlay({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    return Container(
      color: colors.surface,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: colors.accent, size: 40),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: typo.sansBody.copyWith(color: colors.text),
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
