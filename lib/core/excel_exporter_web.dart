import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'excel_exporter.dart';

ExcelExporter createExcelExporter() => _WebExcelExporter();

class _WebExcelExporter implements ExcelExporter {
  @override
  Future<bool> save(Uint8List bytes, String filename) async {
    final parts = [bytes.toJS].toJS;
    final blob = web.Blob(
      parts,
      web.BlobPropertyBag(
        type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      ),
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
