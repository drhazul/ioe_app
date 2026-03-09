import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ioe_app/core/api_error.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'caja_general_models.dart';
import 'caja_general_providers.dart';

class EntregaGlobalPage extends ConsumerStatefulWidget {
  const EntregaGlobalPage({
    super.key,
    required this.suc,
    required this.fecha,
    required this.tipo,
  });

  final String suc;
  final DateTime fecha;
  final String tipo;

  @override
  ConsumerState<EntregaGlobalPage> createState() => _EntregaGlobalPageState();
}

class _EntregaGlobalPageState extends ConsumerState<EntregaGlobalPage> {
  bool _loadingReporte = false;
  String _reportTipo = 'GLOBAL';

  @override
  Widget build(BuildContext context) {
    const operationTipo = 'GLOBAL';
    final filtros = CajaGeneralFiltros(
      suc: widget.suc,
      fecha: widget.fecha,
      opv: '',
      tipo: operationTipo,
    );
    final resumenAsync = ref.watch(cajaGeneralResumenGlobalProvider(filtros));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resumen Global Caja General'),
        actions: [
          IconButton(
            tooltip: 'Refrescar',
            onPressed: _loadingReporte
                ? null
                : () => ref.invalidate(cajaGeneralResumenGlobalProvider(filtros)),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: resumenAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorBlock(
          message: apiErrorMessage(error),
          onRetry: () => ref.invalidate(cajaGeneralResumenGlobalProvider(filtros)),
        ),
        data: (resumen) {
          final hasPendings = resumen.hasPendingOpv || resumen.pendientes.isNotEmpty;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('SUC: ${widget.suc}'),
                      Text('FCN: ${_formatDate(widget.fecha)}'),
                      const Text('TIPO OPERACION: GLOBAL'),
                      const SizedBox(height: 6),
                      Text(
                        hasPendings
                            ? 'Advertencia: existen OPV pendientes de cierre.'
                            : 'No hay OPV pendientes de cierre.',
                        style: TextStyle(
                          color: hasPendings
                              ? Colors.orange.shade800
                              : Colors.green.shade700,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _simpleTable(
                title: 'Formas global',
                columns: const ['FORM', 'IMPT', 'IMPR', 'IMPE', 'DIFD'],
                rows: resumen.formasPago
                    .map(
                      (row) => [
                        row.form,
                        _money(row.impt),
                        _money(row.impr),
                        _money(row.impe),
                        _money(row.difd),
                      ],
                    )
                    .toList(growable: false),
              ),
              const SizedBox(height: 10),
              _simpleTable(
                title: 'Transacciones global',
                columns: const ['AUT', 'DESC', 'CTA', 'TOTAL'],
                rows: resumen.transacciones
                    .map(
                      (row) => [
                        row.aut,
                        row.desc,
                        row.cta.toStringAsFixed(0),
                        _money(row.total),
                      ],
                    )
                    .toList(growable: false),
              ),
              const SizedBox(height: 10),
              _simpleTable(
                title: 'Ventas globales',
                columns: const ['DEPTO', 'SUBDEPTO', 'PZS', 'TOTAL'],
                rows: resumen.ventas
                    .map(
                      (row) => [
                        row.ddepa,
                        row.dsubd,
                        row.vtapzs.toStringAsFixed(2),
                        _money(row.vtapsos),
                      ],
                    )
                    .toList(growable: false),
              ),
              const SizedBox(height: 10),
              _simpleTable(
                title: 'Efectivo global',
                columns: const ['DENO', 'CTDA', 'TOTAL'],
                rows: resumen.efectivo
                    .map(
                      (row) => [
                        _money(row.deno),
                        row.ctda.toStringAsFixed(2),
                        _money(row.total),
                      ],
                    )
                    .toList(growable: false),
              ),
              const SizedBox(height: 10),
              _simpleTable(
                title: 'OPV pendientes',
                columns: const ['OPV', 'NOMBRE', 'TRN', 'TOTAL', 'ESTA'],
                rows: resumen.pendientes
                    .map(
                      (row) => [
                        row.opv,
                        row.opvNombre,
                        row.trn.toStringAsFixed(0),
                        _money(row.total),
                        row.estaEntrega,
                      ],
                    )
                    .toList(growable: false),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  key: ValueKey('cg-global-report-tipo-$_reportTipo'),
                  initialValue: _reportTipo,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de reporte',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'GLOBAL', child: Text('GLOBAL')),
                    DropdownMenuItem(value: 'CA', child: Text('CA')),
                    DropdownMenuItem(value: 'VF', child: Text('VF')),
                  ],
                  onChanged: _loadingReporte
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() => _reportTipo = value);
                        },
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _loadingReporte ? null : _generarReporteGlobal,
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Generar reporte global'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _generarReporteGlobal() async {
    setState(() => _loadingReporte = true);
    try {
      final reporte = await ref.read(cajaGeneralApiProvider).fetchReporteGlobal(
            suc: widget.suc,
            fecha: widget.fecha,
            tipo: _reportTipo,
          );
      if (!mounted) return;
      final doc = _buildReporteGlobalPdf(reporte);
      final reportDate = _formatDate(widget.fecha);
      final fileName = 'cg_global_${widget.suc}_${_reportTipo}_$reportDate.pdf';
      final bytes = await doc.save();
      if (kIsWeb) {
        await Printing.sharePdf(bytes: bytes, filename: fileName);
      } else {
        await Printing.layoutPdf(
          name: fileName,
          onLayout: (_) async => bytes,
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(error))),
      );
    } finally {
      if (mounted) {
        setState(() => _loadingReporte = false);
      }
    }
  }

  Widget _simpleTable({
    required String title,
    required List<String> columns,
    required List<List<String>> rows,
  }) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: columns
                    .map((label) => DataColumn(label: Text(label)))
                    .toList(growable: false),
                rows: rows
                    .map(
                      (row) => DataRow(
                        cells: row
                            .map((value) => DataCell(Text(value)))
                            .toList(growable: false),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ],
        ),
      ),
    );
  }

  pw.Document _buildReporteGlobalPdf(Map<String, dynamic> data) {
    final forms = _asMapList(data['forms']);
    final transacciones = _asMapList(data['transacciones']);
    final ventas = _asMapList(data['ventas']);
    final pendientes = _asMapList(data['pendientes']);
    final generatedAt = _asText(data['generatedAt']);
    final hasPendingOpv = _asBool(data['hasPendingOpv']);
    final isGlobalReport = _reportTipo.toUpperCase() == 'GLOBAL';
    final totalImpt = forms.fold<double>(0, (sum, row) => sum + _asNumber(row['IMPT']));
    final totalImpr = forms.fold<double>(0, (sum, row) => sum + _asNumber(row['IMPR']));
    final totalImpe = forms.fold<double>(0, (sum, row) => sum + _asNumber(row['IMPE']));
    final totalDifd = forms.fold<double>(0, (sum, row) => sum + _asNumber(row['DIFD']));
    final formsHeaders = isGlobalReport
        ? const ['FORM', 'IMPT', 'IMPR', 'IMPE', 'DIFD']
        : const ['FORM', 'IMPT'];
    final formsRows = [
      ...forms
        .map(
          (row) => isGlobalReport
              ? [
                  _asText(row['FORM']),
                  _money(_asNumber(row['IMPT'])),
                  _money(_asNumber(row['IMPR'])),
                  _money(_asNumber(row['IMPE'])),
                  _money(_asNumber(row['DIFD'])),
                ]
              : [
                  _asText(row['FORM']),
                  _money(_asNumber(row['IMPT'])),
                ],
        ),
      if (isGlobalReport)
        [
          'TOTALES',
          _money(totalImpt),
          _money(totalImpr),
          _money(totalImpe),
          _money(totalDifd),
        ]
      else
        [
          'TOTALES',
          _money(totalImpt),
        ],
    ];

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Text(
            'REPORTE GLOBAL CAJA GENERAL',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'SUC: ${widget.suc}   FCN: ${_formatDate(widget.fecha)}   TIPO: $_reportTipo',
          ),
          if (generatedAt.isNotEmpty) pw.Text('Generado: $generatedAt'),
          pw.Text(
            hasPendingOpv
                ? 'ADVERTENCIA: existen OPV pendientes de cierre.'
                : 'Sin OPV pendientes de cierre.',
          ),
          pw.SizedBox(height: 10),
          _pdfTable(
            'Formas global',
            formsHeaders,
            formsRows,
          ),
          _pdfTable(
            'Transacciones global',
            const ['AUT', 'DESC', 'CTA', 'TOTAL'],
            transacciones
                .map(
                  (row) => [
                    _asText(row['AUT']),
                    _asText(row['DESC']),
                    _asNumber(row['CTA']).toStringAsFixed(0),
                    _money(_asNumber(row['TOTAL'])),
                  ],
                )
                .toList(growable: false),
          ),
          _pdfTable(
            'Ventas globales',
            const ['DEPTO', 'SUBDEPTO', 'PZS', 'TOTAL'],
            ventas
                .map(
                  (row) => [
                    _asText(row['DDEPA']),
                    _asText(row['DSUBD']),
                    _asNumber(row['VTAPZS']).toStringAsFixed(2),
                    _money(_asNumber(row['VTAPSOS'])),
                  ],
                )
                .toList(growable: false),
          ),
          _pdfTable(
            'OPV pendientes',
            const ['OPV', 'NOMBRE', 'TRN', 'TOTAL', 'ESTA'],
            pendientes
                .map(
                  (row) => [
                    _asText(row['OPV']),
                    _asText(row['OPV_NOMBRE']),
                    _asNumber(row['TRN']).toStringAsFixed(0),
                    _money(_asNumber(row['TOTAL'])),
                    _asText(row['ESTA_ENTREGA']),
                  ],
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
    return doc;
  }

  pw.Widget _pdfTable(
    String title,
    List<String> headers,
    List<List<String>> rows,
  ) {
    final safeRows = rows.isEmpty ? <List<String>>[List.filled(headers.length, '-')] : rows;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
        ),
        pw.SizedBox(height: 4),
        pw.TableHelper.fromTextArray(
          headers: headers,
          data: safeRows,
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
          cellStyle: const pw.TextStyle(fontSize: 9),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.3),
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        ),
        pw.SizedBox(height: 10),
      ],
    );
  }

  List<Map<String, dynamic>> _asMapList(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  String _asText(dynamic value) => (value ?? '').toString().trim();

  double _asNumber(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse((value ?? '').toString().trim()) ?? 0;
  }

  bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value > 0;
    final text = (value ?? '').toString().trim().toLowerCase();
    return text == 'true' || text == '1' || text == 'yes';
  }

  String _formatDate(DateTime value) {
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _money(double value) => '\$${value.toStringAsFixed(2)}';
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
