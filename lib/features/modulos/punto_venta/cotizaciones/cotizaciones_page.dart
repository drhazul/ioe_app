import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ioe_app/core/dio_provider.dart';
import 'package:ioe_app/core/terminal_name.dart';
import 'package:ioe_app/features/masterdata/sucursales/sucursales_providers.dart';

import 'cotizaciones_models.dart';
import 'cotizaciones_providers.dart';

class CotizacionesPage extends ConsumerStatefulWidget {
  const CotizacionesPage({super.key});

  @override
  ConsumerState<CotizacionesPage> createState() => _CotizacionesPageState();
}

class _CotizacionesPageState extends ConsumerState<CotizacionesPage> {
  final _searchCtrl = TextEditingController();
  final _opvCtrl = TextEditingController();
  final _sucCtrl = TextEditingController();
  PvCtrFolAsvrModel? _selected;
  int? _roleId;
  String? _userSuc;
  String? _userOpv;

  @override
  void initState() {
    super.initState();
    _loadUserContext();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _opvCtrl.dispose();
    _sucCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cotizacionesAsync = ref.watch(cotizacionesListProvider);
    final isAdmin = (_roleId ?? 0) == 1;
    final hasUserSuc = (_userSuc ?? '').trim().isNotEmpty;
    final hasUserOpv = (_userOpv ?? '').trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de cotizaciones pendientes'),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(cotizacionesListProvider),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refrescar',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _confirmCreate(context, ref),
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
        child: cotizacionesAsync.when(
          data: (cotizaciones) => RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(cotizacionesListProvider);
              await ref.read(cotizacionesListProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _TopFilters(
                  opvCtrl: _opvCtrl,
                  sucCtrl: _sucCtrl,
                  searchCtrl: _searchCtrl,
                  isAdmin: isAdmin,
                  hasUserOpv: hasUserOpv,
                  hasUserSuc: hasUserSuc,
                  onSucChanged: (value) => setState(() => _sucCtrl.text = value?.trim() ?? ''),
                  onSearch: () => setState(() {}),
                  onClear: () => setState(() {
                    _searchCtrl.clear();
                    if (hasUserOpv) {
                      _opvCtrl.text = _userOpv ?? '';
                    } else {
                      _opvCtrl.clear();
                    }
                    if (isAdmin) {
                      _sucCtrl.clear();
                    } else if (hasUserSuc) {
                      _sucCtrl.text = _userSuc ?? '';
                    } else {
                      _sucCtrl.clear();
                    }
                  }),
                ),
                const SizedBox(height: 12),
                _CotizacionesTable(
                  cotizaciones: _filter(cotizaciones),
                  selected: _selected,
                  onSelect: (c) {
                    setState(() => _selected = c);
                    context.go('/punto-venta/cotizaciones/${Uri.encodeComponent(c.idfol)}/detalle');
                  },
                  onDelete: (c) => _confirmDelete(context, ref, c),
                ),
              ],
            ),
          ),
          error: (e, _) => Center(child: Text('Error: $e')),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }

  List<PvCtrFolAsvrModel> _filter(List<PvCtrFolAsvrModel> data) {
    final term = _searchCtrl.text.trim().toLowerCase();
    final isAdmin = (_roleId ?? 0) == 1;
    final hasUserSuc = (_userSuc ?? '').trim().isNotEmpty;
    final hasUserOpv = (_userOpv ?? '').trim().isNotEmpty;
    final baseSuc = isAdmin ? _sucCtrl.text : (hasUserSuc ? _userSuc! : _sucCtrl.text);
    final baseOpv = hasUserOpv ? _userOpv! : _opvCtrl.text;
    final suc = baseSuc.trim().toLowerCase();
    final opv = baseOpv.trim().toLowerCase();
    final filtered = data.where((c) {
      final matchTerm = term.isEmpty || c.idfol.toLowerCase().contains(term);
      final matchOpv = opv.isEmpty
          ? true
          : hasUserOpv
              ? (c.opv ?? '').trim().toLowerCase() == opv
              : (c.opv ?? '').toLowerCase().contains(opv);
      final matchSuc = suc.isEmpty || (c.suc ?? '').trim().toLowerCase() == suc;
      final esta = (c.esta ?? '').toUpperCase();
      final matchEsta = esta.contains('PENDIENTE') || esta.contains('PAGADO') || esta.contains('EDITANDO');
      final aut = (c.aut ?? '').toUpperCase();
      final matchAut = aut.contains('CP');
      return matchTerm && matchOpv && matchSuc && matchEsta && matchAut;
    }).toList();
    filtered.sort((a, b) {
      final af = a.fcn;
      final bf = b.fcn;
      if (af != null && bf != null) {
        final cmp = bf.compareTo(af);
        if (cmp != 0) return cmp;
      } else if (af != null) {
        return -1;
      } else if (bf != null) {
        return 1;
      }
      return b.idfol.compareTo(a.idfol);
    });
    return filtered;
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, PvCtrFolAsvrModel model) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar cotización'),
        content: Text('¿Deseas eliminar la cotización ${model.idfol}?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirm != true) return;
    await ref.read(cotizacionesApiProvider).deleteCotizacion(model.idfol);
    ref.invalidate(cotizacionesListProvider);
  }

  Future<void> _confirmCreate(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nueva cotización'),
        content: const Text('¿Seguro que deseas generar una nueva cotización?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Generar')),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

    if ((_userSuc ?? '').trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se encontró la sucursal del usuario.')),
      );
      return;
    }
    if ((_userOpv ?? '').trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se encontró el usuario (OPV).')),
      );
      return;
    }

    final terminal = _resolveTerminalName();
    try {
      final created = await ref.read(cotizacionesApiProvider).createCotizacionAuto(ter: terminal);
      ref.invalidate(cotizacionesListProvider);
      if (!context.mounted) return;
      context.go('/punto-venta/cotizaciones/${Uri.encodeComponent(created.idfol)}/detalle');
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo crear la cotización: $e')),
      );
    }
  }

  String _resolveTerminalName() {
    final systemName = getTerminalName().trim();
    if (systemName.isNotEmpty) return systemName;
    final opv = (_userOpv ?? '').trim();
    if (opv.isNotEmpty) return opv;
    final suc = (_userSuc ?? '').trim();
    if (suc.isNotEmpty) return suc;
    return 'APP';
  }

  Future<void> _loadUserContext() async {
    final storage = ref.read(storageProvider);
    final token = await storage.getAccessToken();
    if (token == null || token.isEmpty) return;
    final payload = _decodeJwt(token);
    if (!mounted) return;
    setState(() {
      _roleId = _asInt(payload['roleId']);
      final rawSuc = payload['suc'] ?? payload['SUC'];
      final rawOpv = payload['opv'] ?? payload['OPV'] ?? payload['username'];
      _userSuc = rawSuc?.toString().trim();
      _userOpv = rawOpv?.toString().trim();
      if ((_userOpv ?? '').trim().isNotEmpty) {
        _opvCtrl.text = _userOpv!;
      }
      if ((_userSuc ?? '').trim().isNotEmpty) {
        final isAdmin = (_roleId ?? 0) == 1;
        if (!isAdmin || _sucCtrl.text.trim().isEmpty) {
          _sucCtrl.text = _userSuc!;
        }
      }
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
    return null;
  }
}

class _TopFilters extends ConsumerWidget {
  const _TopFilters({
    required this.opvCtrl,
    required this.sucCtrl,
    required this.searchCtrl,
    required this.onSearch,
    required this.onClear,
    required this.onSucChanged,
    required this.isAdmin,
    required this.hasUserOpv,
    required this.hasUserSuc,
  });

  final TextEditingController opvCtrl;
  final TextEditingController sucCtrl;
  final TextEditingController searchCtrl;
  final VoidCallback onSearch;
  final VoidCallback onClear;
  final ValueChanged<String?> onSucChanged;
  final bool isAdmin;
  final bool hasUserOpv;
  final bool hasUserSuc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sucAsync = isAdmin ? ref.watch(sucursalesListProvider) : null;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 16,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _SmallField(label: 'OPV', controller: opvCtrl, enabled: !hasUserOpv),
            if (!isAdmin) _SmallField(label: 'Sucursal', controller: sucCtrl, enabled: !hasUserSuc),
            if (isAdmin)
              SizedBox(
                width: 200,
                child: sucAsync!.when(
                  data: (sucursales) {
                    final items = <DropdownMenuItem<String>>[];
                    for (var i = 0; i < sucursales.length; i++) {
                      final s = sucursales[i];
                      final label = (s.desc?.trim().isNotEmpty == true) ? '${s.suc} - ${s.desc}' : s.suc;
                      items.add(DropdownMenuItem(value: s.suc, child: Text(label)));
                    }
                    final selected = sucCtrl.text.trim();
                    final value = items.any((i) => i.value == selected) ? selected : null;
                    return DropdownButtonFormField<String>(
                      initialValue: value,
                      isExpanded: true,
                      items: items,
                      onChanged: onSucChanged,
                      decoration: const InputDecoration(
                        labelText: 'Sucursal',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    );
                  },
                  loading: () => _SmallField(label: 'Sucursal', controller: sucCtrl, enabled: false),
                  error: (e, _) => _SmallField(label: 'Sucursal', controller: sucCtrl, enabled: false),
                ),
              ),
            SizedBox(
              width: 520,
              child: TextField(
                controller: searchCtrl,
                decoration: const InputDecoration(
                  labelText: 'Buscar cotización',
                  isDense: true,
                  border: OutlineInputBorder(),
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

class _SmallField extends StatelessWidget {
  const _SmallField({required this.label, required this.controller, this.enabled = true});

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
        decoration: InputDecoration(labelText: label, isDense: true, border: const OutlineInputBorder()),
      ),
    );
  }
}

class _CotizacionesTable extends StatelessWidget {
  const _CotizacionesTable({
    required this.cotizaciones,
    required this.selected,
    required this.onSelect,
    required this.onDelete,
  });

  final List<PvCtrFolAsvrModel> cotizaciones;
  final PvCtrFolAsvrModel? selected;
  final ValueChanged<PvCtrFolAsvrModel> onSelect;
  final ValueChanged<PvCtrFolAsvrModel> onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            color: Colors.grey.shade200,
            child: const Row(
              children: [
                SizedBox(width: 70, child: Text('SUC', style: TextStyle(fontWeight: FontWeight.w600))),
                SizedBox(width: 140, child: Text('OPV', style: TextStyle(fontWeight: FontWeight.w600))),
                SizedBox(width: 240, child: Text('IDFOL', style: TextStyle(fontWeight: FontWeight.w600))),
                SizedBox(width: 110, child: Text('FCN', style: TextStyle(fontWeight: FontWeight.w600))),
                SizedBox(width: 70, child: Text('TRA', style: TextStyle(fontWeight: FontWeight.w600))),
                SizedBox(width: 90, child: Text('N Cliente', style: TextStyle(fontWeight: FontWeight.w600))),
                SizedBox(width: 140, child: Text('Estado', style: TextStyle(fontWeight: FontWeight.w600))),
                SizedBox(width: 110, child: Text('Importe', style: TextStyle(fontWeight: FontWeight.w600))),
                SizedBox(width: 96),
              ],
            ),
          ),
          const Divider(height: 1),
          SizedBox(
            height: 420,
            child: ListView.separated(
              itemCount: cotizaciones.length,
              itemBuilder: (_, index) {
                final c = cotizaciones[index];
                final selectedRow = selected?.idfol == c.idfol;
                return InkWell(
                  onTap: () => onSelect(c),
                  child: Container(
                    color: selectedRow ? Colors.blue.shade50 : null,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Row(
                      children: [
                        SizedBox(width: 70, child: Text(c.suc ?? '-')),
                        SizedBox(width: 140, child: Text(c.opv ?? '-', overflow: TextOverflow.ellipsis)),
                        SizedBox(width: 240, child: Text(c.idfol, overflow: TextOverflow.ellipsis)),
                        SizedBox(width: 110, child: Text(_formatDate(c.fcn))),
                        SizedBox(width: 70, child: Text(c.tra ?? '-')),
                        SizedBox(width: 90, child: Text(c.clien?.toString() ?? '-')),
                        SizedBox(width: 140, child: Text(c.esta ?? '-', overflow: TextOverflow.ellipsis)),
                        SizedBox(width: 110, child: Text(_formatMoney(c.impt))),
                        SizedBox(
                          width: 96,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                tooltip: 'Eliminar',
                                onPressed: () => onDelete(c),
                                icon: const Icon(Icons.delete_outline, size: 18),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              separatorBuilder: (_, _) => const Divider(height: 1),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '-';
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$d/$m/$y';
  }

  String _formatMoney(double? value) {
    if (value == null) return '-';
    return '\$${value.toStringAsFixed(2)}';
  }
}
