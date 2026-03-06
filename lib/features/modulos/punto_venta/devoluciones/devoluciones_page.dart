import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ioe_app/core/api_error.dart';
import 'package:ioe_app/core/dio_provider.dart';
import 'package:ioe_app/features/masterdata/sucursales/sucursales_providers.dart';

import 'devoluciones_models.dart';
import 'devoluciones_providers.dart';

class DevolucionesPage extends ConsumerStatefulWidget {
  const DevolucionesPage({super.key});

  @override
  ConsumerState<DevolucionesPage> createState() => _DevolucionesPageState();
}

class _DevolucionesPageState extends ConsumerState<DevolucionesPage> {
  final _searchCtrl = TextEditingController();
  final _sucCtrl = TextEditingController();
  final _opvCtrl = TextEditingController();

  int? _roleId;
  String? _userSuc;
  String? _userOpv;
  bool _contextReady = false;
  DevolucionPanelItem? _selected;
  DevolucionesPanelQuery _query = const DevolucionesPanelQuery();

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

    final panelAsync = ref.watch(devolucionesPanelProvider(_query));
    final isAdmin = (_roleId ?? 0) == 1;
    final hasUserSuc = (_userSuc ?? '').trim().isNotEmpty;
    final hasUserOpv = (_userOpv ?? '').trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de devoluciones'),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(devolucionesPanelProvider(_query)),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refrescar',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDialog,
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
        child: panelAsync.when(
          data: (items) => RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(devolucionesPanelProvider(_query));
              await ref.read(devolucionesPanelProvider(_query).future);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _TopFilters(
                  isAdmin: isAdmin,
                  hasUserSuc: hasUserSuc,
                  hasUserOpv: hasUserOpv,
                  searchCtrl: _searchCtrl,
                  sucCtrl: _sucCtrl,
                  opvCtrl: _opvCtrl,
                  onSearch: _applyFilters,
                  onClear: _clearFilters,
                  onSucChanged: (value) => setState(() => _sucCtrl.text = value?.trim() ?? ''),
                ),
                const SizedBox(height: 12),
                _PanelTable(
                  rows: items,
                  selected: _selected,
                  onSelect: _handleRowSelect,
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

  void _applyFilters() {
    final isAdmin = (_roleId ?? 0) == 1;
    final suc = isAdmin
        ? _sucCtrl.text.trim()
        : (_userSuc ?? _sucCtrl.text).trim();
    final opv = (_userOpv ?? _opvCtrl.text).trim();
    setState(() {
      _selected = null;
      _query = DevolucionesPanelQuery(
        suc: suc,
        opv: opv,
        search: _searchCtrl.text.trim(),
      );
    });
  }

  void _clearFilters() {
    final isAdmin = (_roleId ?? 0) == 1;
    setState(() {
      _searchCtrl.clear();
      if (isAdmin) {
        _sucCtrl.clear();
      } else {
        _sucCtrl.text = (_userSuc ?? '').trim();
      }
      _opvCtrl.text = (_userOpv ?? '').trim();
      _selected = null;
      _query = DevolucionesPanelQuery(
        suc: _sucCtrl.text.trim(),
        opv: _opvCtrl.text.trim(),
      );
    });
  }

  Future<void> _showCreateDialog() async {
    final createdIdfolDev = await showDialog<String>(
      context: context,
      builder: (_) => _CreateDevolucionDialog(query: _query),
    );

    if (!mounted || createdIdfolDev == null) return;
    ref.invalidate(devolucionesPanelProvider(_query));
    context.go('/punto-venta/devoluciones/${Uri.encodeComponent(createdIdfolDev)}');
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
    final suc = (payload['suc'] ?? payload['SUC'] ?? '').toString().trim();
    final opv = (payload['opv'] ?? payload['OPV'] ?? payload['username'] ?? '')
        .toString()
        .trim();

    setState(() {
      _roleId = roleId;
      _userSuc = suc;
      _userOpv = opv;
      if (opv.isNotEmpty) _opvCtrl.text = opv;
      if (suc.isNotEmpty) _sucCtrl.text = suc;
      _query = DevolucionesPanelQuery(
        suc: roleId == 1 ? _sucCtrl.text.trim() : suc,
        opv: opv,
      );
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

  bool _isEstadoPagado(String? value) {
    final estado = (value ?? '').trim().toUpperCase();
    return estado.contains('PAGADO');
  }

  Future<void> _handleRowSelect(DevolucionPanelItem item) async {
    setState(() => _selected = item);
    final idfolDev = Uri.encodeComponent(item.idfol);
    if (_isEstadoPagado(item.esta)) {
      context.go('/punto-venta/devoluciones/$idfolDev/pago');
      return;
    }

    try {
      final detalle = await ref.read(devolucionesApiProvider).fetchDetalle(item.idfol);
      if (!mounted) return;
      final hasSelectedLines = detalle.summary.linesSelected > 0 ||
          detalle.lines.any((line) => (line.ctdd ?? 0) > 0);
      if (hasSelectedLines) {
        context.go('/punto-venta/devoluciones/$idfolDev/detalle');
        return;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              apiErrorMessage(
                e,
                fallback: 'No se pudo validar el detalle de la devolución',
              ),
            ),
          ),
        );
      }
    }

    if (!mounted) return;
    context.go('/punto-venta/devoluciones/$idfolDev');
  }
}

class _CreateDevolucionDialog extends ConsumerStatefulWidget {
  const _CreateDevolucionDialog({required this.query});

  final DevolucionesPanelQuery query;

  @override
  ConsumerState<_CreateDevolucionDialog> createState() =>
      _CreateDevolucionDialogState();
}

class _CreateDevolucionDialogState extends ConsumerState<_CreateDevolucionDialog> {
  final _idfolCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  String? _errorText;

  @override
  void dispose() {
    _idfolCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nueva devolución'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _idfolCtrl,
              enabled: !_loading,
              decoration: const InputDecoration(
                labelText: 'IDFOL original',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _passCtrl,
              enabled: !_loading,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Contraseña supervisor',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorText!,
                style: TextStyle(color: Colors.red.shade700),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Devolver'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final idfolOrig = _idfolCtrl.text.trim();
    final authPassword = _passCtrl.text;
    if (idfolOrig.isEmpty || authPassword.trim().isEmpty) {
      setState(() {
        _errorText = 'Capture folio y contraseña de supervisor';
      });
      return;
    }

    setState(() {
      _loading = true;
      _errorText = null;
    });

    try {
      final detail = await ref.read(devolucionesApiProvider).createDevolucion(
            idfolOrig: idfolOrig,
            authPassword: authPassword,
          );
      ref.invalidate(devolucionesPanelProvider(widget.query));
      if (!mounted) return;
      Navigator.of(context).pop(detail.header.idfolDev);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = apiErrorMessage(
          e,
          fallback: 'No se pudo crear la devolución',
        );
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }
}

class _TopFilters extends ConsumerWidget {
  const _TopFilters({
    required this.isAdmin,
    required this.hasUserSuc,
    required this.hasUserOpv,
    required this.searchCtrl,
    required this.sucCtrl,
    required this.opvCtrl,
    required this.onSearch,
    required this.onClear,
    required this.onSucChanged,
  });

  final bool isAdmin;
  final bool hasUserSuc;
  final bool hasUserOpv;
  final TextEditingController searchCtrl;
  final TextEditingController sucCtrl;
  final TextEditingController opvCtrl;
  final VoidCallback onSearch;
  final VoidCallback onClear;
  final ValueChanged<String?> onSucChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sucsAsync = isAdmin ? ref.watch(sucursalesListProvider) : null;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 12,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (!isAdmin)
              _SmallField(
                label: 'Sucursal',
                controller: sucCtrl,
                enabled: !hasUserSuc,
              ),
            if (isAdmin)
              SizedBox(
                width: 220,
                child: sucsAsync!.when(
                  data: (sucursales) {
                    final items = sucursales
                        .map(
                          (s) => DropdownMenuItem<String>(
                            value: s.suc,
                            child: Text(
                              (s.desc?.trim().isNotEmpty == true)
                                  ? '${s.suc} - ${s.desc}'
                                  : s.suc,
                            ),
                          ),
                        )
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
              ),
            _SmallField(
              label: 'OPV',
              controller: opvCtrl,
              enabled: !hasUserOpv,
            ),
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

class _PanelTable extends StatelessWidget {
  const _PanelTable({
    required this.rows,
    required this.selected,
    required this.onSelect,
  });

  final List<DevolucionPanelItem> rows;
  final DevolucionPanelItem? selected;
  final ValueChanged<DevolucionPanelItem> onSelect;

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
                SizedBox(width: 220, child: Text('Folio', style: TextStyle(fontWeight: FontWeight.w600))),
                SizedBox(width: 200, child: Text('Folio origen', style: TextStyle(fontWeight: FontWeight.w600))),
                SizedBox(width: 80, child: Text('SUC', style: TextStyle(fontWeight: FontWeight.w600))),
                SizedBox(width: 120, child: Text('AUT', style: TextStyle(fontWeight: FontWeight.w600))),
                SizedBox(width: 140, child: Text('Estado', style: TextStyle(fontWeight: FontWeight.w600))),
                SizedBox(width: 120, child: Text('Importe', style: TextStyle(fontWeight: FontWeight.w600))),
                SizedBox(width: 220, child: Text('Cliente', style: TextStyle(fontWeight: FontWeight.w600))),
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
                return InkWell(
                  onTap: () => onSelect(item),
                  child: Container(
                    color: selectedRow ? Colors.blue.shade50 : null,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    child: Row(
                      children: [
                        SizedBox(width: 220, child: Text(item.idfol, overflow: TextOverflow.ellipsis)),
                        SizedBox(width: 200, child: Text(item.idfolorig ?? '-', overflow: TextOverflow.ellipsis)),
                        SizedBox(width: 80, child: Text(item.suc ?? '-')),
                        SizedBox(width: 120, child: Text(item.aut ?? '-')),
                        SizedBox(width: 140, child: Text(item.esta ?? '-', overflow: TextOverflow.ellipsis)),
                        SizedBox(width: 120, child: Text(_money(item.impt))),
                        SizedBox(
                          width: 220,
                          child: Text(
                            item.razonSocialReceptor ?? '-',
                            overflow: TextOverflow.ellipsis,
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
}
