import 'dart:typed_data';

import 'package:excel/excel.dart' as xls;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ioe_app/core/api_error.dart';
import 'package:ioe_app/core/excel_exporter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ctrl_ctas_models.dart';
import 'ctrl_ctas_providers.dart';

enum _SortDir { asc, desc }

enum _DetalleSortField { total, fecha }

class CtrlCtasResumenClientePage extends ConsumerStatefulWidget {
  const CtrlCtasResumenClientePage({super.key, required this.filtros});

  final CtrlCtasFiltros filtros;

  @override
  ConsumerState<CtrlCtasResumenClientePage> createState() => _CtrlCtasResumenClientePageState();
}

class _CtrlCtasResumenClientePageState extends ConsumerState<CtrlCtasResumenClientePage> {
  static const String _kPrefLeftPanelWidth = 'ctrl_ctas_resumen_left_panel_width';
  static const String _kPrefRightPanelWidth = 'ctrl_ctas_resumen_right_panel_width';
  static const double _defaultLeftPanelWidth = 520.0;
  static const double _defaultRightPanelWidth = 940.0;
  static const double _minLeftPanelWidth = 320.0;
  static const double _minRightPanelWidth = 560.0;
  static const double _resizeHandleWidth = 18.0;
  static const double _razonSocialWidth = 160.0;

  String? _selectedClient;
  String? _selectedIdfol;
  double _leftPanelWidth = _defaultLeftPanelWidth;
  double _rightPanelWidth = _defaultRightPanelWidth;
  bool _panelWidthsLoaded = false;
  bool _hasStoredLeftWidth = false;
  bool _hasStoredRightWidth = false;
  bool _didAutoFitPanelWidths = false;
  _SortDir _clienteTotalSort = _SortDir.desc;
  bool _clienteOnlyNonZero = false;
  _SortDir _transTotalSort = _SortDir.desc;
  bool _transOnlyNonZero = false;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    if (widget.filtros.clients.length == 1) {
      _selectedClient = widget.filtros.clients.first;
    }
    if (widget.filtros.idfols.length == 1) {
      _selectedIdfol = widget.filtros.idfols.first;
    }
    _loadPanelWidths();
  }

  Future<void> _loadPanelWidths() async {
    final sp = await SharedPreferences.getInstance();
    final leftStored = sp.getDouble(_kPrefLeftPanelWidth);
    final rightStored = sp.getDouble(_kPrefRightPanelWidth);
    if (!mounted) return;
    setState(() {
      _panelWidthsLoaded = true;
      _hasStoredLeftWidth = leftStored != null;
      _hasStoredRightWidth = rightStored != null;
      if (leftStored != null) {
        _leftPanelWidth = leftStored.clamp(_minLeftPanelWidth, 1400.0).toDouble();
      }
      if (rightStored != null) {
        _rightPanelWidth = rightStored.clamp(_minRightPanelWidth, 3200.0).toDouble();
      }
    });
  }

  Future<void> _saveLeftPanelWidth(double value) async {
    _hasStoredLeftWidth = true;
    final sp = await SharedPreferences.getInstance();
    await sp.setDouble(_kPrefLeftPanelWidth, value);
  }

  Future<void> _saveRightPanelWidth(double value) async {
    _hasStoredRightWidth = true;
    final sp = await SharedPreferences.getInstance();
    await sp.setDouble(_kPrefRightPanelWidth, value);
  }

  Future<void> _resetPanelWidths() async {
    setState(() {
      _leftPanelWidth = _defaultLeftPanelWidth;
      _rightPanelWidth = _defaultRightPanelWidth;
    });
    await Future.wait([
      _saveLeftPanelWidth(_leftPanelWidth),
      _saveRightPanelWidth(_rightPanelWidth),
    ]);
  }

  int _compareAbs(double a, double b, _SortDir direction) {
    final byAbs = a.abs().compareTo(b.abs());
    if (byAbs != 0) return direction == _SortDir.asc ? byAbs : -byAbs;
    final tieBreak = a.compareTo(b);
    return direction == _SortDir.asc ? tieBreak : -tieBreak;
  }

  int _compareDate(DateTime? a, DateTime? b, _SortDir direction) {
    int cmp;
    if (a == null && b == null) {
      cmp = 0;
    } else if (a == null) {
      cmp = 1;
    } else if (b == null) {
      cmp = -1;
    } else {
      cmp = a.compareTo(b);
    }
    return direction == _SortDir.asc ? cmp : -cmp;
  }

  List<CtrlCtasResumenClienteItem> _applyResumenClienteView(List<CtrlCtasResumenClienteItem> items) {
    final filtered = _clienteOnlyNonZero ? items.where((row) => row.total.abs() > 0.0000001).toList() : [...items];
    filtered.sort((a, b) => _compareAbs(a.total, b.total, _clienteTotalSort));
    return filtered;
  }

  List<CtrlCtasResumenTransItem> _applyResumenTransView(List<CtrlCtasResumenTransItem> items) {
    final filtered = _transOnlyNonZero ? items.where((row) => row.total.abs() > 0.0000001).toList() : [...items];
    filtered.sort((a, b) => _compareAbs(a.total, b.total, _transTotalSort));
    return filtered;
  }

  List<CtrlCtasDetalleItem> _applyDetalleView(
    List<CtrlCtasDetalleItem> items, {
    required bool onlyNonZero,
    required _DetalleSortField sortField,
    required _SortDir sortDirection,
  }) {
    final filtered = onlyNonZero ? items.where((row) => row.impt.abs() > 0.0000001).toList() : [...items];
    filtered.sort((a, b) {
      if (sortField == _DetalleSortField.fecha) {
        final byDate = _compareDate(a.fcnd, b.fcnd, sortDirection);
        if (byDate != 0) return byDate;
      }
      return _compareAbs(a.impt, b.impt, sortDirection);
    });
    return filtered;
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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

  String _buildExportFilename() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    return 'CTRL_CTAS_$y$m$d-$hh$mm.xlsx';
  }

  Uint8List? _buildExcelBytes({
    required List<CtrlCtasResumenClienteItem> resumenCliente,
    required List<CtrlCtasResumenTransItem> resumenTrans,
    required List<CtrlCtasDetalleItem> detalle,
  }) {
    final excel = xls.Excel.createExcel();

    final sheetCliente = excel['RESUMEN_CLIENTE'];
    sheetCliente.appendRow([
      _excelValue('CLIENT'),
      _excelValue('Razon social'),
      _excelValue('TOTAL'),
    ]);
    for (final row in resumenCliente) {
      sheetCliente.appendRow([
        _excelValue(row.client),
        _excelValue(row.razonSocial ?? ''),
        _excelValue(row.total),
      ]);
    }

    final sheetTrans = excel['RESUMEN_TRANS'];
    sheetTrans.appendRow([
      _excelValue('CLIENT'),
      _excelValue('Razon social'),
      _excelValue('CTA'),
      _excelValue('IDFOL'),
      _excelValue('TOTAL'),
    ]);
    for (final row in resumenTrans) {
      sheetTrans.appendRow([
        _excelValue(row.client),
        _excelValue(row.razonSocial ?? ''),
        _excelValue(row.cta ?? ''),
        _excelValue(row.idfol ?? ''),
        _excelValue(row.total),
      ]);
    }

    final sheetDetalle = excel['DETALLE'];
    sheetDetalle.appendRow([
      _excelValue('FCND'),
      _excelValue('NDOC'),
      _excelValue('SUC'),
      _excelValue('CLIENT'),
      _excelValue('Razon social'),
      _excelValue('CTA'),
      _excelValue('CLSD'),
      _excelValue('IDFOL'),
      _excelValue('RTXT'),
      _excelValue('IMPT'),
      _excelValue('IDOPV'),
    ]);
    for (final row in detalle) {
      sheetDetalle.appendRow([
        _excelValue(_fmtDate(row.fcnd)),
        _excelValue(row.ndoc ?? ''),
        _excelValue(row.suc ?? ''),
        _excelValue(row.client ?? ''),
        _excelValue(row.razonSocial ?? ''),
        _excelValue(row.cta ?? ''),
        _excelValue(row.clsd ?? ''),
        _excelValue(row.idfol ?? ''),
        _excelValue(row.rtxt ?? ''),
        _excelValue(row.impt),
        _excelValue(row.idopv ?? ''),
      ]);
    }

    if (excel.tables.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }
    excel.setDefaultSheet('RESUMEN_CLIENTE');
    final bytes = excel.encode();
    if (bytes == null || bytes.isEmpty) return null;
    return Uint8List.fromList(bytes);
  }

  Future<void> _exportToExcel() async {
    if (_exporting) return;
    setState(() {
      _exporting = true;
    });

    try {
      final selectedClient = (_selectedClient ?? '').trim();
      if (selectedClient.isEmpty) {
        _showSnack('Selecciona un cliente para exportar.');
        return;
      }

      final resumenClienteRaw = await ref.read(ctrlCtasResumenClienteProvider(widget.filtros).future);
      final resumenCliente = resumenClienteRaw
          .where((row) => row.client.trim() == selectedClient)
          .toList()
        ..sort((a, b) => _compareAbs(a.total, b.total, _clienteTotalSort));

      List<CtrlCtasResumenTransItem> resumenTrans = const [];
      final filtrosTrans = widget.filtros.copyWith(clients: [selectedClient], idfols: const []);
      final resumenTransRaw = await ref.read(ctrlCtasResumenTransProvider(filtrosTrans).future);
      resumenTrans = _applyResumenTransView(resumenTransRaw);

      List<CtrlCtasDetalleItem> detalle = const [];
      final idfols = resumenTransRaw
          .map((row) => _clean(row.idfol))
          .where((idfol) => idfol.isNotEmpty)
          .toSet()
          .toList();

      if (idfols.isNotEmpty) {
        final detailCalls = idfols.map((idfol) {
          final filtrosDet = widget.filtros.copyWith(clients: [selectedClient], idfols: [idfol]);
          return ref.read(ctrlCtasDetalleProvider(filtrosDet).future);
        }).toList();

        final detalleLists = await Future.wait(detailCalls);
        final detalleRaw = detalleLists.expand((rows) => rows).toList();
        detalle = _applyDetalleView(
          detalleRaw,
          onlyNonZero: false,
          sortField: _DetalleSortField.total,
          sortDirection: _SortDir.desc,
        );
      }

      if (resumenCliente.isEmpty && resumenTrans.isEmpty && detalle.isEmpty) {
        _showSnack('Sin resultados para exportar.');
        return;
      }

      final bytes = _buildExcelBytes(
        resumenCliente: resumenCliente,
        resumenTrans: resumenTrans,
        detalle: detalle,
      );
      if (bytes == null) {
        _showSnack('No se pudo generar el archivo Excel.');
        return;
      }

      final filename = _buildExportFilename();
      final saved = await getExcelExporter().save(bytes, filename);
      if (!mounted) return;
      if (!saved) {
        _showSnack('Exportacion cancelada.');
      } else {
        _showSnack('Exportacion lista: $filename');
      }
    } catch (e) {
      _showSnack('No se pudo exportar: ${apiErrorMessage(e)}');
    } finally {
      if (mounted) {
        setState(() {
          _exporting = false;
        });
      }
    }
  }

  Widget _sortLabel(String text, _SortDir direction) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text),
        const SizedBox(width: 4),
        Icon(direction == _SortDir.asc ? Icons.arrow_upward : Icons.arrow_downward, size: 13),
      ],
    );
  }

  Widget _panelControls({
    required _SortDir sortDirection,
    required bool onlyNonZero,
    required VoidCallback onToggleSort,
    required VoidCallback onToggleNonZero,
    required VoidCallback onClear,
  }) {
    const btnConstraints = BoxConstraints.tightFor(width: 28, height: 28);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Orden total ABS (${sortDirection == _SortDir.asc ? 'Asc' : 'Desc'})',
          onPressed: onToggleSort,
          constraints: btnConstraints,
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          icon: Icon(
            sortDirection == _SortDir.asc ? Icons.arrow_upward : Icons.arrow_downward,
            size: 18,
          ),
        ),
        const SizedBox(width: 2),
        IconButton(
          tooltip: onlyNonZero ? 'Filtro: != 0 activo' : 'Filtrar: != 0',
          onPressed: onToggleNonZero,
          constraints: btnConstraints,
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          icon: Icon(
            onlyNonZero ? Icons.filter_alt : Icons.filter_alt_outlined,
            size: 18,
          ),
        ),
        const SizedBox(width: 2),
        IconButton(
          tooltip: 'Limpiar filtros/orden',
          onPressed: onClear,
          constraints: btnConstraints,
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.backspace_outlined, size: 18),
        ),
      ],
    );
  }

  void _tryAutoFitPanelWidths({required double viewportWidth}) {
    if (!_panelWidthsLoaded || _didAutoFitPanelWidths) return;
    if (_hasStoredLeftWidth && _hasStoredRightWidth) return;
    _didAutoFitPanelWidths = true;

    const handlesWidth = _resizeHandleWidth * 2;
    final maxLeftForFit = (viewportWidth - handlesWidth - _minRightPanelWidth).clamp(_minLeftPanelWidth, 1400.0).toDouble();
    final targetLeft = _hasStoredLeftWidth
        ? _leftPanelWidth.clamp(_minLeftPanelWidth, 1400.0).toDouble()
        : (viewportWidth * 0.34).clamp(_minLeftPanelWidth, maxLeftForFit).toDouble();
    final targetRight = _hasStoredRightWidth
        ? _rightPanelWidth.clamp(_minRightPanelWidth, 3200.0).toDouble()
        : (viewportWidth - targetLeft - handlesWidth).clamp(_minRightPanelWidth, 3200.0).toDouble();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      setState(() {
        _leftPanelWidth = targetLeft;
        _rightPanelWidth = targetRight;
      });
      if (!_hasStoredLeftWidth) {
        await _saveLeftPanelWidth(targetLeft);
      }
      if (!_hasStoredRightWidth) {
        await _saveRightPanelWidth(targetRight);
      }
    });
  }

  String _fmtMoney(double value) => value.toStringAsFixed(2);

  String _fmtDate(DateTime? value) {
    if (value == null) return '-';
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    final hh = value.hour.toString().padLeft(2, '0');
    final mm = value.minute.toString().padLeft(2, '0');
    return '$d/$m/$y $hh:$mm';
  }

  String _clean(String? value) {
    final text = (value ?? '').trim();
    return text;
  }

  void _selectClient(String client) {
    setState(() {
      _selectedClient = client;
      _selectedIdfol = null;
    });
  }

  void _selectTrans(CtrlCtasResumenTransItem row) {
    final idfol = _clean(row.idfol);
    setState(() {
      _selectedClient = row.client;
      _selectedIdfol = idfol.isEmpty ? null : idfol;
    });
    if (idfol.isEmpty) return;
    _openDetalleDialog(client: row.client, idfol: idfol);
  }

  void _openDetalleDialog({required String client, required String idfol}) {
    final filtrosDet = widget.filtros.copyWith(clients: [client], idfols: [idfol]);
    var onlyNonZero = false;
    var sortDirection = _SortDir.desc;
    var sortField = _DetalleSortField.total;

    showDialog<void>(
      context: context,
      builder: (context) {
        final width = MediaQuery.sizeOf(context).width * 0.95;
        final height = MediaQuery.sizeOf(context).height * 0.85;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final sortFieldLabel = sortField == _DetalleSortField.total ? 'Ordenando: Total ABS' : 'Ordenando: Fecha';
            return Dialog(
              insetPadding: const EdgeInsets.all(16),
              child: SizedBox(
                width: width,
                height: height,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Detalle por transaccion', style: TextStyle(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 2),
                                Text('CLIENT: $client   IDFOL: $idfol'),
                                const SizedBox(height: 2),
                                Text(sortFieldLabel, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: sortField == _DetalleSortField.total
                                ? 'Cambiar orden a Fecha'
                                : 'Cambiar orden a Total ABS',
                            onPressed: () {
                              setDialogState(() {
                                sortField = sortField == _DetalleSortField.total
                                    ? _DetalleSortField.fecha
                                    : _DetalleSortField.total;
                              });
                            },
                            icon: Icon(
                              sortField == _DetalleSortField.total
                                  ? Icons.calendar_month_outlined
                                  : Icons.attach_money_outlined,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Direccion ${sortDirection == _SortDir.asc ? 'Asc' : 'Desc'}',
                            onPressed: () {
                              setDialogState(() {
                                sortDirection = sortDirection == _SortDir.asc ? _SortDir.desc : _SortDir.asc;
                              });
                            },
                            icon: Icon(sortDirection == _SortDir.asc ? Icons.arrow_upward : Icons.arrow_downward),
                          ),
                          IconButton(
                            tooltip: onlyNonZero ? 'Filtro: != 0 activo' : 'Filtrar: != 0',
                            onPressed: () {
                              setDialogState(() {
                                onlyNonZero = !onlyNonZero;
                              });
                            },
                            icon: Icon(onlyNonZero ? Icons.filter_alt : Icons.filter_alt_outlined),
                          ),
                          IconButton(
                            tooltip: 'Limpiar filtros/orden',
                            onPressed: () {
                              setDialogState(() {
                                onlyNonZero = false;
                                sortDirection = _SortDir.desc;
                                sortField = _DetalleSortField.total;
                              });
                            },
                            icon: const Icon(Icons.backspace_outlined),
                          ),
                          Consumer(
                            builder: (context, ref, _) {
                              return IconButton(
                                tooltip: 'Refrescar',
                                onPressed: () => ref.invalidate(ctrlCtasDetalleProvider(filtrosDet)),
                                icon: const Icon(Icons.refresh),
                              );
                            },
                          ),
                          IconButton(
                            tooltip: 'Cerrar',
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: Colors.grey.shade300),
                    Expanded(
                      child: Consumer(
                        builder: (context, ref, _) {
                          final detalleAsync = ref.watch(ctrlCtasDetalleProvider(filtrosDet));
                          return Padding(
                            padding: const EdgeInsets.all(10),
                            child: detalleAsync.when(
                              loading: () => const Center(child: CircularProgressIndicator()),
                              error: (error, _) => Center(child: Text('Error: ${apiErrorMessage(error)}')),
                              data: (items) => _buildDetalleTable(
                                _applyDetalleView(
                                  items,
                                  onlyNonZero: onlyNonZero,
                                  sortField: sortField,
                                  sortDirection: sortDirection,
                                ),
                                sortField: sortField,
                                sortDirection: sortDirection,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _panel({
    required String title,
    required Widget child,
    String? subtitle,
    Widget? headerActions,
    double? height,
  }) {
    Widget panel = Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 5, width: double.infinity, color: Theme.of(context).colorScheme.primary),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (headerActions != null) headerActions,
                  ],
                ),
                if (subtitle != null && subtitle.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                ],
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade300),
          if (height == null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: child,
            )
          else
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: child,
              ),
            ),
        ],
      ),
    );

    if (height != null) {
      panel = SizedBox(height: height, child: panel);
    }
    return panel;
  }

  Widget _tableShell({required Widget child}) {
    return _DualAxisTableScroll(child: child);
  }

  Widget _buildResizeHandle({
    required double panelHeight,
    required void Function(double deltaX) onDrag,
    required VoidCallback onSave,
    required VoidCallback onReset,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (details) => onDrag(details.delta.dx),
        onHorizontalDragEnd: (_) => onSave(),
        onDoubleTap: onReset,
        child: SizedBox(
          width: _resizeHandleWidth,
          height: panelHeight,
          child: Center(
            child: Container(
              width: 10,
              height: 84,
              margin: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                border: Border.all(color: Colors.grey.shade500),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.drag_indicator,
                size: 12,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResumenClienteTable(List<CtrlCtasResumenClienteItem> items) {
    if (items.isEmpty) return const Center(child: Text('Sin resultados'));

    return _tableShell(
      child: DataTable(
        showCheckboxColumn: false,
        columnSpacing: 16,
        horizontalMargin: 10,
        headingRowHeight: 36,
        dataRowMinHeight: 34,
        dataRowMaxHeight: 38,
        columns: [
          const DataColumn(label: Text('CLIENT')),
          const DataColumn(label: SizedBox(width: _razonSocialWidth, child: Text('Razon social'))),
          DataColumn(label: _sortLabel('Total', _clienteTotalSort)),
        ],
        rows: [
          for (final row in items)
            DataRow(
              color: _selectedClient == row.client
                  ? WidgetStatePropertyAll(
                      Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                    )
                  : null,
              cells: [
                DataCell(
                  Text(row.client),
                  onTap: () => _selectClient(row.client),
                ),
                DataCell(
                  SizedBox(
                    width: _razonSocialWidth,
                    child: Text(
                      row.razonSocial ?? 'Sin nombre',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  onTap: () => _selectClient(row.client),
                ),
                DataCell(
                  Text(_fmtMoney(row.total)),
                  onTap: () => _selectClient(row.client),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildResumenTransTable(List<CtrlCtasResumenTransItem> items) {
    if (_selectedClient == null) {
      return const Center(child: Text('Selecciona un cliente para ver transacciones'));
    }
    if (items.isEmpty) return const Center(child: Text('Sin transacciones'));

    return _tableShell(
      child: DataTable(
        showCheckboxColumn: false,
        columnSpacing: 16,
        horizontalMargin: 10,
        headingRowHeight: 36,
        dataRowMinHeight: 34,
        dataRowMaxHeight: 38,
        columns: [
          const DataColumn(label: Text('CLIENT')),
          const DataColumn(label: SizedBox(width: _razonSocialWidth, child: Text('Razon social'))),
          const DataColumn(label: Text('CTA')),
          const DataColumn(label: Text('IDFOL')),
          DataColumn(label: _sortLabel('Total', _transTotalSort)),
        ],
        rows: [
          for (final row in items)
            DataRow(
              color: _selectedIdfol != null && _selectedIdfol == _clean(row.idfol)
                  ? WidgetStatePropertyAll(
                      Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                    )
                  : null,
              cells: [
                DataCell(
                  Text(row.client),
                  onTap: () => _selectTrans(row),
                ),
                DataCell(
                  SizedBox(
                    width: _razonSocialWidth,
                    child: Text(
                      row.razonSocial ?? 'Sin nombre',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  onTap: () => _selectTrans(row),
                ),
                DataCell(
                  Text(row.cta ?? '-'),
                  onTap: () => _selectTrans(row),
                ),
                DataCell(
                  Text(row.idfol ?? '-'),
                  onTap: () => _selectTrans(row),
                ),
                DataCell(
                  Text(_fmtMoney(row.total)),
                  onTap: () => _selectTrans(row),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDetalleTable(
    List<CtrlCtasDetalleItem> items, {
    _DetalleSortField sortField = _DetalleSortField.total,
    _SortDir sortDirection = _SortDir.desc,
  }) {
    if (items.isEmpty) return const Center(child: Text('Sin detalle'));

    return _tableShell(
      child: DataTable(
        showCheckboxColumn: false,
        columnSpacing: 14,
        horizontalMargin: 10,
        headingRowHeight: 36,
        dataRowMinHeight: 34,
        dataRowMaxHeight: 40,
        columns: [
          DataColumn(
            label: sortField == _DetalleSortField.fecha ? _sortLabel('FCND', sortDirection) : const Text('FCND'),
          ),
          const DataColumn(label: Text('NDOC')),
          const DataColumn(label: Text('SUC')),
          const DataColumn(label: Text('CLIENT')),
          const DataColumn(label: SizedBox(width: _razonSocialWidth, child: Text('Razon social'))),
          const DataColumn(label: Text('CTA')),
          const DataColumn(label: Text('CLSD')),
          const DataColumn(label: Text('IDFOL')),
          const DataColumn(label: Text('RTXT')),
          DataColumn(
            label: sortField == _DetalleSortField.total ? _sortLabel('IMPT', sortDirection) : const Text('IMPT'),
          ),
          const DataColumn(label: Text('IDOPV')),
        ],
        rows: [
          for (final row in items)
            DataRow(
              cells: [
                DataCell(Text(_fmtDate(row.fcnd))),
                DataCell(Text(row.ndoc ?? '-')),
                DataCell(Text(row.suc ?? '-')),
                DataCell(Text(row.client ?? '-')),
                DataCell(
                  SizedBox(
                    width: _razonSocialWidth,
                    child: Text(
                      row.razonSocial ?? 'Sin nombre',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(Text(row.cta ?? '-')),
                DataCell(Text(row.clsd ?? '-')),
                DataCell(Text(row.idfol ?? '-')),
                DataCell(Text(row.rtxt ?? '-')),
                DataCell(Text(_fmtMoney(row.impt))),
                DataCell(Text(row.idopv ?? '-')),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resumenClienteAsync = ref.watch(ctrlCtasResumenClienteProvider(widget.filtros));

    final selectedClient = _selectedClient;

    AsyncValue<List<CtrlCtasResumenTransItem>> resumenTransAsync = const AsyncValue.data(<CtrlCtasResumenTransItem>[]);
    if (selectedClient != null) {
      final filtrosTrans = widget.filtros.copyWith(clients: [selectedClient], idfols: const []);
      resumenTransAsync = ref.watch(ctrlCtasResumenTransProvider(filtrosTrans));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resumen por Deudor'),
        actions: [
          IconButton(
            tooltip: 'Exportar Excel',
            onPressed: _exporting ? null : _exportToExcel,
            icon: _exporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download),
          ),
          IconButton(
            tooltip: 'Restablecer anchos',
            onPressed: _resetPanelWidths,
            icon: const Icon(Icons.width_normal),
          ),
          IconButton(
            tooltip: 'Refrescar',
            onPressed: () {
              ref.invalidate(ctrlCtasResumenClienteProvider(widget.filtros));
              if (selectedClient != null) {
                ref.invalidate(
                  ctrlCtasResumenTransProvider(widget.filtros.copyWith(clients: [selectedClient], idfols: const [])),
                );
              }
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final panelHeight = constraints.maxHeight > 0 ? (constraints.maxHeight - 24).toDouble() : 760.0;
          final viewportWidth = constraints.maxWidth > 0 ? constraints.maxWidth : 1200.0;
          _tryAutoFitPanelWidths(viewportWidth: viewportWidth);

          final maxLeftWidth =
              (viewportWidth - (_resizeHandleWidth * 2) - _minRightPanelWidth).clamp(_minLeftPanelWidth, 1400.0).toDouble();
          final effectiveLeftWidth = _leftPanelWidth.clamp(_minLeftPanelWidth, maxLeftWidth).toDouble();
          final maxRightWidth = (viewportWidth - (_resizeHandleWidth * 2) - effectiveLeftWidth)
              .clamp(_minRightPanelWidth, 3200.0)
              .toDouble();
          final effectiveRightWidth = _rightPanelWidth.clamp(_minRightPanelWidth, maxRightWidth).toDouble();
          final rowWidth = effectiveLeftWidth + _resizeHandleWidth + effectiveRightWidth + _resizeHandleWidth;

          final leftPanel = _panel(
            title: 'Resumen por cliente',
            subtitle: selectedClient == null ? 'Selecciona un CLIENT' : 'CLIENT seleccionado: $selectedClient',
            headerActions: _panelControls(
              sortDirection: _clienteTotalSort,
              onlyNonZero: _clienteOnlyNonZero,
              onToggleSort: () {
                setState(() {
                  _clienteTotalSort = _clienteTotalSort == _SortDir.asc ? _SortDir.desc : _SortDir.asc;
                });
              },
              onToggleNonZero: () {
                setState(() {
                  _clienteOnlyNonZero = !_clienteOnlyNonZero;
                });
              },
              onClear: () {
                setState(() {
                  _clienteOnlyNonZero = false;
                  _clienteTotalSort = _SortDir.desc;
                });
              },
            ),
            height: panelHeight,
            child: resumenClienteAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Error: ${apiErrorMessage(error)}')),
              data: (items) => _buildResumenClienteTable(_applyResumenClienteView(items)),
            ),
          );

          final middlePanel = _panel(
            title: 'Resumen por transaccion',
            subtitle: selectedClient == null
                ? 'Selecciona un registro para abrir detalle'
                : 'Filtro CLIENT: $selectedClient',
            headerActions: _panelControls(
              sortDirection: _transTotalSort,
              onlyNonZero: _transOnlyNonZero,
              onToggleSort: () {
                setState(() {
                  _transTotalSort = _transTotalSort == _SortDir.asc ? _SortDir.desc : _SortDir.asc;
                });
              },
              onToggleNonZero: () {
                setState(() {
                  _transOnlyNonZero = !_transOnlyNonZero;
                });
              },
              onClear: () {
                setState(() {
                  _transOnlyNonZero = false;
                  _transTotalSort = _SortDir.desc;
                });
              },
            ),
            height: panelHeight,
            child: resumenTransAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Error: ${apiErrorMessage(error)}')),
              data: (items) => _buildResumenTransTable(_applyResumenTransView(items)),
            ),
          );

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: rowWidth,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: effectiveLeftWidth, child: leftPanel),
                  _buildResizeHandle(
                    panelHeight: panelHeight,
                    onDrag: (deltaX) {
                      final next = (_leftPanelWidth + deltaX).clamp(_minLeftPanelWidth, maxLeftWidth).toDouble();
                      if (next == _leftPanelWidth) return;
                      setState(() {
                        _leftPanelWidth = next;
                      });
                    },
                    onSave: () => _saveLeftPanelWidth(_leftPanelWidth),
                    onReset: () => _resetPanelWidths(),
                  ),
                  SizedBox(width: effectiveRightWidth, child: middlePanel),
                  _buildResizeHandle(
                    panelHeight: panelHeight,
                    onDrag: (deltaX) {
                      final next = (_rightPanelWidth + deltaX).clamp(_minRightPanelWidth, maxRightWidth).toDouble();
                      if (next == _rightPanelWidth) return;
                      setState(() {
                        _rightPanelWidth = next;
                      });
                    },
                    onSave: () => _saveRightPanelWidth(_rightPanelWidth),
                    onReset: () => _resetPanelWidths(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DualAxisTableScroll extends StatefulWidget {
  const _DualAxisTableScroll({required this.child});

  final Widget child;

  @override
  State<_DualAxisTableScroll> createState() => _DualAxisTableScrollState();
}

class _DualAxisTableScrollState extends State<_DualAxisTableScroll> {
  late final ScrollController _verticalCtrl;
  late final ScrollController _horizontalCtrl;

  @override
  void initState() {
    super.initState();
    _verticalCtrl = ScrollController();
    _horizontalCtrl = ScrollController();
  }

  @override
  void dispose() {
    _verticalCtrl.dispose();
    _horizontalCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _verticalCtrl,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _verticalCtrl,
        primary: false,
        child: Scrollbar(
          controller: _horizontalCtrl,
          thumbVisibility: true,
          notificationPredicate: (notification) => notification.metrics.axis == Axis.horizontal,
          child: SingleChildScrollView(
            controller: _horizontalCtrl,
            primary: false,
            scrollDirection: Axis.horizontal,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
