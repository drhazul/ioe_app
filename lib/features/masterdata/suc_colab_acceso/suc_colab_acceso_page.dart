import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'suc_colab_acceso_models.dart';
import 'suc_colab_acceso_providers.dart';

class SucColabAccesoPage extends ConsumerWidget {
  const SucColabAccesoPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(sucColabAccesoFiltersProvider);
    final rowsAsync = ref.watch(sucColabAccesoListProvider(filters));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Colaboradores compartidos por sucursal'),
        actions: [
          IconButton(
            onPressed: () =>
                ref.invalidate(sucColabAccesoListProvider(filters)),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refrescar',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/masterdata/access/suc-colab-acceso/new'),
        child: const Icon(Icons.add),
      ),
      body: rowsAsync.when(
        data: (items) => _SucColabAccesoList(items: items, ref: ref),
        error: (e, _) => Center(child: Text('Error: $e')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _SucColabAccesoList extends StatefulWidget {
  const _SucColabAccesoList({required this.items, required this.ref});

  final List<SucColabAccesoModel> items;
  final WidgetRef ref;

  @override
  State<_SucColabAccesoList> createState() => _SucColabAccesoListState();
}

class _SucColabAccesoListState extends State<_SucColabAccesoList> {
  final _searchCtrl = TextEditingController();
  bool _includeInactive = true;
  String _searchApplied = '';
  final _updatingIds = <int>{};

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _applyFilters() {
    widget.ref
        .read(sucColabAccesoFiltersProvider.notifier)
        .state = SucColabAccesoFilters(
      search: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
      includeInactive: _includeInactive,
    );
    setState(() => _searchApplied = _searchCtrl.text.trim());
  }

  void _clearFilters() {
    _searchCtrl.clear();
    setState(() {
      _includeInactive = true;
      _searchApplied = '';
    });
    widget.ref.read(sucColabAccesoFiltersProvider.notifier).state =
        const SucColabAccesoFilters();
  }

  Future<void> _refresh() async {
    final filters = widget.ref.read(sucColabAccesoFiltersProvider);
    widget.ref.invalidate(sucColabAccesoListProvider(filters));
    await widget.ref.read(sucColabAccesoListProvider(filters).future);
  }

  Future<void> _toggleEstado(SucColabAccesoModel item, bool nextValue) async {
    if (_updatingIds.contains(item.id)) return;
    setState(() => _updatingIds.add(item.id));
    try {
      await widget.ref.read(sucColabAccesoApiProvider).update(item.id, {
        'ACTIVO': nextValue,
      });
      final filters = widget.ref.read(sucColabAccesoFiltersProvider);
      widget.ref.invalidate(sucColabAccesoListProvider(filters));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nextValue ? 'Relación activada' : 'Relación inactivada',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al actualizar: $e')));
    } finally {
      if (mounted) setState(() => _updatingIds.remove(item.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final term = _searchApplied.trim().toLowerCase();
    final filtered =
        widget.items.where((item) {
          if (!_includeInactive && !item.activo) return false;
          if (term.isEmpty) return true;
          final haystack =
              '${item.sucDestino} ${item.sucDestinoDesc ?? ''} ${item.sucOrigen} ${item.sucOrigenDesc ?? ''} ${item.observacion ?? ''}'
                  .toLowerCase();
          return haystack.contains(term);
        }).toList()..sort((a, b) {
          final dest = a.sucDestino.compareTo(b.sucDestino);
          if (dest != 0) return dest;
          return a.sucOrigen.compareTo(b.sucOrigen);
        });

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(12),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _FiltersBar(
            searchController: _searchCtrl,
            includeInactive: _includeInactive,
            onIncludeInactiveChanged: (value) =>
                setState(() => _includeInactive = value ?? true),
            onApply: _applyFilters,
            onClear: _clearFilters,
          ),
          const SizedBox(height: 12),
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text('No hay relaciones para los filtros aplicados.'),
              ),
            )
          else
            ...filtered.map(
              (item) => _SucColabAccesoTile(
                item: item,
                updating: _updatingIds.contains(item.id),
                onToggleEstado: _toggleEstado,
                onEdit: () => context.go(
                  '/masterdata/access/suc-colab-acceso/${item.id}',
                ),
                onDelete: () => _confirmDelete(context, item),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    SucColabAccesoModel item,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar relación'),
        content: Text(
          '¿Eliminar relación ${item.sucDestino} -> ${item.sucOrigen}?',
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

    try {
      await widget.ref.read(sucColabAccesoApiProvider).delete(item.id);
      final filters = widget.ref.read(sucColabAccesoFiltersProvider);
      widget.ref.invalidate(sucColabAccesoListProvider(filters));
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Relación eliminada')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
    }
  }
}

class _FiltersBar extends StatelessWidget {
  const _FiltersBar({
    required this.searchController,
    required this.includeInactive,
    required this.onIncludeInactiveChanged,
    required this.onApply,
    required this.onClear,
  });

  final TextEditingController searchController;
  final bool includeInactive;
  final ValueChanged<bool?> onIncludeInactiveChanged;
  final VoidCallback onApply;
  final VoidCallback onClear;

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
                  labelText: 'Buscar por sucursal, descripción u observación',
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
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Incluir inactivos'),
          value: includeInactive,
          onChanged: onIncludeInactiveChanged,
        ),
      ],
    );
  }
}

class _SucColabAccesoTile extends StatelessWidget {
  const _SucColabAccesoTile({
    required this.item,
    required this.updating,
    required this.onToggleEstado,
    required this.onEdit,
    required this.onDelete,
  });

  final SucColabAccesoModel item;
  final bool updating;
  final Future<void> Function(SucColabAccesoModel item, bool nextValue)
  onToggleEstado;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final title = '${item.sucDestino} -> ${item.sucOrigen}';
    final subtitle = <String>[
      if ((item.sucDestinoDesc ?? '').trim().isNotEmpty)
        'Destino: ${item.sucDestinoDesc}',
      if ((item.sucOrigenDesc ?? '').trim().isNotEmpty)
        'Origen: ${item.sucOrigenDesc}',
      if ((item.observacion ?? '').trim().isNotEmpty)
        'Obs: ${item.observacion}',
      if (item.fcreg != null) 'Alta: ${item.fcreg}',
      if (item.fcmod != null) 'Mod: ${item.fcmod}',
    ].join('  |  ');

    return Card(
      child: ListTile(
        leading: Icon(
          item.activo ? Icons.link : Icons.link_off,
          color: item.activo ? Colors.green : Colors.red,
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Wrap(
          spacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Switch(
              value: item.activo,
              onChanged: updating
                  ? null
                  : (value) => onToggleEstado(item, value),
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Editar',
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: 'Eliminar',
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
