import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'csv_exporter.dart';

CsvExporter createCsvExporter() => _WebCsvExporter();

class _WebCsvExporter implements CsvExporter {
  @override
  Future<bool> save(Uint8List bytes, String filename) async {
    final parts = [bytes.toJS].toJS;
    final blob = web.Blob(
      parts,
      web.BlobPropertyBag(type: 'text/csv'),
    );
    final url = web.URL.createObjectURL(blob);
    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = filename;
    anchor.click();
    web.URL.revokeObjectURL(url);
    return true;
  }
}
