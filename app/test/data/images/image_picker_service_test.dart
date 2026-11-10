// Plan/30 — ImagePickerService pick + iterative size-ceiling logic, via the
// ImagePickerBackend seam (no plugins / device).

import 'dart:typed_data';

import 'package:app/data/images/image_picker_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeBackend implements ImagePickerBackend {
  String? path = '/tmp/pic.jpg'; // null → user cancelled
  bool denied = false;

  /// Bytes returned per compress pass, in order. The last value repeats.
  List<int> sizes = [200 * 1024];
  final List<({int side, int quality})> calls = [];
  ImageSourceKind? pickedSource;

  @override
  Future<String?> pick(ImageSourceKind source) async {
    pickedSource = source;
    if (denied) throw const ImagePermissionDeniedException();
    return path;
  }

  @override
  Future<Uint8List> compress(
    String path, {
    required int maxSide,
    required int quality,
  }) async {
    calls.add((side: maxSide, quality: quality));
    final idx = calls.length - 1;
    final n = idx < sizes.length ? sizes[idx] : sizes.last;
    return Uint8List(n);
  }

  @override
  Future<Uint8List> compressBytes(
    Uint8List bytes, {
    required int maxSide,
    required int quality,
  }) async =>
      compress('', maxSide: maxSide, quality: quality);
}

void main() {
  test('gallery pick under the ceiling compresses once', () async {
    final backend = _FakeBackend()..sizes = [180 * 1024];
    final svc = ImagePickerService(backend);

    final result = await svc.pickFromGallery();
    expect(result, isNotNull);
    expect(result!.mime, 'image/jpeg');
    expect(result.bytes.length, 180 * 1024);
    expect(backend.pickedSource, ImageSourceKind.gallery);
    expect(backend.calls, hasLength(1));
    expect(backend.calls.first.side, 1568);
    expect(backend.calls.first.quality, 80);
  });

  test('oversized result re-compresses with smaller side + quality', () async {
    final backend = _FakeBackend()
      // First two passes blow the 1.5MB ceiling, the third lands under.
      ..sizes = [2000 * 1024, 1700 * 1024, 300 * 1024];
    final svc = ImagePickerService(backend);

    final result = await svc.pickFromCamera();
    expect(result!.bytes.length, 300 * 1024);
    expect(backend.calls.length, 3);
    // Side + quality shrink monotonically across passes.
    expect(backend.calls[1].side, lessThan(backend.calls[0].side));
    expect(backend.calls[1].quality, lessThan(backend.calls[0].quality));
    expect(backend.calls[2].side, lessThan(backend.calls[1].side));
  });

  test('cancelled pick returns null and never compresses', () async {
    final backend = _FakeBackend()..path = null;
    final svc = ImagePickerService(backend);
    expect(await svc.pickFromGallery(), isNull);
    expect(backend.calls, isEmpty);
  });

  test('denied camera permission propagates as a typed exception', () async {
    final backend = _FakeBackend()..denied = true;
    final svc = ImagePickerService(backend);
    expect(
      () => svc.pickFromCamera(),
      throwsA(isA<ImagePermissionDeniedException>()),
    );
  });

  test('processImageBytes returns null on empty input and compresses non-empty bytes', () async {
    final backend = _FakeBackend()..sizes = [1600 * 1024, 240 * 1024];
    final svc = ImagePickerService(backend);

    expect(await svc.processImageBytes(Uint8List(0), 'image/png'), isNull);
    expect(backend.calls, isEmpty);

    final result = await svc.processImageBytes(
      Uint8List.fromList([1, 2, 3, 4]),
      'image/png',
    );
    expect(result, isNotNull);
    expect(result!.bytes.length, 240 * 1024);
    expect(result.mime, 'image/jpeg');
    expect(backend.calls.length, 2);
  });

  test('processImageBytes preserves original mime when compressor returns empty fallback', () async {
    final backend = _FakeBackend()..sizes = [0];
    final svc = ImagePickerService(backend);
    final raw = Uint8List.fromList([137, 80, 78, 71]);

    final result = await svc.processImageBytes(raw, 'image/png');
    expect(result, isNotNull);
    expect(result!.bytes, same(raw));
    expect(result.mime, 'image/png');
  });
}
