import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'excel_exporter.dart';

ExcelExporter createExcelExporter() => _IoExcelExporter();

class _IoExcelExporter implements ExcelExporter {
  @override
  Future<bool> save(Uint8List bytes, String filename) async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Guardar Excel',
      fileName: filename,
      type: FileType.custom,
      allowedExtensions: const ['xlsx'],
    );
    if (path == null || path.isEmpty) return false;
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    return true;
  }
}
