import 'dart:typed_data';

import 'excel_exporter_stub.dart'
    if (dart.library.html) 'excel_exporter_web.dart'
    if (dart.library.io) 'excel_exporter_io.dart';

abstract class ExcelExporter {
  Future<bool> save(Uint8List bytes, String filename);
}

ExcelExporter getExcelExporter() => createExcelExporter();
