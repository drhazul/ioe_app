import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'dat_form_models.dart';
import 'dat_form_providers.dart';

class DatFormPage extends ConsumerWidget {
  const DatFormPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final datFormsAsync = ref.watch(datFormListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Formas de pago (DAT_FORM)'),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(datFormListProvider),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refrescar',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/masterdata/dat-form/new'),
        child: const Icon(Icons.add),
      ),
      body: datFormsAsync.when(
        data: (items) => _DatFormList(items: items, ref: ref),
        error: (e, _) => Center(child: Text('Error: $e')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _DatFormList extends StatefulWidget {
  const _DatFormList({required this.items, required this.ref});

  final List<DatFormModel> items;
  final WidgetRef ref;

  @override
  State<_DatFormList> createState() => _DatFormListState();
}

class _DatFormListState extends State<_DatFormList> {
  final _searchCtrl = TextEditingController();
  final _updatingIds = <int>{};
  String _searchApplied = '';
  String _selectedStatus = 'TODOS';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    widget.ref.invalidate(datFormListProvider);
    await widget.ref.read(datFormListProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final term = _searchApplied.trim().toLowerCase();
    final filtered = widget.items.where((item) {
      if (_selectedStatus == 'ACTIVO' && !item.estado) return false;
      if (_selectedStatus == 'INACTIVO' && item.estado) return false;

      if (term.isEmpty) return true;
      final haystack =
          '${item.idform} ${item.form} ${item.nom} ${item.aspel ?? ''}'
              .toLowerCase();
      return haystack.contains(term);
    }).toList()..sort((a, b) => a.form.compareTo(b.form));

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(12),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _FiltersBar(
            searchController: _searchCtrl,
            selectedStatus: _selectedStatus,
            onApply: () => setState(() => _searchApplied = _searchCtrl.text),
            onClear: () => setState(() {
              _searchCtrl.clear();
              _searchApplied = '';
              _selectedStatus = 'TODOS';
            }),
            onStatusChanged: (value) =>
                setState(() => _selectedStatus = value ?? 'TODOS'),
          ),
          const SizedBox(height: 12),
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'No hay formas de pago para los filtros aplicados.',
                ),
              ),
            )
          else
            ...filtered.map(
              (item) => _DatFormTile(
                item: item,
                ref: widget.ref,
                updating: _updatingIds.contains(item.idform),
                onToggleEstado: _toggleEstado,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _toggleEstado(DatFormModel item, bool nextValue) async {
    if (_updatingIds.contains(item.idform)) return;
    setState(() => _updatingIds.add(item.idform));

    try {
      await widget.ref
          .read(datFormApiProvider)
          .updateDatFormEstado(item.idform, nextValue);
      widget.ref.invalidate(datFormListProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Forma ${item.form} ${nextValue ? 'activada' : 'inactivada'}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al actualizar estado: $e')));
    } finally {
      if (mounted) {
        setState(() => _updatingIds.remove(item.idform));
      }
    }
  }
}

class _FiltersBar extends StatelessWidget {
  const _FiltersBar({
    required this.searchController,
    required this.selectedStatus,
    required this.onApply,
    required this.onClear,
    required this.onStatusChanged,
  });

  final TextEditingController searchController;
  final String selectedStatus;
  final VoidCallback onApply;
  final VoidCallback onClear;
  final ValueChanged<String?> onStatusChanged;

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
                  labelText: 'Buscar por FORM, NOM, ASPEL o IDFORM',
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
      ],
    );
  }
}

class _DatFormTile extends StatelessWidget {
  const _DatFormTile({
    required this.item,
    required this.ref,
    required this.updating,
    required this.onToggleEstado,
  });

  final DatFormModel item;
  final WidgetRef ref;
  final bool updating;
  final Future<void> Function(DatFormModel item, bool nextValue) onToggleEstado;

  @override
  Widget build(BuildContext context) {
    final subtitle = <String>[
      if (item.nom.isNotEmpty) 'NOM: ${item.nom}',
      if (item.aspel != null) 'ASPEL: ${item.aspel}',
      'IDFORM: ${item.idform}',
    ].join('  |  ');

    return Card(
      child: ListTile(
        leading: Icon(
          item.estado ? Icons.check_circle : Icons.block,
          color: item.estado ? Colors.green : Colors.red,
        ),
        title: Text(item.form),
        subtitle: Text(subtitle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: item.estado,
              onChanged: updating
                  ? null
                  : (value) => onToggleEstado(item, value),
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Editar',
              onPressed: () =>
                  context.go('/masterdata/dat-form/${item.idform}'),
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
        title: const Text('Eliminar forma de pago'),
        content: Text('¿Seguro de eliminar ${item.form}?'),
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

    if (confirmed != true) return;
    if (!context.mounted) return;

    try {
      await ref.read(datFormApiProvider).deleteDatForm(item.idform);
      ref.invalidate(datFormListProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Forma de pago eliminada')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
    }
  }
}
