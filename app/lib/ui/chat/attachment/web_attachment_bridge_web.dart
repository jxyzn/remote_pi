// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

abstract class WebAttachmentBridge {
  static WebAttachmentHandle? attach({
    required void Function(Uint8List bytes, String mime) onImage,
    void Function(bool isDragging)? onDragStateChanged,
  }) {
    return _WebAttachmentHandleImpl(
      onImage: onImage,
      onDragStateChanged: onDragStateChanged,
    );
  }
}

abstract class WebAttachmentHandle {
  void dispose();
}

class _WebAttachmentHandleImpl implements WebAttachmentHandle {
  _WebAttachmentHandleImpl({
    required this.onImage,
    this.onDragStateChanged,
  }) {
    _init();
  }

  final void Function(Uint8List bytes, String mime) onImage;
  final void Function(bool isDragging)? onDragStateChanged;

  StreamSubscription? _pasteSub;
  StreamSubscription? _dragEnterSub;
  StreamSubscription? _dragOverSub;
  StreamSubscription? _dragLeaveSub;
  StreamSubscription? _dropSub;

  int _dragDepth = 0;

  void _init() {
    _pasteSub = html.document.onPaste.listen(_handlePaste);
    _dragEnterSub = html.window.onDragEnter.listen(_handleDragEnter);
    _dragOverSub = html.window.onDragOver.listen(_handleDragOver);
    _dragLeaveSub = html.window.onDragLeave.listen(_handleDragLeave);
    _dropSub = html.window.onDrop.listen(_handleDrop);
  }

  void _handlePaste(html.ClipboardEvent event) {
    final items = event.clipboardData?.items;
    if (items == null) return;

    final count = items.length ?? 0;
    for (var i = 0; i < count; i++) {
      final item = items[i];
      final type = item.type;
      if (type != null && type.startsWith('image/')) {
        final file = item.getAsFile();
        if (file != null) {
          event.preventDefault();
          _readFile(file, type);
          break;
        }
      }
    }
  }

  void _handleDragEnter(html.MouseEvent event) {
    event.preventDefault();
    _dragDepth++;
    if (_dragDepth == 1) {
      onDragStateChanged?.call(true);
    }
  }

  void _handleDragOver(html.MouseEvent event) {
    event.preventDefault();
    try {
      event.dataTransfer.dropEffect = 'copy';
    } catch (_) {}
    if (_dragDepth == 0) {
      _dragDepth = 1;
      onDragStateChanged?.call(true);
    }
  }

  void _handleDragLeave(html.MouseEvent event) {
    _dragDepth = (_dragDepth - 1).clamp(0, 999);
    if (_dragDepth == 0) {
      onDragStateChanged?.call(false);
    }
  }

  void _handleDrop(html.MouseEvent event) {
    event.preventDefault();
    _dragDepth = 0;
    onDragStateChanged?.call(false);

    final files = event.dataTransfer.files;
    if (files == null || files.isEmpty) return;

    for (final file in files) {
      final name = file.name.toLowerCase();
      final type = file.type;
      final isImage = type.startsWith('image/') ||
          name.endsWith('.png') ||
          name.endsWith('.jpg') ||
          name.endsWith('.jpeg') ||
          name.endsWith('.webp') ||
          name.endsWith('.gif') ||
          name.endsWith('.bmp');

      if (isImage) {
        _readFile(file, type.isNotEmpty ? type : 'image/jpeg');
        break; // Only attach one image per drop
      }
    }
  }

  void _readFile(html.File file, String mime) {
    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    reader.onLoadEnd.listen((_) {
      final result = reader.result;
      if (result is ByteBuffer) {
        onImage(Uint8List.view(result), mime);
      } else if (result is Uint8List) {
        onImage(result, mime);
      }
    });
  }

  @override
  void dispose() {
    _pasteSub?.cancel();
    _dragEnterSub?.cancel();
    _dragOverSub?.cancel();
    _dragLeaveSub?.cancel();
    _dropSub?.cancel();
    _dragDepth = 0;
  }
}
