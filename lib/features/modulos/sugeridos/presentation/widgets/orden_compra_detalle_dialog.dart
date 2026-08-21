import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart' as xls;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../../core/auth/auth_controller.dart';
import '../../../reloj_checador/consultas/download_helper.dart';
import '../../domain/sugeridos_models.dart';
import '../../providers/sugeridos_provider.dart';

class OrdenCompraDetalleDialog extends ConsumerStatefulWidget {
  const OrdenCompraDetalleDialog({
    super.key,
    required this.doc,
    this.onChanged,
  });

  final SugeridoOrdenModel doc;
  final ValueChanged<SugeridoOrdenModel>? onChanged;

  @override
  ConsumerState<OrdenCompraDetalleDialog> createState() =>
      _OrdenCompraDetalleDialogState();
}

class _OrdenCompraDetalleDialogState
    extends ConsumerState<OrdenCompraDetalleDialog> {
  static const _detailPageSize = 100;

  late SugeridoOrdenModel _doc;
  bool _saving = false;
  int _detailPage = 0;

  @override
  void initState() {
    super.initState();
    _doc = widget.doc;
  }

  @override
  Widget build(BuildContext context) {
    final roleId = ref.watch(
      authControllerProvider.select((auth) => auth.roleId),
    );
    final editable = _doc.estatus == 'ABIERTO';
    final rejectedQuantityOnly = _doc.estatus == 'RECHAZADO';
    final canReturnToBranch = rejectedQuantityOnly && roleId == 2;
    final processed = _doc.estatus == 'PROCESADO';
    final activeItems = _doc.detalle.where((d) => d.bloq != -1).toList();
    final totalPages = activeItems.isEmpty
        ? 1
        : ((activeItems.length - 1) ~/ _detailPageSize) + 1;
    final currentPage = _detailPage >= totalPages
        ? totalPages - 1
        : _detailPage;
    final pageStart = activeItems.isEmpty ? 0 : currentPage * _detailPageSize;
    final pageEnd = activeItems.length < pageStart + _detailPageSize
        ? activeItems.length
        : pageStart + _detailPageSize;
    final visibleItems = activeItems.isEmpty
        ? <SugeridoDetalleModel>[]
        : activeItems.sublist(pageStart, pageEnd);
    final cantidad = activeItems.fold<double>(
      0,
      (sum, item) => sum + item.ctdped,
    );
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: Text('Orden de compra ${_doc.nped}'),
          actions: [
            IconButton(
              tooltip: 'Refrescar',
              onPressed: _saving ? null : _refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _HeaderBand(doc: _doc, cantidad: cantidad),
            const SizedBox(height: 14),
            if (canReturnToBranch)
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _returnToBranch,
                  icon: const Icon(Icons.keyboard_return),
                  label: const Text('Devolver a sucursal'),
                ),
              ),
            if (canReturnToBranch) const SizedBox(height: 14),
            if (editable)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: _saving ? null : _addArticulo,
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar articulo'),
                  ),
                  FilledButton.icon(
                    onPressed: activeItems.isEmpty || _saving
                        ? null
                        : () => _runOrderAction('enviar'),
                    icon: const Icon(Icons.send),
                    label: const Text('Enviar a autorizacion'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _importFile,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Importar archivo'),
                  ),
                ],
              ),
            if (editable) const SizedBox(height: 14),
            if (_saving) const LinearProgressIndicator(minHeight: 2),
            if (_saving) const SizedBox(height: 10),
            if (processed && activeItems.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _exportPdf,
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Descargar PDF'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _exportExcel,
                    icon: const Icon(Icons.table_view),
                    label: const Text('Descargar Excel'),
                  ),
                ],
              ),
            if (processed && activeItems.isNotEmpty) const SizedBox(height: 10),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(8),
              ),
              child: activeItems.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('Sin articulos capturados.'),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _detailPagination(
                          totalItems: activeItems.length,
                          pageStart: pageStart,
                          pageEnd: pageEnd,
                          currentPage: currentPage,
                          totalPages: totalPages,
                        ),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: [
                              const DataColumn(label: Text('Articulo')),
                              const DataColumn(label: Text('Descripcion')),
                              const DataColumn(
                                label: Text('Cantidad'),
                                numeric: true,
                              ),
                              const DataColumn(
                                label: Text('Costo'),
                                numeric: true,
                              ),
                              const DataColumn(
                                label: Text('Total'),
                                numeric: true,
                              ),
                              if (editable || rejectedQuantityOnly)
                                const DataColumn(label: Text('Acciones')),
                            ],
                            rows: [
                              for (final item in visibleItems)
                                DataRow(
                                  cells: [
                                    DataCell(Text(item.art)),
                                    DataCell(
                                      SizedBox(
                                        width: 360,
                                        child: Text(item.des ?? ''),
                                      ),
                                    ),
                                    DataCell(Text(_num(item.ctdped))),
                                    DataCell(Text(_money(item.cto))),
                                    DataCell(Text(_money(item.ctot))),
                                    if (editable || rejectedQuantityOnly)
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              tooltip: 'Editar cantidad',
                                              icon: const Icon(Icons.edit),
                                              onPressed: !_saving
                                                  ? () => _editCantidad(item)
                                                  : null,
                                            ),
                                            if (editable)
                                              IconButton(
                                                tooltip: 'Eliminar articulo',
                                                icon: const Icon(
                                                  Icons.delete_outline,
                                                ),
                                                onPressed: !_saving
                                                    ? () => _removeItem(item)
                                                    : null,
                                              ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
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

  Widget _detailPagination({
    required int totalItems,
    required int pageStart,
    required int pageEnd,
    required int currentPage,
    required int totalPages,
  }) {
    final canGoBack = currentPage > 0 && !_saving;
    final canGoForward = currentPage < totalPages - 1 && !_saving;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Articulos ${pageStart + 1}-$pageEnd de $totalItems',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          IconButton.outlined(
            tooltip: 'Primera pagina',
            onPressed: canGoBack ? () => setState(() => _detailPage = 0) : null,
            icon: const Icon(Icons.first_page),
          ),
          IconButton.outlined(
            tooltip: 'Pagina anterior',
            onPressed: canGoBack
                ? () => setState(() => _detailPage = currentPage - 1)
                : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Text('Pagina ${currentPage + 1} de $totalPages'),
          IconButton.outlined(
            tooltip: 'Pagina siguiente',
            onPressed: canGoForward
                ? () => setState(() => _detailPage = currentPage + 1)
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
          IconButton.outlined(
            tooltip: 'Ultima pagina',
            onPressed: canGoForward
                ? () => setState(() => _detailPage = totalPages - 1)
                : null,
            icon: const Icon(Icons.last_page),
          ),
        ],
      ),
    );
  }

  Future<void> _refresh() async {
    await _runMutation(
      () => ref.read(sugeridosApiProvider).fetchOne(_doc.nped),
      'O.C. actualizada.',
      showSuccess: false,
    );
  }

  Future<void> _addArticulo() async {
    final added = await showDialog<SugeridoOrdenModel>(
      context: context,
      builder: (context) => _AddOrdenArticuloDialog(
        doc: _doc,
        onChanged: (updated) {
          if (!mounted) return;
          setState(() => _doc = updated);
          widget.onChanged?.call(updated);
        },
      ),
    );
    if (added == null || !mounted) return;
    setState(() => _doc = added);
    widget.onChanged?.call(added);
  }

  Future<void> _runOrderAction(String action) async {
    final confirmed = await _confirmAction(
      title: 'Enviar a autorizacion',
      message: 'Se enviara la O.C. ${_doc.nped} a autorizacion.',
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      final updated = await ref
          .read(sugeridosApiProvider)
          .action(_doc.nped, action);
      if (!mounted) return;
      widget.onChanged?.call(updated);
      Navigator.pop(context, updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _returnToBranch() async {
    final motive = TextEditingController();
    String? validation;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Devolver a sucursal'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'La O.C. ${_doc.nped} volverá a PROCESADO y quedará disponible para el Encargado de sucursal.',
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: motive,
                  autofocus: true,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Motivo de devolución',
                    errorText: validation,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (motive.text.trim().isEmpty) {
                  setDialogState(
                    () => validation = 'Capture el motivo de devolución.',
                  );
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ),
    );
    final reason = motive.text.trim();
    motive.dispose();
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      final updated = await ref
          .read(sugeridosApiProvider)
          .action(_doc.nped, 'devolver-sucursal', obs: reason);
      if (!mounted) return;
      widget.onChanged?.call(updated);
      Navigator.pop(context, updated);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo devolver: $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool?> _confirmAction({
    required String title,
    required String message,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  Future<void> _importFile() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx', 'xls', 'csv'],
      allowMultiple: false,
      withData: false,
      withReadStream: true,
    );
    final file = picked?.files.single;
    if (file == null) return;

    late final List<_ImportOrdenArticuloRow> rows;
    try {
      final bytes = await _readPickedFileBytes(file);
      rows = _parseOrdenArticuloFile(file.name, bytes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Archivo invalido: $e')));
      return;
    }
    if (rows.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El archivo no contiene ART y CTDA.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final api = ref.read(sugeridosApiProvider);
      final resolved = <SugeridoOrdenDraftItem>[];
      final invalid = <String>[];
      for (final row in rows) {
        final matches = await api.articulosProveedor(
          suc: _doc.suc,
          prov: _doc.nprov,
          search: row.art,
          searchBy: 'ART',
          limit: 10,
        );
        SugeridoArticuloProveedorModel? match;
        for (final item in matches) {
          if (item.art.trim().toUpperCase() == row.art) {
            match = item;
            break;
          }
        }
        if (match == null) {
          invalid.add(row.art);
        } else {
          resolved.add(match.toDraft(row.cantidad));
        }
      }
      if (!mounted) return;
      if (invalid.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Articulos fuera del proveedor: ${invalid.take(6).join(', ')}',
            ),
          ),
        );
        return;
      }
      var updated = _doc;
      for (final item in resolved) {
        updated = await api.addDetalle(
          nped: _doc.nped,
          art: item.art,
          ctdped: item.ctdped,
          cto: item.cto,
          uncom: item.uncom,
        );
      }
      if (!mounted) return;
      setState(() => _doc = updated);
      widget.onChanged?.call(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Archivo importado. ${resolved.length} articulos.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo importar: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editCantidad(SugeridoDetalleModel item) async {
    final ctrl = TextEditingController(text: _num(item.ctdped));
    final value = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cantidad ${item.art}'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Cantidad',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) =>
              Navigator.pop(context, double.tryParse(ctrl.text.trim())),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, double.tryParse(ctrl.text.trim())),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (value == null || value <= 0 || !mounted) return;
    await _runMutation(
      () => ref
          .read(sugeridosApiProvider)
          .updateDetalle(nped: _doc.nped, idped: item.idped, ctdped: value),
      'Cantidad actualizada.',
    );
  }

  Future<void> _removeItem(SugeridoDetalleModel item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar articulo'),
        content: Text('Se eliminara ${item.art} de la O.C.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _runMutation(
      () => ref
          .read(sugeridosApiProvider)
          .removeDetalle(nped: _doc.nped, idped: item.idped),
      'Articulo eliminado.',
    );
  }

  Future<void> _runMutation(
    Future<SugeridoOrdenModel> Function() action,
    String success, {
    bool showSuccess = true,
  }) async {
    setState(() => _saving = true);
    try {
      final updated = await action();
      if (!mounted) return;
      setState(() => _doc = updated);
      widget.onChanged?.call(updated);
      if (showSuccess) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(success)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _exportExcel() async {
    if (_doc.estatus == 'PROCESADO') {
      await _exportProcessedExcel();
      return;
    }
    final activeItems = _doc.detalle.where((d) => d.bloq != -1).toList();
    final excel = xls.Excel.createExcel();
    final sheet = excel['DETALLE'];
    _prepareOrderDetailSheet(sheet);
    _appendOrderDetailHeader(sheet, _doc, activeItems);
    const headerRow = 5;
    final headers = [
      'O.C.',
      'Articulo',
      'Descripcion',
      'Cantidad',
      'Un de compra',
      'Costo',
      'Total',
    ];
    for (var col = 0; col < headers.length; col++) {
      _writeExcelCell(
        sheet,
        headerRow,
        col,
        headers[col],
        style: _excelBlueHeaderStyle(),
      );
    }
    for (var i = 0; i < activeItems.length; i++) {
      final item = activeItems[i];
      final row = headerRow + 1 + i;
      final rowStyle = i.isEven ? _excelGridStyle() : _excelAltGridStyle();
      _writeExcelCell(sheet, row, 0, _doc.nped, style: rowStyle);
      _writeExcelCell(sheet, row, 1, item.art, style: rowStyle);
      _writeExcelCell(sheet, row, 2, item.des ?? '', style: rowStyle);
      _writeExcelCell(sheet, row, 3, item.ctdped, style: _excelNumberStyle());
      _writeExcelCell(sheet, row, 4, item.uncom, style: rowStyle);
      _writeExcelCell(sheet, row, 5, item.cto, style: _excelMoneyStyle());
      _writeExcelCell(sheet, row, 6, item.ctot, style: _excelMoneyStyle());
    }
    if (excel.tables.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }
    excel.setDefaultSheet('DETALLE');
    final encoded = excel.encode();
    if (encoded == null || encoded.isEmpty) return;
    await saveBytesFile(
      Uint8List.fromList(encoded),
      'OC_${_doc.nped}.xlsx',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Archivo Excel generado.')));
    }
  }

  Future<void> _exportProcessedExcel() async {
    final rows = _buildLensExportRows(
      _doc.detalle.where((d) => d.bloq != -1).toList(),
    );
    if (rows.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No hay micas MONOFOCAL, BASES o BIFOCAL.'),
          ),
        );
      }
      return;
    }

    final excel = xls.Excel.createExcel();
    _appendLensSheet(
      excel,
      sheetName: 'MONOFOCAL',
      dimensionLabel: 'SPH/CYL',
      rows: rows.where((row) => row.sheetName == 'MONOFOCAL').toList(),
      doc: _doc,
    );
    _appendLensSheet(
      excel,
      sheetName: 'BASES',
      dimensionLabel: 'BASE/ADD',
      rows: rows.where((row) => row.sheetName == 'BASES').toList(),
      doc: _doc,
    );
    _appendLensSheet(
      excel,
      sheetName: 'BIFOCAL',
      dimensionLabel: 'SPH/ADD',
      rows: rows.where((row) => row.sheetName == 'BIFOCAL').toList(),
      doc: _doc,
    );
    if (excel.tables.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }
    excel.setDefaultSheet('MONOFOCAL');
    final encoded = excel.encode();
    if (encoded == null || encoded.isEmpty) return;
    await saveBytesFile(
      Uint8List.fromList(encoded),
      'OC_${_doc.nped}_micas.xlsx',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Archivo Excel generado.')));
    }
  }

  Future<void> _exportPdf() async {
    if (!supportsDownload) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La descarga de PDF solo esta disponible en Web.'),
        ),
      );
      return;
    }

    try {
      final activeItems = _doc.detalle.where((d) => d.bloq != -1).toList();
      final providerName = _providerName(_doc);
      final sucursalInfo = _sucursalDeliveryInfo(_doc.suc);
      final deliveryLines = _deliveryAddressLines(_doc.suc);
      final cantidad = activeItems.fold<double>(
        0,
        (sum, item) => sum + item.ctdped,
      );
      final logo =
          await _loadPdfAssetImage('assets/images/ioe_logo.jpeg') ??
          _embeddedPdfLogoImage();
      final footerLogo = await _loadPdfAssetImage(
        'assets/images/grupo_ioe_logo.jpeg',
      );
      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.letter,
          margin: const pw.EdgeInsets.fromLTRB(24, 22, 24, 16),
          footer: (_) => _pdfFooter(footerLogo),
          build: (_) => [
            _pdfModernHeader(logo, sucursalInfo),
            pw.SizedBox(height: 16),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  flex: 5,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _pdfBlueBand(
                        'FECHA DE SOLICITUD DEL PEDIDO: ${_dateText(_doc.fcnp ?? _doc.fcnc)}',
                      ),
                      _pdfBlueBand('NUMERO DE PEDIDO: ${_doc.nped}'),
                      pw.SizedBox(height: 12),
                      _pdfBox(
                        title: 'DIRECCION DE ENTREGA',
                        lines: deliveryLines,
                        bodyFontSize: 10,
                        titleFontSize: 10,
                        bodyPadding: const pw.EdgeInsets.fromLTRB(8, 7, 8, 7),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 26),
                pw.Expanded(
                  flex: 4,
                  child: pw.Column(
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.end,
                        children: [
                          _pdfSmallInfo('NO. DE ORDEN DE\nCOMPRA', _doc.nped),
                          pw.SizedBox(width: 20),
                          _pdfSmallInfo(
                            'TIPO DE\nCOMPRA',
                            _doc.tipo.trim().isEmpty ? 'NORMAL' : _doc.tipo,
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 28),
                      _pdfProviderBox(
                        providerName: providerName,
                        providerId: '${_doc.nprov}',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 22),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Cantidad: ${_num(cantidad)}   Importe: ${_money(_doc.impp)}',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: _pdfNavy,
                ),
              ),
            ),
            pw.TableHelper.fromTextArray(
              headers: const [
                'ARTICULO',
                'DESCRIPCION',
                'UNIDAD DE COMPRA',
                'CANTIDAD',
              ],
              data: activeItems
                  .map(
                    (item) => [
                      item.art,
                      item.des ?? '',
                      item.uncom.isEmpty ? 'PAR' : item.uncom,
                      _num(item.ctdped),
                    ],
                  )
                  .toList(),
              border: pw.TableBorder.all(color: PdfColors.black, width: 0.45),
              headerDecoration: const pw.BoxDecoration(color: _pdfNavy),
              rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
              oddRowDecoration: const pw.BoxDecoration(color: _pdfSoftBlue),
              headerStyle: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 4,
              ),
              columnWidths: {
                0: const pw.FixedColumnWidth(70),
                1: const pw.FlexColumnWidth(3.0),
                2: const pw.FixedColumnWidth(70),
                3: const pw.FixedColumnWidth(60),
              },
              cellAlignments: {
                0: pw.Alignment.center,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.center,
                3: pw.Alignment.center,
              },
            ),
          ],
        ),
      );
      await saveBytesFile(
        await pdf.save(),
        'OC_${_doc.nped}.pdf',
        'application/pdf',
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Archivo PDF generado.')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo generar PDF: $e')));
    }
  }
}

class _HeaderBand extends StatelessWidget {
  const _HeaderBand({required this.doc, required this.cantidad});

  final SugeridoOrdenModel doc;
  final double cantidad;

  @override
  Widget build(BuildContext context) {
    final providerName = (doc.alias ?? '').trim().isNotEmpty
        ? doc.alias!
        : ((doc.rsoc ?? '').trim().isNotEmpty ? doc.rsoc! : '${doc.nprov}');
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 18,
          runSpacing: 8,
          children: [
            Text(
              'DOC: ${doc.nped}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text('Estatus: ${doc.estatus}'),
            Text('Sucursal: ${doc.suc}'),
            Text('Proveedor: ${doc.nprov} - $providerName'),
            Text('Cantidad: ${_num(cantidad)}'),
            Text('Importe: ${_money(doc.impp)}'),
          ],
        ),
      ),
    );
  }
}

const _pdfNavy = PdfColor.fromInt(0xff0B3D78);
const _pdfBlue = PdfColor.fromInt(0xff0F56A6);
const _pdfCyan = PdfColor.fromInt(0xff21B3E6);
const _pdfSoftBlue = PdfColor.fromInt(0xffEEF6FF);
const _pdfInk = PdfColor.fromInt(0xff111827);

pw.Widget _pdfModernHeader(
  pw.ImageProvider? logo,
  _SucursalDeliveryInfo sucursalInfo,
) {
  return pw.Container(
    padding: const pw.EdgeInsets.only(bottom: 14),
    decoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: _pdfNavy, width: 3)),
    ),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: 76,
          height: 58,
          alignment: pw.Alignment.centerLeft,
          child: _pdfLogo(logo),
        ),
        pw.SizedBox(width: 14),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'DISTRIBUIDORA IOE',
                style: pw.TextStyle(
                  fontSize: 19,
                  fontWeight: pw.FontWeight.bold,
                  color: _pdfNavy,
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                'JOEL JIMENEZ',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: _pdfInk,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                sucursalInfo.ciudad,
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
        ),
        pw.Container(
          width: 152,
          height: 62,
          decoration: pw.BoxDecoration(
            color: _pdfCyan,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          alignment: pw.Alignment.center,
          child: pw.Text(
            'ORDEN DE\nCOMPRA',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black,
            ),
          ),
        ),
      ],
    ),
  );
}

pw.Widget _pdfBlueBand(String text) {
  return pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 5),
    color: _pdfNavy,
    child: pw.Text(
      text,
      style: pw.TextStyle(
        color: PdfColors.white,
        fontSize: 9,
        fontWeight: pw.FontWeight.bold,
      ),
    ),
  );
}

pw.Widget _pdfBox({
  required String title,
  required List<String> lines,
  double titleFontSize = 8,
  double bodyFontSize = 8,
  pw.EdgeInsets bodyPadding = const pw.EdgeInsets.all(8),
}) {
  return pw.Container(
    decoration: pw.BoxDecoration(
      color: PdfColors.white,
      border: pw.Border.all(color: _pdfBlue, width: 0.8),
      borderRadius: pw.BorderRadius.circular(3),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
          decoration: const pw.BoxDecoration(color: _pdfNavy),
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: pw.Text(
            title,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: titleFontSize,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.Padding(
          padding: bodyPadding,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              for (final line in lines)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Text(
                    line,
                    style: pw.TextStyle(fontSize: bodyFontSize),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

pw.Widget _pdfProviderBox({
  required String providerName,
  required String providerId,
}) {
  return pw.Container(
    decoration: pw.BoxDecoration(
      color: PdfColors.white,
      border: pw.Border.all(color: _pdfBlue, width: 0.8),
      borderRadius: pw.BorderRadius.circular(3),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
          decoration: const pw.BoxDecoration(color: _pdfNavy),
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          child: pw.Text(
            'INFORMACION DEL PROVEEDOR',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: pw.Column(
            children: [
              _pdfProviderLine('Proveedor:', providerName),
              pw.SizedBox(height: 7),
              _pdfProviderLine('N PROV', providerId),
            ],
          ),
        ),
      ],
    ),
  );
}

pw.Widget _pdfProviderLine(String label, String value) {
  return pw.Row(
    children: [
      pw.SizedBox(
        width: 72,
        child: pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 9,
            color: _pdfNavy,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ),
      pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 2),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: PdfColors.black, width: 0.7),
            ),
          ),
          child: pw.Text(
            value,
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 9),
          ),
        ),
      ),
    ],
  );
}

pw.Widget _pdfSmallInfo(String label, String value) {
  return pw.Column(
    children: [
      pw.Text(
        label,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          fontSize: 7,
          color: _pdfNavy,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
      pw.SizedBox(height: 4),
      pw.Container(
        width: 80,
        height: 24,
        alignment: pw.Alignment.center,
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          border: pw.Border.all(color: _pdfInk, width: 0.7),
          borderRadius: pw.BorderRadius.circular(2),
        ),
        child: pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
      ),
    ],
  );
}

Future<pw.ImageProvider?> _loadPdfAssetImage(String assetPath) async {
  try {
    final data = await rootBundle.load(assetPath);
    return pw.MemoryImage(data.buffer.asUint8List());
  } catch (_) {
    return null;
  }
}

pw.Widget _pdfLogo(pw.ImageProvider? logo) {
  if (logo == null) {
    return pw.SizedBox(width: 76, height: 58);
  }
  return pw.Image(logo, width: 76, height: 58, fit: pw.BoxFit.contain);
}

pw.ImageProvider _embeddedPdfLogoImage() {
  return pw.MemoryImage(base64Decode(_ioeLogoPdfJpgBase64));
}

const _ioeLogoPdfJpgBase64 =
    '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';

// ignore: unused_element
const _ioeLogoPdfRealPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAIwAAACaCAYAAAB7T6C4AAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAB68SURBVHhe7Z0FsBzFE8bDHwnuDsGDuwZP8AT34O4aNIEAAYIkuEdIcA2uQYMEDQR3CRDcIbjtv35b9W319du927vbu3f33n5VU/fe3crszLc9Pd09PR2CHDnKQAf/RY4cxZATJkdZyAmTAf7555/gzz//DP7444/g999/D3799dfgl19+iQrf8fu///7rT43Ff//9579qGOSEiQEdRufyqSLQ+d99913w6aefBu+++24wZsyY4KGHHgpGjBgRDB8+PLjooouCAQMGBCeffHLQu3fv4Kijjgo/TzzxxKBfv37B+eefH1x77bXByJEjg1deeSX46quvCu4N7D0hY1qi1QM5YRxsZ9FRdNhvv/0WfPnll8GHH34YfPjhh8ERRxwRjBs3Lnj77bej0vbs2RNMmDAh+Pn5eUGcnp4e7LjjjuHSSy8N/vjHPw6OO+64oEuXLkG/fv2Cjz76KIwaNSr48MMPg7Fjxwbr169PXn/99eDss88Otm/fHrx+/fqgZ8+e4Y477gguuuii4Oqrrw7efvvt0Ldvn+Dzzz8PnnnmmWB8fHy84LLLLgvmzZsX/Pjjj8Hbb78dHHTQQcGIESOC++67Lzhy5EigW7duwdKlS4PTTz89+Nlnnw3Gjx8fDB06NOjcuXNg3bp1wbZt24I333wz+Oqrrw4mTZoUfPPNN8GNN94YHHDAAcG6detC7dq1g2PHjg3mzZsX7LHHHsEzzzwTzJ07N/jggw+C9evXB0uXLg1Wr14dTJgwIfj999+D5cuXB+PGjQu+//77oX///sGtt94afPPNN8PkyZODjRs3BiNHjgwmT54cLFy4MHjxxReDN998M/jggw+Cn376KWjTpk3Qv3//4Pbbbw8uv/zy4IILLghGjBgRjBw5MnjssceCjz/+OFi/fn3Qrl27gq+//jrYvn17cN111wWnnnpq8NRTTwWHDh0KnnjiieD8888PZs6cGaxevTq4/fbbg/Xr1weTJ08OevXqFbzxxhuD0aNHB5MnTw6eeOKJYOTIkcG8efOC1atXB3/7298G48aNC5YvXx5cccUVweDBg4Ply5cHf/jDH4Lhw4cHkydPDqZOnRr88MMPgzfffDOYO3duMGnSpOD2228PZs2aFbz66quDkSNHBv/6178GGzduDH7/+98Hf//738PChQuD3bt3B9ddd13w/vvvB7NmzQpGjhwZDBs2LPj444+Ddu3aBXfffXfw5ptvBuPGjQu2bt0afPbZZ4M333wz2L59e3D++ecHixYtCjZs2BB88MEHwcaNG4Ozzz47mDhxYjBz5szg0KFDg0cffTQYN25c8PbbbwdnnHFGMGLEiOD5558PZs6cGaxevTq4+uqrw9atW4Mnn3wyGDVqVDB06NDg7bffDk466aTg3XffDXbs2BH86le/Cr744ovBunXrgjfffDOYMWNGMGLEiOD0008P9u3bF4wZMyaYPn168PjjjweDBw8OxowZE9x3333B66+/Htx9993Bp59+GgwfPjyYO3duMHLkyODgwYODQYMGBePGjQvWr18fLF26NMjLywueeeaZYM+ePcGTTz4ZfPbZZ8G1114bTJo0Kfj888+D999/Pzj77LPDkSNHBnfffXfw3HPPBc8991ywfft24MILLwwmTpwYjBw5MnjooYeCu+++O1i8eHHw0UcfBfPmzQuuueaa4M033wzOOOOMYOTIkcH8+fOD6667LrjsssuCwYMHh6+//jq4+OKLg8TERGBpaWnQqlWr4MILLwzmzJkTXHDBBcG9994b3HbbbYGSkpKCt99+O/jkk0+CE088Mfj888+DCRMmBAsXLgxGjhwZHD16NNi2bVuwfPny4O233w7uu+++4N577w2OOOKI4Pnnnw+2bdsWDBo0KBgyZEjw448/BuPGjQvWrVsX7LTTTqE0f39/8MILLwzmzp0bHDhwIDh69GjQtm3b4Nprrw3OOOOMYNGiRUF9fX2wY8eO4IorrggmTZoU3HvvvcG0adOCESNGBE888UTw1FNPBfv27QvGjRsXHDt2LFi/fn0wZ86c4P777w/mz58frFu3Lli+fHnw2GOPBfPmzQuuv/76YMeOHcH9998fTJw4MXj55ZeDdevWBVdddVXwzDPPBFu3bg1GjhwZzJ49O/jggw+C3bt3B4sXLw5mz54dHD16NDjiiCOCd999N7jpppuC5cuXBw888EBw4MCB4J133gkWLlwYLFy4MPjyyy+C6dOnB0uXLg0uvPDC4JprrgnGjRsXHDlyJLjmmmuC48ePB8OGDQvWrVsXfP7558H69euD1atXB4sXLw6OO+64YPLkycGf//zn4Nprrw1mzZoVfPDBB8GmTZsC48aNC15//fVg6NChwZkzZ4IJEyYEr7zySrBhw4bg2WefDYYMGVI0J0eOHBksW7YsuO6664Lx48cHixYtCk488cRg+PDhwe7du4MrrrgiWL9+fXDhhRcGx44dC66//vrgkUceCc4888zg2GOPDc4//3xw5513BgsWLAiWL18e3H777cGLL74YHDx4MBg5cmRw5513Bq+//nrw9ddfD+bMmRNs3LgxuO+++4LHHnssGD16dHB2dhbs2bMn2LdvX3DfffcF06dPD+69995gwoQJwYQJE4Krr746mD59enDPPfcEzzzzTDBmzJhg9uzZwR133BFs2rQpOOecc4KRI0cGq1atCqZNmxb89NNPwYsvvhgMGjQo2LJlS3D77bcHixYtCr7//vvg6KOPDk466aTg8ssvD44//vjg8ccfD+bOnRtMnTo1eOqpp4K33347mD59ejB+/PigRYsWwfnnnx+MGDEi2LVrV3DccceF2mOPPTb4+uuvg8OHDwd33HFH8N577w3OOOOMYOTIkcHjjz8eLFu2LLjnnnuC3bt3B6dOnQrGjBkT3HfffXHrrbcGJ0+eDLZt2xZs3Lgx+O677w5mzJgR3HvvvcG8efOCdevWBccffzzYvXt3cP/998fGjRsXPPfcc8H9998fDBgwIDjvvPNC3bp1wZAhQ4KbbropWL16dXDHHXcEgwYNCp588skgNzc3uP/++4MdO3YEv/3tb8GCBQuCffv2BV9++WUwYcKEYP/+/cG8efOCe++9N7jllluC1atXB5MmTQp+//33wV133RWsWbMm2LJlS/Doo4+Cu+66K/j000+DdevWBZs3b45+f39/8L777gvmzp0bTJw4MXjrrbeCxYsXB2PGjAnWrVsX3HXXXcG5554bHDhwIDj77LOD3bt3B8OGDQvWr18fDB06NDj33HOD5557LnjzzTcH69atC+6///7g3XffDXbs2BH89NNPwWuvvRZMmzYt+Pjjj4PbbrstWL9+fXDFFVcEgwcPDnbs2BH84Q9/CJYuXRqsWLEi+P7774PZs2cHf/vb3wYjR44M5s6dGwwbNiy48847g3bt2gWnnnpq8MADDwTz588PZs6cGdx3333B6tWrwVlnnRW8+uqrweDBg4Prr78+eO2114Lrr78+GD9+fDBlypTg7rvvDqZNmxb06dMn+P7774Ply5cHixYtCq677rrgk08+CUpKSoLPP/88mD59enDjjTeC3bt3B6dOnQrGjBkT3H///cGkSZOCO++8M5g9e3YwYsSI4K677gqWL18evPbaa8GUKVOCS5cuDQoKCgL3338/2Lt3b7Bt27bg+uuvD+64447g6NGjweHDh4PZs2cHzzzzTDBx4sTg2muvDY4++uhg8ODBwffffx9MnDgx+Oabb4KxY8cG06ZNCzZs2BBs3bo1+Oijj4LFixcHzZo1C/7whz8EAwYMCG688cZg+vTpwSuvvBJMmTIl+Pjjj4Pp06cHn3zySdCuXbtg0KBBwW233RZ88MEHwcaNG4P58+cHgwYNChYsWBBcccUVwTXXXBNs2LAhePDBB4M777wzGDJkSLC0tDR46KGHgrfffjvYs2dP8PjjjweTJk0K7r333mD58uXB66+/HnzxxRfBwoULg8cffzy4/fbbg6OPPjoYNWpU8NlnnwVPP/10MGHChOB3v/td8PbbbwcPPvhgMGfOnODaa68Njj766GDVqlXB8uXLg+HDhwfr168Prrrqqui4AuqbnDCSAqtfv34g6uvrQ4kHDx4cTJs2LVg2bFjQvHnz4MknnwyuueaaYMOGDcHmzZuD6dOnB3v27AmGDRsWHDt2LJg5c2YwZcqU4O677w6GDx8eXHDBBcGnn34a7NixI3jrrbeCffv2Bdddd13QpUuX4MMPPwxGjBgR3HPPPcG1114bHH300cGNN94Y/PDDD8PcuXODn376KRg7dmywaNGi4Pnnnw8efvjh4PXXXx8sXrw4mD17djB+/PjgjTfeCF544YXg0UcfDXbu3BkMHTo0+O6774Lly5cHjz76aDD33HODxx57LJg/f36wZs2a4P777w+WL18eLF++PLjmmmuCgQMHBu+88Uawbt26YOPGjYPr168PFi5cGNy5cyd4/vnnw8mTJ4NXX301WLFiRfD4448H48ePDz744IPg8ccfD6ZOnRoMHTq06MZ8w0FSlEXiBldffXXQqlWr4N133w22bdsWvP3228GECROCJ554Ijj77LODVatWBV27dg2eeeaZYM+ePcHSpUsDzzzzTDBy5Mjg+uuvD1asWBGsWbMmuO6664Jp06YFhYWFBY888khw+eWXByNH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';
// ignore: unused_element
const _ioeLogoPdfPngBase64Fixed =
    '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'
    'TkSuQmCC';

// ignore: unused_element
const _ioeLogoPdfPngBase64 =
    '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';

const _pdfFooterTriangleSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 30">
  <polygon points="0,30 24,0 48,30" fill="#0B3D78"/>
</svg>
''';

pw.Widget _pdfFooter(pw.ImageProvider? footerLogo) {
  return pw.Container(
    height: 38,
    alignment: pw.Alignment.bottomLeft,
    child: pw.Stack(
      children: [
        pw.Positioned(
          left: 0,
          bottom: 0,
          child: pw.Container(
            width: 170,
            height: 30,
            color: _pdfCyan,
            alignment: pw.Alignment.centerLeft,
            padding: const pw.EdgeInsets.only(left: 20),
            child: footerLogo == null
                ? pw.Text(
                    'GRUPO\nioe',
                    style: pw.TextStyle(
                      color: PdfColors.blue900,
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  )
                : pw.Image(
                    footerLogo,
                    width: 92,
                    height: 22,
                    fit: pw.BoxFit.contain,
                  ),
          ),
        ),
        pw.Positioned(
          left: 146,
          bottom: 0,
          child: pw.SvgImage(
            svg: _pdfFooterTriangleSvg,
            width: 48,
            height: 30,
            fit: pw.BoxFit.fill,
          ),
        ),
        pw.Positioned(
          left: 190,
          right: 0,
          bottom: 0,
          child: pw.Container(height: 5, color: _pdfNavy),
        ),
      ],
    ),
  );
}

List<String> _deliveryAddressLines(String suc) {
  final info = _sucursalDeliveryInfo(suc);
  return [
    'Distribuidora IOE ${info.nombre}.',
    'Joel Jimenez Cruz',
    'Direccion:',
    ...info.direccion,
    'Correo: joeljims@hotmail.com',
    'Cel: 2299 152535',
  ];
}

_SucursalDeliveryInfo _sucursalDeliveryInfo(String suc) {
  final normalized = suc.trim().toUpperCase();
  return switch (normalized) {
    'DF04' => const _SucursalDeliveryInfo(
      suc: 'DF04',
      nombre: 'Cordoba Centro',
      ciudad: 'Cordoba, Veracruz.',
      direccion: [
        'Calle 13 No. 902',
        'entre Av. 11 y Av. 7 Centro.',
        'Cordoba, Ver.',
      ],
    ),
    'DF05' => const _SucursalDeliveryInfo(
      suc: 'DF05',
      nombre: 'Puebla Centro',
      ciudad: 'Puebla, Puebla.',
      direccion: [
        'Poniente 3 No. 318 Int 217',
        'Col. Centro Puebla',
        'C.P. 72000, Puebla, Puebla.',
      ],
    ),
    'DF06' => const _SucursalDeliveryInfo(
      suc: 'DF06',
      nombre: 'CDMX Centro Historico',
      ciudad: 'Ciudad de Mexico.',
      direccion: ['Direccion no registrada en DAT_SUC.'],
    ),
    _ => const _SucursalDeliveryInfo(
      suc: 'DF01',
      nombre: 'Veracruz',
      ciudad: 'Veracruz, Mexico.',
      direccion: [
        'Avenida 5 de Mayo Num. 1369-1 Altos',
        'entre Mariano Arista y Aquiles Serdan.',
        'Col. Centro.',
        'Veracruz, Ver. C.P. 91700',
      ],
    ),
  };
}

class _SucursalDeliveryInfo {
  const _SucursalDeliveryInfo({
    required this.suc,
    required this.nombre,
    required this.ciudad,
    required this.direccion,
  });

  final String suc;
  final String nombre;
  final String ciudad;
  final List<String> direccion;
}

String _dateText(DateTime? value) {
  final date = value ?? DateTime.now();
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

String _providerName(SugeridoOrdenModel doc) {
  final alias = (doc.alias ?? '').trim();
  if (alias.isNotEmpty) return alias;
  final rsoc = (doc.rsoc ?? '').trim();
  if (rsoc.isNotEmpty) return rsoc;
  return '${doc.nprov}';
}

void _appendLensSheet(
  xls.Excel excel, {
  required String sheetName,
  required String dimensionLabel,
  required List<_LensExportRow> rows,
  required SugeridoOrdenModel doc,
}) {
  final sheet = excel[sheetName];
  _prepareLensSheet(sheet);
  _mergeExcelCells(
    sheet,
    0,
    1,
    0,
    9,
    'ORDEN DE COMPRA - $sheetName',
    style: _excelTitleStyle(),
  );
  _writeExcelCell(sheet, 1, 1, 'Proveedor', style: _excelLabelStyle());
  _writeExcelCell(sheet, 1, 2, doc.nprov, style: _excelValueStyle());
  _mergeExcelCells(
    sheet,
    1,
    3,
    1,
    8,
    _providerName(doc),
    style: _excelValueStyle(),
  );
  _writeExcelCell(sheet, 2, 1, 'Documento', style: _excelLabelStyle());
  _mergeExcelCells(sheet, 2, 2, 2, 4, doc.nped, style: _excelValueStyle());
  _mergeExcelCells(
    sheet,
    2,
    5,
    2,
    6,
    'Sucursal ${doc.suc}',
    style: _excelValueStyle(),
  );
  _mergeExcelCells(sheet, 2, 7, 2, 8, 'Total pares', style: _excelLabelStyle());
  _writeExcelCell(sheet, 2, 9, _sumLensRows(rows), style: _excelValueStyle());

  if (rows.isEmpty) {
    _writeExcelCell(
      sheet,
      5,
      1,
      'Sin articulos para esta hoja',
      style: _excelValueStyle(),
    );
    return;
  }

  final grouped = <String, List<_LensExportRow>>{};
  for (final row in rows) {
    grouped.putIfAbsent(row.material, () => <_LensExportRow>[]).add(row);
  }
  final materials = grouped.keys.toList()..sort();
  var rowIndex = 5;

  for (final material in materials) {
    final materialRows = grouped[material]!;
    _writeExcelCell(sheet, rowIndex, 1, 'Material:', style: _excelLabelStyle());
    _mergeExcelCells(
      sheet,
      rowIndex,
      2,
      rowIndex,
      9,
      material,
      style: _excelValueStyle(),
    );
    _writeExcelCell(
      sheet,
      rowIndex + 1,
      1,
      'Total Pares:',
      style: _excelLabelStyle(),
    );
    _mergeExcelCells(
      sheet,
      rowIndex + 1,
      3,
      rowIndex + 1,
      4,
      _sumLensRows(materialRows),
      style: _excelValueStyle(),
    );

    if (sheetName == 'MONOFOCAL') {
      rowIndex = _appendMonofocalGrid(sheet, rowIndex + 3, materialRows) + 3;
    } else {
      final rowValues = sheetName == 'BASES' ? _baseRows : _sphereRows(0, 8.25);
      final colValues = sheetName == 'BASES' ? _baseAddColumns : _addColumns;
      rowIndex =
          _appendSimpleLensGrid(
            sheet,
            rowIndex + 3,
            materialRows,
            label: dimensionLabel,
            rowValues: rowValues,
            colValues: colValues,
            rowSelector: sheetName == 'BASES'
                ? (row) => row.base
                : (row) => row.sph ?? row.primary,
            colSelector: sheetName == 'BASES'
                ? (row) => row.add ?? row.secondary
                : (row) => row.add ?? row.secondary,
          ) +
          3;
    }
  }
  _appendLensMaterialSummary(sheet, rows, startRow: 1);
}

const _monoCylLeftColumns = <double>[
  -2.0,
  -1.75,
  -1.5,
  -1.25,
  -1.0,
  -0.75,
  -0.5,
  -0.25,
  0.0,
];

const _monoCylRightColumns = <double>[
  0.0,
  -0.25,
  -0.5,
  -0.75,
  -1.0,
  -1.25,
  -1.5,
  -1.75,
  -2.0,
];

const _addColumns = <double>[
  1.0,
  1.25,
  1.5,
  1.75,
  2.0,
  2.25,
  2.5,
  2.75,
  3.0,
  3.25,
  3.5,
  3.75,
  4.0,
];

const _baseAddColumns = <double>[
  0.0,
  1.0,
  1.25,
  1.5,
  1.75,
  2.0,
  2.25,
  2.5,
  2.75,
  3.0,
  3.25,
  3.5,
  3.75,
  4.0,
];

const _baseRows = <double>[0, 2, 4, 6, 8, 10, 12, 14, 16];

void _prepareLensSheet(xls.Sheet sheet) {
  sheet.setColumnWidth(0, 4);
  for (var col = 1; col <= 20; col++) {
    sheet.setColumnWidth(col, col == 10 || col == 11 ? 9 : 7);
  }
  sheet.setColumnWidth(21, 5);
  sheet.setColumnWidth(22, 42);
  sheet.setColumnWidth(23, 10);
  sheet.setColumnWidth(24, 12);
  sheet.setRowHeight(0, 24);
  sheet.setRowHeight(1, 18);
  sheet.setRowHeight(2, 18);
}

void _prepareOrderDetailSheet(xls.Sheet sheet) {
  final widths = <double>[14, 14, 46, 12, 16, 12, 14];
  for (var col = 0; col < widths.length; col++) {
    sheet.setColumnWidth(col, widths[col]);
  }
  sheet.setRowHeight(0, 24);
  sheet.setRowHeight(1, 18);
  sheet.setRowHeight(2, 18);
  sheet.setRowHeight(5, 22);
}

void _appendOrderDetailHeader(
  xls.Sheet sheet,
  SugeridoOrdenModel doc,
  List<SugeridoDetalleModel> items,
) {
  final totalQty = items.fold<double>(0, (sum, item) => sum + item.ctdped);
  final totalAmount = items.fold<double>(0, (sum, item) => sum + item.ctot);
  _writeExcelCell(sheet, 0, 0, 'ORDEN DE COMPRA', style: _excelTitleStyle());
  _writeExcelCell(sheet, 1, 0, 'Documento', style: _excelLabelStyle());
  _writeExcelCell(sheet, 1, 1, doc.nped, style: _excelValueStyle());
  _writeExcelCell(sheet, 1, 2, 'Proveedor', style: _excelLabelStyle());
  _writeExcelCell(
    sheet,
    1,
    3,
    '${doc.nprov} - ${_providerName(doc)}',
    style: _excelValueStyle(),
  );
  _writeExcelCell(sheet, 2, 0, 'Sucursal', style: _excelLabelStyle());
  _writeExcelCell(sheet, 2, 1, doc.suc, style: _excelValueStyle());
  _writeExcelCell(sheet, 2, 2, 'Cantidad', style: _excelLabelStyle());
  _writeExcelCell(sheet, 2, 3, totalQty, style: _excelNumberStyle());
  _writeExcelCell(sheet, 2, 4, 'Importe', style: _excelLabelStyle());
  _writeExcelCell(sheet, 2, 5, totalAmount, style: _excelMoneyStyle());
}

void _appendLensMaterialSummary(
  xls.Sheet sheet,
  List<_LensExportRow> rows, {
  int startRow = 0,
}) {
  final grouped = <String, List<_LensExportRow>>{};
  for (final row in rows) {
    grouped.putIfAbsent(row.material, () => <_LensExportRow>[]).add(row);
  }
  final materials = grouped.keys.toList()..sort();
  _writeExcelCell(sheet, startRow, 22, 'DESC', style: _excelBlueHeaderStyle());
  _writeExcelCell(sheet, startRow, 23, 'PARES', style: _excelBlueHeaderStyle());
  _writeExcelCell(sheet, startRow, 24, 'COSTO', style: _excelBlueHeaderStyle());
  for (var i = 0; i < materials.length; i++) {
    final materialRows = grouped[materials[i]]!;
    final totalPairs = _sumLensRows(materialRows);
    final totalCost = materialRows.fold<double>(
      0,
      (sum, row) => sum + row.costoTotal,
    );
    final rowIndex = startRow + 1 + i;
    _writeExcelCell(
      sheet,
      rowIndex,
      22,
      materials[i],
      style: _excelAltGridStyle(),
    );
    _writeExcelCell(sheet, rowIndex, 23, totalPairs, style: _excelCountStyle());
    _writeExcelCell(sheet, rowIndex, 24, totalCost, style: _excelMoneyStyle());
  }
}

int _appendMonofocalGrid(
  xls.Sheet sheet,
  int startRow,
  List<_LensExportRow> rows,
) {
  final sphereValues = _sphereRows(0, 8.25);
  _writeExcelCell(sheet, startRow, 3, 'CYL', style: _excelTopHeaderStyle());
  _writeExcelCell(sheet, startRow, 15, 'CYL', style: _excelTopHeaderStyle());

  final headerRow = startRow + 1;
  for (var i = 0; i < _monoCylLeftColumns.length; i++) {
    _writeExcelCell(
      sheet,
      headerRow,
      1 + i,
      _monoCylLeftColumns[i],
      style: _excelOrangeHeaderStyle(),
    );
  }
  _writeExcelCell(
    sheet,
    headerRow,
    10,
    'ESFERA',
    style: _excelBlueHeaderStyle(),
  );
  _writeExcelCell(
    sheet,
    headerRow,
    11,
    'ESFERA',
    style: _excelBlueHeaderStyle(),
  );
  for (var i = 0; i < _monoCylRightColumns.length; i++) {
    _writeExcelCell(
      sheet,
      headerRow,
      12 + i,
      _monoCylRightColumns[i],
      style: _excelOrangeHeaderStyle(),
    );
  }

  for (var i = 0; i < sphereValues.length; i++) {
    final rowIndex = headerRow + 1 + i;
    final negativeSphere = -sphereValues[i];
    final positiveSphere = sphereValues[i];
    _writeExcelCell(
      sheet,
      rowIndex,
      10,
      negativeSphere,
      style: _excelBlueHeaderStyle(),
    );
    _writeExcelCell(
      sheet,
      rowIndex,
      11,
      positiveSphere,
      style: _excelBlueHeaderStyle(),
    );

    for (var c = 0; c < _monoCylLeftColumns.length; c++) {
      final total = _sumLensRows(
        rows.where(
          (row) =>
              row.sph != null &&
              _sameLensStep(row.sph!, negativeSphere) &&
              _sameLensStep(row.cyl ?? 0, _monoCylLeftColumns[c]),
        ),
      );
      _writeMatrixCell(sheet, rowIndex, 1 + c, total);
    }
    for (var c = 0; c < _monoCylRightColumns.length; c++) {
      final total = _sumLensRows(
        rows.where(
          (row) =>
              row.sph != null &&
              _sameLensStep(row.sph!, positiveSphere) &&
              _sameLensStep(row.cyl ?? 0, _monoCylRightColumns[c]),
        ),
      );
      _writeMatrixCell(sheet, rowIndex, 12 + c, total);
    }
  }
  return headerRow + sphereValues.length + 1;
}

int _appendSimpleLensGrid(
  xls.Sheet sheet,
  int startRow,
  List<_LensExportRow> rows, {
  required String label,
  required List<double> rowValues,
  required List<double> colValues,
  required double Function(_LensExportRow row) rowSelector,
  required double Function(_LensExportRow row) colSelector,
}) {
  _writeExcelCell(sheet, startRow, 1, label, style: _excelBlueHeaderStyle());
  for (var c = 0; c < colValues.length; c++) {
    _writeExcelCell(
      sheet,
      startRow,
      2 + c,
      colValues[c],
      style: _excelOrangeHeaderStyle(),
    );
  }
  for (var r = 0; r < rowValues.length; r++) {
    final rowIndex = startRow + 1 + r;
    _writeExcelCell(
      sheet,
      rowIndex,
      1,
      rowValues[r],
      style: _excelBlueHeaderStyle(),
    );
    for (var c = 0; c < colValues.length; c++) {
      final total = _sumLensRows(
        rows.where(
          (row) =>
              _sameLensStep(rowSelector(row), rowValues[r]) &&
              _sameLensStep(colSelector(row), colValues[c]),
        ),
      );
      _writeMatrixCell(sheet, rowIndex, 2 + c, total);
    }
  }
  return startRow + rowValues.length + 1;
}

List<double> _sphereRows(double start, double end) {
  final values = <double>[];
  var current = start;
  while (current <= end + 0.001) {
    values.add(double.parse(current.toStringAsFixed(2)));
    current += 0.25;
  }
  return values;
}

void _writeMatrixCell(xls.Sheet sheet, int row, int col, double total) {
  _writeExcelCell(
    sheet,
    row,
    col,
    total > 0 ? total : '',
    style: total > 0 ? _excelCountStyle() : _excelGridStyle(),
  );
}

void _writeExcelCell(
  xls.Sheet sheet,
  int row,
  int col,
  dynamic value, {
  xls.CellStyle? style,
}) {
  sheet.updateCell(
    xls.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
    _excelValue(value),
    cellStyle: style,
  );
}

void _mergeExcelCells(
  xls.Sheet sheet,
  int startRow,
  int startCol,
  int endRow,
  int endCol,
  dynamic value, {
  xls.CellStyle? style,
}) {
  final start = xls.CellIndex.indexByColumnRow(
    columnIndex: startCol,
    rowIndex: startRow,
  );
  final end = xls.CellIndex.indexByColumnRow(
    columnIndex: endCol,
    rowIndex: endRow,
  );
  sheet.merge(start, end);
  _writeExcelCell(sheet, startRow, startCol, value, style: style);
  if (style != null) {
    sheet.setMergedCellStyle(start, style);
  }
}

double _sumLensRows(Iterable<_LensExportRow> rows) {
  return rows.fold<double>(0, (sum, row) => sum + row.cantidad);
}

bool _sameLensStep(double a, double b) => (a - b).abs() < 0.001;

xls.CellStyle _excelTitleStyle() => xls.CellStyle(
  bold: true,
  fontSize: 14,
  fontColorHex: xls.ExcelColor.white,
  horizontalAlign: xls.HorizontalAlign.Left,
  verticalAlign: xls.VerticalAlign.Center,
  backgroundColorHex: xls.ExcelColor.fromHexString('FF0B3D78'),
);

xls.CellStyle _excelLabelStyle() => xls.CellStyle(
  bold: true,
  fontColorHex: xls.ExcelColor.fromHexString('FF0B3D78'),
  horizontalAlign: xls.HorizontalAlign.Center,
  verticalAlign: xls.VerticalAlign.Center,
  backgroundColorHex: xls.ExcelColor.fromHexString('FFEAF4FF'),
  topBorder: _excelSoftBorder(),
  bottomBorder: _excelSoftBorder(),
  leftBorder: _excelSoftBorder(),
  rightBorder: _excelSoftBorder(),
);

xls.CellStyle _excelValueStyle() => xls.CellStyle(
  horizontalAlign: xls.HorizontalAlign.Center,
  verticalAlign: xls.VerticalAlign.Center,
  textWrapping: xls.TextWrapping.WrapText,
  backgroundColorHex: xls.ExcelColor.fromHexString('FFFFFFFF'),
  topBorder: _excelSoftBorder(),
  bottomBorder: _excelSoftBorder(),
  leftBorder: _excelSoftBorder(),
  rightBorder: _excelSoftBorder(),
);

xls.CellStyle _excelTopHeaderStyle() => xls.CellStyle(
  bold: true,
  fontColorHex: xls.ExcelColor.white,
  horizontalAlign: xls.HorizontalAlign.Center,
  verticalAlign: xls.VerticalAlign.Center,
  backgroundColorHex: xls.ExcelColor.fromHexString('FF1498C8'),
  topBorder: _excelThinBorder(),
  bottomBorder: _excelThinBorder(),
  leftBorder: _excelThinBorder(),
  rightBorder: _excelThinBorder(),
);

xls.CellStyle _excelOrangeHeaderStyle() => xls.CellStyle(
  bold: true,
  fontSize: 9,
  fontColorHex: xls.ExcelColor.fromHexString('FF111827'),
  horizontalAlign: xls.HorizontalAlign.Center,
  verticalAlign: xls.VerticalAlign.Center,
  backgroundColorHex: xls.ExcelColor.fromHexString('FFFFC857'),
  topBorder: _excelThinBorder(),
  bottomBorder: _excelThinBorder(),
  leftBorder: _excelThinBorder(),
  rightBorder: _excelThinBorder(),
);

xls.CellStyle _excelBlueHeaderStyle() => xls.CellStyle(
  bold: true,
  fontSize: 9,
  fontColorHex: xls.ExcelColor.white,
  horizontalAlign: xls.HorizontalAlign.Center,
  verticalAlign: xls.VerticalAlign.Center,
  textWrapping: xls.TextWrapping.WrapText,
  backgroundColorHex: xls.ExcelColor.fromHexString('FF0B3D78'),
  topBorder: _excelThinBorder(),
  bottomBorder: _excelThinBorder(),
  leftBorder: _excelThinBorder(),
  rightBorder: _excelThinBorder(),
);

xls.CellStyle _excelGridStyle() => xls.CellStyle(
  horizontalAlign: xls.HorizontalAlign.Center,
  verticalAlign: xls.VerticalAlign.Center,
  textWrapping: xls.TextWrapping.WrapText,
  backgroundColorHex: xls.ExcelColor.fromHexString('FFFFFFFF'),
  topBorder: _excelSoftBorder(),
  bottomBorder: _excelSoftBorder(),
  leftBorder: _excelSoftBorder(),
  rightBorder: _excelSoftBorder(),
);

xls.CellStyle _excelAltGridStyle() => xls.CellStyle(
  horizontalAlign: xls.HorizontalAlign.Center,
  verticalAlign: xls.VerticalAlign.Center,
  textWrapping: xls.TextWrapping.WrapText,
  backgroundColorHex: xls.ExcelColor.fromHexString('FFF3F8FC'),
  topBorder: _excelSoftBorder(),
  bottomBorder: _excelSoftBorder(),
  leftBorder: _excelSoftBorder(),
  rightBorder: _excelSoftBorder(),
);

xls.CellStyle _excelCountStyle() => xls.CellStyle(
  bold: true,
  horizontalAlign: xls.HorizontalAlign.Center,
  verticalAlign: xls.VerticalAlign.Center,
  backgroundColorHex: xls.ExcelColor.fromHexString('FFDFF3FB'),
  topBorder: _excelSoftBorder(),
  bottomBorder: _excelSoftBorder(),
  leftBorder: _excelSoftBorder(),
  rightBorder: _excelSoftBorder(),
);

xls.CellStyle _excelNumberStyle() => xls.CellStyle(
  horizontalAlign: xls.HorizontalAlign.Center,
  verticalAlign: xls.VerticalAlign.Center,
  numberFormat: xls.NumFormat.custom(formatCode: '#,##0.##'),
  topBorder: _excelSoftBorder(),
  bottomBorder: _excelSoftBorder(),
  leftBorder: _excelSoftBorder(),
  rightBorder: _excelSoftBorder(),
);

xls.CellStyle _excelMoneyStyle() => xls.CellStyle(
  horizontalAlign: xls.HorizontalAlign.Right,
  verticalAlign: xls.VerticalAlign.Center,
  numberFormat: xls.NumFormat.custom(formatCode: r'"$"#,##0.00'),
  backgroundColorHex: xls.ExcelColor.fromHexString('FFFFFFFF'),
  topBorder: _excelSoftBorder(),
  bottomBorder: _excelSoftBorder(),
  leftBorder: _excelSoftBorder(),
  rightBorder: _excelSoftBorder(),
);

xls.Border _excelThinBorder() => xls.Border(
  borderColorHex: xls.ExcelColor.black,
  borderStyle: xls.BorderStyle.Thin,
);

xls.Border _excelSoftBorder() => xls.Border(
  borderColorHex: xls.ExcelColor.fromHexString('FFB8C7D9'),
  borderStyle: xls.BorderStyle.Thin,
);

List<_LensExportRow> _buildLensExportRows(List<SugeridoDetalleModel> items) {
  final rows = <_LensExportRow>[];
  for (final item in items) {
    final desc = (item.des ?? '').trim();
    final kind = _classifyLens(desc);
    if (kind == null) continue;
    final sph = _extractLensNumber(desc, 'SPH');
    final cyl = _extractLensNumber(desc, 'CYL') ?? 0;
    final add =
        _extractLensNumber(desc, 'ADD') ?? _extractLensNumber(desc, 'ADIC');
    final base = _extractLensNumber(desc, 'BASE') ?? 0;
    final material = _lensMaterial(desc, kind);
    final double primary = switch (kind) {
      'MONOFOCAL' => sph ?? 0.0,
      'BIFOCAL' => sph ?? 0.0,
      'BASES' => base,
      _ => 0.0,
    };
    final double secondary = switch (kind) {
      'MONOFOCAL' => cyl,
      'BIFOCAL' => add ?? 0.0,
      'BASES' => add ?? 0.0,
      _ => 0.0,
    };
    final dimensionText = switch (kind) {
      'MONOFOCAL' => 'SPH ${_num(primary)} / CYL ${_num(secondary)}',
      'BIFOCAL' => 'SPH ${_num(primary)} / ADD ${_num(secondary)}',
      'BASES' => 'BASE ${_num(primary)} / ADD ${_num(secondary)}',
      _ => '',
    };
    rows.add(
      _LensExportRow(
        sheetName: kind,
        material: material,
        art: item.art,
        descripcion: desc,
        primary: primary,
        secondary: secondary,
        dimensionText: dimensionText,
        sph: sph,
        cyl: cyl,
        add: add,
        base: base,
        cantidad: item.ctdped,
        costoTotal: item.ctot,
        uncom: item.uncom,
      ),
    );
  }
  return rows;
}

String? _classifyLens(String description) {
  final text = description.toUpperCase();
  if (text.isEmpty) return null;
  if (RegExp(r'\bBASE\b').hasMatch(text)) return 'BASES';
  if (text.contains('BIFOC') || text.contains('BLENDED')) return 'BIFOCAL';
  if (RegExp(r'\bADD\b').hasMatch(text) && !RegExp(r'\bCYL\b').hasMatch(text)) {
    return 'BIFOCAL';
  }
  if (RegExp(r'\bSPH\b|\bCYL\b').hasMatch(text)) return 'MONOFOCAL';
  return null;
}

double? _extractLensNumber(String description, String label) {
  final match = RegExp(
    '\\b$label\\s*([+-]?\\d+(?:[\\.,]\\d+)?)',
    caseSensitive: false,
  ).firstMatch(description);
  if (match == null) return null;
  return double.tryParse(match.group(1)!.replaceAll(',', '.'));
}

String _lensMaterial(String description, String kind) {
  var material = description.toUpperCase();
  material = material.replaceAll(
    RegExp(
      r'\b(SPH|CYL|ADD|ADIC|BASE)\s*[+-]?\d+(?:[\.,]\d+)?',
      caseSensitive: false,
    ),
    '',
  );
  material = material.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (material.isEmpty) return kind;
  return material;
}

class _LensExportRow {
  const _LensExportRow({
    required this.sheetName,
    required this.material,
    required this.art,
    required this.descripcion,
    required this.primary,
    required this.secondary,
    required this.dimensionText,
    required this.sph,
    required this.cyl,
    required this.add,
    required this.base,
    required this.cantidad,
    required this.costoTotal,
    required this.uncom,
  });

  final String sheetName;
  final String material;
  final String art;
  final String descripcion;
  final double primary;
  final double secondary;
  final String dimensionText;
  final double? sph;
  final double? cyl;
  final double? add;
  final double base;
  final double cantidad;
  final double costoTotal;
  final String uncom;
}

class _AddOrdenArticuloDialog extends ConsumerStatefulWidget {
  const _AddOrdenArticuloDialog({required this.doc, this.onChanged});

  final SugeridoOrdenModel doc;
  final ValueChanged<SugeridoOrdenModel>? onChanged;

  @override
  ConsumerState<_AddOrdenArticuloDialog> createState() =>
      _AddOrdenArticuloDialogState();
}

class _AddOrdenArticuloDialogState
    extends ConsumerState<_AddOrdenArticuloDialog> {
  final _searchCtrl = TextEditingController();
  final _depaCtrl = TextEditingController();
  final _subdCtrl = TextEditingController();
  final _clasCtrl = TextEditingController();
  final _sclaCtrl = TextEditingController();
  final _scla2Ctrl = TextEditingController();
  final _sphCtrl = TextEditingController();
  final _cylCtrl = TextEditingController();
  final _adicCtrl = TextEditingController();
  List<SugeridoArticuloProveedorModel> _items = const [];
  SugeridoOrdenModel? _updatedDoc;
  String _searchBy = 'ART';
  bool _loading = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _depaCtrl.dispose();
    _subdCtrl.dispose();
    _clasCtrl.dispose();
    _sclaCtrl.dispose();
    _scla2Ctrl.dispose();
    _sphCtrl.dispose();
    _cylCtrl.dispose();
    _adicCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Agregar articulo'),
      insetPadding: const EdgeInsets.all(16),
      content: SizedBox(
        width: 720,
        height: 560,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _filters(),
            const SizedBox(height: 12),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: _items.isEmpty && !_loading
                  ? const Center(
                      child: Text('Capture filtros y presione Buscar.'),
                    )
                  : ListView.separated(
                      itemCount: _items.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return ListTile(
                          dense: true,
                          title: Text('${item.art} | ${item.des}'),
                          subtitle: Text('Costo ${_money(item.cto)}'),
                          trailing: IconButton.outlined(
                            tooltip: 'Agregar',
                            icon: const Icon(Icons.add),
                            onPressed: item.cto <= 0
                                ? null
                                : () => _askQuantityAndAdd(item),
                          ),
                          onTap: item.cto <= 0
                              ? null
                              : () => _askQuantityAndAdd(item),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, _updatedDoc),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }

  Widget _filters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Filtros de busqueda'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 150,
              child: DropdownButtonFormField<String>(
                initialValue: widget.doc.suc,
                decoration: const InputDecoration(
                  labelText: 'SUC',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  DropdownMenuItem(
                    value: widget.doc.suc,
                    child: Text(widget.doc.suc),
                  ),
                ],
                onChanged: null,
              ),
            ),
            SizedBox(
              width: 150,
              child: DropdownButtonFormField<String>(
                initialValue: _searchBy,
                decoration: const InputDecoration(
                  labelText: 'Buscar por',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: 'ART', child: Text('ART')),
                  DropdownMenuItem(value: 'UPC', child: Text('UPC')),
                  DropdownMenuItem(value: 'DES', child: Text('DES')),
                  DropdownMenuItem(value: 'TODO', child: Text('Todos')),
                ],
                onChanged: (value) =>
                    setState(() => _searchBy = value ?? 'ART'),
              ),
            ),
            SizedBox(
              width: 270,
              child: TextField(
                controller: _searchCtrl,
                decoration: const InputDecoration(
                  labelText: 'Buscar',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: (_) => _search(),
              ),
            ),
            _filterField(_depaCtrl, 'DEPA'),
            _filterField(_subdCtrl, 'SUBD'),
            _filterField(_clasCtrl, 'CLAS'),
            _filterField(_sclaCtrl, 'SCLA'),
            _filterField(_scla2Ctrl, 'SCLA2'),
            _filterField(_sphCtrl, 'SPH'),
            _filterField(_cylCtrl, 'CYL'),
            _filterField(_adicCtrl, 'ADIC'),
            FilledButton.icon(
              onPressed: _loading ? null : _search,
              icon: const Icon(Icons.search),
              label: const Text('Buscar'),
            ),
            OutlinedButton.icon(
              onPressed: _loading ? null : _clearFilters,
              icon: const Icon(Icons.refresh),
              label: const Text('Limpiar'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _filterField(TextEditingController controller, String label) {
    return SizedBox(
      width: 118,
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        onSubmitted: (_) => _search(),
      ),
    );
  }

  Future<void> _search() async {
    setState(() => _loading = true);
    try {
      final items = await ref
          .read(sugeridosApiProvider)
          .articulosProveedor(
            suc: widget.doc.suc,
            prov: widget.doc.nprov,
            search: _searchCtrl.text,
            searchBy: _searchBy,
            depa: _depaCtrl.text,
            subd: _subdCtrl.text,
            clas: _clasCtrl.text,
            scla: _sclaCtrl.text,
            scla2: _scla2Ctrl.text,
            sph: _sphCtrl.text,
            cyl: _cylCtrl.text,
            adic: _adicCtrl.text,
            limit: 50,
          );
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo buscar: $e')));
    }
  }

  void _clearFilters() {
    setState(() {
      _searchCtrl.clear();
      _depaCtrl.clear();
      _subdCtrl.clear();
      _clasCtrl.clear();
      _sclaCtrl.clear();
      _scla2Ctrl.clear();
      _sphCtrl.clear();
      _cylCtrl.clear();
      _adicCtrl.clear();
      _searchBy = 'ART';
      _items = const [];
    });
  }

  Future<void> _askQuantityAndAdd(SugeridoArticuloProveedorModel item) async {
    final ctrl = TextEditingController(text: '1');
    final qty = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cantidad ${item.art}'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Cantidad',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => Navigator.pop(
            context,
            double.tryParse(ctrl.text.replaceAll(',', '.')),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              double.tryParse(ctrl.text.replaceAll(',', '.')),
            ),
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (qty == null || qty <= 0) return;
    try {
      final updated = await ref
          .read(sugeridosApiProvider)
          .addDetalle(
            nped: widget.doc.nped,
            art: item.art,
            ctdped: qty,
            cto: item.cto,
            uncom: item.unComp,
          );
      if (!mounted) return;
      setState(() => _updatedDoc = updated);
      widget.onChanged?.call(updated);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Articulo ${item.art} agregado.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo agregar: $e')));
    }
  }
}

class _ImportOrdenArticuloRow {
  const _ImportOrdenArticuloRow({
    required this.art,
    required this.descripcion,
    required this.cantidad,
  });

  final String art;
  final String descripcion;
  final double cantidad;
}

Future<Uint8List> _readPickedFileBytes(PlatformFile file) async {
  final stream = file.readStream;
  if (stream != null) {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  }
  final bytes = file.bytes;
  if (bytes != null) return bytes;
  throw const FormatException('No fue posible leer el archivo seleccionado.');
}

List<_ImportOrdenArticuloRow> _parseOrdenArticuloFile(
  String name,
  Uint8List bytes,
) {
  final rows = name.toLowerCase().endsWith('.csv')
      ? _parseCsvRows(bytes)
      : _parseExcelRows(bytes);
  if (rows.isEmpty) return const [];
  return _rowsToOrdenArticulos(rows);
}

List<List<String>> _parseExcelRows(Uint8List bytes) {
  final book = xls.Excel.decodeBytes(bytes);
  if (book.tables.isEmpty) return const [];
  final sheet = book.tables.values.first;
  return sheet.rows
      .map((row) => row.map(_excelCellText).toList(growable: false))
      .where((row) => row.any((cell) => cell.isNotEmpty))
      .toList(growable: false);
}

String _excelCellText(xls.Data? cell) {
  final value = cell?.value;
  if (value == null) return '';
  if (value is xls.TextCellValue) return value.value.toString().trim();
  if (value is xls.IntCellValue) return value.value.toString();
  if (value is xls.DoubleCellValue) return value.value.toString();
  if (value is xls.BoolCellValue) return value.value ? 'true' : 'false';
  return value.toString().trim();
}

List<List<String>> _parseCsvRows(Uint8List bytes) {
  final content = utf8.decode(bytes, allowMalformed: true);
  final delimiter = content.contains(';')
      ? ';'
      : content.contains('\t')
      ? '\t'
      : ',';
  return const LineSplitter()
      .convert(content)
      .where((line) => line.trim().isNotEmpty)
      .map((line) => line.split(delimiter).map(_cleanCell).toList())
      .toList(growable: false);
}

String _cleanCell(String value) =>
    value.trim().replaceAll(RegExp(r'^"|"$'), '');

List<_ImportOrdenArticuloRow> _rowsToOrdenArticulos(List<List<String>> rows) {
  final headerIndex = rows.indexWhere((row) {
    final headers = row.map(_normalizeImportHeader).toList();
    return _findImportColumn(headers, const ['art', 'articulo']) >= 0 &&
        _findImportColumn(headers, const ['ctda', 'cantidad', 'ctdped']) >= 0;
  });
  if (headerIndex < 0) {
    throw const FormatException('No se encontraron encabezados ART y CTDA.');
  }
  final headers = rows[headerIndex].map(_normalizeImportHeader).toList();
  final artIndex = _findImportColumn(headers, const ['art', 'articulo']);
  final descIndex = _findImportColumn(headers, const [
    'desc',
    'descripcion',
    'descripcionarticulo',
  ]);
  final cantidadIndex = _findImportColumn(headers, const [
    'ctda',
    'cantidad',
    'ctdped',
  ]);
  final parsed = <_ImportOrdenArticuloRow>[];
  for (final row in rows.skip(headerIndex + 1)) {
    final art = _rowValue(row, artIndex).trim().toUpperCase();
    final cantidad = _parseImportNumber(_rowValue(row, cantidadIndex));
    if (art.isEmpty || cantidad == null || cantidad <= 0) continue;
    parsed.add(
      _ImportOrdenArticuloRow(
        art: art,
        descripcion: descIndex >= 0 ? _rowValue(row, descIndex).trim() : '',
        cantidad: cantidad,
      ),
    );
  }
  return parsed;
}

String _normalizeImportHeader(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[\s_\-.]'), '')
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u');
}

int _findImportColumn(List<String> headers, List<String> aliases) {
  for (var i = 0; i < headers.length; i++) {
    if (aliases.contains(headers[i])) return i;
  }
  return -1;
}

String _rowValue(List<String> row, int index) {
  if (index < 0 || index >= row.length) return '';
  return row[index];
}

double? _parseImportNumber(String raw) {
  final text = raw.trim().replaceAll(',', '.');
  if (text.isEmpty) return null;
  return double.tryParse(text);
}

String _num(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(2);
}

String _money(double value) => '\$${value.toStringAsFixed(2)}';

xls.CellValue _excelValue(dynamic value) {
  if (value == null) return xls.TextCellValue('');
  if (value is xls.CellValue) return value;
  if (value is int) return xls.IntCellValue(value);
  if (value is double) return xls.DoubleCellValue(value);
  if (value is num) return xls.DoubleCellValue(value.toDouble());
  if (value is bool) return xls.BoolCellValue(value);
  return xls.TextCellValue(value.toString());
}
