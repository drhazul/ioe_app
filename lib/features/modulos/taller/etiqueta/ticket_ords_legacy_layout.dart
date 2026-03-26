import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Respaldo del layout retirado del bloque ORDS en tickets de pago.
/// Este archivo queda listo para reusar en un futuro modulo de taller.
class TallerEtiquetaOrdLegacy {
  const TallerEtiquetaOrdLegacy({
    required this.ord,
    this.description,
    this.tipo,
    this.clientNumber,
    this.clientName,
    this.deliveryDate,
    this.deliveryTime,
    this.comment,
    this.details = const [],
  });

  final String ord;
  final String? description;
  final String? tipo;
  final String? clientNumber;
  final String? clientName;
  final String? deliveryDate;
  final String? deliveryTime;
  final String? comment;
  final List<TallerEtiquetaOrdLegacyDetail> details;
}

class TallerEtiquetaOrdLegacyDetail {
  const TallerEtiquetaOrdLegacyDetail({this.job, this.esf, this.cil, this.eje});

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
  bool showSectionTitle = true,
}) {
  final widgets = <pw.Widget>[
    if (showSectionTitle)
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
      pw.Text(emptyMessage, style: pw.TextStyle(fontSize: smallFontSize)),
    );
    return widgets;
  }

  widgets.addAll(
    ords.map((ord) {
      final ordDesc = (ord.description ?? '').trim();
      final ordTipo = (ord.tipo ?? '').trim();
      final clientNumber = (ord.clientNumber ?? '').trim();
      final clientName = (ord.clientName ?? '').trim();
      final deliveryDate = (ord.deliveryDate ?? '').trim();
      final deliveryTime = (ord.deliveryTime ?? '').trim();
      final comment = (ord.comment ?? '').trim();
      final barcodeData = _sanitizeCode39Data(ord.ord);
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'ORD: ${ord.ord}',
            style: pw.TextStyle(
              fontSize: baseFontSize + 0.6,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          if (ordDesc.isNotEmpty)
            pw.Text(
              ordDesc,
              style: pw.TextStyle(fontSize: baseFontSize - 0.2),
              maxLines: 1,
            ),
          if (ordTipo.isNotEmpty)
            pw.Text(
              'TIPO: $ordTipo',
              style: pw.TextStyle(fontSize: baseFontSize - 0.2),
            ),
          if (clientNumber.isNotEmpty || clientName.isNotEmpty)
            _buildClientRow(
              clientNumber: clientNumber,
              clientName: clientName,
              fontSize: smallFontSize + 0.3,
            ),
          if (barcodeData.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 1.2, bottom: 1.2),
              child: pw.Center(
                child: pw.BarcodeWidget(
                  barcode: pw.Barcode.code39(),
                  data: barcodeData,
                  drawText: true,
                  textStyle: pw.TextStyle(fontSize: smallFontSize + 0.1),
                  width: _mmToPt(widthMm <= 58 ? widthMm - 8 : widthMm - 16),
                  height: widthMm <= 58 ? 12 : (widthMm <= 76 ? 14 : 18),
                ),
              ),
            ),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                flex: 7,
                child: _buildOrdDetailsTable(
                  details: ord.details,
                  smallFontSize: smallFontSize - 0.2,
                ),
              ),
              pw.SizedBox(width: 4),
              pw.Expanded(
                flex: 4,
                child: _buildDateTimePanel(
                  deliveryDate: deliveryDate,
                  deliveryTime: deliveryTime,
                  smallFontSize: smallFontSize - 0.1,
                ),
              ),
            ],
          ),
          _buildCommentBox(comment: comment, smallFontSize: smallFontSize),
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

  pw.Widget cell(String text, {required bool header}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 0.2, horizontal: 0.4),
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
    padding: const pw.EdgeInsets.only(top: 0.2, bottom: 0.4),
    child: pw.Table(
      border: null,
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

pw.Widget _buildClientRow({
  required String clientNumber,
  required String clientName,
  required double fontSize,
}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(top: 0.4),
    child: pw.Container(
      width: double.infinity,
      color: PdfColors.grey100,
      padding: const pw.EdgeInsets.symmetric(horizontal: 1, vertical: 0.8),
      child: pw.Text(
        [
          clientNumber,
          clientName,
        ].where((value) => value.trim().isNotEmpty).join(' '),
        style: pw.TextStyle(fontSize: fontSize),
        maxLines: 1,
      ),
    ),
  );
}

pw.Widget _buildDateTimePanel({
  required String deliveryDate,
  required String deliveryTime,
  required double smallFontSize,
}) {
  pw.Widget box(String title, String value) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            color: PdfColors.grey700,
            padding: const pw.EdgeInsets.symmetric(
              horizontal: 1,
              vertical: 0.8,
            ),
            child: pw.Text(
              title,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: smallFontSize,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Container(
            color: PdfColors.grey100,
            padding: const pw.EdgeInsets.symmetric(
              horizontal: 1,
              vertical: 1.2,
            ),
            child: pw.Text(
              value.trim().isEmpty ? '-' : value.trim(),
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: smallFontSize + 0.1),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  return pw.Padding(
    padding: const pw.EdgeInsets.only(top: 0.4),
    child: pw.Column(
      children: [box('FCNTE', deliveryDate), box('HR_ENT', deliveryTime)],
    ),
  );
}

pw.Widget _buildCommentBox({
  required String comment,
  required double smallFontSize,
}) {
  final content = comment.trim().isEmpty ? 'SIN COMENTARIO' : comment.trim();
  return pw.Padding(
    padding: const pw.EdgeInsets.only(top: 0.4),
    child: pw.Container(
      width: double.infinity,
      height: _mmToPt(10),
      padding: const pw.EdgeInsets.symmetric(horizontal: 1, vertical: 0.6),
      child: pw.Text(
        'COMENTARIO: $content',
        style: pw.TextStyle(fontSize: smallFontSize),
        maxLines: 2,
      ),
    ),
  );
}
