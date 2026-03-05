import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Respaldo del layout retirado del bloque ORDS en tickets de pago.
/// Este archivo queda listo para reusar en un futuro modulo de taller.
class TallerEtiquetaOrdLegacy {
  const TallerEtiquetaOrdLegacy({
    required this.ord,
    this.upc = '',
    this.description,
    this.tipo,
    this.details = const [],
  });

  final String ord;
  final String upc;
  final String? description;
  final String? tipo;
  final List<TallerEtiquetaOrdLegacyDetail> details;
}

class TallerEtiquetaOrdLegacyDetail {
  const TallerEtiquetaOrdLegacyDetail({
    this.job,
    this.esf,
    this.cil,
    this.eje,
  });

  final String? job;
  final String? esf;
  final String? cil;
  final String? eje;
}

List<pw.Widget> buildTicketOrdsLegacySection({
  required List<TallerEtiquetaOrdLegacy> ords,
  required double widthMm,
  required double baseFontSize,
  required double smallFontSize,
  String emptyMessage = 'Sin ORDs ligadas',
}) {
  final widgets = <pw.Widget>[
    pw.Text(
      'ORDS',
      style: pw.TextStyle(
        fontSize: baseFontSize,
        fontWeight: pw.FontWeight.bold,
      ),
    ),
  ];

  if (ords.isEmpty) {
    widgets.add(
      pw.Text(
        emptyMessage,
        style: pw.TextStyle(fontSize: smallFontSize),
      ),
    );
    return widgets;
  }

  widgets.addAll(
    ords.map((ord) {
      final ordUpc = ord.upc.trim();
      final ordDesc = (ord.description ?? '').trim();
      final ordTipo = (ord.tipo ?? '').trim();
      final barcodeData = _sanitizeCode39Data(ord.ord);
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildOrdCutLine(smallFontSize: smallFontSize),
          pw.Text(
            'ORD: ${ord.ord}',
            style: pw.TextStyle(fontSize: baseFontSize),
          ),
          pw.Text(
            'UPC: ${ordUpc.isEmpty ? '-' : ordUpc}',
            style: pw.TextStyle(fontSize: smallFontSize),
          ),
          if (ordDesc.isNotEmpty)
            pw.Text(
              ordDesc,
              style: pw.TextStyle(fontSize: smallFontSize),
            ),
          if (ordTipo.isNotEmpty)
            pw.Text(
              'TIPO: $ordTipo',
              style: pw.TextStyle(fontSize: smallFontSize),
            ),
          if (barcodeData.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 2, bottom: 3),
              child: pw.BarcodeWidget(
                barcode: pw.Barcode.code39(),
                data: barcodeData,
                drawText: true,
                textStyle: pw.TextStyle(fontSize: smallFontSize),
                width: widthMm <= 58 ? _mmToPt(48) : _mmToPt(70),
                height: widthMm <= 58 ? 30 : 36,
              ),
            ),
          _buildOrdDetailsTable(
            details: ord.details,
            smallFontSize: smallFontSize,
          ),
          pw.SizedBox(height: 2),
        ],
      );
    }),
  );

  return widgets;
}

double _mmToPt(double mm) => mm * PdfPageFormat.mm;

String _sanitizeCode39Data(String value) {
  final raw = value.trim().toUpperCase();
  if (raw.isEmpty) return '';
  final reg = RegExp(r'^[0-9A-Z\-\.\ \$\/\+\%]$');
  final sb = StringBuffer();
  for (final codeUnit in raw.codeUnits) {
    final ch = String.fromCharCode(codeUnit);
    sb.write(reg.hasMatch(ch) ? ch : '-');
  }
  final sanitized = sb.toString().trim();
  return sanitized.isEmpty ? '' : sanitized;
}

pw.Widget _buildOrdCutLine({required double smallFontSize}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(top: 2, bottom: 2),
    child: pw.Row(
      children: [
        pw.Expanded(child: pw.Container(height: 0.8, color: PdfColors.grey700)),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 4),
          child: pw.Text(
            '✂',
            style: pw.TextStyle(
              fontSize: smallFontSize + 1,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.Expanded(child: pw.Container(height: 0.8, color: PdfColors.grey700)),
      ],
    ),
  );
}

pw.Widget _buildOrdDetailsTable({
  required List<TallerEtiquetaOrdLegacyDetail> details,
  required double smallFontSize,
}) {
  final rows = details
      .map(
        (d) => [
          (d.job ?? '').trim(),
          (d.esf ?? '').trim(),
          (d.cil ?? '').trim(),
          (d.eje ?? '').trim(),
        ],
      )
      .toList();

  if (rows.isEmpty) {
    rows.add(['', '', '', '']);
  }

  pw.Widget cell(
    String text, {
    required bool header,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 3),
      alignment: pw.Alignment.center,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: smallFontSize,
          fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  return pw.Padding(
    padding: const pw.EdgeInsets.only(top: 2, bottom: 2),
    child: pw.Table(
      border: pw.TableBorder.all(
        color: PdfColors.grey700,
        width: 0.6,
      ),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.0),
        1: pw.FlexColumnWidth(1.2),
        2: pw.FlexColumnWidth(1.2),
        3: pw.FlexColumnWidth(1.2),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            cell('JOB', header: true),
            cell('ESF', header: true),
            cell('CIL', header: true),
            cell('EJE', header: true),
          ],
        ),
        ...rows.map(
          (row) => pw.TableRow(
            children: [
              cell(row[0], header: false),
              cell(row[1], header: false),
              cell(row[2], header: false),
              cell(row[3], header: false),
            ],
          ),
        ),
      ],
    ),
  );
}
