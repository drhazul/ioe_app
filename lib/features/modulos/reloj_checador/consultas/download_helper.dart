import 'dart:typed_data';

import 'download_helper_stub.dart'
    if (dart.library.html) 'download_helper_web.dart' as impl;

bool get supportsDownload => impl.supportsDownload;

Future<void> saveBytesFile(Uint8List bytes, String fileName, String mimeType) {
  return impl.saveBytesFile(bytes, fileName, mimeType);
}
