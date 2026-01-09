import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'access_models.dart';
import 'access_providers.dart';

class GruposBackendPage extends ConsumerWidget {
  const GruposBackendPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gruposAsync = ref.watch(backendGruposProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Grupos (Backend)'),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(backendGruposProvider),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refrescar',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _GrupoBackendForm.show(context, ref),
        child: const Icon(Icons.add),
      ),
      body: gruposAsync.when(
        data: (items) => _GruposBackendList(items: items, ref: ref),
        error: (e, _) => Center(child: Text('Error: $e')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _GruposBackendList extends StatefulWidget {
  const _GruposBackendList({required this.items, required this.ref});

  final List<AccessGrupoModulo> items;
  final WidgetRef ref;

  @override
  State<_GruposBackendList> createState() => _GruposBackendListState();
}

class _GruposBackendListState extends State<_GruposBackendList> {
  final _searchCtrl = TextEditingController();
  String _searchApplied = '';
  String _status = 'TODOS';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete(AccessGrupoModulo grupo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text('¿Eliminar grupo ${grupo.nombre}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      await widget.ref.read(accessApiProvider).deleteBackendGrupo(grupo.id);
      if (!mounted) return;
      widget.ref.invalidate(backendGruposProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _assignModules(AccessGrupoModulo grupo) async {
    final api = widget.ref.read(accessApiProvider);
    final allMods = await widget.ref.read(backendModulosProvider.future);
    allMods.sort((a, b) => a.codigo.compareTo(b.codigo));
    final assigned = await widget.ref.read(backendGroupModulesProvider(grupo.id).future);

    final selected = assigned.map((e) => e.id).toSet();

    if (!mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Asignar módulos a ${grupo.nombre}'),
        content: StatefulBuilder(
          builder: (ctx, setState) => SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final mod in allMods)
                  CheckboxListTile(
                    value: selected.contains(mod.id),
                    title: Text('${mod.codigo} - ${mod.nombre}'),
                    subtitle: Text(mod.activo ? 'Activo' : 'Inactivo'),
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          selected.add(mod.id);
                        } else {
                          selected.remove(mod.id);
                        }
                      });
                    },
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
        ],
      ),
    );

    if (saved != true) return;
    await api.setBackendGroupModules(grupo.id, selected.toList());
    if (!mounted) return;
    widget.ref.invalidate(backendGroupModulesProvider(grupo.id));
  }

  @override
  Widget build(BuildContext context) {
    final term = _searchApplied.trim().toLowerCase();
    final filtered = widget.items.where((g) {
      if (_status == 'ACTIVO' && !g.activo) return false;
      if (_status == 'INACTIVO' && g.activo) return false;
      if (term.isEmpty) return true;
      final text = g.nombre.toLowerCase();
      return text.contains(term);
    }).toList();

    return RefreshIndicator(
      onRefresh: () async {
        widget.ref.invalidate(backendGruposProvider);
        await widget.ref.read(backendGruposProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.all(12),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _FiltersBar(
            searchController: _searchCtrl,
            onApplySearch: () => setState(() => _searchApplied = _searchCtrl.text),
            onClearSearch: () => setState(() {
              _searchCtrl.clear();
              _searchApplied = '';
              _status = 'TODOS';
            }),
            status: _status,
            onStatusChanged: (value) => setState(() => _status = value ?? 'TODOS'),
          ),
          const SizedBox(height: 12),
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('No hay grupos para los filtros aplicados.')),
            )
          else
            for (final grupo in filtered)
              _GrupoRow(
                grupo: grupo,
                onEdit: () => _GrupoBackendForm.show(context, widget.ref, existing: grupo),
                onDelete: () => _confirmDelete(grupo),
                onAssign: () => _assignModules(grupo),
              ),
        ],
      ),
    );
  }
}

class _FiltersBar extends StatelessWidget {
  const _FiltersBar({
    required this.searchController,
    required this.onApplySearch,
    required this.onClearSearch,
    required this.status,
    required this.onStatusChanged,
  });

  final TextEditingController searchController;
  final VoidCallback onApplySearch;
  final VoidCallback onClearSearch;
  final String status;
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
                  labelText: 'Buscar por nombre',
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
        DropdownButtonFormField<String>(
          key: ValueKey(status),
          initialValue: status,
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

class _GrupoRow extends StatelessWidget {
  const _GrupoRow({
    required this.grupo,
    required this.onEdit,
    required this.onDelete,
    required this.onAssign,
  });

  final AccessGrupoModulo grupo;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAssign;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        title: Text(grupo.nombre),
        subtitle: Text(grupo.activo ? 'Activo' : 'Inactivo'),
        trailing: Wrap(
          spacing: 8,
          children: [
            IconButton(onPressed: onAssign, icon: const Icon(Icons.link)),
            IconButton(onPressed: onEdit, icon: const Icon(Icons.edit)),
            IconButton(onPressed: onDelete, icon: const Icon(Icons.delete, color: Colors.red)),
          ],
        ),
      ),
    );
  }
}

class _GrupoBackendForm {
  static Future<void> show(BuildContext context, WidgetRef ref, {AccessGrupoModulo? existing}) async {
    final nombreCtrl = TextEditingController(text: existing?.nombre ?? '');
    var activo = existing?.activo ?? true;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Nuevo grupo' : 'Editar grupo'),
        content: StatefulBuilder(
          builder: (ctx, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreCtrl,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Activo'),
                value: activo,
                onChanged: (v) => setState(() => activo = v),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
        ],
      ),
    );

    if (saved != true) return;

    final payload = {
      'NOMBRE': nombreCtrl.text.trim(),
      'ACTIVO': activo,
    };

    try {
      final api = ref.read(accessApiProvider);
      if (existing == null) {
        await api.createBackendGrupo(payload);
      } else {
        await api.updateBackendGrupo(existing.id, payload);
      }
      if (!context.mounted) return;
      ref.invalidate(backendGruposProvider);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}
