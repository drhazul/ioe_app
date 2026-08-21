import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/auth/auth_controller.dart';
import '../../domain/recepciones_models.dart';
import '../../providers/recepciones_provider.dart';

class RecepcionesPage extends ConsumerStatefulWidget {
  const RecepcionesPage({super.key});

  @override
  ConsumerState<RecepcionesPage> createState() => _RecepcionesPageState();
}

class _RecepcionesPageState extends ConsumerState<RecepcionesPage>
    with SingleTickerProviderStateMixin {
  static const _branchManagerRoleId = 13008;
  late final TabController _tabs;
  late final bool _isBranchManager;
  late final String? _assignedSuc;
  final _oc = TextEditingController();
  final _dateFilter = TextEditingController();
  String? _selectedDateIso;
  int? _providerId;
  String? _suc;
  final _historyOc = TextEditingController();
  final _historyDateFilter = TextEditingController();
  String? _historySelectedDateIso;
  int? _historyProviderId;
  String? _historySuc;
  String? _indicatorSuc;
  int _filterRevision = 0;
  int _historyFilterRevision = 0;
  int _indicatorFilterRevision = 0;
  int _page = 1;
  bool _loading = false;
  String? _error;
  static const _sucursales = ['DF01', 'DF04', 'DF05', 'DF06'];
  List<Map<String, dynamic>> _providers = const [];
  bool _loadingProviders = true;
  bool _hasFilteredPending = false;
  bool _hasFilteredHistory = false;
  RecepcionesPageResult<RecepcionOrden>? _pending;
  RecepcionesPageResult<RecepcionResumen>? _history;
  RecepcionIndicadores? _indicators;

  @override
  void initState() {
    super.initState();
    final auth = ref.read(authControllerProvider);
    _isBranchManager = auth.roleId == _branchManagerRoleId;
    final authSuc = auth.suc?.trim().toUpperCase();
    _assignedSuc = authSuc == null || authSuc.isEmpty ? null : authSuc;
    _suc = _isBranchManager ? _assignedSuc : null;
    _tabs = TabController(length: _isBranchManager ? 1 : 3, vsync: this)
      ..addListener(() {
        if (!_tabs.indexIsChanging) {
          setState(() => _page = 1);
          final shouldLoad = switch (_tabs.index) {
            0 => _hasFilteredPending,
            1 => _hasFilteredHistory,
            _ => true,
          };
          if (shouldLoad) {
            _load();
          }
        }
      });
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProviders());
  }

  @override
  void dispose() {
    _tabs.dispose();
    _oc.dispose();
    _dateFilter.dispose();
    _historyOc.dispose();
    _historyDateFilter.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final api = ref.read(recepcionesApiProvider);
    try {
      if (_tabs.index == 0) {
        _pending = await api.pendientes(
          page: _page,
          oc: _oc.text,
          prov: _providerId,
          suc: _suc,
          from: _selectedDateIso,
          to: _selectedDateIso,
        );
      } else if (_tabs.index == 1) {
        _history = await api.historial(
          page: _page,
          oc: _historyOc.text,
          prov: _historyProviderId,
          suc: _historySuc,
          from: _historySelectedDateIso,
          to: _historySelectedDateIso,
        );
      } else {
        _indicators = await api.indicadores(suc: _indicatorSuc);
      }
    } catch (error) {
      _error = _message(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recepción de mercancías'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: [
            const Tab(text: 'Pedidos pendientes'),
            if (!_isBranchManager) ...const [
              Tab(text: 'Histórico'),
              Tab(text: 'Indicadores'),
            ],
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _refresh,
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          _filters(),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          if (_error != null)
            MaterialBanner(
              content: Text(_error!),
              actions: [
                TextButton(onPressed: _load, child: const Text('REINTENTAR')),
              ],
            ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _pendingView(),
                if (!_isBranchManager) ...[_historyView(), _indicatorView()],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filters() {
    if (_tabs.index == 1) return _historyFilters();
    if (_tabs.index == 2) return _indicatorFilters();
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 190,
            child: TextField(
              controller: _oc,
              decoration: const InputDecoration(
                labelText: 'Documento',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _applyPendingFilters(),
            ),
          ),
          SizedBox(
            width: 290,
            child: _loadingProviders
                ? const LinearProgressIndicator()
                : DropdownButtonFormField<int>(
                    key: ValueKey(
                      'pending-provider-$_providerId-$_filterRevision-${_providers.length}',
                    ),
                    initialValue: _providerId,
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
                      ..._providers.map((row) {
                        final rawId = row['ID'] ?? row['id'];
                        final id = rawId is num
                            ? rawId.toInt()
                            : int.tryParse('$rawId') ?? 0;
                        final name = _providerName(row);
                        return DropdownMenuItem<int>(
                          value: id,
                          child: Text(
                            '$id - $name',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }),
                    ],
                    onChanged: (value) => setState(() => _providerId = value),
                  ),
          ),
          SizedBox(
            width: 180,
            child: TextField(
              controller: _dateFilter,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Fecha',
                border: OutlineInputBorder(),
              ),
              onTap: _pickDate,
            ),
          ),
          if (!_isBranchManager)
            SizedBox(
              width: 210,
              child: DropdownButtonFormField<String>(
                key: ValueKey('pending-suc-$_suc-$_filterRevision'),
                initialValue: _suc,
                decoration: const InputDecoration(
                  labelText: 'Sucursal',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Todas')),
                  ..._sucursales.map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text(value)),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _suc = value;
                    _page = 1;
                  });
                },
              ),
            ),
          FilledButton(
            onPressed: _loading ? null : _applyPendingFilters,
            child: const Text('Filtrar'),
          ),
          OutlinedButton(
            onPressed: _loading ? null : _clearPendingFilters,
            child: const Text('Limpiar filtros'),
          ),
        ],
      ),
    );
  }

  Widget _historyFilters() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 190,
            child: TextField(
              controller: _historyOc,
              decoration: const InputDecoration(
                labelText: 'Documento',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _applyHistoryFilters(),
            ),
          ),
          SizedBox(
            width: 290,
            child: _loadingProviders
                ? const LinearProgressIndicator()
                : DropdownButtonFormField<int>(
                    key: ValueKey(
                      'history-provider-$_historyProviderId-$_historyFilterRevision-${_providers.length}',
                    ),
                    initialValue: _historyProviderId,
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
                      ..._providers.map((row) {
                        final rawId = row['ID'] ?? row['id'];
                        final id = rawId is num
                            ? rawId.toInt()
                            : int.tryParse('$rawId') ?? 0;
                        return DropdownMenuItem<int>(
                          value: id,
                          child: Text(
                            '$id - ${_providerName(row)}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }),
                    ],
                    onChanged: (value) =>
                        setState(() => _historyProviderId = value),
                  ),
          ),
          SizedBox(
            width: 180,
            child: TextField(
              controller: _historyDateFilter,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Fecha',
                border: OutlineInputBorder(),
              ),
              onTap: _pickHistoryDate,
            ),
          ),
          SizedBox(
            width: 210,
            child: DropdownButtonFormField<String>(
              key: ValueKey('history-suc-$_historySuc-$_historyFilterRevision'),
              initialValue: _historySuc,
              decoration: const InputDecoration(
                labelText: 'Sucursal',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('Todas')),
                ..._sucursales.map(
                  (value) => DropdownMenuItem(value: value, child: Text(value)),
                ),
              ],
              onChanged: (value) => setState(() {
                _historySuc = value;
                _page = 1;
              }),
            ),
          ),
          FilledButton(
            onPressed: _loading ? null : _applyHistoryFilters,
            child: const Text('Filtrar'),
          ),
          OutlinedButton(
            onPressed: _loading ? null : _clearHistoryFilters,
            child: const Text('Limpiar filtros'),
          ),
        ],
      ),
    );
  }

  Widget _indicatorFilters() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 210,
            child: DropdownButtonFormField<String>(
              key: ValueKey(
                'indicator-suc-$_indicatorSuc-$_indicatorFilterRevision',
              ),
              initialValue: _indicatorSuc,
              decoration: const InputDecoration(
                labelText: 'Sucursal',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('Todas')),
                ..._sucursales.map(
                  (value) => DropdownMenuItem(value: value, child: Text(value)),
                ),
              ],
              onChanged: (value) => setState(() => _indicatorSuc = value),
            ),
          ),
          FilledButton(
            onPressed: _loading ? null : _applyIndicatorFilters,
            child: const Text('Filtrar'),
          ),
          OutlinedButton(
            onPressed: _loading ? null : _clearIndicatorFilters,
            child: const Text('Limpiar filtros'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_selectedDateIso ?? '') ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (selected == null) return;
    setState(() {
      _selectedDateIso =
          '${selected.year.toString().padLeft(4, '0')}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')}';
      _dateFilter.text =
          '${selected.day.toString().padLeft(2, '0')}/${selected.month.toString().padLeft(2, '0')}/${selected.year}';
    });
  }

  Future<void> _pickHistoryDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_historySelectedDateIso ?? '') ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (selected == null) return;
    setState(() {
      _historySelectedDateIso =
          '${selected.year.toString().padLeft(4, '0')}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')}';
      _historyDateFilter.text =
          '${selected.day.toString().padLeft(2, '0')}/${selected.month.toString().padLeft(2, '0')}/${selected.year}';
    });
  }

  void _applyPendingFilters() {
    final hasFilter =
        _oc.text.trim().isNotEmpty ||
        _providerId != null ||
        _selectedDateIso != null ||
        _suc != null ||
        _isBranchManager;
    if (!hasFilter) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Capture al menos un filtro.')),
      );
      return;
    }
    setState(() {
      _hasFilteredPending = true;
      _pending = null;
      _page = 1;
    });
    _load();
  }

  void _applyHistoryFilters() {
    final hasFilter =
        _historyOc.text.trim().isNotEmpty ||
        _historyProviderId != null ||
        _historySelectedDateIso != null ||
        _historySuc != null;
    if (!hasFilter) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Capture al menos un filtro.')),
      );
      return;
    }
    setState(() {
      _hasFilteredHistory = true;
      _history = null;
      _page = 1;
    });
    _load();
  }

  void _applyIndicatorFilters() {
    setState(() => _indicators = null);
    _load();
  }

  Future<void> _loadProviders() async {
    try {
      final rows = await ref.read(recepcionesApiProvider).proveedores();
      if (mounted) {
        setState(() {
          _providers = rows;
          _loadingProviders = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _loadingProviders = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo cargar proveedores: ${_message(error)}'),
          ),
        );
      }
    }
  }

  String _providerName(Map<String, dynamic> row) {
    return '${row['NOMBRE'] ?? row['nombre'] ?? row['ALIAS'] ?? row['RSOC'] ?? ''}'
        .trim();
  }

  void _clearPendingFilters() {
    _oc.clear();
    _dateFilter.clear();
    setState(() {
      _selectedDateIso = null;
      _providerId = null;
      _suc = _isBranchManager ? _assignedSuc : null;
      _filterRevision += 1;
      _hasFilteredPending = false;
      _pending = null;
      _error = null;
      _page = 1;
    });
  }

  void _clearHistoryFilters() {
    _historyOc.clear();
    _historyDateFilter.clear();
    setState(() {
      _historySelectedDateIso = null;
      _historyProviderId = null;
      _historySuc = null;
      _historyFilterRevision += 1;
      _hasFilteredHistory = false;
      _history = null;
      _error = null;
      _page = 1;
    });
  }

  void _clearIndicatorFilters() {
    setState(() {
      _indicatorSuc = null;
      _indicatorFilterRevision += 1;
      _indicators = null;
      _error = null;
    });
    _load();
  }

  void _refresh() {
    if (_tabs.index == 0) {
      _applyPendingFilters();
      return;
    }
    if (_tabs.index == 1) {
      _applyHistoryFilters();
      return;
    }
    _load();
  }

  Widget _pendingView() {
    if (!_hasFilteredPending) {
      return const Center(
        child: Text('Capture al menos un filtro y presione Filtrar.'),
      );
    }
    final data = _pending;
    if (data == null || data.items.isEmpty) {
      return const Center(
        child: Text('No hay órdenes pendientes con los filtros seleccionados.'),
      );
    }
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('O.C.')),
                  DataColumn(label: Text('Sucursal')),
                  DataColumn(label: Text('Proveedor')),
                  DataColumn(label: Text('Fecha')),
                  DataColumn(label: Text('Artículos')),
                  DataColumn(label: Text('Solicitado')),
                  DataColumn(label: Text('Recibido')),
                  DataColumn(label: Text('Pendiente')),
                  DataColumn(label: Text('Estado O.C.')),
                  DataColumn(label: Text('Acciones')),
                ],
                rows: data.items
                    .map(
                      (order) => DataRow(
                        cells: [
                          DataCell(Text(order.nped)),
                          DataCell(Text(order.suc)),
                          DataCell(
                            SizedBox(
                              width: 220,
                              child: Text(
                                order.proveedor,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          DataCell(Text(_date(order.fecha))),
                          DataCell(Text('${order.nart}')),
                          DataCell(Text(_qty(order.solicitado))),
                          DataCell(Text(_qty(order.recibido))),
                          DataCell(Text(_qty(order.pendiente))),
                          DataCell(
                            _status(order.estatusRecepcion ?? order.estatus),
                          ),
                          DataCell(
                            FilledButton.tonalIcon(
                              onPressed: () => _openOrder(order),
                              icon: const Icon(Icons.inventory_2_outlined),
                              label: Text(
                                order.estatusRecepcion == 'RECHAZADO'
                                    ? 'Ver'
                                    : order.docrecActivo == null
                                    ? 'Recibir'
                                    : 'Continuar',
                              ),
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
        _pagination(data.total, data.limit),
      ],
    );
  }

  Widget _historyView() {
    if (!_hasFilteredHistory) {
      return const Center(
        child: Text('Capture al menos un filtro y presione Filtrar.'),
      );
    }
    final data = _history;
    if (data == null || data.items.isEmpty) {
      return const Center(child: Text('No hay recepciones registradas.'));
    }
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: data.items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = data.items[index];
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.receipt_long)),
                  title: Text('Recepción ${item.docrec} · O.C. ${item.nped}'),
                  subtitle: Text(
                    '${item.tipoRecepcion} · ${_date(item.fechaFisica)}${item.tipoDocumento == null ? '' : ' · ${item.tipoDocumento} ${item.folioDocumento ?? ''}'}',
                  ),
                  trailing: _status(item.estatus),
                  onTap: () => _showDocument(item.docrec),
                ),
              );
            },
          ),
        ),
        _pagination(data.total, data.limit),
      ],
    );
  }

  Future<void> _openOrder(RecepcionOrden order) async {
    final accounted = await context.push<bool>(
      '/modulos/recepciones/${order.nped}',
    );
    if (!mounted) return;
    if (accounted == true && !_isBranchManager) {
      setState(() {
        _historyOc.text = order.nped;
        _historyProviderId = null;
        _historySelectedDateIso = null;
        _historyDateFilter.clear();
        _historySuc = null;
        _hasFilteredHistory = true;
        _page = 1;
      });
      _tabs.animateTo(1);
      return;
    }
    await _load();
  }

  Widget _indicatorView() {
    final data = _indicators;
    if (data == null) {
      return const Center(
        child: Text('Consulte para calcular los indicadores.'),
      );
    }
    final cards = <(String, String, IconData)>[
      ('Recepciones', '${data.recepciones}', Icons.inventory),
      ('Pedidos', '${data.pedidos}', Icons.shopping_cart),
      (
        'Cumplimiento proveedor',
        '${data.cumplimiento.toStringAsFixed(1)} %',
        Icons.verified,
      ),
      (
        'Exactitud recepción',
        '${data.exactitud.toStringAsFixed(1)} %',
        Icons.fact_check,
      ),
      ('Incidencias', '${data.incidencias}', Icons.warning_amber),
      (
        'Tiempo promedio',
        '${data.minutosPromedio.toStringAsFixed(0)} min',
        Icons.timer,
      ),
    ];
    return GridView.extent(
      maxCrossAxisExtent: 340,
      padding: const EdgeInsets.all(20),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.2,
      children: cards
          .map(
            (item) => Card(
              child: ListTile(
                leading: Icon(item.$3, size: 34),
                title: Text(item.$1),
                subtitle: Text(
                  item.$2,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _pagination(int total, int limit) {
    final pages = total == 0 ? 1 : (total / limit).ceil();
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: _page > 1
                ? () {
                    setState(() => _page--);
                    _load();
                  }
                : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Text('Página $_page de $pages · $total registros'),
          IconButton(
            onPressed: _page < pages
                ? () {
                    setState(() => _page++);
                    _load();
                  }
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Future<void> _showDocument(String docrec) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final document = await ref.read(recepcionesApiProvider).documento(docrec);
      if (!mounted) return;
      Navigator.of(context).pop();
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Recepción ${document.resumen.docrec}'),
          content: SizedBox(
            width: 720,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'O.C. ${document.resumen.nped} · ${document.suc} · ${document.proveedor}',
                  ),
                  const SizedBox(height: 8),
                  _status(document.resumen.estatus),
                  const Divider(),
                  Text(
                    'Artículos: ${document.detalle.length} · Guías: ${document.guias.length} · Incidencias: ${document.incidencias.length}',
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_message(error))));
      }
    }
  }
}

Widget _status(String value) {
  final status = value.toUpperCase();
  final color = status.contains('CONTABIL') || status == 'RECIBIDO'
      ? Colors.green
      : status.contains('RECHAZ')
      ? Colors.red
      : status.contains('PENDIENTE')
      ? Colors.orange
      : Colors.blue;
  return Chip(
    label: Text(status.replaceAll('_', ' ')),
    side: BorderSide(color: color),
    visualDensity: VisualDensity.compact,
  );
}

String _qty(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(2);
String _date(DateTime? value) => value == null
    ? '-'
    : '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
String _message(Object error) =>
    error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
