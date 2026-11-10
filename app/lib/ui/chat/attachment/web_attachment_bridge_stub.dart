import 'dart:typed_data';

abstract class WebAttachmentBridge {
  static WebAttachmentHandle? attach({
    required void Function(Uint8List bytes, String mime) onImage,
    void Function(bool isDragging)? onDragStateChanged,
  }) =>
      null;
}

abstract class WebAttachmentHandle {
  void dispose();
}
