import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/auth/auth_controller.dart';
import '../../../../../core/dio_provider.dart';
import '../../../punto_venta/cotizaciones/detalle_cot/jrq_api.dart';
import '../../../punto_venta/cotizaciones/detalle_cot/jrq_models.dart';
import '../../domain/recepciones_models.dart';
import '../../providers/recepciones_provider.dart';

class RecepcionDetailPage extends ConsumerStatefulWidget {
  const RecepcionDetailPage({super.key, required this.nped});
  final String nped;

  @override
  ConsumerState<RecepcionDetailPage> createState() =>
      _RecepcionDetailPageState();
}

class _RecepcionDetailPageState extends ConsumerState<RecepcionDetailPage> {
  static const _branchManagerRoleId = 13008;
  static const _inventoryChiefRoleId = 2;
  static const _inventoryAnalystRoleId = 9005;
  static const _articlesPerPage = 100;
  late final bool _isBranchManager;
  late final bool _isInventoryChief;
  late final bool _isInventoryReviewer;
  RecepcionOrden? _order;
  RecepcionDocumento? _document;
  RecepcionDocumento? _capturedDocumentData;
  bool _loading = true;
  String? _error;
  String _receiptType = 'PARCIAL';
  String _documentType = 'PENDIENTE';
  final _folio = TextEditingController();
  final _additionalFolios = <TextEditingController>[];
  final _observations = TextEditingController();
  final _guide = TextEditingController();
  final _shippingCompany = TextEditingController();
  final _received = <String, TextEditingController>{};
  final _accepted = <String, TextEditingController>{};
  final _quality = <String, String?>{};
  final _selectedItems = <String>{};
  Timer? _draftDebounce;
  bool _draftSaving = false;
  Future<void>? _draftSaveInFlight;
  int _articlePage = 1;
  bool _hierarchyView = false;
  bool _hierarchyLoading = false;
  String? _hierarchyError;
  double? _selectedDepa;
  double? _selectedSubd;
  double? _selectedClas;
  double? _selectedScla;
  double? _selectedScla2;
  List<JrqDepaModel> _depaItems = const [];
  List<JrqSubdModel> _subdItems = const [];
  List<JrqClasModel> _clasItems = const [];
  List<JrqSclaModel> _sclaItems = const [];
  List<JrqScla2Model> _scla2Items = const [];
  final _sphFilter = TextEditingController();
  final _cylFilter = TextEditingController();
  final _adicFilter = TextEditingController();

  @override
  void initState() {
    super.initState();
    final roleId = ref.read(authControllerProvider).roleId;
    _isBranchManager = roleId == _branchManagerRoleId;
    _isInventoryChief = roleId == _inventoryChiefRoleId;
    _isInventoryReviewer =
        _isInventoryChief || roleId == _inventoryAnalystRoleId;
    _load();
    _loadHierarchyDepartments();
  }

  @override
  void dispose() {
    _draftDebounce?.cancel();
    _folio.dispose();
    for (final controller in _additionalFolios) {
      controller.dispose();
    }
    _observations.dispose();
    _guide.dispose();
    _shippingCompany.dispose();
    _sphFilter.dispose();
    _cylFilter.dispose();
    _adicFilter.dispose();
    for (final controller in [..._received.values, ..._accepted.values]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final order = await ref.read(recepcionesApiProvider).orden(widget.nped);
      RecepcionDocumento? document;
      RecepcionDocumento? capturedDocumentData;
      var activeDocrec = order.docrecActivo;
      if ((activeDocrec ?? '').isEmpty) {
        for (final receipt in order.recepciones) {
          if (const {
            'RECEPCION_FISICA',
            'VALIDADO',
            'PENDIENTE_AUTORIZACION',
            'RECHAZADO',
          }.contains(receipt.estatus)) {
            activeDocrec = receipt.docrec;
            break;
          }
        }
      }
      if ((activeDocrec ?? '').isNotEmpty) {
        document = await ref
            .read(recepcionesApiProvider)
            .documento(activeDocrec!);
      } else if (_isInventoryReviewer && order.estatus == 'PARCIAL') {
        for (final receipt in order.recepciones) {
          if (receipt.estatus == 'CONTABILIZADO') {
            capturedDocumentData = await ref
                .read(recepcionesApiProvider)
                .documento(receipt.docrec);
            break;
          }
        }
      }
      Map<String, dynamic> draft = const {};
      if (_isBranchManager && document == null) {
        draft = await ref.read(recepcionesApiProvider).borrador(widget.nped);
      }
      _resetControllers(order, draft);
      if (capturedDocumentData != null) {
        _reuseCapturedDocumentData(capturedDocumentData);
      }
      if (mounted) {
        setState(() {
          _order = order;
          _document = document;
          _capturedDocumentData = capturedDocumentData;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _resetControllers(RecepcionOrden order, Map<String, dynamic> draft) {
    for (final row in order.detalle.where((row) => row.pendiente > 0)) {
      _received.putIfAbsent(row.idped, () => TextEditingController(text: '0'));
      _accepted.putIfAbsent(row.idped, () => TextEditingController(text: '0'));
      _quality.putIfAbsent(
        row.idped,
        () => _isBranchManager ? null : 'APROBADO',
      );
    }
    if (draft['existe'] != true) return;
    _receiptType = '${draft['tipoRecepcion'] ?? 'PARCIAL'}';
    _documentType = '${draft['tipoDocumento'] ?? 'PENDIENTE'}';
    _setFoliosFromPersisted('${draft['folioDocumento'] ?? ''}');
    final draftGuide = '${draft['guia'] ?? ''}';
    _guide.text = _isBranchManager
        ? draftGuide.replaceAll(RegExp(r'[^0-9]'), '')
        : draftGuide;
    _observations.text = '${draft['observaciones'] ?? ''}';
    _shippingCompany.text = '${draft['paqueteria'] ?? ''}';
    final items = draft['items'];
    if (items is! List) return;
    for (final raw in items.whereType<Map>()) {
      final item = Map<String, dynamic>.from(raw);
      final idped = '${item['idped'] ?? ''}'.trim();
      if (!_received.containsKey(idped)) continue;
      _received[idped]!.text = _draftQty(item['cantidadRecibida']);
      _accepted[idped]!.text = _draftQty(item['cantidadAceptada']);
      final status = '${item['estatus'] ?? ''}'.trim().toUpperCase();
      _quality[idped] = status.isEmpty ? null : status;
      if (status.isNotEmpty) _selectedItems.add(idped);
    }
  }

  void _reuseCapturedDocumentData(RecepcionDocumento document) {
    final summary = document.resumen;
    if (summary.tipoRecepcion.trim().isNotEmpty) {
      _receiptType = summary.tipoRecepcion;
    }
    final documentType = summary.tipoDocumento?.trim();
    if (documentType != null && documentType.isNotEmpty) {
      _documentType = documentType;
    }
    _setFoliosFromPersisted(summary.folioDocumento ?? '');
    _observations.text = summary.observaciones ?? '';
    for (final guide in document.guias) {
      final value = '${guide['GUIA'] ?? guide['guia'] ?? ''}'.trim();
      if (value.isNotEmpty) {
        _guide.text = value;
      }
      final shipping = '${guide['PAQUETERIA'] ?? guide['paqueteria'] ?? ''}'
          .trim();
      if (shipping.isNotEmpty) _shippingCompany.text = shipping;
      if (value.isNotEmpty || shipping.isNotEmpty) break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    return PopScope(
      canPop: !_isBranchManager || _document != null,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || !_isBranchManager) return;
        final saved = await _flushDraft();
        if (mounted && saved) Navigator.of(this.context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Recepción · O.C. ${widget.nped}'),
          actions: [
            IconButton(
              onPressed: _loading ? null : _refreshDetail,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: _loading && order == null
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _load,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              )
            : order == null
            ? const SizedBox.shrink()
            : Column(
                children: [
                  if (_loading) const LinearProgressIndicator(minHeight: 2),
                  _header(order),
                  Expanded(
                    child: _document == null
                        ? _capture(order)
                        : _documentView(order, _document!),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _header(RecepcionOrden order) {
    final receptionStatus =
        _document?.resumen.estatus ?? order.estatusRecepcion;
    return SizedBox(
      width: double.infinity,
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.all(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            alignment: WrapAlignment.start,
            crossAxisAlignment: WrapCrossAlignment.start,
            spacing: 16,
            runSpacing: 8,
            children: [
              Text(
                'Sucursal: ${order.suc}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('Proveedor: ${order.proveedor}'),
              Text(
                receptionStatus == null
                    ? 'Estado O.C.: ${order.estatus}'
                    : 'Estado recepción: $receptionStatus',
              ),
              Text('Solicitado: ${_qty(order.solicitado)}'),
              Text('Recibido acumulado: ${_qty(order.recibido)}'),
              Text('Pendiente: ${_qty(order.pendiente)}'),
              if (order.importe != null)
                Text('Importe O.C.: \$${order.importe!.toStringAsFixed(2)}'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _capture(RecepcionOrden order) {
    if (_isBranchManager || _isInventoryReviewer) {
      return _branchCapture(order);
    }
    final pending = order.detalle.where((row) => row.pendiente > 0).toList();
    return Column(
      children: [
        _captureForm(order),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: (constraints.maxWidth - 24).clamp(
                      0,
                      double.infinity,
                    ),
                  ),
                  child: DataTable(
                    horizontalMargin: 8,
                    columnSpacing: 20,
                    columns: [
                      const DataColumn(label: Text('Artículo')),
                      const DataColumn(label: Text('UPC')),
                      const DataColumn(label: Text('Descripción')),
                      const DataColumn(label: Text('Unidad')),
                      const DataColumn(label: Text('Solicitado')),
                      const DataColumn(label: Text('Recibido acum.')),
                      const DataColumn(label: Text('Pendiente')),
                      const DataColumn(label: Text('Cantidad física')),
                      const DataColumn(label: Text('Cantidad aceptada')),
                      const DataColumn(label: Text('Calidad')),
                      if (order.puedeVerFinanciero)
                        const DataColumn(label: Text('Costo')),
                    ],
                    rows: pending
                        .map(
                          (row) => DataRow(
                            cells: [
                              DataCell(Text(row.art)),
                              DataCell(Text(row.upc ?? '-')),
                              DataCell(
                                SizedBox(
                                  width: 260,
                                  child: Text(row.descripcion),
                                ),
                              ),
                              DataCell(Text(row.unidad)),
                              DataCell(Text(_qty(row.solicitado))),
                              DataCell(Text(_qty(row.recibido))),
                              DataCell(Text(_qty(row.pendiente))),
                              DataCell(
                                _quantityField(
                                  _received[row.idped]!,
                                  row.pendiente,
                                  onChanged: (value) {
                                    if ((_accepted[row.idped]?.text ?? '0') ==
                                        '0') {
                                      _accepted[row.idped]?.text = value;
                                    }
                                  },
                                ),
                              ),
                              DataCell(
                                _quantityField(
                                  _accepted[row.idped]!,
                                  row.pendiente,
                                ),
                              ),
                              DataCell(
                                DropdownButton<String>(
                                  value: _quality[row.idped],
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'APROBADO',
                                      child: Text('Aprobado'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'RECHAZADO',
                                      child: Text('Rechazado'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'NO_APLICA',
                                      child: Text('No aplica'),
                                    ),
                                  ],
                                  onChanged: (value) => setState(
                                    () => _quality[row.idped] =
                                        value ?? 'APROBADO',
                                  ),
                                ),
                              ),
                              if (order.puedeVerFinanciero)
                                DataCell(
                                  Text(
                                    '\$${(row.costo ?? 0).toStringAsFixed(2)}',
                                  ),
                                ),
                            ],
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _branchCapture(RecepcionOrden order) {
    final allPending = order.detalle.where((row) => row.pendiente > 0).toList();
    final pending = allPending.where(_matchesHierarchyFilters).toList();
    final groups = _hierarchyGroups(pending);
    final rowCount = _hierarchyView ? groups.length : pending.length;
    final calculatedPages = (rowCount / _articlesPerPage).ceil();
    final totalPages = calculatedPages < 1 ? 1 : calculatedPages;
    final allSelected =
        pending.isNotEmpty &&
        pending.every((row) => _selectedItems.contains(row.idped));
    if (_articlePage > totalPages) _articlePage = totalPages;
    final start = (_articlePage - 1) * _articlesPerPage;
    final visible = pending.skip(start).take(_articlesPerPage).toList();
    final visibleGroups = groups.skip(start).take(_articlesPerPage).toList();
    return Column(
      children: [
        if (_isInventoryReviewer && _capturedDocumentData != null)
          _capturedDocumentDataCard(_capturedDocumentData!),
        _hierarchyFilters(),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              alignment: WrapAlignment.start,
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: _loading ? null : () => _prepareCompletion(order),
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(
                    _isInventoryReviewer
                        ? 'Contabilizar'
                        : 'Completar recepción física',
                  ),
                ),
                if (_isBranchManager)
                  OutlinedButton.icon(
                    onPressed: _loading
                        ? null
                        : () => _rejectMerchandise(order),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Rechazar mercancía'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: _loading
                      ? null
                      : () => allSelected
                            ? _clearRows(pending)
                            : _selectRows(pending),
                  icon: Icon(allSelected ? Icons.remove_done : Icons.done_all),
                  label: Text(
                    allSelected ? 'Limpiar selección' : 'Seleccionar todo',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => setState(() {
                    _hierarchyView = !_hierarchyView;
                    _articlePage = 1;
                  }),
                  icon: Icon(
                    _hierarchyView
                        ? Icons.table_rows_outlined
                        : Icons.account_tree_outlined,
                  ),
                  label: Text(
                    _hierarchyView
                        ? 'Vista por artículos'
                        : 'Vista por jerarquías',
                  ),
                ),
                if (_draftSaving) ...[
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 6),
                  const Text('Guardando borrador...'),
                ],
              ],
            ),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: (constraints.maxWidth - 24).clamp(
                      0,
                      double.infinity,
                    ),
                  ),
                  child: DataTable(
                    horizontalMargin: 8,
                    columnSpacing: 16,
                    columns: _hierarchyView
                        ? [
                            const DataColumn(label: Text('Jerarquía')),
                            const DataColumn(label: Text('Artículos')),
                            const DataColumn(label: Text('Solicitado')),
                            const DataColumn(label: Text('Pendiente')),
                            const DataColumn(label: Text('Cantidad física')),
                            if (order.puedeVerFinanciero)
                              const DataColumn(label: Text('Importe')),
                          ]
                        : [
                            DataColumn(
                              label: Checkbox(
                                value: allSelected,
                                onChanged: (value) => value == true
                                    ? _selectRows(pending)
                                    : _clearRows(pending),
                              ),
                            ),
                            const DataColumn(label: Text('Artículo')),
                            const DataColumn(label: Text('UPC')),
                            const DataColumn(label: Text('Descripción')),
                            const DataColumn(label: Text('Unidad')),
                            const DataColumn(label: Text('Solicitado')),
                            const DataColumn(label: Text('Pendiente')),
                            const DataColumn(label: Text('Cantidad física')),
                            const DataColumn(label: Text('Acciones')),
                          ],
                    rows: _hierarchyView
                        ? visibleGroups
                              .map(
                                (group) => DataRow(
                                  cells: [
                                    DataCell(
                                      SizedBox(
                                        width: 360,
                                        child: Text(group.name),
                                      ),
                                    ),
                                    DataCell(Text('${group.articleCount}')),
                                    DataCell(Text(_qty(group.requested))),
                                    DataCell(Text(_qty(group.pending))),
                                    DataCell(Text(_qty(group.physical))),
                                    if (order.puedeVerFinanciero)
                                      DataCell(
                                        Text(
                                          '\$${group.amount.toStringAsFixed(2)}',
                                        ),
                                      ),
                                  ],
                                ),
                              )
                              .toList()
                        : visible.map((row) {
                            return DataRow(
                              cells: [
                                DataCell(
                                  Checkbox(
                                    value: _selectedItems.contains(row.idped),
                                    onChanged: (value) =>
                                        _toggleItem(row, value ?? false),
                                  ),
                                ),
                                DataCell(Text(row.art)),
                                DataCell(Text(row.upc ?? '-')),
                                DataCell(
                                  SizedBox(
                                    width: 210,
                                    child: Text(
                                      row.descripcion,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataCell(Text(row.unidad)),
                                DataCell(Text(_qty(row.solicitado))),
                                DataCell(Text(_qty(row.pendiente))),
                                DataCell(
                                  Text(
                                    _qty(_number(_received[row.idped]?.text)),
                                  ),
                                ),
                                DataCell(
                                  IconButton(
                                    tooltip: 'Editar recepción del artículo',
                                    onPressed: _loading
                                        ? null
                                        : () => _editBranchItem(row),
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (totalPages > 1)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _articlePage > 1
                      ? () => setState(() => _articlePage--)
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  'Página $_articlePage de $totalPages · $rowCount ${_hierarchyView ? 'jerarquías' : 'artículos'}',
                ),
                IconButton(
                  onPressed: _articlePage < totalPages
                      ? () => setState(() => _articlePage++)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _hierarchyFilters() => Card(
    margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Filtros de jerarquía',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              if (_hierarchyLoading) ...[
                const SizedBox(width: 10),
                const SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _hierarchyDropdown<JrqDepaModel>(
                label: 'DEP',
                value: _selectedDepa,
                items: _depaItems,
                itemValue: (item) => item.depa,
                itemLabel: (item) => _hierarchyOption(item.depa, item.ddepa),
                onChanged: _changeDepa,
              ),
              _hierarchyDropdown<JrqSubdModel>(
                label: 'SDEP',
                value: _selectedSubd,
                items: _subdItems,
                itemValue: (item) => item.subd,
                itemLabel: (item) => _hierarchyOption(item.subd, item.dsubd),
                onChanged: _changeSubd,
              ),
              _hierarchyDropdown<JrqClasModel>(
                label: 'CLS',
                value: _selectedClas,
                items: _clasItems,
                itemValue: (item) => item.clas,
                itemLabel: (item) => _hierarchyOption(item.clas, item.dclas),
                onChanged: _changeClas,
              ),
              _hierarchyDropdown<JrqSclaModel>(
                label: 'SCLS',
                value: _selectedScla,
                items: _sclaItems,
                itemValue: (item) => item.scla,
                itemLabel: (item) => _hierarchyOption(item.scla, item.dscla),
                onChanged: _changeScla,
              ),
              _hierarchyDropdown<JrqScla2Model>(
                label: 'SCLS2',
                value: _selectedScla2,
                items: _scla2Items,
                itemValue: (item) => item.scla2,
                itemLabel: (item) => _hierarchyOption(item.scla2, item.dscla2),
                onChanged: (value) => setState(() {
                  _selectedScla2 = value;
                  _articlePage = 1;
                }),
              ),
              _hierarchyNumberField('SPH', _sphFilter),
              _hierarchyNumberField('CYL', _cylFilter),
              _hierarchyNumberField('ADIC', _adicFilter),
              OutlinedButton.icon(
                onPressed: _clearHierarchyFilters,
                icon: const Icon(Icons.filter_alt_off_outlined),
                label: const Text('Limpiar jerarquías'),
              ),
            ],
          ),
          if ((_hierarchyError ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _hierarchyError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _hierarchyDropdown<T>({
    required String label,
    required double? value,
    required List<T> items,
    required double Function(T) itemValue,
    required String Function(T) itemLabel,
    required ValueChanged<double?>? onChanged,
  }) => SizedBox(
    width: 175,
    child: DropdownButtonFormField<double>(
      key: ValueKey('$label:$value:${items.length}'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      items: items
          .map(
            (item) => DropdownMenuItem<double>(
              value: itemValue(item),
              child: Text(itemLabel(item), overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: _hierarchyLoading ? null : onChanged,
    ),
  );

  Widget _hierarchyNumberField(
    String label,
    TextEditingController controller,
  ) => SizedBox(
    width: 92,
    child: TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      onChanged: (_) => setState(() => _articlePage = 1),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    ),
  );

  Future<void> _loadHierarchyDepartments() async {
    setState(() {
      _hierarchyLoading = true;
      _hierarchyError = null;
    });
    try {
      final api = JrqApi(ref.read(dioProvider));
      final results = await Future.wait<dynamic>([
        api.fetchDepa(),
        api.fetchSubd(),
        api.fetchClas(),
        api.fetchScla(),
        api.fetchScla2(),
      ]);
      if (mounted) {
        setState(() {
          _depaItems = (results[0] as List).cast<JrqDepaModel>();
          _subdItems = (results[1] as List).cast<JrqSubdModel>();
          _clasItems = (results[2] as List).cast<JrqClasModel>();
          _sclaItems = (results[3] as List).cast<JrqSclaModel>();
          _scla2Items = (results[4] as List).cast<JrqScla2Model>();
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _hierarchyError =
              'No se pudieron cargar las jerarquías: ${_message(error)}',
        );
      }
    } finally {
      if (mounted) setState(() => _hierarchyLoading = false);
    }
  }

  Future<void> _changeDepa(double? value) async {
    setState(() {
      _selectedDepa = value;
      _selectedSubd = null;
      _selectedClas = null;
      _selectedScla = null;
      _selectedScla2 = null;
      _subdItems = const [];
      _articlePage = 1;
    });
    if (value == null) {
      await _loadHierarchyDepartments();
      return;
    }
    await _loadHierarchyLevel(
      () => JrqApi(ref.read(dioProvider)).fetchSubd(depa: value),
      (items) => _subdItems = items,
      'SDEP',
    );
  }

  Future<void> _changeSubd(double? value) async {
    setState(() {
      _selectedSubd = value;
      _selectedClas = null;
      _selectedScla = null;
      _selectedScla2 = null;
      _clasItems = const [];
      _articlePage = 1;
    });
    if (value == null) {
      await _loadHierarchyDepartments();
      return;
    }
    await _loadHierarchyLevel(
      () => JrqApi(ref.read(dioProvider)).fetchClas(subd: value),
      (items) => _clasItems = items,
      'CLS',
    );
  }

  Future<void> _changeClas(double? value) async {
    setState(() {
      _selectedClas = value;
      _selectedScla = null;
      _selectedScla2 = null;
      _sclaItems = const [];
      _articlePage = 1;
    });
    if (value == null) {
      await _loadHierarchyDepartments();
      return;
    }
    await _loadHierarchyLevel(
      () => JrqApi(ref.read(dioProvider)).fetchScla(clas: value),
      (items) => _sclaItems = items,
      'SCLS',
    );
  }

  Future<void> _changeScla(double? value) async {
    setState(() {
      _selectedScla = value;
      _selectedScla2 = null;
      _scla2Items = const [];
      _articlePage = 1;
    });
    if (value == null) {
      await _loadHierarchyDepartments();
      return;
    }
    await _loadHierarchyLevel(
      () => JrqApi(ref.read(dioProvider)).fetchScla2(scla: value),
      (items) => _scla2Items = items,
      'SCLS2',
    );
  }

  Future<void> _loadHierarchyLevel<T>(
    Future<List<T>> Function() load,
    void Function(List<T>) assign,
    String label,
  ) async {
    setState(() {
      _hierarchyLoading = true;
      _hierarchyError = null;
    });
    try {
      final items = await load();
      if (mounted) setState(() => assign(items));
    } catch (error) {
      if (mounted) {
        setState(
          () =>
              _hierarchyError = 'No se pudo cargar $label: ${_message(error)}',
        );
      }
    } finally {
      if (mounted) setState(() => _hierarchyLoading = false);
    }
  }

  void _clearHierarchyFilters() {
    setState(() {
      _selectedDepa = null;
      _selectedSubd = null;
      _selectedClas = null;
      _selectedScla = null;
      _selectedScla2 = null;
      _sphFilter.clear();
      _cylFilter.clear();
      _adicFilter.clear();
      _hierarchyError = null;
      _articlePage = 1;
    });
    unawaited(_loadHierarchyDepartments());
  }

  bool _matchesHierarchyFilters(RecepcionOrdenDetalle row) =>
      _sameNumber(row.depa, _selectedDepa) &&
      _sameNumber(row.subd, _selectedSubd) &&
      _sameNumber(row.clas, _selectedClas) &&
      _sameNumber(row.scla, _selectedScla) &&
      _sameNumber(row.scla2, _selectedScla2) &&
      _sameNumber(row.sph, _optionalNumber(_sphFilter.text)) &&
      _sameNumber(row.cyl, _optionalNumber(_cylFilter.text)) &&
      _sameNumber(row.adic, _optionalNumber(_adicFilter.text));

  List<_HierarchySummary> _hierarchyGroups(List<RecepcionOrdenDetalle> rows) {
    final groups = <String, _HierarchySummary>{};
    for (final row in rows) {
      final name = row.jerarquiaNombre.trim().isEmpty
          ? 'SIN JERARQUIA'
          : row.jerarquiaNombre.trim();
      final physical = _number(_received[row.idped]?.text);
      groups.update(
        name,
        (group) => group.add(row, physical),
        ifAbsent: () => _HierarchySummary.fromRow(row, physical),
      );
    }
    final result = groups.values.toList();
    result.sort((a, b) => a.name.compareTo(b.name));
    return result;
  }

  static bool _sameNumber(double? rowValue, double? filterValue) =>
      filterValue == null ||
      (rowValue != null && (rowValue - filterValue).abs() < 0.000001);

  static double? _optionalNumber(String value) {
    final normalized = value.trim().replaceAll(',', '.');
    return normalized.isEmpty ? null : double.tryParse(normalized);
  }

  static String _hierarchyOption(double value, String? description) {
    final number = value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
    final text = (description ?? '').trim();
    return text.isEmpty ? number : '$number - $text';
  }

  Widget _capturedDocumentDataCard(RecepcionDocumento document) {
    final guides = document.guias
        .map((row) => '${row['GUIA'] ?? row['guia'] ?? ''}'.trim())
        .where((value) => value.isNotEmpty)
        .join(', ');
    final shippingCompanies = document.guias
        .map((row) => '${row['PAQUETERIA'] ?? row['paqueteria'] ?? ''}'.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .join(', ');
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Datos de la recepción ${document.resumen.docrec}'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _documentFact(
                  'Tipo de recepción',
                  _receiptTypeLabel(document.resumen.tipoRecepcion),
                  210,
                ),
                _documentFact(
                  'Documento',
                  _documentTypeLabel(document.resumen.tipoDocumento),
                  210,
                ),
                _documentFact(
                  'Folio factura o nota',
                  document.resumen.folioDocumento ?? '-',
                  240,
                ),
                _documentFact('Guías de envío', guides, 220),
                _documentFact('Paquetería', shippingCompanies, 220),
                _documentFact(
                  'Observaciones',
                  document.resumen.observaciones ?? '-',
                  360,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _showCompletionDialog({bool editing = false}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            editing
                ? 'Editar datos de la recepción'
                : 'Datos de la recepción física',
          ),
          content: SizedBox(
            width: 800,
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.start,
                children: [
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String>(
                      initialValue: _receiptType,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de recepción',
                        border: OutlineInputBorder(),
                        filled: true,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'TOTAL',
                          child: Text('Recepción Total'),
                        ),
                        DropdownMenuItem(
                          value: 'PARCIAL',
                          child: Text('Recepción Parcial'),
                        ),
                        DropdownMenuItem(
                          value: 'DIFERENCIAS',
                          child: Text('Recepción con Diferencias'),
                        ),
                        DropdownMenuItem(
                          value: 'RECHAZO',
                          child: Text('Rechazo de Mercancía'),
                        ),
                      ],
                      onChanged: null,
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String>(
                      initialValue: _documentType,
                      decoration: const InputDecoration(
                        labelText: 'Documento',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'FACTURA',
                          child: Text('Factura'),
                        ),
                        DropdownMenuItem(value: 'NOTA', child: Text('Nota')),
                        DropdownMenuItem(
                          value: 'PENDIENTE',
                          child: Text('Pendiente factura'),
                        ),
                        DropdownMenuItem(
                          value: 'CONSIGNACION',
                          child: Text('Consignación'),
                        ),
                      ],
                      onChanged: (value) {
                        _documentType = value ?? 'PENDIENTE';
                        _scheduleDraftSave();
                      },
                    ),
                  ),
                  _folioFields(setDialogState),
                  _draftTextField(_guide, 'Guías de envío', 250),
                  _draftTextField(_shippingCompany, 'Paquetería', 250),
                  _draftTextField(_observations, 'Observaciones', 526),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.save_outlined),
              label: Text(
                editing
                    ? 'Guardar cambios'
                    : _isInventoryReviewer
                    ? 'Contabilizar'
                    : 'Guardar recepción física',
              ),
            ),
          ],
        ),
      ),
    );
    return result == true;
  }

  Widget _folioFields(StateSetter setDialogState) => SizedBox(
    width: 250,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _folio,
          onChanged: (_) => _scheduleDraftSave(),
          decoration: InputDecoration(
            labelText: 'Folio factura o nota',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              tooltip: 'Agregar otro folio',
              onPressed: () {
                setDialogState(
                  () => _additionalFolios.add(TextEditingController()),
                );
                _scheduleDraftSave();
              },
              icon: const Icon(Icons.add_circle_outline),
            ),
          ),
        ),
        for (var index = 0; index < _additionalFolios.length; index++) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _additionalFolios[index],
            onChanged: (_) => _scheduleDraftSave(),
            decoration: InputDecoration(
              labelText: 'Folio adicional ${index + 1}',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: 'Quitar folio',
                onPressed: () {
                  final controller = _additionalFolios.removeAt(index);
                  controller.dispose();
                  setDialogState(() {});
                  _scheduleDraftSave();
                },
                icon: const Icon(Icons.remove_circle_outline),
              ),
            ),
          ),
        ],
      ],
    ),
  );

  Widget _draftTextField(
    TextEditingController controller,
    String label,
    double width,
  ) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.text,
        onChanged: (_) => _scheduleDraftSave(),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _captureForm(RecepcionOrden order) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 190,
              child: DropdownButtonFormField<String>(
                initialValue: _receiptType,
                decoration: const InputDecoration(
                  labelText: 'Tipo de recepción',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'TOTAL', child: Text('Total')),
                  DropdownMenuItem(value: 'PARCIAL', child: Text('Parcial')),
                  DropdownMenuItem(
                    value: 'DIFERENCIAS',
                    child: Text('Con diferencias'),
                  ),
                  DropdownMenuItem(value: 'RECHAZO', child: Text('Rechazo')),
                ],
                onChanged: (value) {
                  setState(() => _receiptType = value ?? 'PARCIAL');
                  if (value == 'TOTAL') _fillTotal(order);
                },
              ),
            ),
            SizedBox(
              width: 190,
              child: DropdownButtonFormField<String>(
                initialValue: _documentType,
                decoration: const InputDecoration(
                  labelText: 'Documento',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'FACTURA', child: Text('Factura')),
                  DropdownMenuItem(value: 'NOTA', child: Text('Nota')),
                  DropdownMenuItem(
                    value: 'PENDIENTE',
                    child: Text('Pendiente factura'),
                  ),
                  DropdownMenuItem(
                    value: 'CONSIGNACION',
                    child: Text('Consignación'),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => _documentType = value ?? 'PENDIENTE'),
              ),
            ),
            SizedBox(
              width: 220,
              child: TextField(
                controller: _folio,
                decoration: const InputDecoration(
                  labelText: 'Folio factura/nota',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            SizedBox(
              width: 190,
              child: TextField(
                controller: _guide,
                decoration: const InputDecoration(
                  labelText: 'Guía',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            SizedBox(
              width: 320,
              child: TextField(
                controller: _observations,
                decoration: const InputDecoration(
                  labelText: 'Observaciones',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _documentView(RecepcionOrden order, RecepcionDocumento document) {
    final status = document.resumen.estatus;
    final guides = document.guias
        .map((row) => '${row['GUIA'] ?? row['guia'] ?? ''}'.trim())
        .where((value) => value.isNotEmpty)
        .join(', ');
    final shippingCompanies = document.guias
        .map((row) => '${row['PAQUETERIA'] ?? row['paqueteria'] ?? ''}'.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .join(', ');
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Recepción ${document.resumen.docrec}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    if (_isInventoryChief && status == 'VALIDADO') ...[
                      OutlinedButton.icon(
                        onPressed: _loading
                            ? null
                            : () => _editDocumentData(document),
                        icon: const Icon(Icons.edit_note_outlined),
                        label: const Text('Editar datos'),
                      ),
                      const SizedBox(width: 8),
                    ],
                    _status(status),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _documentFact(
                      'Tipo de recepción',
                      _receiptTypeLabel(document.resumen.tipoRecepcion),
                      210,
                    ),
                    _documentFact(
                      'Documento',
                      _documentTypeLabel(document.resumen.tipoDocumento),
                      210,
                    ),
                    for (
                      var index = 0;
                      index <
                          _folioValues(document.resumen.folioDocumento).length;
                      index++
                    )
                      _documentFact(
                        index == 0
                            ? 'Folio factura o nota'
                            : 'Folio adicional $index',
                        _folioValues(document.resumen.folioDocumento)[index],
                        240,
                      ),
                    _documentFact('Guías de envío', guides, 220),
                    _documentFact('Paquetería', shippingCompanies, 220),
                    _documentFact(
                      'Observaciones',
                      document.resumen.observaciones ?? '-',
                      360,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: DataTable(
                  horizontalMargin: 16,
                  columnSpacing: 24,
                  columns: [
                    const DataColumn(label: Text('Artículo')),
                    const DataColumn(label: Text('UPC')),
                    const DataColumn(label: Text('Descripción')),
                    const DataColumn(label: Text('Unidad')),
                    const DataColumn(label: Text('Solicitado')),
                    const DataColumn(label: Text('Cantidad física')),
                    if (!_isInventoryReviewer)
                      const DataColumn(label: Text('Cantidad aceptada')),
                    if (!_isInventoryReviewer)
                      const DataColumn(label: Text('Estatus')),
                    if (_isInventoryReviewer) ...[
                      const DataColumn(label: Text('Faltantes')),
                      const DataColumn(label: Text('Sobrantes')),
                    ],
                    if (order.puedeVerFinanciero)
                      const DataColumn(label: Text('Costo')),
                    if (_isInventoryChief && status == 'VALIDADO')
                      const DataColumn(label: Text('Acciones')),
                  ],
                  rows: document.detalle
                      .map(
                        (row) => DataRow(
                          cells: [
                            DataCell(Text('${row['art'] ?? ''}')),
                            DataCell(Text('${row['upc'] ?? '-'}')),
                            DataCell(
                              SizedBox(
                                width: 250,
                                child: Text(
                                  '${row['des'] ?? ''}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(Text('${row['unidad'] ?? '-'}')),
                            DataCell(Text(_jsonQty(row['cantidadSolicitada']))),
                            DataCell(Text(_jsonQty(row['cantidadRecibida']))),
                            if (!_isInventoryReviewer)
                              DataCell(Text(_jsonQty(row['cantidadAceptada']))),
                            if (!_isInventoryReviewer)
                              DataCell(
                                Text(
                                  _itemStatusLabel(
                                    '${row['calidadEstado'] ?? ''}',
                                  ),
                                ),
                              ),
                            if (_isInventoryReviewer) ...[
                              DataCell(
                                Text(
                                  _jsonQty(
                                    _incidentQuantity(
                                      document,
                                      row,
                                      'FALTANTE',
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  _jsonQty(
                                    _incidentQuantity(
                                      document,
                                      row,
                                      'SOBRANTE',
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            if (order.puedeVerFinanciero)
                              DataCell(
                                Text(
                                  '\$${_jsonNumber(row['costo']).toStringAsFixed(2)}',
                                ),
                              ),
                            if (_isInventoryChief && status == 'VALIDADO')
                              DataCell(
                                IconButton(
                                  tooltip: 'Editar costo',
                                  onPressed: _loading
                                      ? null
                                      : () => _editDocumentCost(document, row),
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                              ),
                          ],
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (status == 'RECEPCION_FISICA' && !_isBranchManager)
              FilledButton.icon(
                onPressed: _loading
                    ? null
                    : _isInventoryReviewer
                    ? _confirmAccounting
                    : () => _action('solicitar-autorizacion'),
                icon: Icon(_isInventoryReviewer ? Icons.verified : Icons.send),
                label: Text(
                  _isInventoryReviewer
                      ? 'Contabilizar'
                      : 'Solicitar autorización',
                ),
              ),
            if ((status == 'VALIDADO' || status == 'PENDIENTE_AUTORIZACION') &&
                document.puedeAutorizar) ...[
              OutlinedButton.icon(
                onPressed: _loading ? null : _reject,
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Rechazar'),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: _loading
                    ? null
                    : _isInventoryReviewer
                    ? _confirmAccounting
                    : () => _action('autorizar'),
                icon: const Icon(Icons.verified),
                label: Text(
                  _isInventoryReviewer
                      ? 'Contabilizar'
                      : 'Autorizar y contabilizar',
                ),
              ),
            ],
          ],
        ),
        if (status == 'RECEPCION_FISICA')
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              'La recepción física aún no afecta existencias. El inventario se actualizará después de la autorización administrativa.',
            ),
          ),
        if (status == 'VALIDADO')
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              'La recepción está validada y pendiente de revisión por Jefe o Analista de Inventarios.',
            ),
          ),
      ],
    );
  }

  Widget _documentFact(String label, String value, double width) {
    return SizedBox(
      width: width,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        child: Text(value.trim().isEmpty ? '-' : value),
      ),
    );
  }

  List<String> _folioValues(String? value) {
    final values = (value ?? '')
        .split(' | ')
        .map((folio) => folio.trim())
        .where((folio) => folio.isNotEmpty)
        .toList();
    return values.isEmpty ? const ['-'] : values;
  }

  Future<void> _editDocumentData(RecepcionDocumento document) async {
    _receiptType = document.resumen.tipoRecepcion;
    _documentType = document.resumen.tipoDocumento ?? 'PENDIENTE';
    _setFoliosFromPersisted(document.resumen.folioDocumento ?? '');
    _guide.clear();
    _shippingCompany.clear();
    for (final row in document.guias) {
      final guide = '${row['GUIA'] ?? row['guia'] ?? ''}'.trim();
      final shipping = '${row['PAQUETERIA'] ?? row['paqueteria'] ?? ''}'.trim();
      if (guide.isNotEmpty) _guide.text = guide;
      if (shipping.isNotEmpty) _shippingCompany.text = shipping;
      if (guide.isNotEmpty || shipping.isNotEmpty) break;
    }
    _observations.text = document.resumen.observaciones ?? '';
    final save = await _showCompletionDialog(editing: true);
    if (!save || !mounted) return;
    final folios = _folioDocumentValue();
    if ((_documentType == 'FACTURA' || _documentType == 'NOTA') &&
        folios.isEmpty) {
      _snack('Capture el folio de la factura o nota.');
      return;
    }
    if (folios.length > 100) {
      _snack('Los folios capturados no deben exceder 100 caracteres en total.');
      return;
    }
    setState(() => _loading = true);
    try {
      final result = await ref
          .read(recepcionesApiProvider)
          .actualizarDatos(
            docrec: document.resumen.docrec,
            tipoDocumento: _documentType,
            folioDocumento: folios,
            guia: _guide.text.trim(),
            paqueteria: _shippingCompany.text.trim(),
            observaciones: _observations.text.trim(),
          );
      if (mounted) {
        setState(() => _document = result);
        _snack('Datos documentales actualizados.');
      }
    } catch (error) {
      _snack(_message(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editDocumentCost(
    RecepcionDocumento document,
    Map<String, dynamic> row,
  ) async {
    final controller = TextEditingController(
      text: _jsonNumber(row['costo']).toStringAsFixed(2),
    );
    String? validation;
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Editar costo · ${row['art'] ?? ''}'),
          content: SizedBox(
            width: 320,
            child: TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Costo unitario',
                prefixText: '\$ ',
                errorText: validation,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final value = double.tryParse(
                  controller.text.trim().replaceAll(',', '.'),
                );
                if (value == null || value < 0) {
                  setDialogState(() => validation = 'Capture un costo válido.');
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    final cost = double.tryParse(controller.text.trim().replaceAll(',', '.'));
    controller.dispose();
    if (save != true || cost == null || !mounted) return;
    setState(() => _loading = true);
    try {
      final result = await ref
          .read(recepcionesApiProvider)
          .actualizarCosto(
            docrec: document.resumen.docrec,
            idrec: '${row['idrec'] ?? ''}',
            costo: cost,
          );
      if (mounted) {
        setState(() => _document = result);
        _snack('Costo actualizado.');
      }
    } catch (error) {
      _snack(_message(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double _incidentQuantity(
    RecepcionDocumento document,
    Map<String, dynamic> detail,
    String type,
  ) {
    final detailId = '${detail['idrec'] ?? ''}'.trim();
    final article = '${detail['art'] ?? ''}'.trim();
    for (final incident in document.incidencias) {
      final incidentType = '${incident['TIPO'] ?? incident['tipo'] ?? ''}'
          .trim()
          .toUpperCase();
      final incidentId = '${incident['IDREC'] ?? incident['idrec'] ?? ''}'
          .trim();
      final incidentArticle = '${incident['ART'] ?? incident['art'] ?? ''}'
          .trim();
      final matchesDetail = detailId.isNotEmpty && incidentId.isNotEmpty
          ? incidentId == detailId
          : incidentArticle == article;
      if (incidentType != type || !matchesDetail) {
        continue;
      }
      final difference = _jsonNumber(
        incident['DIFERENCIA'] ?? incident['diferencia'],
      );
      if (difference != 0) return difference.abs();
      final expected = _jsonNumber(
        incident['CTD_ESPERADA'] ?? incident['cantidadEsperada'],
      );
      final received = _jsonNumber(
        incident['CTD_RECIBIDA'] ?? incident['cantidadRecibida'],
      );
      return (received - expected).abs();
    }

    final isUnrequested = '${detail['idped'] ?? ''}'.trim().isEmpty;
    return switch (type) {
      'NO_SOLICITADO' when isUnrequested => _jsonNumber(
        detail['cantidadRecibida'],
      ),
      _ => 0,
    };
  }

  Widget _quantityField(
    TextEditingController controller,
    double max, {
    ValueChanged<String>? onChanged,
  }) => SizedBox(
    width: 105,
    child: TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: onChanged,
      decoration: InputDecoration(
        isDense: true,
        hintText: '0 / ${_qty(max)}',
        border: const OutlineInputBorder(),
      ),
    ),
  );
  void _fillTotal(RecepcionOrden order) {
    for (final row in order.detalle.where((row) => row.pendiente > 0)) {
      final value = _qty(row.pendiente);
      _received[row.idped]?.text = value;
      _accepted[row.idped]?.text = value;
    }
  }

  void _selectRows(Iterable<RecepcionOrdenDetalle> rows) {
    setState(() {
      for (final row in rows) {
        _selectedItems.add(row.idped);
        final value = _qty(row.pendiente);
        _received[row.idped]?.text = value;
        _accepted[row.idped]?.text = value;
        _quality[row.idped] = 'APROBADO';
      }
    });
    _scheduleDraftSave();
  }

  void _toggleItem(RecepcionOrdenDetalle row, bool selected) {
    setState(() {
      if (selected) {
        _selectedItems.add(row.idped);
        final value = _qty(row.pendiente);
        _received[row.idped]?.text = value;
        _accepted[row.idped]?.text = value;
        _quality[row.idped] = 'APROBADO';
      } else {
        _selectedItems.remove(row.idped);
        _received[row.idped]?.text = '0';
        _accepted[row.idped]?.text = '0';
        _quality[row.idped] = null;
      }
    });
    _scheduleDraftSave();
  }

  Future<void> _editBranchItem(RecepcionOrdenDetalle row) async {
    final received = TextEditingController(
      text: _received[row.idped]?.text ?? '0',
    );
    String? validation;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Editar artículo ${row.art}'),
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  row.descripcion,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: received,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Cantidad física',
                    helperText: 'Pendiente: ${_qty(row.pendiente)}',
                    border: const OutlineInputBorder(),
                  ),
                ),
                if (validation != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        validation!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
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
                final receivedValue = _number(received.text);
                if (receivedValue < 0) {
                  setDialogState(
                    () => validation = 'La cantidad no puede ser negativa.',
                  );
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (saved == true && mounted) {
      setState(() {
        final value = _draftQty(_number(received.text));
        _received[row.idped]?.text = value;
        _accepted[row.idped]?.text = value;
        _quality[row.idped] = 'APROBADO';
        _selectedItems.add(row.idped);
      });
      _scheduleDraftSave();
    }
    received.dispose();
  }

  void _clearRows(Iterable<RecepcionOrdenDetalle> rows) {
    setState(() {
      for (final row in rows) {
        _selectedItems.remove(row.idped);
        _received[row.idped]?.text = '0';
        _accepted[row.idped]?.text = '0';
        _quality[row.idped] = null;
      }
    });
    _scheduleDraftSave();
  }

  Future<void> _rejectMerchandise(RecepcionOrden order) async {
    final motive = TextEditingController();
    String? validation;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Rechazar mercancía'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'La recepción se enviará al Jefe o Analista de Inventarios con estatus RECHAZADO.',
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: motive,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Motivo del rechazo',
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
                    () => validation = 'Capture el motivo del rechazo.',
                  );
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('Confirmar rechazo'),
            ),
          ],
        ),
      ),
    );
    final rejectionMotive = motive.text.trim();
    motive.dispose();
    if (confirmed != true || !mounted) return;

    setState(() {
      _receiptType = 'RECHAZO';
      _documentType = 'PENDIENTE';
      _setFoliosFromPersisted('');
      _guide.clear();
      _shippingCompany.clear();
      _observations.text = rejectionMotive;
      for (final row in order.detalle.where((row) => row.pendiente > 0)) {
        _selectedItems.add(row.idped);
        _received[row.idped]?.text = _qty(row.pendiente);
        _accepted[row.idped]?.text = '0';
        _quality[row.idped] = 'RECHAZADO';
      }
    });
    await _save(false);
  }

  Future<void> _prepareCompletion(RecepcionOrden order) async {
    final unreviewed = order.detalle
        .where(
          (row) => row.pendiente > 0 && !_selectedItems.contains(row.idped),
        )
        .length;
    if (unreviewed > 0) {
      _snack('Todos los artículos deben revisarse. Faltan $unreviewed.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          _isInventoryReviewer
              ? 'Contabilizar recepción'
              : 'Completar recepción física',
        ),
        content: Text(
          _isInventoryReviewer
              ? '¿Confirma que todos los artículos fueron revisados? Después capture los datos del documento para contabilizar la recepción.'
              : '¿Confirma que todos los artículos fueron revisados? Después podrá capturar los datos del documento y la guía.',
        ),
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
    if (confirmed != true || !mounted) return;
    final reusesCapturedData =
        _isInventoryReviewer && _capturedDocumentData != null;
    if (!reusesCapturedData) {
      _receiptType = _branchReceiptType(order);
      _scheduleDraftSave();
    }
    final save = reusesCapturedData || await _showCompletionDialog();
    if (save && mounted) await _save(false);
  }

  String _branchReceiptType(RecepcionOrden order) {
    for (final row in order.detalle.where((row) => row.pendiente > 0)) {
      final accepted = _number(_accepted[row.idped]?.text);
      if (accepted != row.pendiente) {
        return 'DIFERENCIAS';
      }
    }
    return 'TOTAL';
  }

  void _scheduleDraftSave() {
    if (!_isBranchManager || _document != null || _order == null) return;
    _draftDebounce?.cancel();
    _draftDebounce = Timer(
      const Duration(milliseconds: 600),
      () => _flushDraft(),
    );
  }

  Future<bool> _flushDraft() async {
    if (!_isBranchManager || _document != null || _order == null) return true;
    _draftDebounce?.cancel();
    final previous = _draftSaveInFlight;
    if (previous != null) {
      try {
        await previous;
      } catch (_) {
        return false;
      }
    }
    if (!mounted || _document != null) return true;
    final future = ref
        .read(recepcionesApiProvider)
        .guardarBorrador(nped: widget.nped, payload: _draftPayload());
    _draftSaveInFlight = future;
    setState(() => _draftSaving = true);
    try {
      await future;
      return true;
    } catch (error) {
      _snack('No se pudo guardar el borrador: ${_message(error)}');
      return false;
    } finally {
      if (identical(_draftSaveInFlight, future)) {
        _draftSaveInFlight = null;
      }
      if (mounted) setState(() => _draftSaving = false);
    }
  }

  Future<void> _refreshDetail() async {
    if (_isBranchManager && !await _flushDraft()) return;
    await _load();
  }

  void _setFoliosFromPersisted(String value) {
    for (final controller in _additionalFolios) {
      controller.dispose();
    }
    _additionalFolios.clear();
    final values = value
        .split(' | ')
        .map((folio) => folio.trim())
        .where((folio) => folio.isNotEmpty)
        .toList();
    _folio.text = values.isEmpty ? '' : values.first;
    for (final folio in values.skip(1)) {
      _additionalFolios.add(TextEditingController(text: folio));
    }
  }

  String _folioDocumentValue() => [
    _folio.text,
    ..._additionalFolios.map((controller) => controller.text),
  ].map((folio) => folio.trim()).where((folio) => folio.isNotEmpty).join(' | ');

  Map<String, dynamic> _draftPayload() {
    final order = _order!;
    return {
      'tipoRecepcion': _receiptType,
      'tipoDocumento': _documentType,
      'folioDocumento': _folioDocumentValue(),
      'guia': _guide.text.trim(),
      'paqueteria': _shippingCompany.text.trim(),
      'observaciones': _observations.text.trim(),
      'items': order.detalle
          .where((row) => row.pendiente > 0)
          .map(
            (row) => {
              'idped': row.idped,
              'art': row.art,
              'cantidadRecibida': _number(_received[row.idped]?.text),
              'cantidadAceptada': _number(_accepted[row.idped]?.text),
              if (_quality[row.idped] != null) 'estatus': _quality[row.idped],
            },
          )
          .toList(),
    };
  }

  List<Map<String, dynamic>> _payloadItems() {
    final order = _order!;
    final rows = <Map<String, dynamic>>[];
    for (final row in order.detalle.where((row) => row.pendiente > 0)) {
      final received =
          double.tryParse(
            (_received[row.idped]?.text ?? '').replaceAll(',', '.'),
          ) ??
          0;
      final accepted =
          double.tryParse(
            (_accepted[row.idped]?.text ?? '').replaceAll(',', '.'),
          ) ??
          0;
      if (received <= 0) continue;
      rows.add({
        'idped': row.idped,
        'art': row.art,
        'cantidadRecibida': received,
        'cantidadAceptada': accepted,
        'calidadEstado': _quality[row.idped] ?? 'APROBADO',
      });
    }
    return rows;
  }

  Future<void> _save(bool massive) async {
    if (_isBranchManager || _isInventoryReviewer) {
      final unreviewed = _order!.detalle.any(
        (row) => row.pendiente > 0 && !_selectedItems.contains(row.idped),
      );
      if (unreviewed) {
        _snack('Todos los artículos deben revisarse.');
        return;
      }
      _draftDebounce?.cancel();
      final pendingSave = _draftSaveInFlight;
      if (pendingSave != null) {
        try {
          await pendingSave;
        } catch (_) {
          // _flushDraft ya informa el error de persistencia al usuario.
        }
      }
    }
    final items = _payloadItems();
    if (items.isEmpty) {
      _snack('Capture al menos una cantidad recibida.');
      return;
    }
    if ((_documentType == 'FACTURA' || _documentType == 'NOTA') &&
        _folioDocumentValue().isEmpty) {
      _snack('Capture el folio de la factura o nota.');
      return;
    }
    if (_folioDocumentValue().length > 100) {
      _snack('Los folios capturados no deben exceder 100 caracteres en total.');
      return;
    }
    setState(() => _loading = true);
    try {
      final api = ref.read(recepcionesApiProvider);
      var document = await api.crear(
        nped: widget.nped,
        tipoRecepcion: _receiptType,
        tipoDocumento: _documentType,
        folioDocumento: _folioDocumentValue(),
        observaciones: _observations.text,
        items: items,
        guias: _guide.text.trim().isEmpty
            ? const []
            : [
                {
                  'guia': _guide.text.trim(),
                  if (_shippingCompany.text.trim().isNotEmpty)
                    'paqueteria': _shippingCompany.text.trim(),
                },
              ],
        masiva: massive,
      );
      if (_isInventoryReviewer) {
        if (mounted) setState(() => _document = document);
        document = await api.accion(
          document.resumen.docrec,
          'solicitar-autorizacion',
        );
        if (mounted) setState(() => _document = document);
        document = await api.accion(document.resumen.docrec, 'autorizar');
      }
      if (mounted) {
        setState(() => _document = document);
        _snack(
          _isBranchManager
              ? document.resumen.estatus == 'RECHAZADO'
                    ? 'Recepción ${document.resumen.docrec} rechazada y enviada a Inventarios.'
                    : 'Recepción ${document.resumen.docrec} validada.'
              : _isInventoryReviewer
              ? 'Recepción ${document.resumen.docrec} contabilizada.'
              : 'Recepción física ${document.resumen.docrec} registrada.',
        );
        if (_isBranchManager) Navigator.of(context).pop();
        if (_isInventoryReviewer) Navigator.of(context).pop(true);
      }
    } catch (error) {
      _snack(_message(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmAccounting() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contabilizar recepción'),
        content: const Text(
          '¿Confirma que desea contabilizar esta recepción? Esta acción actualizará las existencias.',
        ),
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
    if (confirmed == true && mounted) {
      await _accountDocument();
    }
  }

  Future<void> _accountDocument() async {
    var document = _document!;
    setState(() => _loading = true);
    try {
      final api = ref.read(recepcionesApiProvider);
      if (document.resumen.estatus == 'RECEPCION_FISICA') {
        document = await api.accion(
          document.resumen.docrec,
          'solicitar-autorizacion',
        );
        if (mounted) setState(() => _document = document);
      }
      document = await api.accion(document.resumen.docrec, 'autorizar');
      if (mounted) {
        setState(() => _document = document);
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      _snack(_message(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _action(String action, {bool closeOnSuccess = false}) async {
    final docrec = _document!.resumen.docrec;
    setState(() => _loading = true);
    try {
      final result = await ref
          .read(recepcionesApiProvider)
          .accion(docrec, action);
      if (mounted) {
        setState(() => _document = result);
        if (closeOnSuccess) {
          Navigator.of(context).pop(true);
          return;
        }
        _snack('Proceso completado.');
        await _load();
      }
    } catch (error) {
      _snack(_message(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reject() async {
    final controller = TextEditingController();
    String? validation;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Rechazar y devolver a sucursal'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'La O.C. regresará a PROCESADO para que el Encargado de sucursal vuelva a revisarla.',
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Motivo',
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
                if (controller.text.trim().isEmpty) {
                  setDialogState(() => validation = 'Capture el motivo.');
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('Rechazar'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true) {
      controller.dispose();
      return;
    }
    setState(() => _loading = true);
    try {
      final result = await ref
          .read(recepcionesApiProvider)
          .accion(
            _document!.resumen.docrec,
            'rechazar',
            motivo: controller.text,
          );
      if (mounted) {
        setState(() => _document = result);
        _snack('Recepción devuelta a sucursal para nueva revisión.');
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      _snack(_message(error));
    } finally {
      controller.dispose();
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }
}

class _HierarchySummary {
  const _HierarchySummary({
    required this.name,
    required this.articleCount,
    required this.requested,
    required this.pending,
    required this.physical,
    required this.amount,
  });

  final String name;
  final int articleCount;
  final double requested;
  final double pending;
  final double physical;
  final double amount;

  factory _HierarchySummary.fromRow(
    RecepcionOrdenDetalle row,
    double physical,
  ) => _HierarchySummary(
    name: row.jerarquiaNombre.trim().isEmpty
        ? 'SIN JERARQUIA'
        : row.jerarquiaNombre.trim(),
    articleCount: 1,
    requested: row.solicitado,
    pending: row.pendiente,
    physical: physical,
    amount: physical * (row.costo ?? 0),
  );

  _HierarchySummary add(RecepcionOrdenDetalle row, double physical) =>
      _HierarchySummary(
        name: name,
        articleCount: articleCount + 1,
        requested: requested + row.solicitado,
        pending: pending + row.pendiente,
        physical: this.physical + physical,
        amount: amount + physical * (row.costo ?? 0),
      );
}

Widget _status(String value) {
  final status = value.toUpperCase();
  final color = status.contains('CONTABIL')
      ? Colors.green
      : status.contains('RECHAZ')
      ? Colors.red
      : status.contains('PENDIENTE')
      ? Colors.orange
      : Colors.blue;
  return Chip(
    label: Text(status.replaceAll('_', ' ')),
    side: BorderSide(color: color),
  );
}

String _qty(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(2);
String _draftQty(dynamic value) {
  final number = value is num
      ? value.toDouble()
      : double.tryParse('${value ?? ''}') ?? 0;
  return _qty(number);
}

double _number(String? value) =>
    double.tryParse((value ?? '').trim().replaceAll(',', '.')) ?? 0;
double _jsonNumber(dynamic value) => value is num
    ? value.toDouble()
    : double.tryParse('${value ?? ''}'.replaceAll(',', '.')) ?? 0;
String _jsonQty(dynamic value) => _qty(_jsonNumber(value));
String _receiptTypeLabel(String value) => switch (value.toUpperCase()) {
  'TOTAL' => 'Recepción Total',
  'PARCIAL' => 'Recepción Parcial',
  'DIFERENCIAS' => 'Recepción con Diferencias',
  'RECHAZO' => 'Rechazo de Mercancía',
  _ => value,
};
String _documentTypeLabel(String? value) => switch (value?.toUpperCase()) {
  'FACTURA' => 'Factura',
  'NOTA' => 'Nota',
  'PENDIENTE' => 'Pendiente factura',
  'CONSIGNACION' => 'Consignación',
  _ => value ?? '-',
};
String _itemStatusLabel(String? value) => switch (value) {
  'APROBADO' => 'Aprobado',
  'RECHAZADO' => 'Rechazado',
  'NO_APLICA' => 'No aplica',
  _ => 'Sin estatus',
};
String _message(Object error) =>
    error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
