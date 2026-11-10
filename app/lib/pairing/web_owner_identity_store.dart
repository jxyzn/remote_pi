import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:remote_pi_identity/remote_pi_identity.dart';

/// Web-compatible [OwnerIdentityStore] backed by [FlutterSecureStorage] (localStorage on Web).
class WebOwnerIdentityStore implements OwnerIdentityStore {
  static const String _kOwnerKey = 'remote_pi_owner_identity_blob_v1';
  final FlutterSecureStorage _storage;
  final _controller = StreamController<OwnerIdentity>.broadcast();
  OwnerIdentity? _cached;

  WebOwnerIdentityStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<bool> isSyncAvailable() async => true;

  @override
  Future<OwnerIdentity?> load() async {
    if (_cached != null) return _cached;
    try {
      final b64 = await _storage.read(key: _kOwnerKey);
      if (b64 == null || b64.isEmpty) return null;
      final bytes = Uint8List.fromList(base64Decode(b64));
      _cached = OwnerIdentity.fromBlob(bytes);
      return _cached;
    } catch (e) {
      throw IdentityStoreError.platform('load_failed', '$e');
    }
  }

  @override
  Future<void> save(OwnerIdentity identity) async {
    try {
      final b64 = base64Encode(identity.toBlob());
      await _storage.write(key: _kOwnerKey, value: b64);
      _cached = identity;
      _controller.add(identity);
    } catch (e) {
      throw IdentityStoreError.platform('save_failed', '$e');
    }
  }

  @override
  Stream<OwnerIdentity> watch() => _controller.stream;

  @override
  Future<void> delete() async {
    try {
      await _storage.delete(key: _kOwnerKey);
      _cached = null;
    } catch (e) {
      throw IdentityStoreError.platform('delete_failed', '$e');
    }
  }
}
