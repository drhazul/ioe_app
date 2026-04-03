import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ioe_app/core/api_error.dart';
import 'package:ioe_app/core/dio_provider.dart';
import 'package:ioe_app/core/terminal_name.dart';
import 'package:ioe_app/features/masterdata/sucursales/sucursales_providers.dart';
import 'package:ioe_app/features/modulos/punto_venta/admin_opv_selector.dart';

import 'ps_models.dart';
import 'ps_providers.dart';

class PsPanelPage extends ConsumerStatefulWidget {
  const PsPanelPage({super.key});

  @override
  ConsumerState<PsPanelPage> createState() => _PsPanelPageState();
}

class _PsPanelPageState extends ConsumerState<PsPanelPage> {
  final _searchCtrl = TextEditingController();
  final _sucCtrl = TextEditingController();
  final _opvCtrl = TextEditingController();

  int? _roleId;
  String? _username;
  String? _userSuc;
  String? _userOpv;
  bool _contextReady = false;
  PsFolioItem? _selected;

  @override
  void initState() {
    super.initState();
    _loadUserContext();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _sucCtrl.dispose();
    _opvCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_contextReady) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isAdmin = _isAdmin;
    final foliosAsync = ref.watch(psFoliosProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Regresar a Punto de Venta',
          onPressed: () => context.go('/punto-venta'),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Pago de Servicios - Panel'),
        actions: [
          IconButton(
            tooltip: 'Refrescar',
            onPressed: () => ref.invalidate(psFoliosProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createFolio,
        child: const Icon(Icons.add),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF6F2EB), Color(0xFFEFE7DB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: foliosAsync.when(
          data: (items) => RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(psFoliosProvider);
              await ref.read(psFoliosProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _PsTopFilters(
                  isAdmin: isAdmin,
                  searchCtrl: _searchCtrl,
                  sucCtrl: _sucCtrl,
                  opvCtrl: _opvCtrl,
                  selectedOpv: _opvCtrl.text.trim(),
                  onOpvChanged: (value) => setState(() => _opvCtrl.text = value?.trim() ?? ''),
                  onSearch: _applyFilters,
                  onClear: _clearFilters,
                  onSucChanged: (value) => setState(() {
                    _sucCtrl.text = value?.trim() ?? '';
                    if (isAdmin) _opvCtrl.clear();
                  }),
                ),
                const SizedBox(height: 12),
                _PsPanelTable(
                  rows: items,
                  selected: _selected,
                  onSelect: (item) {
                    setState(() => _selected = item);
                    final estado = (item.esta ?? '').trim().toUpperCase();
                    final idfol = Uri.encodeComponent(item.idfol);
                    if (
                      estado == 'PAGADO' ||
                      estado == 'CERRADO_PS' ||
                      estado == 'TRANSMITIR'
                    ) {
                      context.go('/ps/$idfol/pago');
                      return;
                    }
                    context.go('/ps/$idfol');
                  },
                  onAnular: (item) => _confirmAnular(item),
                ),
              ],
            ),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }

  void _applyFilters() {
    final isAdmin = _isAdmin;
    final suc = isAdmin
        ? _sucCtrl.text.trim()
        : (_userSuc ?? _sucCtrl.text).trim();
    final opv = (_userOpv ?? _opvCtrl.text).trim();

    setState(() => _selected = null);
    ref.read(psPanelQueryProvider.notifier).state = PsPanelQuery(
      suc: suc,
      opv: opv,
      search: _searchCtrl.text.trim(),
    );
  }

  void _clearFilters() {
    final isAdmin = _isAdmin;
    setState(() {
      _searchCtrl.clear();
      if (isAdmin) {
        _sucCtrl.clear();
        _opvCtrl.clear();
      } else {
        _sucCtrl.text = (_userSuc ?? '').trim();
        _opvCtrl.text = (_userOpv ?? '').trim();
      }
      _selected = null;
    });
    ref.read(psPanelQueryProvider.notifier).state = PsPanelQuery(
      suc: _sucCtrl.text.trim(),
      opv: _selectedOpv(),
      search: '',
    );
  }

  Future<void> _createFolio() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuevo Pago de Servicios'),
        content: const Text('¿Deseas crear un nuevo folio de Pago de Servicios?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Crear')),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    final isAdmin = _isAdmin;
    final suc = isAdmin ? _sucCtrl.text.trim() : (_userSuc ?? '').trim();
    final opv = _selectedOpv();
    final ter = getTerminalName().trim();

    if (suc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debe capturar sucursal para crear el folio.')),
      );
      return;
    }
    if (opv.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo resolver OPV del usuario.')),
      );
      return;
    }

    try {
      final created = await ref.read(psApiProvider).createFolio(
            suc: suc,
            ter: ter.isEmpty ? null : ter,
            opv: opv,
          );
      final idfol = (created['IDFOL']?.toString() ?? '').trim();
      ref.invalidate(psFoliosProvider);
      if (!mounted) return;
      if (idfol.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se recibió IDFOL al crear el folio.')),
        );
        return;
      }
      context.go('/ps/${Uri.encodeComponent(idfol)}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e, fallback: 'No se pudo crear folio PS'))),
      );
    }
  }

  Future<void> _confirmAnular(PsFolioItem item) async {
    if (!_isEstadoPendiente(item.esta)) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Anular folio PS'),
        content: Text('¿Deseas cambiar a ANULADO el folio ${item.idfol}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Anular'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await ref.read(psApiProvider).updateEstado(
            idFol: item.idfol,
            esta: 'ANULADO',
          );
      if (!mounted) return;
      setState(() => _selected = null);
      ref.invalidate(psFoliosProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            apiErrorMessage(e, fallback: 'No se pudo anular el folio PS'),
          ),
        ),
      );
    }
  }

  Future<void> _loadUserContext() async {
    final storage = ref.read(storageProvider);
    final token = await storage.getAccessToken();
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      setState(() => _contextReady = true);
      return;
    }

    final payload = _decodeJwt(token);
    if (!mounted) return;

    final roleId = _asInt(payload['roleId']) ?? 0;
    final username = (payload['username'] ?? payload['USERNAME'] ?? '')
        .toString()
        .trim();
    final suc = (payload['suc'] ?? payload['SUC'] ?? '').toString().trim();
    final opv = (payload['opv'] ?? payload['OPV'] ?? payload['username'] ?? '').toString().trim();
    final isAdmin = roleId == 1 || username.toUpperCase() == 'ADMIN';

    final query = PsPanelQuery(
      suc: suc,
      opv: isAdmin ? '' : opv,
      search: '',
    );

    ref.read(psPanelQueryProvider.notifier).state = query;
    setState(() {
      _roleId = roleId;
      _username = username;
      _userSuc = suc;
      _userOpv = opv;
      if (suc.isNotEmpty) _sucCtrl.text = suc;
      if (isAdmin) {
        _opvCtrl.clear();
      } else if (opv.isNotEmpty) {
        _opvCtrl.text = opv;
      }
      _contextReady = true;
    });
  }

  Map<String, dynamic> _decodeJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return {};
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      return Map<String, dynamic>.from(json.decode(payload) as Map);
    } catch (_) {
      return {};
    }
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  bool get _isAdmin {
    if ((_roleId ?? 0) == 1) return true;
    return (_username ?? '').trim().toUpperCase() == 'ADMIN';
  }

  String _selectedOpv() {
    final explicit = _opvCtrl.text.trim();
    if (explicit.isNotEmpty) return explicit;
    if (_isAdmin) return '';
    return (_userOpv ?? '').trim();
  }

  bool _isEstadoPendiente(String? value) {
    return (value ?? '').trim().toUpperCase() == 'PENDIENTE';
  }
}

class _PsTopFilters extends ConsumerWidget {
  const _PsTopFilters({
    required this.isAdmin,
    required this.searchCtrl,
    required this.sucCtrl,
    required this.opvCtrl,
    required this.onSearch,
    required this.onClear,
    required this.onSucChanged,
    required this.selectedOpv,
    required this.onOpvChanged,
  });

  final bool isAdmin;
  final TextEditingController searchCtrl;
  final TextEditingController sucCtrl;
  final TextEditingController opvCtrl;
  final VoidCallback onSearch;
  final VoidCallback onClear;
  final ValueChanged<String?> onSucChanged;
  final String selectedOpv;
  final ValueChanged<String?> onOpvChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sucAsync = isAdmin ? ref.watch(sucursalesListProvider) : null;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 12,
          runSpacing: 10,
          children: [
            if (isAdmin)
              SizedBox(
                width: 220,
                child: sucAsync!.when(
                  data: (sucursales) {
                    final items = sucursales
                        .map((s) => DropdownMenuItem<String>(
                              value: s.suc,
                              child: Text(
                                (s.desc?.trim().isNotEmpty == true)
                                    ? '${s.suc} - ${s.desc}'
                                    : s.suc,
                              ),
                            ))
                        .toList();
                    final selected = sucCtrl.text.trim();
                    final value = items.any((item) => item.value == selected)
                        ? selected
                        : null;
                    return DropdownButtonFormField<String>(
                      initialValue: value,
                      isExpanded: true,
                      items: items,
                      onChanged: onSucChanged,
                      decoration: const InputDecoration(
                        labelText: 'Sucursal',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    );
                  },
                  loading: () => _SmallField(
                    label: 'Sucursal',
                    controller: sucCtrl,
                    enabled: false,
                  ),
                  error: (_, _) => _SmallField(
                    label: 'Sucursal',
                    controller: sucCtrl,
                    enabled: false,
                  ),
                ),
              )
            else
              _SmallField(label: 'Sucursal', controller: sucCtrl, enabled: false),
            if (isAdmin)
              AdminOpvSelector(
                suc: sucCtrl.text,
                selectedOpv: selectedOpv,
                onOpvChanged: onOpvChanged,
              )
            else
              _SmallField(label: 'OPV', controller: opvCtrl, enabled: false),
            SizedBox(
              width: 360,
              child: TextField(
                controller: searchCtrl,
                decoration: const InputDecoration(
                  labelText: 'Buscar folio / cliente',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: (_) => onSearch(),
              ),
            ),
            IconButton(
              tooltip: 'Buscar',
              onPressed: onSearch,
              icon: const Icon(Icons.search),
            ),
            IconButton(
              tooltip: 'Limpiar',
              onPressed: onClear,
              icon: const Icon(Icons.clear),
            ),
          ],
        ),
      ),
    );
  }
}

class _PsPanelTable extends StatelessWidget {
  const _PsPanelTable({
    required this.rows,
    required this.selected,
    required this.onSelect,
    required this.onAnular,
  });

  final List<PsFolioItem> rows;
  final PsFolioItem? selected;
  final ValueChanged<PsFolioItem> onSelect;
  final ValueChanged<PsFolioItem> onAnular;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Column(
        children: [
          Container(
            color: Colors.grey.shade200,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: const Row(
              children: [
                SizedBox(width: 220, child: Text('IDFOL', style: TextStyle(fontWeight: FontWeight.w600))),
                SizedBox(width: 220, child: Text('IDFOLINICIAL', style: TextStyle(fontWeight: FontWeight.w600))),
                SizedBox(width: 90, child: Text('SUC', style: TextStyle(fontWeight: FontWeight.w600))),
                SizedBox(width: 140, child: Text('OPV', style: TextStyle(fontWeight: FontWeight.w600))),
                SizedBox(width: 130, child: Text('ESTA', style: TextStyle(fontWeight: FontWeight.w600))),
                SizedBox(width: 120, child: Text('AUT', style: TextStyle(fontWeight: FontWeight.w600))),
                SizedBox(width: 120, child: Text('ORIGEN_AUT', style: TextStyle(fontWeight: FontWeight.w600))),
                SizedBox(width: 120, child: Text('IMPT', style: TextStyle(fontWeight: FontWeight.w600))),
                SizedBox(width: 260, child: Text('Cliente', style: TextStyle(fontWeight: FontWeight.w600))),
                SizedBox(width: 44, child: Text('')),
              ],
            ),
          ),
          const Divider(height: 1),
          SizedBox(
            height: 430,
            child: ListView.separated(
              itemCount: rows.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, index) {
                final item = rows[index];
                final selectedRow = selected?.idfol == item.idfol;
                final canAnular = _isEstadoPendiente(item.esta);
                return InkWell(
                  onTap: () => onSelect(item),
                  child: Container(
                    color: selectedRow ? Colors.blue.shade50 : null,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    child: Row(
                      children: [
                        SizedBox(width: 220, child: Text(item.idfol, overflow: TextOverflow.ellipsis)),
                        SizedBox(width: 220, child: Text(item.idfolinicial ?? '-', overflow: TextOverflow.ellipsis)),
                        SizedBox(width: 90, child: Text(item.suc ?? '-')),
                        SizedBox(width: 140, child: Text(item.opv ?? '-', overflow: TextOverflow.ellipsis)),
                        SizedBox(width: 130, child: Text(item.esta ?? '-', overflow: TextOverflow.ellipsis)),
                        SizedBox(width: 120, child: Text(item.aut ?? '-')),
                        SizedBox(width: 120, child: Text((item.origenAut ?? '-').toUpperCase())),
                        SizedBox(width: 120, child: Text(_money(item.impt))),
                        SizedBox(
                          width: 260,
                          child: Text(
                            item.razonSocialReceptor ?? '-',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(
                          width: 44,
                          child: IconButton(
                            tooltip: canAnular
                                ? 'Anular'
                                : 'Disponible solo en PENDIENTE',
                            onPressed: canAnular ? () => onAnular(item) : null,
                            icon: const Icon(Icons.delete_outline, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _money(double? value) {
    if (value == null) return '-';
    return '\$${value.toStringAsFixed(2)}';
  }

  bool _isEstadoPendiente(String? value) {
    return (value ?? '').trim().toUpperCase() == 'PENDIENTE';
  }
}

class _SmallField extends StatelessWidget {
  const _SmallField({
    required this.label,
    required this.controller,
    required this.enabled,
  });

  final String label;
  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: TextField(
        controller: controller,
        enabled: enabled,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }
}

