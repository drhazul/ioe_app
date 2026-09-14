import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart' show rootBundle;

import '../../domain/devolucion_proveedor_models.dart';

const _pdfNavy = PdfColor.fromInt(0xff0B3D78);
const _pdfCyan = PdfColor.fromInt(0xff21B3E6);

String devolucionDocumentNumber(String document) => devDocumentFolio(document);

String devolucionPdfFileName(String document) =>
    'devolucion_proveedor_${devolucionDocumentNumber(document)}.pdf';

String devolucionesProveedorPdfFileName(List<DevDocument> documents) {
  if (documents.length == 1) return devolucionPdfFileName(documents.single.doc);
  return 'devoluciones_proveedor_${documents.length}_documentos.pdf';
}

Future<Uint8List> buildDevolucionProveedorPdf(DevDocument document) =>
    buildDevolucionesProveedorPdf([document]);

Future<Uint8List> buildDevolucionesProveedorPdf(
  List<DevDocument> documents,
) async {
  if (documents.isEmpty) {
    throw ArgumentError.value(documents, 'documents', 'No puede estar vacío.');
  }
  final pdf = pw.Document(
    title: documents.length == 1
        ? 'Devolucion a proveedor ${devolucionDocumentNumber(documents.single.doc)}'
        : 'Devoluciones a proveedor',
    author: 'IOE',
  );

  for (final document in documents) {
    final details = document.details;
    final logo = await _loadPdfAssetImage(
      'assets/images/ioe_logo_pdf_real.png',
    );
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 32),
        header: (_) => _modernHeader(document, logo),
        build: (_) => [
          _summary(document),
          if (document.obs.trim().isNotEmpty) ...[
            pw.SizedBox(height: 9),
            _note('Observaciones', document.obs),
          ],
          if (document.rejectionReason.trim().isNotEmpty) ...[
            pw.SizedBox(height: 6),
            _note('Motivo de rechazo', document.rejectionReason),
          ],
          pw.SizedBox(height: 14),
          pw.Text(
            'ARTICULOS (${details.length})',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey900,
            ),
          ),
          pw.SizedBox(height: 6),
          if (details.isEmpty)
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.blueGrey200),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text('El documento no contiene articulos.'),
            )
          else
            pw.TableHelper.fromTextArray(
              headers: const [
                'ART',
                'Descripcion',
                'Motivo',
                'Cantidad',
                'Costo',
                'Importe',
                'Lote',
                'Caducidad',
                'Fecha captura',
              ],
              data: details
                  .map(
                    (detail) => [
                      detail.art,
                      detail.description,
                      devolucionReasonDescription(detail),
                      detail.quantity.toStringAsFixed(2),
                      _currency(detail.cost),
                      _currency(detail.amount),
                      detail.lot.isEmpty ? '-' : detail.lot,
                      _date(detail.expiration),
                      _date(detail.capturedAt),
                    ],
                  )
                  .toList(),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blue900,
              ),
              headerStyle: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 7.5,
                fontWeight: pw.FontWeight.bold,
              ),
              cellStyle: const pw.TextStyle(fontSize: 6.7),
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 5,
              ),
              border: pw.TableBorder.all(
                color: PdfColors.blueGrey200,
                width: .5,
              ),
              columnWidths: const {
                0: pw.FixedColumnWidth(42),
                1: pw.FlexColumnWidth(2.5),
                2: pw.FlexColumnWidth(1.8),
                3: pw.FixedColumnWidth(46),
                4: pw.FixedColumnWidth(44),
                5: pw.FixedColumnWidth(48),
                6: pw.FixedColumnWidth(42),
                7: pw.FixedColumnWidth(52),
                8: pw.FixedColumnWidth(62),
              },
            ),
          pw.SizedBox(height: 10),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              width: 225,
              padding: const pw.EdgeInsets.all(9),
              decoration: pw.BoxDecoration(
                color: PdfColors.blueGrey50,
                border: pw.Border.all(color: PdfColors.blueGrey200),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Column(
                children: [
                  _totalRow('Articulos', '${document.lines}'),
                  _totalRow('Cantidad', document.quantity.toStringAsFixed(2)),
                  pw.Divider(color: PdfColors.blueGrey300),
                  _totalRow(
                    'Importe',
                    _currency(document.amount),
                    emphasized: true,
                  ),
                ],
              ),
            ),
          ),
          pw.SizedBox(height: 42),
          pw.Align(
            alignment: pw.Alignment.center,
            child: pw.SizedBox(
              width: 280,
              child: pw.Column(
                children: [
                  pw.Divider(color: PdfColors.blueGrey700),
                  pw.Text(
                    'Nombre y firma de recibido',
                    style: const pw.TextStyle(fontSize: 8.5),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  return pdf.save();
}

pw.Widget _summary(DevDocument document) {
  final rows = <List<String>>[
    ['Sucursal', document.suc, 'Almacen', document.warehouse],
    ['Proveedor', document.provider, 'Tipo', document.typeDescription],
    ['Fecha', _date(document.date), 'Estatus', document.status],
    [
      'Orden de compra',
      document.oc.isEmpty ? 'No relacionada' : document.oc,
      'Recepcion',
      document.receipt.isEmpty ? 'No relacionada' : document.receipt,
    ],
  ];
  return pw.Table(
    border: pw.TableBorder.all(color: PdfColors.blueGrey200, width: .5),
    columnWidths: const {
      0: pw.FixedColumnWidth(78),
      1: pw.FlexColumnWidth(2),
      2: pw.FixedColumnWidth(88),
      3: pw.FlexColumnWidth(2),
    },
    children: [
      for (final row in rows)
        pw.TableRow(
          children: [
            _summaryCell(row[0], label: true),
            _summaryCell(row[1]),
            _summaryCell(row[2], label: true),
            _summaryCell(row[3]),
          ],
        ),
    ],
  );
}

pw.Widget _summaryCell(String value, {bool label = false}) => pw.Container(
  color: label ? PdfColors.blue50 : null,
  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
  child: pw.Text(
    value,
    style: pw.TextStyle(
      fontSize: 8.5,
      fontWeight: label ? pw.FontWeight.bold : pw.FontWeight.normal,
      color: label ? PdfColors.blue900 : PdfColors.black,
    ),
  ),
);

pw.Widget _modernHeader(
  DevDocument document,
  pw.ImageProvider? logo,
) => pw.Container(
  padding: const pw.EdgeInsets.only(bottom: 12),
  decoration: const pw.BoxDecoration(
    border: pw.Border(bottom: pw.BorderSide(color: _pdfNavy, width: 3)),
  ),
  child: pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Container(
        width: 54,
        height: 46,
        alignment: pw.Alignment.center,
        child: logo == null
            ? pw.Text(
                'ioe',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: _pdfNavy,
                ),
              )
            : pw.Image(logo, width: 42, height: 42, fit: pw.BoxFit.contain),
      ),
      pw.SizedBox(width: 12),
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'DISTRIBUIDORA IOE',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: _pdfNavy,
              ),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              'DEVOLUCIONES A PROVEEDOR',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              'Documento ${devolucionDocumentNumber(document.doc)}',
              style: const pw.TextStyle(fontSize: 8.5),
            ),
          ],
        ),
      ),
      pw.Container(
        width: 126,
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        alignment: pw.Alignment.center,
        decoration: pw.BoxDecoration(
          color: _pdfCyan,
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Text(
          'DEVOLUCION',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
      ),
    ],
  ),
);

Future<pw.ImageProvider?> _loadPdfAssetImage(String assetPath) async {
  try {
    final data = await rootBundle.load(assetPath);
    return pw.MemoryImage(data.buffer.asUint8List());
  } catch (_) {
    return null;
  }
}

pw.Widget _note(String label, String value) => pw.Container(
  width: double.infinity,
  padding: const pw.EdgeInsets.all(7),
  decoration: pw.BoxDecoration(
    color: PdfColors.blueGrey50,
    border: pw.Border.all(color: PdfColors.blueGrey200),
    borderRadius: pw.BorderRadius.circular(4),
  ),
  child: pw.RichText(
    text: pw.TextSpan(
      style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.blueGrey900),
      children: [
        pw.TextSpan(
          text: '$label: ',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
        pw.TextSpan(text: value),
      ],
    ),
  ),
);

pw.Widget _totalRow(
  String label,
  String value, {
  bool emphasized = false,
}) => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(vertical: 2),
  child: pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text(
        label,
        style: pw.TextStyle(
          fontSize: 8.5,
          fontWeight: emphasized ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
      pw.Text(
        value,
        style: pw.TextStyle(
          fontSize: 8.5,
          fontWeight: emphasized ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    ],
  ),
);

String devolucionReasonDescription(DevDetail detail) {
  final description = detail.reasonDescription.trim();
  return description.isEmpty ? '-' : description;
}

String _currency(double value) => '\$${value.toStringAsFixed(2)}';

String _date(DateTime? value) {
  if (value == null) return '-';
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
