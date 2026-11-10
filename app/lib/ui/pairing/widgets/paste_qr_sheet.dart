import 'package:app/ui/core/themes/themes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Show a bottom sheet that lets the user paste the QR code payload as
/// text — useful when the device's camera can't read the on-screen QR
/// (low-end front cameras, scratched lenses, etc).
///
/// Submits via [onSubmit], which receives the raw `remotepi://pair?…`
/// string the user typed/pasted. The sheet closes automatically after
/// submit; if [onSubmit] throws or rejects the value, the sheet is
/// already gone — the caller surfaces the error through the same
/// pairing-error path the camera scan uses.
Future<void> showPasteQrSheet(
  BuildContext context, {
  required void Function(String raw) onSubmit,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.colors.bg,
    isScrollControlled: true,
    builder: (sheetCtx) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
        ),
        child: const _PasteQrSheetBody(),
      ).withOnSubmit(onSubmit);
    },
  );
}

/// Hook to wire the inner submit callback to the outer parameter. Kept
/// here so the body widget itself is `const`-able for the common case
/// of opening the sheet without nesting the closure inside the build.
extension _PasteQrSheetHook on Widget {
  Widget withOnSubmit(void Function(String raw) onSubmit) {
    return _OnSubmitScope(onSubmit: onSubmit, child: this);
  }
}

class _OnSubmitScope extends InheritedWidget {
  final void Function(String raw) onSubmit;
  const _OnSubmitScope({required this.onSubmit, required super.child});

  static void Function(String raw) of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<_OnSubmitScope>();
    assert(
      scope != null,
      '_PasteQrSheetBody must be wrapped in a _OnSubmitScope (use showPasteQrSheet).',
    );
    return scope!.onSubmit;
  }

  @override
  bool updateShouldNotify(_OnSubmitScope old) => old.onSubmit != onSubmit;
}

class _PasteQrSheetBody extends StatefulWidget {
  const _PasteQrSheetBody();

  @override
  State<_PasteQrSheetBody> createState() => _PasteQrSheetBodyState();
}

class _PasteQrSheetBodyState extends State<_PasteQrSheetBody> {
  final _controller = TextEditingController();
  bool _canSubmit = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  void _onChanged() {
    final next = _controller.text.trim().isNotEmpty;
    if (next != _canSubmit) {
      setState(() => _canSubmit = next);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) return;
    _controller.text = text.trim();
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
  }

  void _submit() {
    final raw = _controller.text.trim();
    if (raw.isEmpty) return;
    final onSubmit = _OnSubmitScope.of(context);
    Navigator.of(context).pop();
    onSubmit(raw);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Paste pairing code',
              style: typo.display.copyWith(fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              "Can't scan the QR? Paste the text from your terminal "
              "below. It starts with remotepi://pair?…",
              style: typo.sansSmall.copyWith(color: colors.muted2),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              minLines: 3,
              maxLines: 6,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.none,
              keyboardType: TextInputType.url,
              style: typo.mono.copyWith(
                fontSize: 12,
                color: colors.text,
              ),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'remotepi://pair?t=…',
                hintStyle: typo.mono.copyWith(
                  fontSize: 12,
                  color: colors.muted,
                ),
                filled: true,
                fillColor: colors.codeBg,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pasteFromClipboard,
                    icon: Icon(
                      LucideIcons.clipboardPaste,
                      size: 16,
                      color: colors.accent,
                    ),
                    label: Text(
                      'Paste from clipboard',
                      style: typo.sansBody.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.accent,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: _canSubmit ? _submit : null,
              child: const Text('Pair'),
            ),
          ],
        ),
      ),
    );
  }
}
