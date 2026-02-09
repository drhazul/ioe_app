import 'dart:typed_data';
import 'csv_exporter.dart';

CsvExporter createCsvExporter() => _StubCsvExporter();

class _StubCsvExporter implements CsvExporter {
  @override
  Future<bool> save(Uint8List bytes, String filename) async {
    throw UnsupportedError('CSV export is not supported on this platform.');
  }
}
