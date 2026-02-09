import 'csv_exporter_stub.dart'
    if (dart.library.html) 'csv_exporter_web.dart'
    if (dart.library.io) 'csv_exporter_io.dart';
import 'dart:typed_data';

abstract class CsvExporter {
  Future<bool> save(Uint8List bytes, String filename);
}

CsvExporter getCsvExporter() => createCsvExporter();
