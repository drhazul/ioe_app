import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/auth_controller.dart';
import 'promociones_models.dart';
import 'promociones_providers.dart';

class PromocionesPage extends ConsumerStatefulWidget {
  const PromocionesPage({super.key});

  @override
  ConsumerState<PromocionesPage> createState() => _PromocionesPageState();
}

class _PromocionesPageState extends ConsumerState<PromocionesPage> {
  final _searchCtrl = TextEditingController();
  String _searchApplied = '';
  String _status = 'TODOS';
  String _selectedSucursal = 'TODAS';
  String _selectedTipoProm = 'TODOS';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final isAdmin =
        (auth.roleId ?? 0) == 1 ||
        (auth.username ?? '').trim().toUpperCase() == 'ADMIN';
    final asyncItems = ref.watch(promocionesListProvider);
    final sucOptionsAsync = ref.watch(promoSucursalesProvider);
    final tipoOptionsAsync = ref.watch(promoTiposPromocionProvider);
    final sucOptions = sucOptionsAsync.maybeWhen(
      data: (rows) {
        final out = <CatalogTextOptionModel>[
          const CatalogTextOptionModel(valor: 'TODAS', descripcion: 'TODAS'),
        ];
        final seen = <String>{'TODAS'};
        for (final row in rows) {
          final value = row.valor.trim().toUpperCase();
          if (value.isEmpty || seen.contains(value)) continue;
          seen.add(value);
          out.add(
            CatalogTextOptionModel(
              valor: value,
              descripcion: '$value - ${row.descripcion.trim()}',
            ),
          );
        }
        return out;
      },
      orElse: () => const <CatalogTextOptionModel>[
        CatalogTextOptionModel(valor: 'TODAS', descripcion: 'TODAS'),
      ],
    );
    final tipoOptions = tipoOptionsAsync.maybeWhen(
      data: (rows) {
        final out = <CatalogOptionModel>[
          const CatalogOptionModel(clave: 'TODOS', descripcion: 'TODOS'),
        ];
        final seen = <String>{'TODOS'};
        for (final row in rows) {
          final key = row.clave.trim().toUpperCase();
          if (key.isEmpty || seen.contains(key)) continue;
          seen.add(key);
          out.add(row);
        }
        return out;
      },
      orElse: () => const <CatalogOptionModel>[
        CatalogOptionModel(clave: 'TODOS', descripcion: 'TODOS'),
      ],
    );
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        title: const Text('Gestión de promociones'),
        actions: [
          IconButton(
            tooltip: 'Refrescar',
            onPressed: () => ref.invalidate(promocionesListProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createPromocion,
        child: const Icon(Icons.add),
      ),
      body: asyncItems.when(
        data: (items) => _buildList(
          items,
          sucOptions,
          tipoOptions,
          isAdmin: isAdmin,
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildList(
    List<PromocionModel> items,
    List<CatalogTextOptionModel> sucOptions,
    List<CatalogOptionModel> tipoOptions,
    {required bool isAdmin}
  ) {
    final term = _searchApplied.trim().toLowerCase();
    final filtered =
        items.where((item) {
          if (_status == 'ACTIVO' && !item.isActive) return false;
          if (_status == 'INACTIVO' && item.isActive) return false;
          if (_selectedSucursal != 'TODAS') {
            if (!_promoMatchesSucursal(item.suc, _selectedSucursal)) {
              return false;
            }
          }
          if (_selectedTipoProm != 'TODOS') {
            final type = (item.tProm ?? '').trim().toUpperCase();
            if (type != _selectedTipoProm) return false;
          }
          if (term.isEmpty) return true;
          final text =
              '${item.idProm} ${item.descPromo ?? ''} ${item.tProm ?? ''} ${item.tipoDesc ?? ''} ${item.suc ?? ''}'
                  .toLowerCase();
          return text.contains(term);
        }).toList()..sort((a, b) {
          final pa = a.prioridad ?? 9999;
          final pb = b.prioridad ?? 9999;
          if (pa != pb) return pa.compareTo(pb);
          return b.idProm.compareTo(a.idProm);
        });

    return RefreshIndicator(
      onRefresh: () async => ref.refresh(promocionesListProvider.future),
      child: ListView(
        padding: const EdgeInsets.all(12),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _FiltersBar(
            searchController: _searchCtrl,
            selectedStatus: _status,
            selectedSucursal: _selectedSucursal,
            selectedTipoProm: _selectedTipoProm,
            sucursales: sucOptions,
            tiposPromocion: tipoOptions,
            onApply: () => setState(() => _searchApplied = _searchCtrl.text),
            onClear: () => setState(() {
              _searchCtrl.clear();
              _searchApplied = '';
              _status = 'TODOS';
              _selectedSucursal = 'TODAS';
              _selectedTipoProm = 'TODOS';
            }),
            onStatusChanged: (value) =>
                setState(() => _status = value ?? 'TODOS'),
            onSucursalChanged: (value) =>
                setState(() => _selectedSucursal = value ?? 'TODAS'),
            onTipoPromChanged: (value) =>
                setState(() => _selectedTipoProm = value ?? 'TODOS'),
          ),
          const SizedBox(height: 12),
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(child: Text('No hay promociones para los filtros')),
            )
          else
            ...filtered.asMap().entries.map(
              (entry) =>
                  _tile(
                    entry.value,
                    index: entry.key,
                    total: filtered.length,
                    isAdmin: isAdmin,
                  ),
            ),
        ],
      ),
    );
  }

  Widget _tile(
    PromocionModel item, {
    required int index,
    required int total,
    required bool isAdmin,
  }) {
    final color = item.isActive ? Colors.green : Colors.red;
    final vig =
        '${_fmtDate(item.fcnIni)} a ${_fmtDate(item.fcnTer)} | PRIO ${item.prioridad ?? '-'}';
    return Card(
      child: ExpansionTile(
        leading: Icon(
          item.isActive ? Icons.check_circle : Icons.block,
          color: color,
        ),
        title: Text(
          item.descPromo?.trim().isNotEmpty == true
              ? item.descPromo!
              : 'Promo ${item.idProm}',
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ID ${item.idProm} | SUC ${item.suc ?? '-'} | ${item.tipoDesc ?? '-'} | $vig',
            ),
            const SizedBox(height: 2),
            _PromoCriteriaSummaryText(idProm: item.idProm),
          ],
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _editPromocion(item),
                icon: const Icon(Icons.edit),
                label: const Text('Editar'),
              ),
              OutlinedButton.icon(
                onPressed: () => _configPromocion(item),
                icon: const Icon(Icons.settings),
                label: const Text('Configuración'),
              ),
              OutlinedButton.icon(
                onPressed: () => _inactivarPromocion(item),
                icon: const Icon(Icons.pause_circle_outline),
                label: const Text('Inactivar'),
              ),
              if (isAdmin)
                OutlinedButton.icon(
                  onPressed: () => _eliminarPromocion(item),
                  icon: const Icon(Icons.delete_forever),
                  label: const Text('Eliminar'),
                ),
              OutlinedButton.icon(
                onPressed: index <= 0
                    ? null
                    : () => _movePrioridad(item, index - 1),
                icon: const Icon(Icons.arrow_upward),
                label: const Text('Subir'),
              ),
              OutlinedButton.icon(
                onPressed: index >= (total - 1)
                    ? null
                    : () => _movePrioridad(item, index + 1),
                icon: const Icon(Icons.arrow_downward),
                label: const Text('Bajar'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _movePrioridad(PromocionModel item, int targetIndex) async {
    try {
      final targetPriority = targetIndex + 1;
      await ref
          .read(promocionesApiProvider)
          .reorderPrioridad(item.idProm, targetPriority);
      ref.invalidate(promocionesListProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Prioridad actualizada: promo ${item.idProm} -> $targetPriority',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error prioridad: $e')));
    }
  }

  Future<void> _createPromocion() async {
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _PromocionDialog(),
    );
    if (payload == null) return;
    try {
      await ref.read(promocionesApiProvider).createPromocion(payload);
      ref.invalidate(promocionesListProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Promoción creada')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _editPromocion(PromocionModel item) async {
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _PromocionDialog(item: item),
    );
    if (payload == null) return;
    try {
      await ref
          .read(promocionesApiProvider)
          .updatePromocion(item.idProm, payload);
      ref.invalidate(promocionesListProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Promoción actualizada')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _configPromocion(PromocionModel item) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _ConfigDialog(item: item),
    );
    ref.invalidate(promoConfigProvider(item.idProm));
    ref.invalidate(promocionesListProvider);
  }

  Future<void> _inactivarPromocion(PromocionModel item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Inactivar promoción'),
        content: Text('Se inactivará la promoción ${item.idProm}.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Inactivar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(promocionesApiProvider).deletePromocion(item.idProm);
    ref.invalidate(promocionesListProvider);
  }

  Future<void> _eliminarPromocion(PromocionModel item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar promoción'),
        content: Text(
          'Se eliminará definitivamente la promoción ${item.idProm}. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(promocionesApiProvider).hardDeletePromocion(item.idProm);
    ref.invalidate(promocionesListProvider);
  }

  String _fmtDate(DateTime? value) {
    if (value == null) return '-';
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  bool _promoMatchesSucursal(String? rawSucs, String selected) {
    final cleaned = (rawSucs ?? '').trim().toUpperCase();
    if (cleaned.isEmpty || cleaned == '*') return true;
    final tokens = cleaned
        .replaceAll(';', ',')
        .split(',')
        .map((x) => x.trim())
        .where((x) => x.isNotEmpty)
        .toSet();
    return tokens.contains(selected.toUpperCase());
  }
}

class _FiltersBar extends StatelessWidget {
  const _FiltersBar({
    required this.searchController,
    required this.selectedStatus,
    required this.selectedSucursal,
    required this.selectedTipoProm,
    required this.sucursales,
    required this.tiposPromocion,
    required this.onApply,
    required this.onClear,
    required this.onStatusChanged,
    required this.onSucursalChanged,
    required this.onTipoPromChanged,
  });

  final TextEditingController searchController;
  final String selectedStatus;
  final String selectedSucursal;
  final String selectedTipoProm;
  final List<CatalogTextOptionModel> sucursales;
  final List<CatalogOptionModel> tiposPromocion;
  final VoidCallback onApply;
  final VoidCallback onClear;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onSucursalChanged;
  final ValueChanged<String?> onTipoPromChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: searchController,
                decoration: const InputDecoration(
                  labelText: 'Buscar por descripción, tipo, sucursal o id',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => onApply(),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: onApply,
              icon: const Icon(Icons.search),
              label: const Text('Filtrar'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.refresh),
              label: const Text('Limpiar'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          key: ValueKey(selectedStatus),
          initialValue: selectedStatus,
          decoration: const InputDecoration(
            labelText: 'Estado',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'TODOS', child: Text('TODOS')),
            DropdownMenuItem(value: 'ACTIVO', child: Text('ACTIVO')),
            DropdownMenuItem(value: 'INACTIVO', child: Text('INACTIVO')),
          ],
          onChanged: onStatusChanged,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                key: ValueKey(selectedSucursal),
                initialValue: selectedSucursal,
                decoration: const InputDecoration(
                  labelText: 'Sucursal',
                  border: OutlineInputBorder(),
                ),
                items: sucursales
                    .map(
                      (s) => DropdownMenuItem(
                        value: s.valor,
                        child: Text(s.descripcion),
                      ),
                    )
                    .toList(),
                onChanged: onSucursalChanged,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<String>(
                key: ValueKey(selectedTipoProm),
                initialValue: selectedTipoProm,
                decoration: const InputDecoration(
                  labelText: 'Tipo promoción',
                  border: OutlineInputBorder(),
                ),
                items: tiposPromocion
                    .map(
                      (t) => DropdownMenuItem(
                        value: t.clave.trim().toUpperCase(),
                        child: Text(
                          t.clave.trim().toUpperCase() == 'TODOS'
                              ? 'TODOS'
                              : '${t.clave} - ${t.descripcion}',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: onTipoPromChanged,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PromocionDialog extends StatefulWidget {
  const _PromocionDialog({this.item});
  final PromocionModel? item;

  @override
  State<_PromocionDialog> createState() => _PromocionDialogState();
}

class _PromocionDialogState extends State<_PromocionDialog> {
  late final TextEditingController _descCtrl;
  late final TextEditingController _prioCtrl;
  late final TextEditingController _fIniCtrl;
  late final TextEditingController _fTerCtrl;
  bool _activo = true;
  bool _acumulable = false;
  bool _combinable = false;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _descCtrl = TextEditingController(text: item?.descPromo ?? '');
    _prioCtrl = TextEditingController(
      text: (item?.prioridad ?? 100).toString(),
    );
    _fIniCtrl = TextEditingController(text: _fmtDate(item?.fcnIni));
    _fTerCtrl = TextEditingController(text: _fmtDate(item?.fcnTer));
    _activo = item == null ? true : item.isActive;
    _acumulable = (item?.acumulable ?? 0) == 1;
    _combinable = (item?.combinable ?? 0) == 1;
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _prioCtrl.dispose();
    _fIniCtrl.dispose();
    _fTerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.item == null ? 'Nueva promoción' : 'Editar promoción'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _descCtrl,
                decoration: const InputDecoration(labelText: 'Descripción'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _prioCtrl,
                      enabled: false,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'PRIORIDAD',
                        helperText: 'Se gestiona con proceso de orden global',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _fIniCtrl,
                      readOnly: true,
                      onTap: () => _pickDate(_fIniCtrl),
                      decoration: const InputDecoration(
                        labelText: 'FCN_INI (YYYY-MM-DD)',
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _fTerCtrl,
                      readOnly: true,
                      onTap: () => _pickDate(_fTerCtrl),
                      decoration: const InputDecoration(
                        labelText: 'FCN_TER (YYYY-MM-DD)',
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: SwitchListTile(
                      value: _activo,
                      dense: true,
                      title: const Text('Activa'),
                      onChanged: (value) => setState(() => _activo = value),
                    ),
                  ),
                  Expanded(
                    child: SwitchListTile(
                      value: _acumulable,
                      dense: true,
                      title: const Text('Acumulable'),
                      onChanged: (value) => setState(() => _acumulable = value),
                    ),
                  ),
                  Expanded(
                    child: SwitchListTile(
                      value: _combinable,
                      dense: true,
                      title: const Text('Combinable'),
                      onChanged: (value) => setState(() => _combinable = value),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Guardar')),
      ],
    );
  }

  void _submit() {
    final desc = _descCtrl.text.trim();
    if (desc.isEmpty) return;
    Navigator.of(context).pop({
      'DESC_PROMO': desc,
      'PRIORIDAD': _int(_prioCtrl.text) ?? 100,
      'FCN_INI': _date(_fIniCtrl.text),
      'FCN_TER': _date(_fTerCtrl.text),
      'EST': _activo ? 1 : 0,
      'ACUMULABLE': _acumulable ? 1 : 0,
      'COMBINABLE': _combinable ? 1 : 0,
    });
  }

  Future<void> _pickDate(TextEditingController ctrl) async {
    DateTime initial = DateTime.now();
    final parsed = DateTime.tryParse(ctrl.text.trim());
    if (parsed != null) initial = parsed;
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      initialDate: initial,
    );
    if (picked == null) return;
    final y = picked.year.toString().padLeft(4, '0');
    final m = picked.month.toString().padLeft(2, '0');
    final d = picked.day.toString().padLeft(2, '0');
    ctrl.text = '$y-$m-$d';
  }
}

class _ConfigDialog extends ConsumerStatefulWidget {
  const _ConfigDialog({required this.item});
  final PromocionModel item;

  @override
  ConsumerState<_ConfigDialog> createState() => _ConfigDialogState();
}

class _ConfigDialogState extends ConsumerState<_ConfigDialog> {
  bool _loading = true;
  bool _saving = false;

  List<CatalogTextOptionModel> _sucs = const [];
  List<CatalogOptionModel> _tBenef = const [];
  List<CatalogNumOptionModel> _depas = const [];
  List<CatalogNumOptionModel> _subds = const [];
  List<CatalogNumOptionModel> _clases = const [];
  List<CatalogNumOptionModel> _sclas = const [];
  List<CatalogNumOptionModel> _scla2s = const [];
  List<CatalogTextOptionModel> _guias = const [];
  List<Map<String, dynamic>> _clientes = const [];

  String? _tBeneficio;
  bool _sucTodas = true;
  List<String> _sucSel = [];
  int? _clienteSel;
  List<int> _depaSel = [];
  List<int> _subdSel = [];
  List<int> _clasSel = [];
  List<int> _sclaSel = [];
  List<int> _scla2Sel = [];
  List<String> _guiaSel = [];
  List<String> _artSel = [];
  List<String> _upcSel = [];
  final _prcCtrl = TextEditingController();
  final _impCtrl = TextEditingController();
  final _precioGratisCtrl = TextEditingController(text: '0.01');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _prcCtrl.dispose();
    _impCtrl.dispose();
    _precioGratisCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final api = ref.read(promocionesApiProvider);
    try {
      final suc = await api.fetchSucursales();
      final tBenef = await api.fetchCatalogOptions('t-beneficio');
      final depas = await api.fetchDepa();
      final cfg = await api.fetchConfig(widget.item.idProm);
      _sucs = suc;
      _tBenef = tBenef;
      _depas = depas;
      if (cfg != null) {
        _tBeneficio = cfg.tBeneficio;
        _sucTodas = cfg.sucTodas;
        _sucSel = List<String>.from(cfg.sucList);
        _clienteSel = (cfg.cliente != null && cfg.cliente! > 0)
            ? cfg.cliente
            : null;
        _depaSel = List<int>.from(cfg.depaList);
        _subdSel = List<int>.from(cfg.subdList);
        _clasSel = List<int>.from(cfg.clasList);
        _sclaSel = List<int>.from(cfg.sclaList);
        _scla2Sel = List<int>.from(cfg.scla2List);
        _guiaSel = List<String>.from(cfg.guiaList);
        _artSel = List<String>.from(cfg.artList);
        _upcSel = List<String>.from(cfg.upcList);
        if (cfg.prcDesc != null) _prcCtrl.text = cfg.prcDesc.toString();
        final impDesc = cfg.impDesc;
        if (impDesc != null) _impCtrl.text = impDesc.toStringAsFixed(2);
        final precioGratis = cfg.precioGratis;
        if (precioGratis != null) {
          _precioGratisCtrl.text = precioGratis.toStringAsFixed(2);
        }
      }
      await _reloadHierarchyCatalogs();
      await _loadClientes();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadClientes() async {
    if (_sucTodas || _sucSel.length != 1) {
      _clientes = const [];
      _clienteSel = null;
      return;
    }
    _clientes = await ref
        .read(promocionesApiProvider)
        .fetchClientes(suc: _sucSel.first);
    if (_clienteSel != null &&
        !_clientes.any((x) => _asPositiveInt(x['cliente']) == _clienteSel)) {
      _clienteSel = null;
    }
  }

  Future<void> _reloadHierarchyCatalogs() async {
    final api = ref.read(promocionesApiProvider);
    _subds = await api.fetchSubd(_depaSel);
    _clases = await api.fetchClas(_subdSel);
    _sclas = await api.fetchScla(_clasSel);
    _scla2s = await api.fetchScla2(_sclaSel);
    _guias = await api.fetchGuia(_scla2Sel);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AlertDialog(
        content: SizedBox(
          height: 120,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    final canPrc = _tBeneficio == 'PORCENTAJE';
    final canImp = _tBeneficio == 'IMP_FIJO';
    final canGratis = _tBeneficio == 'ART_GRATIS';
    return AlertDialog(
      title: Text('Configuración promo ${widget.item.idProm}'),
      content: SizedBox(
        width: 980,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Beneficio',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _tBeneficio,
                      decoration: const InputDecoration(
                        labelText: 'T_BENEFICIO',
                        border: OutlineInputBorder(),
                      ),
                      items: _tBenef
                          .map(
                            (x) => DropdownMenuItem(
                              value: x.clave,
                              child: Text('${x.clave} - ${x.descripcion}'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() {
                        _tBeneficio = value;
                        if (_tBeneficio == 'PORCENTAJE') _impCtrl.clear();
                        if (_tBeneficio == 'IMP_FIJO') _prcCtrl.clear();
                        if (_tBeneficio != 'ART_GRATIS' &&
                            _precioGratisCtrl.text.trim().isEmpty) {
                          _precioGratisCtrl.text = '0.01';
                        }
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _addTipoBeneficio,
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar tipo'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _prcCtrl,
                      enabled: canPrc,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'PRC_DESC',
                        prefixText: '% ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _impCtrl,
                      enabled: canImp,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'IMP_DESC',
                        prefixText: '\$ ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              if (canGratis) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _precioGratisCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'PRECIO_GRATIS',
                    prefixText: '\$ ',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'Criterios',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('TODAS las sucursales'),
                value: _sucTodas,
                onChanged: (value) async {
                  setState(() {
                    _sucTodas = value;
                    if (value) {
                      _sucSel = [];
                      _clienteSel = null;
                    }
                    _depaSel = [];
                    _subdSel = [];
                    _clasSel = [];
                    _sclaSel = [];
                    _scla2Sel = [];
                    _guiaSel = [];
                  });
                  await _loadClientes();
                  final suc = (!_sucTodas && _sucSel.length == 1)
                      ? _sucSel.first
                      : null;
                  _depas = await ref
                      .read(promocionesApiProvider)
                      .fetchDepa(suc: suc);
                  await _reloadHierarchyCatalogs();
                  if (mounted) setState(() {});
                },
              ),
              if (!_sucTodas)
                _MultiSelectButton<String>(
                  label: 'SUC',
                  selected: _sucSel,
                  options: _sucs
                      .where((x) => x.valor != '*')
                      .map(
                        (x) => _Option(
                          value: x.valor,
                          label: '${x.valor} - ${x.descripcion}',
                        ),
                      )
                      .toList(),
                  onChanged: (values) async {
                    setState(() {
                      _sucSel = values;
                      if (_sucSel.length != 1) _clienteSel = null;
                      _depaSel = [];
                      _subdSel = [];
                      _clasSel = [];
                      _sclaSel = [];
                      _scla2Sel = [];
                      _guiaSel = [];
                    });
                    await _loadClientes();
                    final suc = (!_sucTodas && _sucSel.length == 1)
                        ? _sucSel.first
                        : null;
                    _depas = await ref
                        .read(promocionesApiProvider)
                        .fetchDepa(suc: suc);
                    await _reloadHierarchyCatalogs();
                    if (mounted) setState(() {});
                  },
                ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: _clienteSel,
                decoration: const InputDecoration(
                  labelText: 'CLIENTE',
                  border: OutlineInputBorder(),
                ),
                items: _clientes
                    .map((x) {
                      final cliente = _asPositiveInt(x['cliente']);
                      if (cliente == null) return null;
                      return DropdownMenuItem<int>(
                        value: cliente,
                        child: Text(
                          '${x['cliente']} - ${(x['nombre'] ?? '').toString()}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    })
                    .whereType<DropdownMenuItem<int>>()
                    .toList(),
                onChanged: (_sucTodas || _sucSel.length != 1)
                    ? null
                    : (value) => setState(() => _clienteSel = value),
              ),
              const SizedBox(height: 8),
              _MultiSelectButton<int>(
                label: 'DEPA',
                selected: _depaSel,
                options: _depas
                    .map(
                      (x) => _Option(
                        value: x.valor,
                        label: '${x.valor} - ${x.descripcion}',
                      ),
                    )
                    .toList(),
                onChanged: (values) async {
                  setState(() {
                    _depaSel = values;
                    _subdSel = [];
                    _clasSel = [];
                    _sclaSel = [];
                    _scla2Sel = [];
                    _guiaSel = [];
                  });
                  await _reloadHierarchyCatalogs();
                  if (mounted) setState(() {});
                },
              ),
              const SizedBox(height: 8),
              _MultiSelectButton<int>(
                label: 'SUBD',
                selected: _subdSel,
                options: _subds
                    .map(
                      (x) => _Option(
                        value: x.valor,
                        label: '${x.valor} - ${x.descripcion}',
                      ),
                    )
                    .toList(),
                onChanged: (values) async {
                  setState(() {
                    _subdSel = values;
                    _clasSel = [];
                    _sclaSel = [];
                    _scla2Sel = [];
                    _guiaSel = [];
                  });
                  await _reloadHierarchyCatalogs();
                  if (mounted) setState(() {});
                },
              ),
              const SizedBox(height: 8),
              _MultiSelectButton<int>(
                label: 'CLAS',
                selected: _clasSel,
                options: _clases
                    .map(
                      (x) => _Option(
                        value: x.valor,
                        label: '${x.valor} - ${x.descripcion}',
                      ),
                    )
                    .toList(),
                onChanged: (values) async {
                  setState(() {
                    _clasSel = values;
                    _sclaSel = [];
                    _scla2Sel = [];
                    _guiaSel = [];
                  });
                  await _reloadHierarchyCatalogs();
                  if (mounted) setState(() {});
                },
              ),
              const SizedBox(height: 8),
              _MultiSelectButton<int>(
                label: 'SCLA',
                selected: _sclaSel,
                options: _sclas
                    .map(
                      (x) => _Option(
                        value: x.valor,
                        label: '${x.valor} - ${x.descripcion}',
                      ),
                    )
                    .toList(),
                onChanged: (values) async {
                  setState(() {
                    _sclaSel = values;
                    _scla2Sel = [];
                    _guiaSel = [];
                  });
                  await _reloadHierarchyCatalogs();
                  if (mounted) setState(() {});
                },
              ),
              const SizedBox(height: 8),
              _MultiSelectButton<int>(
                label: 'SCLA2',
                selected: _scla2Sel,
                options: _scla2s
                    .map(
                      (x) => _Option(
                        value: x.valor,
                        label: '${x.valor} - ${x.descripcion}',
                      ),
                    )
                    .toList(),
                onChanged: (values) async {
                  setState(() {
                    _scla2Sel = values;
                    _guiaSel = [];
                  });
                  await _reloadHierarchyCatalogs();
                  if (mounted) setState(() {});
                },
              ),
              const SizedBox(height: 8),
              _MultiSelectButton<String>(
                label: 'GUIA',
                selected: _guiaSel,
                options: _guias
                    .map(
                      (x) => _Option(
                        value: x.valor,
                        label: '${x.valor} - ${x.descripcion}',
                      ),
                    )
                    .toList(),
                onChanged: (values) => setState(() => _guiaSel = values),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickArts,
                      icon: const Icon(Icons.list_alt),
                      label: Text(
                        _artSel.isEmpty
                            ? 'Seleccionar ART (opcional)'
                            : 'ART seleccionados: ${_artSel.length}',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickUpcs,
                      icon: const Icon(Icons.qr_code),
                      label: Text(
                        _upcSel.isEmpty
                            ? 'Seleccionar UPC (opcional)'
                            : 'UPC seleccionados: ${_upcSel.length}',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _CriteriaResumeCard(
                sucTodas: _sucTodas,
                sucSel: _sucSel,
                clienteSel: _clienteSel,
                depaSel: _depaSel,
                subdSel: _subdSel,
                clasSel: _clasSel,
                sclaSel: _sclaSel,
                scla2Sel: _scla2Sel,
                guiaSel: _guiaSel,
                artSel: _artSel,
                upcSel: _upcSel,
                depas: _depas,
                subds: _subds,
                clases: _clases,
                sclas: _sclas,
                scla2s: _scla2s,
                guias: _guias,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('Guardar configuración'),
        ),
      ],
    );
  }

  Future<void> _addTipoBeneficio() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const _CatalogAddDialog(),
    );
    if (result == null) return;
    final rows = await ref
        .read(promocionesApiProvider)
        .addCatalogOption(
          't-beneficio',
          clave: result['clave'] ?? '',
          descripcion: result['descripcion'] ?? '',
        );
    if (!mounted) return;
    setState(() {
      _tBenef = rows;
      _tBeneficio = (result['clave'] ?? '').trim().toUpperCase();
    });
  }

  Future<void> _pickArts() async {
    if (_upcSel.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Limpia UPC antes de seleccionar ART')),
      );
      return;
    }
    final suc = (!_sucTodas && _sucSel.isNotEmpty) ? _sucSel.join(',') : null;
    final rows = await ref
        .read(promocionesApiProvider)
        .fetchArticulos(
          suc: suc,
          depa: _depaSel,
          subd: _subdSel,
          clas: _clasSel,
          scla: _sclaSel,
          scla2: _scla2Sel,
          guia: _guiaSel,
        );
    if (!mounted) return;
    final unique = <String, _Option<String>>{};
    for (final x in rows) {
      final key = x.art.trim().toUpperCase();
      if (key.isEmpty) continue;
      unique[key] = _Option(value: x.art, label: '${x.art} - ${x.descripcion}');
    }
    final sel = await _pickValues(
      title: 'Seleccionar ART',
      selected: _artSel,
      options: unique.values.toList()
        ..sort(
          (a, b) => a.label.toUpperCase().compareTo(b.label.toUpperCase()),
        ),
    );
    if (sel != null) setState(() => _artSel = sel);
  }

  Future<void> _pickUpcs() async {
    if (_artSel.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Limpia ART antes de seleccionar UPC')),
      );
      return;
    }
    final suc = (!_sucTodas && _sucSel.isNotEmpty) ? _sucSel.join(',') : null;
    final rows = await ref
        .read(promocionesApiProvider)
        .fetchArticulos(
          suc: suc,
          depa: _depaSel,
          subd: _subdSel,
          clas: _clasSel,
          scla: _sclaSel,
          scla2: _scla2Sel,
          guia: _guiaSel,
        );
    if (!mounted) return;
    final unique = <String, _Option<String>>{};
    for (final x in rows) {
      final key = x.upc.trim().toUpperCase();
      if (key.isEmpty) continue;
      unique[key] = _Option(value: x.upc, label: '${x.upc} - ${x.descripcion}');
    }
    final sel = await _pickValues(
      title: 'Seleccionar UPC',
      selected: _upcSel,
      options: unique.values.toList()
        ..sort(
          (a, b) => a.label.toUpperCase().compareTo(b.label.toUpperCase()),
        ),
    );
    if (sel != null) setState(() => _upcSel = sel);
  }

  Future<void> _save() async {
    if ((_tBeneficio ?? '').trim().isEmpty) return;
    final prc = _double(_prcCtrl.text);
    final imp = _double(_impCtrl.text);
    final precioGratis = _double(_precioGratisCtrl.text) ?? 0.01;
    if (_tBeneficio == 'PORCENTAJE' && prc == null) return;
    if (_tBeneficio == 'IMP_FIJO' && imp == null) return;
    if (_tBeneficio == 'ART_GRATIS' && precioGratis <= 0) return;

    setState(() => _saving = true);
    try {
      final clientePayload =
          (!_sucTodas && _sucSel.length == 1 && (_clienteSel ?? 0) > 0)
          ? _clienteSel
          : null;
      await ref.read(promocionesApiProvider).saveConfig(widget.item.idProm, {
        'T_BENEFICIO': _tBeneficio,
        'PRC_DESC': _tBeneficio == 'PORCENTAJE' ? prc : null,
        'IMP_DESC': _tBeneficio == 'IMP_FIJO' ? imp : null,
        'PRECIO_GRATIS': _tBeneficio == 'ART_GRATIS' ? precioGratis : null,
        'SUC_TODAS': _sucTodas,
        'SUC_LIST': _sucTodas ? const <String>[] : _sucSel,
        'CLIENTE': clientePayload,
        'DEPA_LIST': _depaSel,
        'SUBD_LIST': _subdSel,
        'CLAS_LIST': _clasSel,
        'SCLA_LIST': _sclaSel,
        'SCLA2_LIST': _scla2Sel,
        'GUIA_LIST': _guiaSel,
        'ART_LIST': _artSel,
        'UPC_LIST': _upcSel,
      });
      ref.invalidate(promoConfigProvider(widget.item.idProm));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Configuración guardada')));
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<List<T>?> _pickValues<T>({
    required String title,
    required List<T> selected,
    required List<_Option<T>> options,
  }) {
    return showDialog<List<T>>(
      context: context,
      builder: (ctx) {
        final values = selected.toSet();
        final searchCtrl = TextEditingController();
        String appliedSearch = '';
        return StatefulBuilder(
          builder: (context, setInner) {
            final needle = appliedSearch.trim().toLowerCase();
            final filtered = needle.isEmpty
                ? options
                : options
                      .where((x) => x.label.toLowerCase().contains(needle))
                      .toList();
            return AlertDialog(
              title: Text(title),
              content: SizedBox(
                width: 700,
                height: 500,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: searchCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Buscar ART/UPC/descripción',
                              border: OutlineInputBorder(),
                            ),
                            onSubmitted: (_) =>
                                setInner(() => appliedSearch = searchCtrl.text),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () =>
                              setInner(() => appliedSearch = searchCtrl.text),
                          icon: const Icon(Icons.search),
                          label: const Text('Buscar'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => setInner(() {
                            searchCtrl.clear();
                            appliedSearch = '';
                          }),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Limpiar'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(child: Text('Sin opciones'))
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final item = filtered[index];
                                final checked = values.contains(item.value);
                                return CheckboxListTile(
                                  dense: true,
                                  value: checked,
                                  title: Text(item.label),
                                  onChanged: (value) {
                                    setInner(() {
                                      if (value == true) {
                                        values.add(item.value);
                                      } else {
                                        values.remove(item.value);
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(values.toList()),
                  child: const Text('Aplicar'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _MultiSelectButton<T> extends StatelessWidget {
  const _MultiSelectButton({
    required this.label,
    required this.selected,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final List<T> selected;
  final List<_Option<T>> options;
  final ValueChanged<List<T>> onChanged;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: () async {
        final values = selected.toSet();
        final result = await showDialog<List<T>>(
          context: context,
          builder: (ctx) => StatefulBuilder(
            builder: (context, setInner) => AlertDialog(
              title: Text('Seleccionar $label'),
              content: SizedBox(
                width: 620,
                height: 420,
                child: options.isEmpty
                    ? const Center(child: Text('Sin opciones'))
                    : ListView.builder(
                        itemCount: options.length,
                        itemBuilder: (context, index) {
                          final item = options[index];
                          final checked = values.contains(item.value);
                          return CheckboxListTile(
                            dense: true,
                            value: checked,
                            title: Text(item.label),
                            onChanged: (value) {
                              setInner(() {
                                if (value == true) {
                                  values.add(item.value);
                                } else {
                                  values.remove(item.value);
                                }
                              });
                            },
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(values.toList()),
                  child: const Text('Aplicar'),
                ),
              ],
            ),
          ),
        );
        if (result != null) onChanged(result);
      },
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          selected.isEmpty
              ? '$label: SIN SELECCIÓN'
              : '$label: ${selected.length} seleccionados',
        ),
      ),
    );
  }
}

class _PromoCriteriaSummaryText extends ConsumerWidget {
  const _PromoCriteriaSummaryText({required this.idProm});
  final int idProm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = ref.watch(promoConfigProvider(idProm));
    return cfg.when(
      data: (data) => Text(
        _buildPromoCriteriaSummary(data),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      loading: () => const Text('CRIT: cargando...'),
      error: (error, stackTrace) => const Text('CRIT: sin configuración'),
    );
  }
}

class _CriteriaResumeCard extends StatelessWidget {
  const _CriteriaResumeCard({
    required this.sucTodas,
    required this.sucSel,
    required this.clienteSel,
    required this.depaSel,
    required this.subdSel,
    required this.clasSel,
    required this.sclaSel,
    required this.scla2Sel,
    required this.guiaSel,
    required this.artSel,
    required this.upcSel,
    required this.depas,
    required this.subds,
    required this.clases,
    required this.sclas,
    required this.scla2s,
    required this.guias,
  });

  final bool sucTodas;
  final List<String> sucSel;
  final int? clienteSel;
  final List<int> depaSel;
  final List<int> subdSel;
  final List<int> clasSel;
  final List<int> sclaSel;
  final List<int> scla2Sel;
  final List<String> guiaSel;
  final List<String> artSel;
  final List<String> upcSel;
  final List<CatalogNumOptionModel> depas;
  final List<CatalogNumOptionModel> subds;
  final List<CatalogNumOptionModel> clases;
  final List<CatalogNumOptionModel> sclas;
  final List<CatalogNumOptionModel> scla2s;
  final List<CatalogTextOptionModel> guias;

  @override
  Widget build(BuildContext context) {
    final lines = <String>[
      sucTodas
          ? 'SUC: TODAS'
          : 'SUC: ${_joinList(sucSel, emptyText: 'SIN SELECCIÓN')}',
      if ((clienteSel ?? 0) > 0) 'CLIENTE: $clienteSel',
    ];

    if (artSel.isNotEmpty) {
      lines.add(
        'ALCANCE ART: ${artSel.length} seleccionados (${_joinList(artSel)})',
      );
    } else if (upcSel.isNotEmpty) {
      lines.add(
        'ALCANCE UPC: ${upcSel.length} seleccionados (${_joinList(upcSel)})',
      );
    } else {
      lines.add(
        'DEPA: ${_joinCatalogNums(depaSel, depas, emptyText: 'SIN SELECCIÓN')}',
      );
      lines.add(
        'SUBD: ${_joinCatalogNums(subdSel, subds, emptyText: 'SIN SELECCIÓN')}',
      );
      lines.add(
        'CLAS: ${_joinCatalogNums(clasSel, clases, emptyText: 'SIN SELECCIÓN')}',
      );
      lines.add(
        'SCLA: ${_joinCatalogNums(sclaSel, sclas, emptyText: 'SIN SELECCIÓN')}',
      );
      lines.add(
        'SCLA2: ${_joinCatalogNums(scla2Sel, scla2s, emptyText: 'SIN SELECCIÓN')}',
      );
      lines.add(
        'GUIA: ${_joinCatalogTexts(guiaSel, guias, emptyText: 'SIN SELECCIÓN')}',
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resumen de criterios',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          ...lines.map(
            (x) => Text(x, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

class _CatalogAddDialog extends StatefulWidget {
  const _CatalogAddDialog();

  @override
  State<_CatalogAddDialog> createState() => _CatalogAddDialogState();
}

class _CatalogAddDialogState extends State<_CatalogAddDialog> {
  final _claveCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  @override
  void dispose() {
    _claveCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Agregar tipo beneficio'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _claveCtrl,
              decoration: const InputDecoration(labelText: 'Clave'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(labelText: 'Descripción'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final clave = _claveCtrl.text.trim().toUpperCase();
            final descripcion = _descCtrl.text.trim();
            if (clave.isEmpty || descripcion.isEmpty) return;
            Navigator.of(
              context,
            ).pop({'clave': clave, 'descripcion': descripcion});
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _Option<T> {
  const _Option({required this.value, required this.label});
  final T value;
  final String label;
}

String _fmtDate(DateTime? value) {
  if (value == null) return '';
  final y = value.year.toString().padLeft(4, '0');
  final m = value.month.toString().padLeft(2, '0');
  final d = value.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

int? _int(String raw) => int.tryParse(raw.trim());
double? _double(String raw) => double.tryParse(raw.trim().replaceAll(',', '.'));
String? _date(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;
  if (RegExp(r'^\\d{4}-\\d{2}-\\d{2}$').hasMatch(text)) {
    return '${text}T00:00:00.000Z';
  }
  return text;
}

int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

int? _asPositiveInt(dynamic value) {
  final n = _asInt(value);
  return (n != null && n > 0) ? n : null;
}

String _buildPromoCriteriaSummary(PromoConfigModel? cfg) {
  if (cfg == null) return 'CRIT: sin configuración';
  if (cfg.artList.isNotEmpty) {
    return 'CRIT: ART ${cfg.artList.length} (${_joinList(cfg.artList, maxItems: 2)})';
  }
  if (cfg.upcList.isNotEmpty) {
    return 'CRIT: UPC ${cfg.upcList.length} (${_joinList(cfg.upcList, maxItems: 2)})';
  }
  final chain = <String>[];
  if (cfg.depaList.isNotEmpty) chain.add('DEPA ${_joinNums(cfg.depaList)}');
  if (cfg.subdList.isNotEmpty) chain.add('SUBD ${_joinNums(cfg.subdList)}');
  if (cfg.clasList.isNotEmpty) chain.add('CLAS ${_joinNums(cfg.clasList)}');
  if (cfg.sclaList.isNotEmpty) chain.add('SCLA ${_joinNums(cfg.sclaList)}');
  if (cfg.scla2List.isNotEmpty) chain.add('SCLA2 ${_joinNums(cfg.scla2List)}');
  if (cfg.guiaList.isNotEmpty) chain.add('GUIA ${_joinList(cfg.guiaList)}');
  final detail = chain.isEmpty ? 'SIN JERARQUÍA' : chain.join(' > ');
  return 'CRIT: $detail';
}

String _joinNums(List<int> values, {int maxItems = 2}) {
  if (values.isEmpty) return '-';
  final head = values.take(maxItems).map((x) => x.toString()).join(', ');
  if (values.length <= maxItems) return head;
  return '$head +${values.length - maxItems}';
}

String _joinList(
  List<String> values, {
  int maxItems = 3,
  String emptyText = '-',
}) {
  final clean = values.map((x) => x.trim()).where((x) => x.isNotEmpty).toList();
  if (clean.isEmpty) return emptyText;
  final head = clean.take(maxItems).join(', ');
  if (clean.length <= maxItems) return head;
  return '$head +${clean.length - maxItems}';
}

String _joinCatalogNums(
  List<int> selected,
  List<CatalogNumOptionModel> catalog, {
  int maxItems = 3,
  String emptyText = '-',
}) {
  if (selected.isEmpty) return emptyText;
  final map = {for (final x in catalog) x.valor: x.descripcion};
  final labels = selected
      .map(
        (id) => map[id] != null && map[id]!.trim().isNotEmpty
            ? '$id (${map[id]})'
            : '$id',
      )
      .toList();
  return _joinList(labels, maxItems: maxItems, emptyText: emptyText);
}

String _joinCatalogTexts(
  List<String> selected,
  List<CatalogTextOptionModel> catalog, {
  int maxItems = 3,
  String emptyText = '-',
}) {
  if (selected.isEmpty) return emptyText;
  final map = {
    for (final x in catalog) x.valor.trim().toUpperCase(): x.descripcion,
  };
  final labels = selected.map((id) {
    final key = id.trim().toUpperCase();
    final desc = map[key];
    return (desc != null && desc.trim().isNotEmpty) ? '$id ($desc)' : id;
  }).toList();
  return _joinList(labels, maxItems: maxItems, emptyText: emptyText);
}
