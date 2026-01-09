import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'datmodulos_models.dart';
import 'datmodulos_providers.dart';

const double _actionsWidth = 96;

class DatmodulosPage extends ConsumerWidget {
  const DatmodulosPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modulosAsync = ref.watch(datmodulosListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Módulos'),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(datmodulosListProvider),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refrescar',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/masterdata/datmodulos/new'),
        child: const Icon(Icons.add),
      ),
      body: modulosAsync.when(
        data: (items) => _DatmodulosList(items: items, ref: ref),
        error: (e, _) => Center(child: Text('Error: $e')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _DatmodulosList extends StatefulWidget {
  const _DatmodulosList({required this.items, required this.ref});

  final List<DatModuloModel> items;
  final WidgetRef ref;

  @override
  State<_DatmodulosList> createState() => _DatmodulosListState();
}

class _DatmodulosListState extends State<_DatmodulosList> {
  final _searchCtrl = TextEditingController();
  String _searchApplied = '';
  String _selectedDepto = 'TODOS';
  String _selectedStatus = 'TODOS';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    widget.ref.invalidate(datmodulosListProvider);
    await widget.ref.read(datmodulosListProvider.future);
  }

  void _clearFilters() {
    setState(() {
      _searchCtrl.clear();
      _searchApplied = '';
      _selectedDepto = 'TODOS';
      _selectedStatus = 'TODOS';
    });
  }

  @override
  Widget build(BuildContext context) {
    final deptoSet = <String>{};
    var hasOtros = false;
    for (final m in widget.items) {
      final depto = (m.depto ?? '').trim();
      if (depto.isEmpty) {
        hasOtros = true;
      } else {
        deptoSet.add(depto.toUpperCase());
      }
    }

    final deptos = [
      'TODOS',
      ...deptoSet.toList()..sort(),
      if (hasOtros) 'OTROS',
    ];

    final effectiveDepto = deptos.contains(_selectedDepto) ? _selectedDepto : 'TODOS';
    final effectiveStatus = _selectedStatus;

    final term = _searchApplied.trim().toLowerCase();
    final filtered = widget.items.where((m) {
      if (effectiveStatus == 'ACTIVO' && !m.activo) return false;
      if (effectiveStatus == 'INACTIVO' && m.activo) return false;

      final depto = (m.depto ?? '').trim();
      final deptoKey = depto.isEmpty ? 'OTROS' : depto.toUpperCase();
      if (effectiveDepto != 'TODOS' && deptoKey != effectiveDepto) return false;

      if (term.isEmpty) return true;
      final text = ('${m.codigo} ${m.nombre} ${m.depto ?? ''}').toLowerCase();
      return text.contains(term);
    }).toList();

    final grouped = <String, List<DatModuloModel>>{};
    for (final m in filtered) {
      final depto = (m.depto ?? '').trim();
      final key = depto.isEmpty ? 'OTROS' : depto.toUpperCase();
      grouped.putIfAbsent(key, () => []).add(m);
    }

    final keys = grouped.keys.toList()..sort();
    if (keys.remove('OTROS')) keys.add('OTROS');
    for (final key in keys) {
      grouped[key]!.sort((a, b) => a.codigo.toUpperCase().compareTo(b.codigo.toUpperCase()));
    }

    final children = <Widget>[
      _FiltersBar(
        searchController: _searchCtrl,
        onApplySearch: () => setState(() => _searchApplied = _searchCtrl.text),
        onClearSearch: _clearFilters,
        deptos: deptos,
        selectedDepto: effectiveDepto,
        onDeptoChanged: (v) => setState(() => _selectedDepto = v ?? 'TODOS'),
        statuses: const ['TODOS', 'ACTIVO', 'INACTIVO'],
        selectedStatus: effectiveStatus,
        onStatusChanged: (v) => setState(() => _selectedStatus = v ?? 'TODOS'),
      ),
      const SizedBox(height: 12),
      const _TableHeader(),
      const SizedBox(height: 8),
    ];

    if (filtered.isEmpty) {
      children.add(
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: Text('No hay módulos para los filtros aplicados.')),
        ),
      );
    } else {
      for (final key in keys) {
        children.addAll([
          _GroupHeader(title: key),
          const SizedBox(height: 8),
          for (final modulo in grouped[key]!) _ModuloRow(modulo: modulo, ref: widget.ref),
          const SizedBox(height: 12),
        ]);
      }
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(12),
        physics: const AlwaysScrollableScrollPhysics(),
        children: children,
      ),
    );
  }
}

class _FiltersBar extends StatelessWidget {
  const _FiltersBar({
    required this.searchController,
    required this.onApplySearch,
    required this.onClearSearch,
    required this.deptos,
    required this.selectedDepto,
    required this.onDeptoChanged,
    required this.statuses,
    required this.selectedStatus,
    required this.onStatusChanged,
  });

  final TextEditingController searchController;
  final VoidCallback onApplySearch;
  final VoidCallback onClearSearch;
  final List<String> deptos;
  final String selectedDepto;
  final ValueChanged<String?> onDeptoChanged;
  final List<String> statuses;
  final String selectedStatus;
  final ValueChanged<String?> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: searchController,
                decoration: const InputDecoration(
                  labelText: 'Buscar por código, nombre o depto',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => onApplySearch(),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: onApplySearch,
              icon: const Icon(Icons.search),
              label: const Text('Filtrar'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: onClearSearch,
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
                key: ValueKey(selectedDepto),
                initialValue: selectedDepto,
                decoration: const InputDecoration(
                  labelText: 'Departamento',
                  border: OutlineInputBorder(),
                ),
                items: deptos
                    .map((d) => DropdownMenuItem<String>(
                          value: d,
                          child: Text(d),
                        ))
                    .toList(),
                onChanged: onDeptoChanged,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<String>(
                key: ValueKey(selectedStatus),
                initialValue: selectedStatus,
                decoration: const InputDecoration(
                  labelText: 'Estatus',
                  border: OutlineInputBorder(),
                ),
                items: statuses
                    .map((s) => DropdownMenuItem<String>(
                          value: s,
                          child: Text(s),
                        ))
                    .toList(),
                onChanged: onStatusChanged,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: const [
          Expanded(
            flex: 2,
            child: Text(
              'CODIGO',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            flex: 4,
            child: Text(
              'NOMBRE',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              'DEPTO',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              'ESTATUS',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ),
          SizedBox(width: 12),
          SizedBox(
            width: _actionsWidth,
            child: Text(
              'ACCIONES',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.4),
      ),
    );
  }
}

class _ModuloRow extends StatelessWidget {
  const _ModuloRow({required this.modulo, required this.ref});

  final DatModuloModel modulo;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final depto = (modulo.depto ?? '').trim();
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                modulo.codigo,
                style: const TextStyle(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 4,
              child: Text(
                modulo.nombre,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Text(
                depto.isEmpty ? 'OTROS' : depto,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: Text(
                modulo.activo ? 'Activo' : 'Inactivo',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: _actionsWidth,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit),
                    tooltip: 'Editar',
                    onPressed: () => context.go('/masterdata/datmodulos/${modulo.codigo}'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    tooltip: 'Eliminar',
                    onPressed: () => _confirmDelete(context),
                  ),
                ],
              ),
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
        title: const Text('Eliminar módulo'),
        content: Text('¿Seguro de eliminar ${modulo.codigo}?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Eliminar')),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;
    try {
      await ref.read(datmodulosApiProvider).deleteModulo(modulo.codigo);
      ref.invalidate(datmodulosListProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Módulo eliminado')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
    }
  }
}
