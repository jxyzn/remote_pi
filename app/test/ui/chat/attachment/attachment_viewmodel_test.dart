// Plan/30 — AttachmentViewModel: pick / remove / take + vision gating,
// against fake picker + actions repositories.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:app/data/actions/actions_repository.dart';
import 'package:app/data/images/image_picker_service.dart';
import 'package:app/protocol/protocol.dart';
import 'package:app/ui/chat/attachment/states/attachment_state.dart';
import 'package:app/ui/chat/attachment/viewmodels/attachment_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePicker implements IImagePickerService {
  PickedImage? next = PickedImage(
    bytes: Uint8List.fromList([1, 2, 3]),
    mime: 'image/jpeg',
  );
  bool denyCamera = false;
  bool fail = false;

  @override
  Future<PickedImage?> pickFromCamera() async {
    if (denyCamera) throw const ImagePermissionDeniedException();
    if (fail) throw Exception('boom');
    return next;
  }

  @override
  Future<PickedImage?> pickFromGallery() async {
    if (fail) throw Exception('boom');
    return next;
  }

  @override
  Future<PickedImage?> processImageBytes(
    Uint8List rawBytes, [
    String? mime,
  ]) async {
    if (fail) throw Exception('boom');
    return next ?? PickedImage(bytes: rawBytes, mime: mime ?? 'image/jpeg');
  }
}

class _FakeActions implements IActionsRepository {
  ModelsCatalogue catalogue = const ModelsCatalogue(models: [], current: null);
  ActiveRoomMeta meta = const ActiveRoomMeta();
  final _metaCtrl = StreamController<ActiveRoomMeta>.broadcast();
  bool offline = false;

  void pushMeta(ActiveRoomMeta m) {
    meta = m;
    _metaCtrl.add(m);
  }

  @override
  Future<ModelsCatalogue> listModels({bool forceRefresh = false}) async {
    if (offline) throw const ActionFailure('offline');
    return catalogue;
  }

  @override
  ActiveRoomMeta get activeRoomMeta => meta;

  @override
  Stream<ActiveRoomMeta> get activeRoomMetaStream => _metaCtrl.stream;

  @override
  void dispose() => _metaCtrl.close();

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

WireModel _model({required bool vision, String name = 'M'}) => WireModel(
  id: 'id-$name',
  name: name,
  provider: 'p',
  reasoning: false,
  contextWindow: 1,
  vision: vision,
);

void main() {
  test('pickFromGallery attaches an image; removeImage clears it', () async {
    final vm = AttachmentViewModel(_FakePicker(), _FakeActions());
    await vm.pickFromGallery();
    expect(vm.state, isA<AttachmentAttached>());
    expect(vm.hasImage, isTrue);

    vm.removeImage();
    expect(vm.state, isA<AttachmentEmpty>());
    expect(vm.hasImage, isFalse);
    vm.dispose();
  });

  test('takeImageForSend returns base64 MessageImage and resets', () async {
    final picker = _FakePicker()
      ..next = PickedImage(
        bytes: Uint8List.fromList([10, 20, 30]),
        mime: 'image/jpeg',
      );
    final vm = AttachmentViewModel(picker, _FakeActions());
    await vm.pickFromGallery();

    final msg = vm.takeImageForSend();
    expect(msg, isNotNull);
    expect(msg!.mime, 'image/jpeg');
    expect(base64Decode(msg.data), [10, 20, 30]);
    expect(vm.state, isA<AttachmentEmpty>());
    expect(vm.takeImageForSend(), isNull); // nothing left
    vm.dispose();
  });

  test('denied camera permission emits a hint and stays empty', () async {
    final picker = _FakePicker()..denyCamera = true;
    final vm = AttachmentViewModel(picker, _FakeActions());
    final hints = <AttachHint>[];
    final sub = vm.hints.listen(hints.add);

    await vm.pickFromCamera();
    await Future<void>.delayed(Duration.zero);

    expect(vm.state, isA<AttachmentEmpty>());
    expect(hints, [AttachHint.cameraPermissionDenied]);
    await sub.cancel();
    vm.dispose();
  });

  test('vision=false from catalogue blocks the attach affordance', () async {
    final actions = _FakeActions()
      ..catalogue = ModelsCatalogue(
        models: [_model(vision: false)],
        current: _model(vision: false),
      );
    final vm = AttachmentViewModel(_FakePicker(), actions);
    await Future<void>.delayed(Duration.zero); // let init resolve vision

    expect(vm.state.visionSupported, isFalse);
    expect(vm.state.attachBlockedByVision, isTrue);
    vm.dispose();
  });

  test('vision=true does not block', () async {
    final actions = _FakeActions()
      ..catalogue = ModelsCatalogue(
        models: [_model(vision: true)],
        current: _model(vision: true),
      );
    final vm = AttachmentViewModel(_FakePicker(), actions);
    await Future<void>.delayed(Duration.zero);

    expect(vm.state.visionSupported, isTrue);
    expect(vm.state.attachBlockedByVision, isFalse);
    vm.dispose();
  });

  test('offline catalogue leaves vision unknown (does not block)', () async {
    final actions = _FakeActions()..offline = true;
    final vm = AttachmentViewModel(_FakePicker(), actions);
    await Future<void>.delayed(Duration.zero);

    expect(vm.state.visionSupported, isNull);
    expect(vm.state.attachBlockedByVision, isFalse);
    vm.dispose();
  });

  test('a model change re-resolves vision', () async {
    final actions = _FakeActions()
      ..catalogue = ModelsCatalogue(
        models: [_model(vision: true)],
        current: _model(vision: true),
      );
    final vm = AttachmentViewModel(_FakePicker(), actions);
    await Future<void>.delayed(Duration.zero);
    expect(vm.state.visionSupported, isTrue);

    // Pi switched to a text-only model.
    actions.catalogue = ModelsCatalogue(
      models: [_model(vision: false, name: 'TextOnly')],
      current: _model(vision: false, name: 'TextOnly'),
    );
    actions.pushMeta(const ActiveRoomMeta(model: 'TextOnly'));
    await Future<void>.delayed(Duration.zero);

    expect(vm.state.visionSupported, isFalse);
    vm.dispose();
  });

  test('attachFromBytes attaches image and emits pickFailed hint on error', () async {
    final picker = _FakePicker()..next = null;
    final vm = AttachmentViewModel(picker, _FakeActions());
    final hints = <AttachHint>[];
    final sub = vm.hints.listen(hints.add);

    await vm.attachFromBytes(Uint8List.fromList([7, 8, 9]), 'image/png');
    expect(vm.state, isA<AttachmentAttached>());
    expect((vm.state as AttachmentAttached).image.mime, 'image/png');

    vm.removeImage();
    picker.fail = true;
    await vm.attachFromBytes(Uint8List.fromList([7, 8, 9]), 'image/png');
    await Future<void>.delayed(Duration.zero);
    expect(vm.state, isA<AttachmentEmpty>());
    expect(hints, [AttachHint.pickFailed]);

    await sub.cancel();
    vm.dispose();
  });

  test('resolves vision=true from base model id when current has :effort suffix', () async {
    final actions = _FakeActions()
      ..catalogue = ModelsCatalogue(
        models: [
          const WireModel(
            id: 'gemma-4-26b',
            name: 'gemma-4-26b',
            provider: 'local',
            reasoning: true,
            contextWindow: 65536,
            vision: true,
          ),
        ],
        current: const WireModel(
          id: 'gemma-4-26b:medium',
          name: 'gemma-4-26b:medium',
          provider: 'local',
          reasoning: true,
          contextWindow: 65536,
          vision: false,
        ),
      );
    final vm = AttachmentViewModel(_FakePicker(), actions);
    await Future<void>.delayed(Duration.zero);

    expect(vm.state.visionSupported, isTrue);
    expect(vm.state.attachBlockedByVision, isFalse);
    vm.dispose();
  });
}
