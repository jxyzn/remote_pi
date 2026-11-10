import 'package:app/pairing/storage_platform_fallback_stub.dart'
    if (dart.library.html) 'package:app/pairing/storage_platform_fallback_web.dart';

void initPlatformStorageFallback() {
  initStorageFallback();
}
