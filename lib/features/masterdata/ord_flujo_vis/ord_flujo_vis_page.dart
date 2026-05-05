import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'ord_flujo_vis_models.dart';
import 'ord_flujo_vis_providers.dart';

class OrdFlujoVisPage extends ConsumerWidget {
  const OrdFlujoVisPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(ordFlujoVisListProvider);
    final catalogosAsync = ref.watch(ordFlujoVisCatalogosProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Visualizacion por ROLL en ORD'),
        actions: [
          IconButton(
            tooltip: 'Refrescar',
            onPressed: () {
              ref.invalidate(ordFlujoVisListProvider);
              ref.invalidate(ordFlujoVisCatalogosProvider);
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/masterdata/ord-flujo-vis/new'),
        child: const Icon(Icons.add),
      ),
      body: listAsync.when(
        data: (items) => _OrdFlujoVisList(
          items: items,
          ref: ref,
          catalogos: catalogosAsync.valueOrNull,
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _OrdFlujoVisList extends StatefulWidget {
  const _OrdFlujoVisList({
    required this.items,
    required this.ref,
    required this.catalogos,
  });

  final List<OrdFlujoVisModel> items;
  final WidgetRef ref;
  final OrdFlujoVisCatalogos? catalogos;

  @override
  State<_OrdFlujoVisList> createState() => _OrdFlujoVisListState();
}

class _OrdFlujoVisListState extends State<_OrdFlujoVisList> {
  final _searchCtrl = TextEditingController();
  final _updatingIds = <int>{};
  String _searchApplied = '';
  String _roleCode = 'TODOS';
  String _esta = 'TODOS';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    widget.ref.invalidate(ordFlujoVisListProvider);
    widget.ref.invalidate(ordFlujoVisCatalogosProvider);
    await widget.ref.read(ordFlujoVisListProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final term = _searchApplied.trim().toLowerCase();
    final filtered = widget.items.where((item) {
      if (_roleCode != 'TODOS' && item.roleCode != _roleCode) {
        return false;
      }
      if (_esta != 'TODOS' && _formatEsta(item.esta) != _esta) {
        return false;
      }
      if (term.isEmpty) return true;
      final text =
          '${item.id} ${item.modulo} ${item.panelMode} ${item.roleCode} ${item.esta} ${item.orden ?? ''}'
              .toLowerCase();
      return text.contains(term);
    }).toList()
      ..sort((a, b) {
        final aRole = a.roleCode.compareTo(b.roleCode);
        if (aRole != 0) return aRole;
        final aEsta = a.esta.compareTo(b.esta);
        if (aEsta != 0) return aEsta;
        final aOrden = a.orden ?? 999999;
        final bOrden = b.orden ?? 999999;
        if (aOrden != bOrden) return aOrden.compareTo(bOrden);
        return a.panelMode.compareTo(b.panelMode);
      });

    final roleSet = <String>{};
    if (widget.catalogos != null) {
      for (final role in widget.catalogos!.roles) {
        roleSet.add(role.roleCode);
      }
    }
    final roleItems = roleSet.toList()..sort();

    final estaSet = <String>{};
    final estaDescripcion = <String, String>{};
    if (widget.catalogos != null) {
      for (final estado in widget.catalogos!.estados) {
        final key = _formatEsta(estado.esta);
        estaSet.add(key);
        estaDescripcion[key] = estado.tipo.trim();
      }
    }
    for (final item in widget.items) {
      estaSet.add(_formatEsta(item.esta));
    }
    final estaItems = estaSet.toList()
      ..sort((a, b) => (double.tryParse(a) ?? 0).compareTo(double.tryParse(b) ?? 0));

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(12),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _FiltersBar(
            searchController: _searchCtrl,
            selectedRoleCode: _roleCode,
            selectedEsta: _esta,
            roleItems: roleItems,
            estaItems: estaItems,
            estaDescripcion: estaDescripcion,
            onApply: () => setState(() => _searchApplied = _searchCtrl.text),
            onClear: () => setState(() {
              _searchCtrl.clear();
              _searchApplied = '';
              _roleCode = 'TODOS';
              _esta = 'TODOS';
            }),
            onRoleChanged: (value) => setState(() => _roleCode = value ?? 'TODOS'),
            onEstaChanged: (value) => setState(() => _esta = value ?? 'TODOS'),
          ),
          const SizedBox(height: 12),
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text('No hay registros para los filtros aplicados.'),
              ),
            )
          else
            ...filtered.map(
              (item) => _OrdFlujoVisTile(
                item: item,
                ref: widget.ref,
                updating: _updatingIds.contains(item.id),
                onToggleEstado: _toggleEstado,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _toggleEstado(OrdFlujoVisModel item, bool nextValue) async {
    if (_updatingIds.contains(item.id)) return;
    setState(() => _updatingIds.add(item.id));

    try {
      await widget.ref.read(ordFlujoVisApiProvider).updateEstado(item.id, nextValue);
      widget.ref.invalidate(ordFlujoVisListProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Registro ${item.id} ${nextValue ? 'activado' : 'inactivado'}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar estado: $e')),
      );
    } finally {
      if (mounted) setState(() => _updatingIds.remove(item.id));
    }
  }

  String _formatEsta(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toString();
  }
}

class _FiltersBar extends StatelessWidget {
  const _FiltersBar({
    required this.searchController,
    required this.selectedRoleCode,
    required this.selectedEsta,
    required this.roleItems,
    required this.estaItems,
    required this.estaDescripcion,
    required this.onApply,
    required this.onClear,
    required this.onRoleChanged,
    required this.onEstaChanged,
  });

  final TextEditingController searchController;
  final String selectedRoleCode;
  final String selectedEsta;
  final List<String> roleItems;
  final List<String> estaItems;
  final Map<String, String> estaDescripcion;
  final VoidCallback onApply;
  final VoidCallback onClear;
  final ValueChanged<String?> onRoleChanged;
  final ValueChanged<String?> onEstaChanged;

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
                  labelText: 'Buscar por rol, flujo o id',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => onApply(),
              ),
            ),
            const SizedBox(width: 10),
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
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                key: ValueKey('role-$selectedRoleCode'),
                initialValue: selectedRoleCode,
                decoration: const InputDecoration(
                  labelText: 'ROLL',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(value: 'TODOS', child: Text('TODOS')),
                  ...roleItems.map(
                    (value) => DropdownMenuItem(value: value, child: Text(value)),
                  ),
                ],
                onChanged: onRoleChanged,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<String>(
                key: ValueKey('esta-$selectedEsta'),
                initialValue: selectedEsta,
                decoration: const InputDecoration(
                  labelText: 'ESTSEGU',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(value: 'TODOS', child: Text('TODOS')),
                  ...estaItems.map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(_estaLabel(value)),
                    ),
                  ),
                ],
                onChanged: onEstaChanged,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _estaLabel(String esta) {
    final descripcion = (estaDescripcion[esta] ?? '').trim();
    if (descripcion.isEmpty) return esta;
    return '$esta - $descripcion';
  }
}

class _OrdFlujoVisTile extends StatelessWidget {
  const _OrdFlujoVisTile({
    required this.item,
    required this.ref,
    required this.updating,
    required this.onToggleEstado,
  });

  final OrdFlujoVisModel item;
  final WidgetRef ref;
  final bool updating;
  final Future<void> Function(OrdFlujoVisModel item, bool nextValue)
      onToggleEstado;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      'PANEL: ${item.panelMode.toUpperCase()}',
      'ROL: ${item.roleCode}',
      'ESTA: ${item.esta}',
      'ORDEN: ${item.orden ?? '-'}',
      if (item.soloExterno) 'SOLO EXTERNO',
    ].join('  |  ');

    return Card(
      child: ListTile(
        leading: Icon(
          item.activo ? Icons.check_circle : Icons.block,
          color: item.activo ? Colors.green : Colors.red,
        ),
        title: Text('${item.modulo}  #${item.id}'),
        subtitle: Text(subtitle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: item.activo,
              onChanged: updating ? null : (v) => onToggleEstado(item, v),
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Editar',
              onPressed: () => context.go('/masterdata/ord-flujo-vis/${item.id}'),
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: 'Eliminar',
              onPressed: () => _confirmDelete(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar configuración'),
        content: Text('¿Seguro de eliminar registro #${item.id}?'),
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
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(ordFlujoVisApiProvider).delete(item.id);
      ref.invalidate(ordFlujoVisListProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registro eliminado')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar: $e')),
      );
    }
  }
}
