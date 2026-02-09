import 'dart:typed_data';

import 'excel_exporter.dart';

ExcelExporter createExcelExporter() => _StubExcelExporter();

class _StubExcelExporter implements ExcelExporter {
  @override
  Future<bool> save(Uint8List bytes, String filename) {
    throw UnsupportedError('Excel export is not supported on this platform.');
  }
}
