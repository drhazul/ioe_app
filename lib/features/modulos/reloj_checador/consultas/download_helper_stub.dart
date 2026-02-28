import 'dart:typed_data';

const bool supportsDownload = false;

Future<void> saveBytesFile(Uint8List bytes, String fileName, String mimeType) async {
  throw UnsupportedError('Descarga en archivo disponible solo en Web para este MVP');
}
