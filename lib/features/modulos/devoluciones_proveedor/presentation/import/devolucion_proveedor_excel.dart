import 'dart:typed_data';

import 'package:excel/excel.dart' as xls;

class DevProveedorImportRow {
  const DevProveedorImportRow({
    required this.art,
    required this.description,
    required this.quantity,
  });

  final String art;
  final String description;
  final double quantity;
}

List<DevProveedorImportRow> parseDevolucionProveedorExcel(Uint8List bytes) {
  final book = xls.Excel.decodeBytes(bytes);
  if (book.tables.isEmpty) {
    throw const FormatException('El archivo Excel no contiene hojas.');
  }

  final rows = book.tables.values.first.rows
      .map((row) => row.map((cell) => _cellText(cell?.value)).toList())
      .where((row) => row.any((value) => value.isNotEmpty))
      .toList();
  if (rows.isEmpty) {
    throw const FormatException('El archivo Excel está vacío.');
  }

  final header = rows.first.map((value) => value.toUpperCase()).toList();
  final artIndex = header.indexOf('ART');
  final descIndex = header.indexOf('DESC');
  final qtyIndex = header.indexOf('CTDA');
  if (artIndex < 0 || descIndex < 0 || qtyIndex < 0) {
    throw const FormatException(
      'El archivo Excel debe contener las columnas ART, DESC y CTDA.',
    );
  }

  final result = <DevProveedorImportRow>[];
  for (var index = 1; index < rows.length; index++) {
    final row = rows[index];
    final excelRow = index + 1;
    final art = _valueAt(row, artIndex);
    final description = _valueAt(row, descIndex);
    final quantityText = _valueAt(row, qtyIndex).replaceAll(',', '.');
    final quantity = double.tryParse(quantityText);

    if (art.isEmpty) {
      throw FormatException('La fila $excelRow no contiene ART.');
    }
    if (description.isEmpty) {
      throw FormatException('La fila $excelRow no contiene DESC.');
    }
    if (quantity == null || !quantity.isFinite || quantity <= 0) {
      throw FormatException(
        'La fila $excelRow contiene una CTDA inválida; debe ser mayor a cero.',
      );
    }

    result.add(
      DevProveedorImportRow(
        art: art,
        description: description,
        quantity: quantity,
      ),
    );
  }

  if (result.isEmpty) {
    throw const FormatException(
      'No se encontraron filas de datos para ART, DESC y CTDA.',
    );
  }
  return result;
}

String _valueAt(List<String> row, int index) =>
    index < row.length ? row[index].trim() : '';

String _cellText(xls.CellValue? value) {
  if (value == null) return '';
  if (value is xls.TextCellValue) return value.value.toString().trim();
  if (value is xls.IntCellValue) return value.value.toString();
  if (value is xls.DoubleCellValue) {
    final number = value.value;
    return number == number.truncateToDouble()
        ? number.toInt().toString()
        : number.toString();
  }
  return value.toString().trim();
}
