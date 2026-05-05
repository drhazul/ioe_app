import 'dart:math' as math;

import 'reloj_checador_app_models.dart';

class NominaValidationIssue {
  const NominaValidationIssue({
    required this.code,
    required this.message,
    required this.workdayId,
    required this.colaboradorId,
    required this.nombre,
  });

  final String code;
  final String message;
  final String workdayId;
  final int colaboradorId;
  final String nombre;
}

class NominaJoinedRow {
  const NominaJoinedRow({
    required this.reporte,
    required this.colaborador,
    required this.incidencia,
    required this.estatusFinal,
    required this.bloqueadoPorIncidencia,
    required this.horasDobles,
    required this.horasTriples,
    required this.costoExtraEstimado,
    required this.deduccionRetardo,
  });

  final AsistenciaReporteRow reporte;
  final ColaboradorGestionModel? colaborador;
  final SolicitudIncidenciaModel? incidencia;
  final String estatusFinal;
  final bool bloqueadoPorIncidencia;
  final double horasDobles;
  final double horasTriples;
  final double costoExtraEstimado;
  final double deduccionRetardo;
}

class NominaKpi {
  const NominaKpi({
    required this.totalRegistros,
    required this.puntuales,
    required this.ausentismos,
    required this.diasVacaciones,
    required this.costoHorasExtra,
    required this.totalRetardosMin,
  });

  final int totalRegistros;
  final int puntuales;
  final int ausentismos;
  final int diasVacaciones;
  final double costoHorasExtra;
  final int totalRetardosMin;
}

class NominaComputedData {
  const NominaComputedData({
    required this.rows,
    required this.kpi,
    required this.issues,
  });

  final List<NominaJoinedRow> rows;
  final NominaKpi kpi;
  final List<NominaValidationIssue> issues;
}

class NominaService {
  NominaComputedData compute({
    required List<AsistenciaReporteRow> asistencias,
    required List<ColaboradorGestionModel> colaboradores,
    required List<SolicitudIncidenciaModel> incidencias,
    double costoHoraBase = 100,
    double deduccionPorMinRetardo = 1.5,
  }) {
    final colabById = <int, ColaboradorGestionModel>{
      for (final c in colaboradores) c.id: c,
    };

    final approved = incidencias
        .where((i) => i.estatus.trim().toUpperCase() == 'APROBADO')
        .toList();

    final extraByWeek = _weeklyExtraBuckets(asistencias);

    var puntual = 0;
    var ausentismo = 0;
    var vacaciones = 0;
    var costoExtra = 0.0;
    var retardoMin = 0;

    final rows = <NominaJoinedRow>[];

    for (final row in asistencias) {
      final colab = colabById[row.colaboradorId];
      final inc = _findIncidenciaForRow(row, approved);
      final blocked =
          row.estatus == 'FALTA' &&
          inc != null &&
          _isIncidenciaJustificante(inc);

      final status = blocked
          ? 'JUSTIFICADO'
          : row.estatus.trim().toUpperCase();

      final weekKey = _weekKey(row);
      final bucketKey = '${row.colaboradorId}|$weekKey';
      final weekBucket = extraByWeek[bucketKey] ?? _ExtraWeekBucket.empty();
      final split = weekBucket.consumeForRow(row.minutosExtra);

      final domingoFactor = _isSunday(row.fecha) ? 1.25 : 1.0;
      final festivoFactor = status.contains('FESTIVO') ? 2.0 : 1.0;
      final rateFactor = domingoFactor * festivoFactor;
      final cost =
          ((split.horasDobles * (costoHoraBase * 2)) +
              (split.horasTriples * (costoHoraBase * 3))) *
          rateFactor;

      final deduccion =
          math.max(0, row.retardoMinutos) * deduccionPorMinRetardo;

      if (status == 'OK' || status == 'PUNTUAL') puntual++;
      if (status == 'FALTA') ausentismo++;
      final incCode = inc?.tipoCodigo.trim().toUpperCase() ?? '';
      final incName = inc?.tipoNombre.trim().toUpperCase() ?? '';
      final hasVacationInc = incCode.contains('VACACION') || incName.contains('VACACION');
      if (hasVacationInc) vacaciones++;
      costoExtra += cost;
      retardoMin += math.max(0, row.retardoMinutos);

      rows.add(
        NominaJoinedRow(
          reporte: row,
          colaborador: colab,
          incidencia: inc,
          estatusFinal: status,
          bloqueadoPorIncidencia: blocked,
          horasDobles: split.horasDobles,
          horasTriples: split.horasTriples,
          costoExtraEstimado: cost,
          deduccionRetardo: deduccion,
        ),
      );
    }

    final issues = validate(rows);

    return NominaComputedData(
      rows: rows,
      kpi: NominaKpi(
        totalRegistros: rows.length,
        puntuales: puntual,
        ausentismos: ausentismo,
        diasVacaciones: vacaciones,
        costoHorasExtra: costoExtra,
        totalRetardosMin: retardoMin,
      ),
      issues: issues,
    );
  }

  List<NominaValidationIssue> validate(List<NominaJoinedRow> rows) {
    final issues = <NominaValidationIssue>[];
    final duplicateGuard = <String, int>{};

    for (final row in rows) {
      final r = row.reporte;
      final name = row.colaborador?.nombreCompleto ?? r.nombre;

      if ((r.entrada ?? '').trim().isNotEmpty &&
          (r.salida ?? '').trim().isEmpty &&
          !row.bloqueadoPorIncidencia) {
        issues.add(
          NominaValidationIssue(
            code: 'ORPHAN',
            message: 'Marcaje huérfano (entrada sin salida)',
            workdayId: r.workdayId,
            colaboradorId: r.colaboradorId,
            nombre: name,
          ),
        );
      }

      final dupKey =
          '${r.colaboradorId}|${r.workdayId}|${r.entrada ?? '-'}|${r.salida ?? '-'}';
      duplicateGuard.update(dupKey, (v) => v + 1, ifAbsent: () => 1);
    }

    duplicateGuard.forEach((key, count) {
      if (count <= 1) return;
      final parts = key.split('|');
      final colabId = int.tryParse(parts.first) ?? 0;
      final sample = rows.firstWhere(
        (r) =>
            r.reporte.colaboradorId == colabId &&
            r.reporte.workdayId == (parts.length > 1 ? parts[1] : ''),
        orElse: () => rows.first,
      );
      issues.add(
        NominaValidationIssue(
          code: 'DUPLICATE',
          message: 'Marcaje duplicado detectado',
          workdayId: sample.reporte.workdayId,
          colaboradorId: sample.reporte.colaboradorId,
          nombre: sample.colaborador?.nombreCompleto ?? sample.reporte.nombre,
        ),
      );
    });

    return issues;
  }

  Map<String, _ExtraWeekBucket> _weeklyExtraBuckets(
    List<AsistenciaReporteRow> rows,
  ) {
    final totals = <String, int>{};
    for (final row in rows) {
      final key = '${row.colaboradorId}|${_weekKey(row)}';
      totals.update(
        key,
        (v) => v + math.max(0, row.minutosExtra),
        ifAbsent: () => math.max(0, row.minutosExtra),
      );
    }
    return {
      for (final entry in totals.entries)
        entry.key: _ExtraWeekBucket(totalMinutes: entry.value),
    };
  }

  SolicitudIncidenciaModel? _findIncidenciaForRow(
    AsistenciaReporteRow row,
    List<SolicitudIncidenciaModel> approved,
  ) {
    final day = _parseDate(row.fecha);
    if (day == null) return null;

    for (final inc in approved) {
      if (inc.colaboradorId != row.colaboradorId) continue;
      if (_isBetween(day, inc.fechaInicio, inc.fechaFin)) return inc;
    }
    return null;
  }

  bool _isIncidenciaJustificante(SolicitudIncidenciaModel inc) {
    final code = inc.tipoCodigo.trim().toUpperCase();
    if (code.contains('VACACION')) return true;
    if (code.contains('PERMISO')) return true;
    if (code.contains('COMISION')) return true;
    return inc.tipoNombre.trim().isNotEmpty;
  }

  String _weekKey(AsistenciaReporteRow row) {
    final dt = _parseDate(row.fecha);
    if (dt == null) return row.fecha;
    final monday = dt.subtract(Duration(days: dt.weekday - DateTime.monday));
    return '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
  }

  bool _isSunday(String date) {
    final dt = _parseDate(date);
    return dt?.weekday == DateTime.sunday;
  }

  DateTime? _parseDate(String date) {
    try {
      return DateTime.parse(date);
    } catch (_) {
      return null;
    }
  }

  bool _isBetween(DateTime value, DateTime start, DateTime end) {
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day);
    final v = DateTime(value.year, value.month, value.day);
    return (v.isAtSameMomentAs(s) || v.isAfter(s)) &&
        (v.isAtSameMomentAs(e) || v.isBefore(e));
  }
}

class _ExtraSplit {
  const _ExtraSplit({required this.horasDobles, required this.horasTriples});

  final double horasDobles;
  final double horasTriples;
}

class _ExtraWeekBucket {
  _ExtraWeekBucket({required this.totalMinutes}) : _consumed = 0;

  factory _ExtraWeekBucket.empty() => _ExtraWeekBucket(totalMinutes: 0);

  final int totalMinutes;
  int _consumed;

  _ExtraSplit consumeForRow(int rowMinutes) {
    final safe = math.max(0, rowMinutes);
    if (safe == 0) return const _ExtraSplit(horasDobles: 0, horasTriples: 0);

    final start = _consumed;
    final end = _consumed + safe;
    _consumed = end;

    const doubleCap = 9 * 60;
    final inDouble = math.max(
      0,
      math.min(end, doubleCap) - math.min(start, doubleCap),
    );
    final inTriple = safe - inDouble;

    return _ExtraSplit(horasDobles: inDouble / 60, horasTriples: inTriple / 60);
  }
}
