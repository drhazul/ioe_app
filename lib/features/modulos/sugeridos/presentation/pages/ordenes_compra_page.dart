import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart' as xls;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/sugeridos_models.dart';
import '../../providers/sugeridos_provider.dart';
import '../widgets/orden_compra_detalle_dialog.dart';

class OrdenesCompraPage extends ConsumerStatefulWidget {
  const OrdenesCompraPage({super.key});

  @override
  ConsumerState<OrdenesCompraPage> createState() => _OrdenesCompraPageState();
}

class _OrdenesCompraPageState extends ConsumerState<OrdenesCompraPage> {
  final _docCtrl = TextEditingController();
  final _fechaCtrl = TextEditingController();
  String _doc = '';
  String _suc = '';
  String _estatus = '';
  int? _prov;
  String _fecha = '';
  int _page = 1;
  bool _consulted = false;
  static const int _limit = 30;

  @override
  void dispose() {
    _docCtrl.dispose();
    _fechaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filters = SugeridosFilters(
      page: _page,
      limit: _limit,
      search: _doc,
      suc: _suc,
      estatus: _estatus,
      prov: _prov,
      fecha: _fecha,
    );
    final ordersAsync = _consulted
        ? ref.watch(sugeridosProvider(filters))
        : null;
    final sucsAsync = ref.watch(sugeridosSucursalesProvider);
    final estatusAsync = ref.watch(sugeridosEstatusProvider);
    final proveedoresAsync = ref.watch(sugeridosProveedoresProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ordenes de compra'),
        actions: [
          IconButton(
            tooltip: 'Nueva orden de compra',
            onPressed: _openNuevaOrden,
            icon: const Icon(Icons.add_circle_outline),
          ),
          IconButton(
            tooltip: 'Refrescar',
            icon: const Icon(Icons.refresh),
            onPressed: _consulted
                ? () => ref.invalidate(sugeridosProvider(filters))
                : null,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: _OrdenesFilters(
              docCtrl: _docCtrl,
              fechaCtrl: _fechaCtrl,
              suc: _suc,
              estatus: _estatus,
              prov: _prov,
              sucsAsync: sucsAsync,
              estatusAsync: estatusAsync,
              proveedoresAsync: proveedoresAsync,
              onSucChanged: (value) => setState(() {
                _suc = value ?? '';
                _page = 1;
              }),
              onEstatusChanged: (value) => setState(() {
                _estatus = value ?? '';
                _page = 1;
              }),
              onProvChanged: (value) => setState(() {
                _prov = value;
                _page = 1;
              }),
              onFechaPick: _pickFecha,
              onApply: _applyFilters,
              onClear: _clearFilters,
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ordersAsync == null
                ? const Center(
                    child: Text('Seleccione filtros y presione Consultar.'),
                  )
                : ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      ordersAsync.when(
                        data: (result) => _OrdenesTable(
                          result: result,
                          onPageChanged: _changePage,
                          onOpen: _openDetalle,
                          onAction: _runOrderAction,
                        ),
                        loading: () =>
                            const _LoadingBand(text: 'Cargando ordenes...'),
                        error: (e, _) =>
                            _ErrorBand(message: 'No se pudo cargar: $e'),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  void _applyFilters() {
    setState(() {
      _doc = _docCtrl.text.trim();
      _fecha = _fechaCtrl.text.trim();
      _page = 1;
      _consulted = true;
    });
  }

  Future<void> _pickFecha() async {
    final now = DateTime.now();
    final initial = DateTime.tryParse(_fechaCtrl.text.trim()) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked == null) return;
    final text = _date(picked);
    setState(() {
      _fechaCtrl.text = text;
      _fecha = text;
      _page = 1;
    });
  }

  void _clearFilters() {
    setState(() {
      _docCtrl.clear();
      _fechaCtrl.clear();
      _doc = '';
      _suc = '';
      _estatus = '';
      _prov = null;
      _fecha = '';
      _page = 1;
      _consulted = false;
    });
  }

  void _changePage(int page) {
    if (page < 1 || page == _page) return;
    setState(() => _page = page);
  }

  Future<void> _openDetalle(String nped) async {
    try {
      final doc = await ref.read(sugeridosApiProvider).fetchOne(nped);
      if (!mounted) return;
      await showDialog<SugeridoOrdenModel>(
        context: context,
        builder: (context) => OrdenCompraDetalleDialog(
          doc: doc,
          onChanged: (_) => _refreshOrders(),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo abrir: $e')));
    }
  }

  Future<void> _runOrderAction(SugeridoOrdenModel order, String action) async {
    try {
      await ref.read(sugeridosApiProvider).action(order.nped, action);
      if (!mounted) return;
      _refreshOrders();
      _snack('O.C. ${order.nped}: accion $action ejecutada.');
    } catch (e) {
      if (!mounted) return;
      _snack('No se pudo ejecutar $action: $e');
    }
  }

  Future<void> _openNuevaOrden() async {
    if (_prov == null || _prov! <= 0) {
      _snack('Selecciona primero un proveedor.');
      return;
    }
    if (_suc.trim().isEmpty) {
      _snack('Selecciona una sucursal para la nueva O.C.');
      return;
    }
    final action = await showDialog<_NuevaOrdenAction>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nueva orden de compra'),
        content: Text(
          'Proveedor $_prov. Selecciona articulos del proveedor o importa un archivo.',
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () =>
                Navigator.pop(context, _NuevaOrdenAction.seleccionar),
            icon: const Icon(Icons.checklist),
            label: const Text('Seleccionar articulos'),
          ),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(context, _NuevaOrdenAction.importar),
            icon: const Icon(Icons.upload_file),
            label: const Text('Importar archivo'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
    if (!mounted || action == null) return;
    if (action == _NuevaOrdenAction.seleccionar) {
      await _selectArticulosProveedor();
    } else {
      await _importOrdenFile();
    }
  }

  Future<void> _selectArticulosProveedor() async {
    final articulos = await _loadArticulosProveedor();
    if (!mounted || articulos.isEmpty) return;
    final selected = await showDialog<List<SugeridoOrdenDraftItem>>(
      context: context,
      builder: (context) => _SeleccionArticulosDialog(articulos: articulos),
    );
    if (selected == null || selected.isEmpty || !mounted) return;
    await _createDraftOrder(selected);
  }

  Future<void> _importOrdenFile() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx', 'xls', 'csv'],
      withData: true,
    );
    final file = picked?.files.single;
    final bytes = file?.bytes;
    if (file == null || bytes == null || bytes.isEmpty) return;
    try {
      final imported = _parseImportRows(file.name, bytes);
      if (imported.isEmpty) {
        _snack('El archivo no contiene articulos para importar.');
        return;
      }
      final articulos = await _loadArticulosProveedor();
      if (!mounted || articulos.isEmpty) return;
      final byArt = {
        for (final item in articulos) item.art.trim().toUpperCase(): item,
      };
      final draft = <SugeridoOrdenDraftItem>[];
      final invalid = <String>[];
      for (final row in imported) {
        final info = byArt[row.art.trim().toUpperCase()];
        if (info == null || info.cto <= 0) {
          invalid.add(row.art);
        } else {
          draft.add(info.toDraft(row.cantidad));
        }
      }
      if (invalid.isNotEmpty) {
        _snack('Articulos fuera del proveedor: ${invalid.take(5).join(', ')}');
        return;
      }
      await _createDraftOrder(draft);
    } catch (e) {
      _snack('No se pudo importar el archivo: $e');
    }
  }

  Future<List<SugeridoArticuloProveedorModel>> _loadArticulosProveedor() async {
    try {
      final items = await ref
          .read(sugeridosApiProvider)
          .articulosProveedor(suc: _suc, prov: _prov!);
      if (items.isEmpty && mounted) {
        _snack('El proveedor no tiene articulos disponibles en $_suc.');
      }
      return items;
    } catch (e) {
      if (mounted) _snack('No se pudieron cargar articulos: $e');
      return const [];
    }
  }

  Future<void> _createDraftOrder(List<SugeridoOrdenDraftItem> items) async {
    try {
      final created = await ref
          .read(sugeridosApiProvider)
          .createRaw(suc: _suc, nprov: _prov!, items: items);
      if (!mounted) return;
      setState(() {
        _docCtrl.text = created.nped;
        _doc = created.nped;
        _page = 1;
        _consulted = true;
      });
      _refreshOrders();
      await showDialog<SugeridoOrdenModel>(
        context: context,
        builder: (context) => OrdenCompraDetalleDialog(
          doc: created,
          onChanged: (_) => _refreshOrders(),
        ),
      );
    } catch (e) {
      if (mounted) _snack('No se pudo crear la O.C.: $e');
    }
  }

  void _refreshOrders() {
    final filters = SugeridosFilters(
      page: _page,
      limit: _limit,
      search: _doc,
      suc: _suc,
      estatus: _estatus,
      prov: _prov,
      fecha: _fecha,
    );
    ref.invalidate(sugeridosProvider(filters));
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

enum _NuevaOrdenAction { seleccionar, importar }

class _OrdenesFilters extends StatelessWidget {
  const _OrdenesFilters({
    required this.docCtrl,
    required this.fechaCtrl,
    required this.suc,
    required this.estatus,
    required this.prov,
    required this.sucsAsync,
    required this.estatusAsync,
    required this.proveedoresAsync,
    required this.onSucChanged,
    required this.onEstatusChanged,
    required this.onProvChanged,
    required this.onFechaPick,
    required this.onApply,
    required this.onClear,
  });

  final TextEditingController docCtrl;
  final TextEditingController fechaCtrl;
  final String suc;
  final String estatus;
  final int? prov;
  final AsyncValue<List<String>> sucsAsync;
  final AsyncValue<List<String>> estatusAsync;
  final AsyncValue<List<SugeridoProveedorModel>> proveedoresAsync;
  final ValueChanged<String?> onSucChanged;
  final ValueChanged<String?> onEstatusChanged;
  final ValueChanged<int?> onProvChanged;
  final VoidCallback onFechaPick;
  final VoidCallback onApply;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 180,
            child: TextField(
              controller: docCtrl,
              decoration: const InputDecoration(
                labelText: 'Documento',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (_) => onApply(),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 170,
            child: sucsAsync.when(
              data: (items) => DropdownButtonFormField<String>(
                initialValue: suc.isEmpty ? null : suc,
                decoration: const InputDecoration(
                  labelText: 'Sucursal',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem(value: '', child: Text('Todas')),
                  ...items.map(
                    (s) => DropdownMenuItem(value: s, child: Text(s)),
                  ),
                ],
                onChanged: onSucChanged,
              ),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Sucursales: $e'),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 290,
            child: proveedoresAsync.when(
              data: (items) => DropdownButtonFormField<int>(
                initialValue: prov,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Proveedor',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem<int>(
                    value: null,
                    child: Text('Todos'),
                  ),
                  ...items.map(
                    (p) => DropdownMenuItem<int>(
                      value: p.id,
                      child: Text(p.label),
                    ),
                  ),
                ],
                onChanged: onProvChanged,
              ),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Proveedores: $e'),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 190,
            child: estatusAsync.when(
              data: (items) => DropdownButtonFormField<String>(
                initialValue: estatus.isEmpty ? null : estatus,
                decoration: const InputDecoration(
                  labelText: 'Estatus',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem(value: '', child: Text('Todos')),
                  ...items.map(
                    (s) => DropdownMenuItem(value: s, child: Text(s)),
                  ),
                ],
                onChanged: onEstatusChanged,
              ),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Estatus: $e'),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 180,
            child: TextField(
              controller: fechaCtrl,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Fecha O.C.',
                hintText: 'YYYY-MM-DD',
                border: OutlineInputBorder(),
                isDense: true,
                suffixIcon: Icon(Icons.calendar_month),
              ),
              onTap: onFechaPick,
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: onApply,
            icon: const Icon(Icons.search),
            label: const Text('Consultar'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.cleaning_services),
            label: const Text('Limpiar'),
          ),
        ],
      ),
    );
  }
}

class _OrdenesTable extends StatelessWidget {
  const _OrdenesTable({
    required this.result,
    required this.onPageChanged,
    required this.onOpen,
    required this.onAction,
  });

  final SugeridosPagedResult<SugeridoOrdenModel> result;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<String> onOpen;
  final void Function(SugeridoOrdenModel order, String action) onAction;

  @override
  Widget build(BuildContext context) {
    final totalPages = result.total <= 0
        ? 1
        : ((result.total + result.limit - 1) ~/ result.limit);
    final from = result.total == 0 ? 0 : ((result.page - 1) * result.limit) + 1;
    final to = ((result.page - 1) * result.limit + result.items.length).clamp(
      0,
      result.total,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Ordenes $from-$to de ${result.total}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                _PageIconButton(
                  tooltip: 'Primera pagina',
                  icon: Icons.first_page,
                  enabled: result.page > 1,
                  onPressed: () => onPageChanged(1),
                ),
                _PageIconButton(
                  tooltip: 'Pagina anterior',
                  icon: Icons.chevron_left,
                  enabled: result.page > 1,
                  onPressed: () => onPageChanged(result.page - 1),
                ),
                Text('Pagina ${result.page} de $totalPages'),
                _PageIconButton(
                  tooltip: 'Pagina siguiente',
                  icon: Icons.chevron_right,
                  enabled: result.page < totalPages,
                  onPressed: () => onPageChanged(result.page + 1),
                ),
                _PageIconButton(
                  tooltip: 'Ultima pagina',
                  icon: Icons.last_page,
                  enabled: result.page < totalPages,
                  onPressed: () => onPageChanged(totalPages),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (result.items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Sin ordenes de compra para los filtros.'),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('O.C.')),
                    DataColumn(label: Text('Sucursal')),
                    DataColumn(label: Text('Proveedor')),
                    DataColumn(label: Text('Estatus')),
                    DataColumn(label: Text('Fecha')),
                    DataColumn(label: Text('Art'), numeric: true),
                    DataColumn(label: Text('Importe'), numeric: true),
                    DataColumn(
                      label: SizedBox(width: 132, child: Text('Acciones')),
                    ),
                  ],
                  rows: [
                    for (final order in result.items)
                      DataRow(
                        cells: [
                          DataCell(Text(order.nped)),
                          DataCell(Text(order.suc)),
                          DataCell(
                            SizedBox(
                              width: 260,
                              child: Text(order.alias ?? '${order.nprov}'),
                            ),
                          ),
                          DataCell(Text(order.estatus)),
                          DataCell(Text(_date(order.fcnp))),
                          DataCell(Text('${order.nart}')),
                          DataCell(Text(_money(order.impp))),
                          DataCell(
                            _OrdenActions(
                              order: order,
                              onOpen: onOpen,
                              onAction: onAction,
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
    );
  }
}

class _OrdenActions extends StatelessWidget {
  const _OrdenActions({
    required this.order,
    required this.onOpen,
    required this.onAction,
  });

  final SugeridoOrdenModel order;
  final ValueChanged<String> onOpen;
  final void Function(SugeridoOrdenModel order, String action) onAction;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            tooltip: 'Ver detalle',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.visibility),
            onPressed: () => onOpen(order.nped),
          ),
          IconButton(
            tooltip: 'Enviar',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.send),
            onPressed: order.estatus == 'ABIERTO'
                ? () => onAction(order, 'enviar')
                : null,
          ),
          IconButton(
            tooltip: 'Autorizar',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.verified),
            onPressed: order.estatus == 'PENDIENTE'
                ? () => onAction(order, 'autorizar')
                : null,
          ),
        ],
      ),
    );
  }
}

class _PageIconButton extends StatelessWidget {
  const _PageIconButton({
    required this.tooltip,
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.outlined(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon),
    );
  }
}

class _LoadingBand extends StatelessWidget {
  const _LoadingBand({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(text),
        ],
      ),
    ),
  );
}

class _ErrorBand extends StatelessWidget {
  const _ErrorBand({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Text(message, style: TextStyle(color: Colors.red.shade700)),
    ),
  );
}

class _SeleccionArticulosDialog extends StatefulWidget {
  const _SeleccionArticulosDialog({required this.articulos});

  final List<SugeridoArticuloProveedorModel> articulos;

  @override
  State<_SeleccionArticulosDialog> createState() =>
      _SeleccionArticulosDialogState();
}

class _SeleccionArticulosDialogState extends State<_SeleccionArticulosDialog> {
  final _searchCtrl = TextEditingController();
  final Map<String, double> _cantidades = {};
  String _search = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final search = _search.trim().toUpperCase();
    final filtered = widget.articulos
        .where(
          (item) =>
              search.isEmpty ||
              item.art.toUpperCase().contains(search) ||
              item.des.toUpperCase().contains(search),
        )
        .take(250)
        .toList();
    final selectedCount = _cantidades.values.where((v) => v > 0).length;
    return AlertDialog(
      title: const Text('Seleccionar articulos'),
      content: SizedBox(
        width: 900,
        height: 560,
        child: Column(
          children: [
            TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                labelText: 'Buscar articulo',
                border: OutlineInputBorder(),
                isDense: true,
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _search = value),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Sel')),
                    DataColumn(label: Text('ART')),
                    DataColumn(label: Text('Descripcion')),
                    DataColumn(label: Text('Costo'), numeric: true),
                    DataColumn(label: Text('Cantidad'), numeric: true),
                  ],
                  rows: [
                    for (final item in filtered)
                      DataRow(
                        selected: (_cantidades[item.art] ?? 0) > 0,
                        cells: [
                          DataCell(
                            Checkbox(
                              value: (_cantidades[item.art] ?? 0) > 0,
                              onChanged: item.cto <= 0
                                  ? null
                                  : (value) => setState(() {
                                      if (value == true) {
                                        _cantidades[item.art] = 1;
                                      } else {
                                        _cantidades.remove(item.art);
                                      }
                                    }),
                            ),
                          ),
                          DataCell(Text(item.art)),
                          DataCell(SizedBox(width: 320, child: Text(item.des))),
                          DataCell(Text(_money(item.cto))),
                          DataCell(
                            SizedBox(
                              width: 90,
                              child: TextFormField(
                                key: ValueKey(
                                  '${item.art}-${_cantidades[item.art] ?? 0}',
                                ),
                                initialValue: ((_cantidades[item.art] ?? 0) > 0)
                                    ? _num(_cantidades[item.art]!)
                                    : '',
                                enabled: item.cto > 0,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                textAlign: TextAlign.right,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (value) {
                                  final qty =
                                      double.tryParse(value.trim()) ?? 0;
                                  setState(() {
                                    if (qty > 0) {
                                      _cantidades[item.art] = qty;
                                    } else {
                                      _cantidades.remove(item.art);
                                    }
                                  });
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        Text('$selectedCount seleccionados'),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: selectedCount == 0
              ? null
              : () => Navigator.pop(
                  context,
                  widget.articulos
                      .where((item) => (_cantidades[item.art] ?? 0) > 0)
                      .map((item) => item.toDraft(_cantidades[item.art]!))
                      .toList(),
                ),
          child: const Text('Crear O.C.'),
        ),
      ],
    );
  }
}

class _ImportOrdenRow {
  const _ImportOrdenRow({required this.art, required this.cantidad});

  final String art;
  final double cantidad;
}

List<_ImportOrdenRow> _parseImportRows(String name, Uint8List bytes) {
  final rows = name.toLowerCase().endsWith('.csv')
      ? _parseCsvRows(bytes)
      : _parseExcelRows(bytes);
  if (rows.isEmpty) return const [];
  final header = rows.first.map((cell) => cell.trim().toUpperCase()).toList();
  var artIndex = header.indexWhere(
    (h) => h == 'ART' || h == 'ARTICULO' || h == 'ARTICULO_ID',
  );
  var qtyIndex = header.indexWhere(
    (h) => h == 'CANTIDAD' || h == 'CANT' || h == 'CTDPED' || h == 'PEDIDO',
  );
  var start = 1;
  if (artIndex < 0 || qtyIndex < 0) {
    artIndex = 0;
    qtyIndex = 1;
    start = 0;
  }
  final parsed = <_ImportOrdenRow>[];
  for (final row in rows.skip(start)) {
    if (row.length <= artIndex || row.length <= qtyIndex) continue;
    final art = row[artIndex].trim();
    final cantidad = double.tryParse(row[qtyIndex].trim()) ?? 0;
    if (art.isNotEmpty && cantidad > 0) {
      parsed.add(_ImportOrdenRow(art: art, cantidad: cantidad));
    }
  }
  return parsed;
}

List<List<String>> _parseExcelRows(Uint8List bytes) {
  final book = xls.Excel.decodeBytes(bytes);
  if (book.tables.isEmpty) return const [];
  final sheet = book.tables.values.first;
  return sheet.rows
      .map((row) => row.map(_excelCellText).toList())
      .where((row) => row.any((cell) => cell.isNotEmpty))
      .toList();
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
      .map(
        (line) => line
            .split(delimiter)
            .map((cell) => cell.trim().replaceAll(RegExp(r'^"|"$'), ''))
            .toList(),
      )
      .where((row) => row.any((cell) => cell.isNotEmpty))
      .toList();
}

String _date(DateTime? value) {
  if (value == null) return '';
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

String _num(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(2);
}

String _money(double value) => '\$${value.toStringAsFixed(2)}';
