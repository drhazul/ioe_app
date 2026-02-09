import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'csv_exporter.dart';

CsvExporter createCsvExporter() => _IoCsvExporter();

class _IoCsvExporter implements CsvExporter {
  @override
  Future<bool> save(Uint8List bytes, String filename) async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Guardar CSV',
      fileName: filename,
      type: FileType.custom,
      allowedExtensions: const ['csv'],
    );
    if (path == null || path.isEmpty) return false;
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    return true;
  }
}
