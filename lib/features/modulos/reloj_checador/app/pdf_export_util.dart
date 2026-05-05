import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'nomina_service.dart';

class PdfExportUtil {
  Future<Uint8List> buildPreNominaPdf({
    required List<NominaJoinedRow> rows,
    required NominaKpi kpi,
    required DateTime start,
    required DateTime end,
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(24),
        pageFormat: PdfPageFormat.a4.landscape,
        build: (context) => [
          pw.Container(
            color: const PdfColor.fromInt(0xFF1A237E),
            padding: const pw.EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'SISTEMA DE GESTION IOE - PRE-NOMINA INTELIGENTE',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  '${_d(start)} a ${_d(end)}',
                  style: const pw.TextStyle(color: PdfColors.white),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: 170,
                child: pw.Column(
                  children: [
                    _kpiCard(
                      'Vacaciones',
                      '${kpi.diasVacaciones}',
                      PdfColors.green,
                    ),
                    pw.SizedBox(height: 10),
                    _kpiCard(
                      'Costo Extra',
                      r'$ ${kpi.costoHorasExtra.toStringAsFixed(2)}',
                      PdfColors.amber,
                    ),
                    pw.SizedBox(height: 10),
                    _kpiCard(
                      'Retardos (min)',
                      '${kpi.totalRetardosMin}',
                      PdfColors.red,
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    _kpiCard(
                      'Registros',
                      '${kpi.totalRegistros}',
                      PdfColors.indigo,
                    ),
                    _kpiCard(
                      'Puntuales',
                      '${kpi.puntuales}',
                      PdfColors.green700,
                    ),
                    _kpiCard(
                      'Ausentismo',
                      '${kpi.ausentismos}',
                      PdfColors.red700,
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFF1A237E),
            ),
            cellAlignment: pw.Alignment.centerLeft,
            headers: const [
              'Nombre',
              'RFC',
              'CURP',
              'Fecha',
              'Entrada',
              'Salida',
              'Estatus',
              'Hrs Dobles',
              'Hrs Triples',
            ],
            data: rows
                .map(
                  (r) => [
                    r.colaborador?.nombreCompleto ?? r.reporte.nombre,
                    (r.reporte.rfc ?? '').trim().isEmpty ? '-' : r.reporte.rfc!,
                    (r.reporte.curp ?? '').trim().isEmpty
                        ? '-'
                        : r.reporte.curp!,
                    r.reporte.fecha,
                    r.reporte.entrada ?? '-',
                    r.reporte.salida ?? '-',
                    r.estatusFinal,
                    r.horasDobles.toStringAsFixed(2),
                    r.horasTriples.toStringAsFixed(2),
                  ],
                )
                .toList(),
          ),
          pw.SizedBox(height: 20),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _firma('Elaboro'),
              _firma('Reviso RH'),
              _firma('Autorizo'),
            ],
          ),
        ],
      ),
    );

    return doc.save();
  }

  pw.Widget _kpiCard(String label, String value, PdfColor accent) {
    return pw.Container(
      width: 140,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            height: 3,
            width: 32,
            decoration: pw.BoxDecoration(
              color: accent,
              borderRadius: pw.BorderRadius.circular(2),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: accent),
          ),
        ],
      ),
    );
  }

  pw.Widget _firma(String label) {
    return pw.Column(
      children: [
        pw.Container(width: 140, height: 1, color: PdfColors.black),
        pw.SizedBox(height: 4),
        pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
      ],
    );
  }

  String _d(DateTime v) {
    final y = v.year.toString().padLeft(4, '0');
    final m = v.month.toString().padLeft(2, '0');
    final d = v.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
