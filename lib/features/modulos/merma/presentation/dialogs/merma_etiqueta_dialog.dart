import 'dart:math' as math;

import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';

class MermaEtiquetaDialog extends StatelessWidget {
  const MermaEtiquetaDialog({super.key, required this.data});

  static const double _labelWidthMm = 76.0;
  static const double _labelHeightMm = 51.0;

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final docmer = (data['docmer'] ?? '-').toString();
    final suc = (data['suc'] ?? '-').toString();
    final totalArticulos = (data['totalArticulos'] ?? '-').toString();
    final barcodeValue = docmer;
    final qrData = docmer;

    return AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      content: SizedBox(
        width: 860,
        child: AspectRatio(
          aspectRatio: _labelWidthMm / _labelHeightMm,
          child: _PreviewEtiqueta(
            docmer: docmer,
            suc: suc,
            totalArticulos: totalArticulos,
            qrData: qrData,
            barcodeValue: barcodeValue,
          ),
        ),
      ),
      actions: [
        FilledButton.icon(
          onPressed: () => _printEtiqueta(
            context,
            docmer: docmer,
            suc: suc,
            totalArticulos: totalArticulos,
            payload: qrData,
            barcodeValue: barcodeValue,
          ),
          icon: const Icon(Icons.print),
          label: const Text('Imprimir'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }

  Future<void> _printEtiqueta(
    BuildContext context, {
    required String docmer,
    required String suc,
    required String totalArticulos,
    required String payload,
    required String barcodeValue,
  }) async {
    final doc = pw.Document();
    final pageFormat = PdfPageFormat(
      _labelWidthMm * PdfPageFormat.mm,
      _labelHeightMm * PdfPageFormat.mm,
      marginAll: 0,
    );

    double mm(double value) => value * PdfPageFormat.mm;

    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Padding(
          padding: pw.EdgeInsets.all(mm(1.2)),
          child: pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black, width: 1.0),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            padding: pw.EdgeInsets.all(mm(1.1)),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _pdfInfoRow('DOCMER', docmer),
                          pw.SizedBox(height: mm(0.8)),
                          pw.Divider(color: PdfColors.grey600, thickness: 0.6),
                          pw.SizedBox(height: mm(0.5)),
                          _pdfInfoRow('SUCURSAL', suc),
                          pw.SizedBox(height: mm(0.8)),
                          pw.Divider(color: PdfColors.grey600, thickness: 0.6),
                          pw.SizedBox(height: mm(0.5)),
                          _pdfInfoRow('ARTICULOS', totalArticulos),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: mm(1.0)),
                    pw.Container(
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.black, width: 0.8),
                        borderRadius: const pw.BorderRadius.all(
                          pw.Radius.circular(4),
                        ),
                      ),
                      padding: pw.EdgeInsets.all(mm(0.8)),
                      child: pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: payload,
                        width: mm(17),
                        height: mm(17),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: mm(0.8)),
                pw.Divider(
                  color: PdfColors.grey600,
                  thickness: 0.6,
                  borderStyle: pw.BorderStyle.dashed,
                ),
                pw.SizedBox(height: mm(0.5)),
                pw.Text(
                  'CODIGO DE BARRAS',
                  style: pw.TextStyle(
                    fontSize: 6.8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: mm(0.5)),
                pw.Container(
                  width: double.infinity,
                  height: mm(13),
                  padding: pw.EdgeInsets.symmetric(
                    horizontal: mm(0.9),
                    vertical: mm(0.6),
                  ),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.black, width: 0.8),
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(4),
                    ),
                  ),
                  child: pw.BarcodeWidget(
                    barcode: pw.Barcode.code128(),
                    data: barcodeValue,
                    drawText: false,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      await Printing.layoutPdf(
        name: 'etiqueta_merma_$docmer.pdf',
        format: pageFormat,
        onLayout: (_) async => doc.save(),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo imprimir: $e')));
    }
  }

  pw.Widget _pdfInfoRow(String label, String value) {
    return pw.Text(
      '$label: $value',
      maxLines: 1,
      overflow: pw.TextOverflow.clip,
      style: pw.TextStyle(
        fontSize: 7,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.black,
      ),
    );
  }
}

class _PreviewEtiqueta extends StatelessWidget {
  const _PreviewEtiqueta({
    required this.docmer,
    required this.suc,
    required this.totalArticulos,
    required this.qrData,
    required this.barcodeValue,
  });

  final String docmer;
  final String suc;
  final String totalArticulos;
  final String qrData;
  final String barcodeValue;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black, width: 3),
      ),
      padding: const EdgeInsets.all(14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final qrSize =
              math.min(constraints.maxWidth, constraints.maxHeight) * 0.34;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _infoRow(
                          icon: Icons.description_outlined,
                          label: 'DOCMER',
                          value: docmer,
                        ),
                        const SizedBox(height: 6),
                        Divider(color: Colors.grey.shade400, thickness: 1),
                        const SizedBox(height: 6),
                        _infoRow(
                          icon: Icons.storefront_outlined,
                          label: 'SUCURSAL',
                          value: suc,
                        ),
                        const SizedBox(height: 6),
                        Divider(color: Colors.grey.shade400, thickness: 1),
                        const SizedBox(height: 6),
                        _infoRow(
                          icon: Icons.inventory_2_outlined,
                          label: 'ARTICULOS',
                          value: totalArticulos,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black, width: 3),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: QrImageView(
                      data: qrData,
                      size: qrSize,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _dashedDivider(),
              const SizedBox(height: 4),
              const Text(
                'CODIGO DE BARRAS',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black, width: 3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: BarcodeWidget(
                    barcode: Barcode.code128(),
                    data: barcodeValue,
                    drawText: false,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    final compact = '$label: $value';
    final fontSize = compact.length > 36 ? 14.0 : 16.0;
    return Row(
      children: [
        Icon(icon, size: 28),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            compact,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.black,
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _dashedDivider() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final dashCount = (constraints.maxWidth / 14).floor();
        return Row(
          children: List.generate(dashCount, (index) {
            return Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                color: Colors.grey.shade500,
              ),
            );
          }),
        );
      },
    );
  }
}
