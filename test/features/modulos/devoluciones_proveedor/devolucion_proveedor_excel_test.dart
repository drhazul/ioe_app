import 'dart:typed_data';

import 'package:excel/excel.dart' as xls;
import 'package:flutter_test/flutter_test.dart';
import 'package:ioe_app/features/modulos/devoluciones_proveedor/presentation/import/devolucion_proveedor_excel.dart';

void main() {
  test('importa columnas ART, DESC y CTDA', () {
    final bytes = _workbook([
      ['ART', 'DESC', 'CTDA'],
      ['3013132', 'ARMAZON DE PRUEBA', 2.5],
    ]);

    final rows = parseDevolucionProveedorExcel(bytes);

    expect(rows, hasLength(1));
    expect(rows.single.art, '3013132');
    expect(rows.single.description, 'ARMAZON DE PRUEBA');
    expect(rows.single.quantity, 2.5);
  });

  test('rechaza CTD porque el encabezado requerido es CTDA', () {
    final bytes = _workbook([
      ['ART', 'DESC', 'CTD'],
      ['3013132', 'ARMAZON DE PRUEBA', 1],
    ]);

    expect(
      () => parseDevolucionProveedorExcel(bytes),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('ART, DESC y CTDA'),
        ),
      ),
    );
  });

  test('rechaza filas sin DESC o con CTDA no positiva', () {
    final missingDescription = _workbook([
      ['ART', 'DESC', 'CTDA'],
      ['3013132', '', 1],
    ]);
    final invalidQuantity = _workbook([
      ['ART', 'DESC', 'CTDA'],
      ['3013132', 'ARMAZON DE PRUEBA', 0],
    ]);

    expect(
      () => parseDevolucionProveedorExcel(missingDescription),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('fila 2 no contiene DESC'),
        ),
      ),
    );
    expect(
      () => parseDevolucionProveedorExcel(invalidQuantity),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('fila 2 contiene una CTDA inválida'),
        ),
      ),
    );
  });
}

Uint8List _workbook(List<List<Object>> values) {
  final book = xls.Excel.createExcel();
  final sheet = book[book.getDefaultSheet()!];
  for (final row in values) {
    sheet.appendRow(
      row.map((value) {
        if (value is int) return xls.IntCellValue(value);
        if (value is double) return xls.DoubleCellValue(value);
        return xls.TextCellValue(value.toString());
      }).toList(),
    );
  }
  return Uint8List.fromList(book.encode()!);
}
