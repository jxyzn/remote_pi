// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';

void initStorageFallback() {
  WebInsecureStoragePlatform.registerFallbackIfNeeded();
}

/// Fallback [FlutterSecureStoragePlatform] implementation for non-secure web contexts
/// (e.g. plain HTTP on LAN or non-localhost origins like `http://dev-box/`) where
/// `window.crypto.subtle` is undefined. Stores values in `window.localStorage`.
class WebInsecureStoragePlatform extends FlutterSecureStoragePlatform {
  static const _kPrefix = 'rp_web_storage.';

  static void registerFallbackIfNeeded() {
    try {
      final isSecure = html.window.isSecureContext == true;
      if (!isSecure) {
        FlutterSecureStoragePlatform.instance = WebInsecureStoragePlatform();
      }
    } catch (_) {
      FlutterSecureStoragePlatform.instance = WebInsecureStoragePlatform();
    }
  }

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async {
    return html.window.localStorage.containsKey('$_kPrefix$key');
  }

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async {
    html.window.localStorage.remove('$_kPrefix$key');
  }

  @override
  Future<void> deleteAll({
    required Map<String, String> options,
  }) async {
    html.window.localStorage.removeWhere((k, _) => k.startsWith(_kPrefix));
  }

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async {
    final raw = html.window.localStorage['$_kPrefix$key'];
    if (raw == null) return null;
    try {
      return utf8.decode(base64Decode(raw));
    } catch (_) {
      return raw;
    }
  }

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async {
    final storage = html.window.localStorage;
    final result = <String, String>{};
    for (final entry in storage.entries) {
      if (entry.key.startsWith(_kPrefix)) {
        final realKey = entry.key.substring(_kPrefix.length);
        final raw = entry.value;
        try {
          result[realKey] = utf8.decode(base64Decode(raw));
        } catch (_) {
          result[realKey] = raw;
        }
      }
    }
    return result;
  }

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    final encoded = base64Encode(utf8.encode(value));
    html.window.localStorage['$_kPrefix$key'] = encoded;
  }
}
