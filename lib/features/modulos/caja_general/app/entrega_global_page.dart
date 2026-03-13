import 'package:excel/excel.dart' as xls;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ioe_app/core/api_error.dart';
import 'package:ioe_app/core/excel_exporter.dart';
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
  static const String _uiTipo = 'GLOBAL';
  bool _loadingReporte = false;
  bool _loadingExcel = false;
  String _reportTipo = 'GLOBAL';
  String get _operationTipo => _normalizeTipo(widget.tipo);

  @override
  void initState() {
    super.initState();
    _reportTipo = _operationTipo;
  }

  @override
  Widget build(BuildContext context) {
    final filtros = CajaGeneralFiltros(
      suc: widget.suc,
      fecha: widget.fecha,
      opv: '',
      tipo: _uiTipo,
    );
    final resumenAsync = ref.watch(cajaGeneralResumenGlobalProvider(filtros));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resumen Global Caja General'),
        actions: [
          IconButton(
            tooltip: 'Refrescar',
            onPressed: (_loadingReporte || _loadingExcel)
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
                      Text('TIPO OPERACION: $_uiTipo'),
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
                      const SizedBox(height: 10),
                      _reportControls(),
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
              _pendientesTable(resumen.pendientes),
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

  Future<void> _exportarExcelGlobal() async {
    if (_loadingExcel) return;
    setState(() => _loadingExcel = true);
    try {
      final data = await ref.read(cajaGeneralApiProvider).fetchExcelGlobal(
            suc: widget.suc,
            fecha: widget.fecha,
          );
      final bytes = _buildExcelGlobalBytes(data);
      if (!mounted) return;
      if (bytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sin datos para exportar a Excel.')),
        );
        return;
      }

      final fileName = _buildExcelFilename();
      final saved = await getExcelExporter().save(bytes, fileName);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saved
                ? 'Exportacion Excel lista: $fileName'
                : 'Exportacion Excel cancelada.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(error))),
      );
    } finally {
      if (mounted) {
        setState(() => _loadingExcel = false);
      }
    }
  }

  Widget _reportControls() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 780;
        final tipoControl = SizedBox(
          width: isNarrow ? double.infinity : 260,
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
            onChanged: (_loadingReporte || _loadingExcel)
                ? null
                : (value) {
                    if (value == null) return;
                    setState(() => _reportTipo = value);
                  },
          ),
        );

        final generarButton = FilledButton.icon(
          onPressed: (_loadingReporte || _loadingExcel)
              ? null
              : _generarReporteGlobal,
          icon: const Icon(Icons.picture_as_pdf),
          label: const Text('Generar reporte global'),
        );
        final excelButton = FilledButton.icon(
          onPressed: (_loadingReporte || _loadingExcel)
              ? null
              : _exportarExcelGlobal,
          icon: const Icon(Icons.table_view),
          label: Text(
            _loadingExcel ? 'Exportando...' : 'Exportar Excel',
          ),
        );

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              tipoControl,
              const SizedBox(height: 12),
              generarButton,
              const SizedBox(height: 12),
              excelButton,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            tipoControl,
            const SizedBox(width: 12),
            generarButton,
            const SizedBox(width: 12),
            excelButton,
          ],
        );
      },
    );
  }

  Widget _pendientesTable(List<CajaGeneralPendiente> pendientes) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'OPV pendientes',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('OPV')),
                  DataColumn(label: Text('NOMBRE')),
                  DataColumn(label: Text('TRN')),
                  DataColumn(label: Text('TOTAL')),
                  DataColumn(label: Text('ESTA')),
                ],
                rows: [
                  if (pendientes.isEmpty)
                    const DataRow(
                      cells: [
                        DataCell(Text('-')),
                        DataCell(Text('Sin OPV pendientes')),
                        DataCell(Text('0')),
                        DataCell(Text('\$0.00')),
                        DataCell(Text('-')),
                      ],
                    ),
                  ...pendientes.map(
                    (row) => DataRow(
                      cells: [
                        DataCell(
                          Tooltip(
                            message:
                                'Doble clic para ver transacciones de la entrega pendiente',
                            child: InkWell(
                              onDoubleTap: () =>
                                  _showPendienteTransaccionesDialog(row),
                              child: Text(
                                row.opv,
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  decoration: TextDecoration.underline,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        DataCell(Text(row.opvNombre)),
                        DataCell(Text(row.trn.toStringAsFixed(0))),
                        DataCell(Text(_money(row.total))),
                        DataCell(Text(row.estaEntrega)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPendienteTransaccionesDialog(
    CajaGeneralPendiente pendiente,
  ) async {
    final opv = pendiente.opv.trim().toUpperCase();
    if (opv.isEmpty) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Transacciones pendientes OPV: $opv'),
        content: SizedBox(
          width: 980,
          child: FutureBuilder<List<CajaGeneralPendienteTransaccion>>(
            future: ref.read(cajaGeneralApiProvider).fetchPendienteTransacciones(
                  suc: widget.suc,
                  fecha: widget.fecha,
                  opv: opv,
                  tipo: _uiTipo,
                ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 180,
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return SizedBox(
                  height: 120,
                  child: Center(
                    child: Text(
                      apiErrorMessage(
                        snapshot.error ??
                            'No se pudo consultar transacciones pendientes',
                      ),
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),
                );
              }

              final items =
                  snapshot.data ?? const <CajaGeneralPendienteTransaccion>[];
              if (items.isEmpty) {
                return const SizedBox(
                  height: 120,
                  child: Center(
                    child: Text('Sin transacciones pendientes para este OPV.'),
                  ),
                );
              }

              final total = items.fold<double>(0, (sum, item) => sum + item.total);

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Registros: ${items.length} | Total: ${_money(total)}'),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 380,
                    child: SingleChildScrollView(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('IDFOL')),
                            DataColumn(label: Text('AUT')),
                            DataColumn(label: Text('DESC')),
                            DataColumn(label: Text('ESTA')),
                            DataColumn(label: Text('TOTAL'), numeric: true),
                            DataColumn(label: Text('FCNM')),
                          ],
                          rows: [
                            ...items.map(
                              (item) => DataRow(
                                cells: [
                                  DataCell(Text(item.idfol)),
                                  DataCell(Text(item.aut)),
                                  DataCell(Text(item.autDesc)),
                                  DataCell(Text(item.esta)),
                                  DataCell(Text(_money(item.total))),
                                  DataCell(Text(_formatDateTime(item.fcnm))),
                                ],
                              ),
                            ),
                            DataRow(
                              cells: [
                                const DataCell(
                                  Text(
                                    'TOTAL',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                ),
                                const DataCell(Text('')),
                                const DataCell(Text('')),
                                const DataCell(Text('')),
                                DataCell(
                                  Text(
                                    _money(total),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const DataCell(Text('')),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
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

  Uint8List? _buildExcelGlobalBytes(Map<String, dynamic> data) {
    final formsGlobal = _asMapList(data['formsGlobal']);
    final formsVf = _asMapList(data['formsVf']);
    final formsCa = _asMapList(data['formsCa']);
    final detalle = _asMapList(data['detalleTransacciones']);

    if (formsGlobal.isEmpty &&
        formsVf.isEmpty &&
        formsCa.isEmpty &&
        detalle.isEmpty) {
      return null;
    }

    final excel = xls.Excel.createExcel();
    final resumenSheet = excel['RESUMEN DIA'];
    _appendResumenGlobalSection(
      resumenSheet,
      title: 'Formas global',
      rows: formsGlobal,
    );
    resumenSheet.appendRow([_excelValue('')]);
    _appendResumenTipoSection(
      resumenSheet,
      title: 'Formas VF',
      rows: formsVf,
    );
    resumenSheet.appendRow([_excelValue('')]);
    _appendResumenTipoSection(
      resumenSheet,
      title: 'Formas CA',
      rows: formsCa,
    );

    final detalleSheet = excel['DETALLE TRANSACCIONES'];
    detalleSheet.appendRow([
      _excelValue('SUC'),
      _excelValue('FCN'),
      _excelValue('ORIGEN_AUT'),
      _excelValue('IDFOL'),
      _excelValue('OPVM'),
      _excelValue('CLIEN'),
      _excelValue('RazonSocialReceptor'),
      _excelValue('FORM'),
      _excelValue('IMPD'),
      _excelValue('AUT'),
    ]);
    for (final row in detalle) {
      detalleSheet.appendRow([
        _excelValue(_asText(row['SUC'])),
        _excelValue(_formatExcelDate(row['FCN'])),
        _excelValue(_asText(row['ORIGEN_AUT'])),
        _excelValue(_asText(row['IDFOL'])),
        _excelValue(_asText(row['OPVM'])),
        _excelValue(_asText(row['CLIEN'])),
        _excelValue(_asText(row['RazonSocialReceptor'])),
        _excelValue(_asText(row['FORM'])),
        _excelValue(_money(_asNumber(row['IMPD']))),
        _excelValue(_asText(row['AUT'])),
      ]);
    }

    if (excel.tables.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }
    excel.setDefaultSheet('RESUMEN DIA');
    final encoded = excel.encode();
    if (encoded == null || encoded.isEmpty) return null;
    return Uint8List.fromList(encoded);
  }

  void _appendResumenGlobalSection(
    xls.Sheet sheet, {
    required String title,
    required List<Map<String, dynamic>> rows,
  }) {
    sheet.appendRow([_excelValue(title)]);
    sheet.appendRow([
      _excelValue('FORM'),
      _excelValue('IMPT'),
      _excelValue('IMPR'),
      _excelValue('IMPE'),
      _excelValue('DIFD'),
    ]);
    for (final row in rows) {
      sheet.appendRow([
        _excelValue(_asText(row['FORM'])),
        _excelValue(_money(_asNumber(row['IMPT']))),
        _excelValue(_money(_asNumber(row['IMPR']))),
        _excelValue(_money(_asNumber(row['IMPE']))),
        _excelValue(_money(_asNumber(row['DIFD']))),
      ]);
    }
    sheet.appendRow([
      _excelValue('TOTALES'),
      _excelValue(_money(_sumRows(rows, 'IMPT'))),
      _excelValue(_money(_sumRows(rows, 'IMPR'))),
      _excelValue(_money(_sumRows(rows, 'IMPE'))),
      _excelValue(_money(_sumRows(rows, 'DIFD'))),
    ]);
  }

  void _appendResumenTipoSection(
    xls.Sheet sheet, {
    required String title,
    required List<Map<String, dynamic>> rows,
  }) {
    sheet.appendRow([_excelValue(title)]);
    sheet.appendRow([
      _excelValue('FORM'),
      _excelValue('IMPT'),
    ]);
    for (final row in rows) {
      sheet.appendRow([
        _excelValue(_asText(row['FORM'])),
        _excelValue(_money(_asNumber(row['IMPT']))),
      ]);
    }
    sheet.appendRow([
      _excelValue('TOTALES'),
      _excelValue(_money(_sumRows(rows, 'IMPT'))),
    ]);
  }

  xls.CellValue _excelValue(dynamic value) {
    if (value == null) return xls.TextCellValue('');
    if (value is xls.CellValue) return value;
    if (value is int) return xls.IntCellValue(value);
    if (value is double) return xls.DoubleCellValue(value);
    if (value is num) return xls.DoubleCellValue(value.toDouble());
    if (value is bool) return xls.BoolCellValue(value);
    return xls.TextCellValue(value.toString());
  }

  double _sumRows(List<Map<String, dynamic>> rows, String key) {
    return rows.fold<double>(0, (sum, row) => sum + _asNumber(row[key]));
  }

  String _buildExcelFilename() {
    final reportDate = _formatDate(widget.fecha);
    return 'cg_global_${widget.suc}_$reportDate.xlsx';
  }

  String _formatExcelDate(dynamic value) {
    final text = _asText(value);
    if (text.isEmpty) return '';
    final parsed = DateTime.tryParse(text);
    if (parsed == null) return text;
    return _formatDate(parsed);
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

  String _normalizeTipo(String raw) {
    final tipo = raw.trim().toUpperCase();
    if (tipo == 'CA' || tipo == 'VF' || tipo == 'GLOBAL') return tipo;
    return 'GLOBAL';
  }

  String _formatDateTime(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return '';
    final parsed = DateTime.tryParse(text);
    if (parsed == null) return text;

    final y = parsed.year.toString().padLeft(4, '0');
    final m = parsed.month.toString().padLeft(2, '0');
    final d = parsed.day.toString().padLeft(2, '0');
    final hh = parsed.hour.toString().padLeft(2, '0');
    final mm = parsed.minute.toString().padLeft(2, '0');
    final ss = parsed.second.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm:$ss';
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
