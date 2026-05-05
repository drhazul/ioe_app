import 'dart:typed_data';

import 'package:excel/excel.dart';

import 'nomina_service.dart';

class ExcelExportUtil {
  Uint8List buildPreNominaExcel({
    required List<NominaJoinedRow> rows,
    required NominaKpi kpi,
    required DateTime start,
    required DateTime end,
  }) {
    final excel = Excel.createExcel();
    final resumen = excel['Resumen'];
    final auditoria = excel['Auditoria'];

    resumen.appendRow([
      TextCellValue('PRE-NOMINA INTELIGENTE'),
      TextCellValue('${_d(start)} a ${_d(end)}'),
    ]);
    resumen.appendRow([]);
    resumen.appendRow([
      TextCellValue('Total registros'),
      IntCellValue(kpi.totalRegistros),
    ]);
    resumen.appendRow([
      TextCellValue('Puntuales'),
      IntCellValue(kpi.puntuales),
    ]);
    resumen.appendRow([
      TextCellValue('Ausentismo'),
      IntCellValue(kpi.ausentismos),
    ]);
    resumen.appendRow([
      TextCellValue('Dias vacaciones'),
      IntCellValue(kpi.diasVacaciones),
    ]);
    resumen.appendRow([
      TextCellValue('Costo est. horas extra'),
      DoubleCellValue(kpi.costoHorasExtra),
    ]);

    resumen.appendRow([]);
    resumen.appendRow([
      TextCellValue('Nombre'),
      TextCellValue('ID'),
      TextCellValue('Dias trabajados'),
      TextCellValue('Monto extra est.'),
      TextCellValue('Retardo min'),
    ]);

    final byColab = <int, _ResumenColab>{};
    for (final row in rows) {
      final key = row.reporte.colaboradorId;
      final current =
          byColab[key] ??
          _ResumenColab(
            nombre: row.colaborador?.nombreCompleto ?? row.reporte.nombre,
            id: row.colaborador?.idEmpleado ?? row.reporte.pin,
          );
      byColab[key] = current.copy(
        dias: current.dias + 1,
        extra: current.extra + row.costoExtraEstimado,
        retardo: current.retardo + row.reporte.retardoMinutos,
      );
    }
    for (final item in byColab.values) {
      resumen.appendRow([
        TextCellValue(item.nombre),
        TextCellValue(item.id),
        IntCellValue(item.dias),
        DoubleCellValue(item.extra),
        IntCellValue(item.retardo),
      ]);
    }

    auditoria.appendRow([
      TextCellValue('Fecha'),
      TextCellValue('ID'),
      TextCellValue('Nombre'),
      TextCellValue('RFC'),
      TextCellValue('CURP'),
      TextCellValue('Entrada'),
      TextCellValue('Salida'),
      TextCellValue('Estatus'),
      TextCellValue('Incidencia'),
      TextCellValue('Horas Dobles'),
      TextCellValue('Horas Triples'),
      TextCellValue('Deduccion Retardo'),
    ]);

    for (final row in rows) {
      auditoria.appendRow([
        TextCellValue(row.reporte.fecha),
        TextCellValue(row.colaborador?.idEmpleado ?? row.reporte.pin),
        TextCellValue(row.colaborador?.nombreCompleto ?? row.reporte.nombre),
        TextCellValue(
          (row.reporte.rfc ?? '').trim().isEmpty ? '-' : row.reporte.rfc!,
        ),
        TextCellValue(
          (row.reporte.curp ?? '').trim().isEmpty ? '-' : row.reporte.curp!,
        ),
        TextCellValue(row.reporte.entrada ?? '-'),
        TextCellValue(row.reporte.salida ?? '-'),
        TextCellValue(row.estatusFinal),
        TextCellValue(row.incidencia?.tipoNombre ?? '-'),
        DoubleCellValue(row.horasDobles),
        DoubleCellValue(row.horasTriples),
        DoubleCellValue(row.deduccionRetardo),
      ]);
    }

    final bytes = excel.encode();
    return Uint8List.fromList(bytes ?? <int>[]);
  }

  String _d(DateTime v) {
    final y = v.year.toString().padLeft(4, '0');
    final m = v.month.toString().padLeft(2, '0');
    final d = v.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

class _ResumenColab {
  const _ResumenColab({
    required this.nombre,
    required this.id,
    this.dias = 0,
    this.extra = 0,
    this.retardo = 0,
  });

  final String nombre;
  final String id;
  final int dias;
  final double extra;
  final int retardo;

  _ResumenColab copy({int? dias, double? extra, int? retardo}) {
    return _ResumenColab(
      nombre: nombre,
      id: id,
      dias: dias ?? this.dias,
      extra: extra ?? this.extra,
      retardo: retardo ?? this.retardo,
    );
  }
}
