import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/api_error.dart';
import '../../../../../core/auth/auth_controller.dart';
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
    final roleId = ref.watch(
      authControllerProvider.select((auth) => auth.roleId),
    );
    final isInventoryChief = roleId == 2;
    final hidePartialStatus = roleId == 2 || roleId == 9005;
    final selectedStatus = hidePartialStatus && _estatus == 'PARCIAL'
        ? ''
        : _estatus;
    final filters = SugeridosFilters(
      page: _page,
      limit: _limit,
      search: _doc,
      suc: _suc,
      estatus: selectedStatus,
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
              estatus: selectedStatus,
              hidePartialStatus: hidePartialStatus,
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
                          canCancelProcessed: isInventoryChief,
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
    final label = action == 'autorizar'
        ? 'autorizar'
        : action == 'enviar'
        ? 'enviar a autorizacion'
        : action == 'anular'
        ? 'cancelar'
        : action;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirmar $label'),
        content: Text('Se va a $label la O.C. ${order.nped}.'),
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
    try {
      await ref.read(sugeridosApiProvider).action(order.nped, action);
      if (!mounted) return;
      _refreshOrders();
      _snack(
        action == 'anular'
            ? 'O.C. ${order.nped} cancelada correctamente.'
            : 'O.C. ${order.nped}: acción $action ejecutada.',
      );
    } catch (e) {
      if (!mounted) return;
      _snack(
        apiErrorMessage(
          e,
          fallback: 'No se pudo $label la O.C. ${order.nped}.',
        ),
      );
    }
  }

  Future<void> _openNuevaOrden() async {
    final contextData = await _pickNuevaOrdenContext();
    if (!mounted || contextData == null) return;
    await _createDraftOrder(contextData, const []);
  }

  Future<_NuevaOrdenContext?> _pickNuevaOrdenContext() async {
    final proveedores = await ref.read(sugeridosProveedoresProvider.future);
    final sucs = await ref.read(sugeridosSucursalesProvider.future);
    if (!mounted) return null;
    if (proveedores.isEmpty) {
      _snack('No hay proveedores disponibles.');
      return null;
    }
    final normalizedSucs = _sucursalesOrdenesPermitidas(sucs);
    if (normalizedSucs.isEmpty) {
      _snack('No hay sucursales disponibles.');
      return null;
    }
    final picked = await showDialog<_NuevaOrdenContext>(
      context: context,
      builder: (context) => _NuevaOrdenProveedorDialog(
        sucs: normalizedSucs,
        proveedores: proveedores,
        initialSuc: _suc,
        initialProv: _prov,
      ),
    );
    if (picked == null || !mounted) return null;
    setState(() {
      _suc = picked.suc;
      _prov = picked.prov;
      _page = 1;
    });
    return picked;
  }

  Future<void> _createDraftOrder(
    _NuevaOrdenContext contextData,
    List<SugeridoOrdenDraftItem> items,
  ) async {
    try {
      final created = await ref
          .read(sugeridosApiProvider)
          .createRaw(
            suc: contextData.suc,
            nprov: contextData.prov,
            items: items,
          );
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

class _NuevaOrdenContext {
  const _NuevaOrdenContext({required this.suc, required this.prov});

  final String suc;
  final int prov;
}

class _NuevaOrdenProveedorDialog extends StatefulWidget {
  const _NuevaOrdenProveedorDialog({
    required this.sucs,
    required this.proveedores,
    required this.initialSuc,
    required this.initialProv,
  });

  final List<String> sucs;
  final List<SugeridoProveedorModel> proveedores;
  final String initialSuc;
  final int? initialProv;

  @override
  State<_NuevaOrdenProveedorDialog> createState() =>
      _NuevaOrdenProveedorDialogState();
}

class _NuevaOrdenProveedorDialogState
    extends State<_NuevaOrdenProveedorDialog> {
  late String _suc;
  int? _prov;

  @override
  void initState() {
    super.initState();
    final initialSuc = widget.initialSuc.trim().toUpperCase();
    _suc = widget.sucs.contains(initialSuc) ? initialSuc : widget.sucs.first;
    final initialProv = widget.initialProv;
    _prov =
        initialProv != null &&
            widget.proveedores.any((provider) => provider.id == initialProv)
        ? initialProv
        : null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Seleccionar sucursal y proveedor'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _suc,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Sucursal',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                for (final suc in widget.sucs)
                  DropdownMenuItem(value: suc, child: Text(suc)),
              ],
              onChanged: (value) => setState(() => _suc = value ?? ''),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _prov,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Proveedor',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                for (final provider in widget.proveedores)
                  DropdownMenuItem(
                    value: provider.id,
                    child: Text(provider.label),
                  ),
              ],
              onChanged: (value) => setState(() => _prov = value),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _suc.isEmpty || _prov == null
              ? null
              : () => Navigator.pop(
                  context,
                  _NuevaOrdenContext(suc: _suc, prov: _prov!),
                ),
          child: const Text('Continuar'),
        ),
      ],
    );
  }
}

class _OrdenesFilters extends StatelessWidget {
  const _OrdenesFilters({
    required this.docCtrl,
    required this.fechaCtrl,
    required this.suc,
    required this.estatus,
    required this.hidePartialStatus,
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
  final bool hidePartialStatus;
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
              data: (items) {
                final sucs = _sucursalesOrdenesPermitidas(items);
                return DropdownButtonFormField<String>(
                  initialValue: suc.isEmpty || !sucs.contains(suc) ? null : suc,
                  decoration: const InputDecoration(
                    labelText: 'Sucursal',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('Todas')),
                    ...sucs.map(
                      (s) => DropdownMenuItem(value: s, child: Text(s)),
                    ),
                  ],
                  onChanged: onSucChanged,
                );
              },
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
              data: (items) {
                final visibleItems = hidePartialStatus
                    ? items
                          .where(
                            (status) =>
                                status.trim().toUpperCase() != 'PARCIAL',
                          )
                          .toList()
                    : items;
                return DropdownButtonFormField<String>(
                  initialValue: estatus.isEmpty ? null : estatus,
                  decoration: const InputDecoration(
                    labelText: 'Estatus',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('Todos')),
                    ...visibleItems.map(
                      (s) => DropdownMenuItem(value: s, child: Text(s)),
                    ),
                  ],
                  onChanged: onEstatusChanged,
                );
              },
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

List<String> _sucursalesOrdenesPermitidas(List<String> items) {
  const requeridas = {'DF01', 'DF04', 'DF05', 'DF06'};
  final sucs = <String>{
    ...items.map((s) => s.trim().toUpperCase()).where((s) => s.isNotEmpty),
    ...requeridas,
  }.where((s) => requeridas.contains(s)).toList()..sort();
  return sucs;
}

class _OrdenesTable extends StatelessWidget {
  const _OrdenesTable({
    required this.result,
    required this.canCancelProcessed,
    required this.onPageChanged,
    required this.onOpen,
    required this.onAction,
  });

  final SugeridosPagedResult<SugeridoOrdenModel> result;
  final bool canCancelProcessed;
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
                      label: SizedBox(width: 172, child: Text('Acciones')),
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
                              canCancelProcessed: canCancelProcessed,
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
    required this.canCancelProcessed,
    required this.onOpen,
    required this.onAction,
  });

  final SugeridoOrdenModel order;
  final bool canCancelProcessed;
  final ValueChanged<String> onOpen;
  final void Function(SugeridoOrdenModel order, String action) onAction;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 172,
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
          IconButton(
            tooltip: 'Cancelar',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.cancel_outlined),
            onPressed:
                order.estatus == 'ABIERTO' ||
                    order.estatus == 'PENDIENTE' ||
                    (canCancelProcessed &&
                        const {
                          'PROCESADO',
                          'VALIDADO',
                          'RECHAZADO',
                        }.contains(order.estatus))
                ? () => onAction(order, 'anular')
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

typedef _BuscarArticulosProveedor =
    Future<List<SugeridoArticuloProveedorModel>> Function({
      required String search,
      required String searchBy,
      String? depa,
      String? subd,
      String? clas,
      String? scla,
      String? scla2,
    });

class _SeleccionArticulosDialog extends StatefulWidget {
  const _SeleccionArticulosDialog({required this.onSearch});

  final _BuscarArticulosProveedor onSearch;

  @override
  State<_SeleccionArticulosDialog> createState() =>
      _SeleccionArticulosDialogState();
}

class _SeleccionArticulosDialogState extends State<_SeleccionArticulosDialog> {
  final _searchCtrl = TextEditingController();
  final _depaCtrl = TextEditingController();
  final _subdCtrl = TextEditingController();
  final _clasCtrl = TextEditingController();
  final _sclaCtrl = TextEditingController();
  final _scla2Ctrl = TextEditingController();
  final Map<String, double> _cantidades = {};
  final Map<String, SugeridoArticuloProveedorModel> _seleccionados = {};
  List<SugeridoArticuloProveedorModel> _items = const [];
  String _searchBy = 'ART';
  bool _loading = false;
  bool _searched = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _depaCtrl.dispose();
    _subdCtrl.dispose();
    _clasCtrl.dispose();
    _sclaCtrl.dispose();
    _scla2Ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _cantidades.values.where((v) => v > 0).length;
    return AlertDialog(
      title: const Text('Seleccionar articulos'),
      insetPadding: const EdgeInsets.all(16),
      content: SizedBox(
        width: MediaQuery.sizeOf(context).width - 64,
        height: MediaQuery.sizeOf(context).height - 180,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _filters(context),
            const SizedBox(height: 10),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            if (_loading) const SizedBox(height: 8),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final showSelectedPanel = constraints.maxWidth >= 980;
                  if (!showSelectedPanel) {
                    return _resultsPanel();
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _resultsPanel()),
                      const SizedBox(width: 12),
                      SizedBox(width: 360, child: _selectedPanel()),
                    ],
                  );
                },
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
                  _seleccionados.values
                      .where((item) => (_cantidades[item.art] ?? 0) > 0)
                      .map((item) => item.toDraft(_cantidades[item.art]!))
                      .toList(),
                ),
          child: const Text('Crear O.C.'),
        ),
      ],
    );
  }

  Widget _filters(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Filtros de busqueda',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
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
              width: 300,
              child: TextField(
                controller: _searchCtrl,
                decoration: const InputDecoration(
                  labelText: 'Buscar articulo',
                  border: OutlineInputBorder(),
                  isDense: true,
                  prefixIcon: Icon(Icons.search),
                ),
                onSubmitted: (_) => _search(),
              ),
            ),
            _filterField(_depaCtrl, 'DEPA'),
            _filterField(_subdCtrl, 'SUBD'),
            _filterField(_clasCtrl, 'CLAS'),
            _filterField(_sclaCtrl, 'SCLA'),
            _filterField(_scla2Ctrl, 'SCLA2'),
            FilledButton.icon(
              onPressed: _loading ? null : _search,
              icon: const Icon(Icons.search),
              label: const Text('Buscar'),
            ),
            OutlinedButton.icon(
              onPressed: _loading ? null : _clearFilters,
              icon: const Icon(Icons.cleaning_services),
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

  Widget _resultsPanel() {
    if (!_searched) {
      return const Center(
        child: Text(
          'Capture filtros y presione Buscar para agregar articulos.',
        ),
      );
    }
    if (!_loading && _items.isEmpty) {
      return const Center(child: Text('Sin articulos para el filtro. '));
    }
    return Scrollbar(
      child: SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Sel')),
              DataColumn(label: Text('ART')),
              DataColumn(label: Text('UPC')),
              DataColumn(label: Text('Descripcion')),
              DataColumn(label: Text('Costo'), numeric: true),
              DataColumn(label: Text('Cantidad'), numeric: true),
            ],
            rows: [
              for (final item in _items)
                DataRow(
                  selected: (_cantidades[item.art] ?? 0) > 0,
                  cells: [
                    DataCell(
                      Checkbox(
                        value: (_cantidades[item.art] ?? 0) > 0,
                        onChanged: item.cto <= 0
                            ? null
                            : (value) =>
                                  _setCantidad(item, value == true ? 1 : 0),
                      ),
                    ),
                    DataCell(Text(item.art)),
                    DataCell(Text(item.upc ?? '')),
                    DataCell(SizedBox(width: 360, child: Text(item.des))),
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
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          textAlign: TextAlign.right,
                          decoration: const InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) {
                            final qty =
                                double.tryParse(value.replaceAll(',', '.')) ??
                                0;
                            _setCantidad(item, qty);
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
    );
  }

  Widget _selectedPanel() {
    final items = _seleccionados.values
        .where((item) => (_cantidades[item.art] ?? 0) > 0)
        .toList();
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'Articulos agregados',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('Sin articulos seleccionados.'))
                : ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return ListTile(
                        dense: true,
                        title: Text('${item.art} | ${item.des}'),
                        subtitle: Text(
                          'Cantidad ${_num(_cantidades[item.art] ?? 0)}',
                        ),
                        trailing: IconButton(
                          tooltip: 'Quitar',
                          icon: const Icon(Icons.close),
                          onPressed: () => _setCantidad(item, 0),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _search() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _searched = true;
    });
    try {
      final items = await widget.onSearch(
        search: _searchCtrl.text,
        searchBy: _searchBy,
        depa: _depaCtrl.text,
        subd: _subdCtrl.text,
        clas: _clasCtrl.text,
        scla: _sclaCtrl.text,
        scla2: _scla2Ctrl.text,
      );
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _items = const [];
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudieron cargar articulos: $e')),
      );
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
      _searchBy = 'ART';
      _items = const [];
      _searched = false;
    });
  }

  void _setCantidad(SugeridoArticuloProveedorModel item, double qty) {
    setState(() {
      if (qty > 0) {
        _cantidades[item.art] = qty;
        _seleccionados[item.art] = item;
      } else {
        _cantidades.remove(item.art);
        _seleccionados.remove(item.art);
      }
    });
  }
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
