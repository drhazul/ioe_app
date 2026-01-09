import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'access_models.dart';
import 'access_providers.dart';

class ModulosBackendPage extends ConsumerWidget {
  const ModulosBackendPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modulosAsync = ref.watch(backendModulosProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Módulos (Backend)'),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(backendModulosProvider),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refrescar',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _ModuloBackendForm.show(context, ref),
        child: const Icon(Icons.add),
      ),
      body: modulosAsync.when(
        data: (items) => _ModulosBackendList(items: items, ref: ref),
        error: (e, _) => Center(child: Text('Error: $e')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _ModulosBackendList extends StatefulWidget {
  const _ModulosBackendList({required this.items, required this.ref});

  final List<AccessModulo> items;
  final WidgetRef ref;

  @override
  State<_ModulosBackendList> createState() => _ModulosBackendListState();
}

class _ModulosBackendListState extends State<_ModulosBackendList> {
  final _searchCtrl = TextEditingController();
  String _searchApplied = '';
  String _status = 'TODOS';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete(AccessModulo modulo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text('¿Eliminar módulo ${modulo.codigo}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      await widget.ref.read(accessApiProvider).deleteBackendModulo(modulo.id);
      if (!mounted) return;
      widget.ref.invalidate(backendModulosProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final term = _searchApplied.trim().toLowerCase();
    final filtered = widget.items.where((m) {
      if (_status == 'ACTIVO' && !m.activo) return false;
      if (_status == 'INACTIVO' && m.activo) return false;
      if (term.isEmpty) return true;
      final text = ('${m.codigo} ${m.nombre}').toLowerCase();
      return text.contains(term);
    }).toList();

    return RefreshIndicator(
      onRefresh: () async {
        widget.ref.invalidate(backendModulosProvider);
        await widget.ref.read(backendModulosProvider.future);
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
              child: Center(child: Text('No hay módulos para los filtros aplicados.')),
            )
          else
            for (final modulo in filtered)
              _ModuloRow(
                modulo: modulo,
                onEdit: () => _ModuloBackendForm.show(context, widget.ref, existing: modulo),
                onDelete: () => _confirmDelete(modulo),
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
                  labelText: 'Buscar por código o nombre',
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

class _ModuloRow extends StatelessWidget {
  const _ModuloRow({required this.modulo, required this.onEdit, required this.onDelete});

  final AccessModulo modulo;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        title: Text('${modulo.codigo} - ${modulo.nombre}'),
        subtitle: Text(modulo.activo ? 'Activo' : 'Inactivo'),
        trailing: Wrap(
          spacing: 8,
          children: [
            IconButton(onPressed: onEdit, icon: const Icon(Icons.edit)),
            IconButton(onPressed: onDelete, icon: const Icon(Icons.delete, color: Colors.red)),
          ],
        ),
      ),
    );
  }
}

class _ModuloBackendForm {
  static Future<void> show(BuildContext context, WidgetRef ref, {AccessModulo? existing}) async {
    final codigoCtrl = TextEditingController(text: existing?.codigo ?? '');
    final nombreCtrl = TextEditingController(text: existing?.nombre ?? '');
    var activo = existing?.activo ?? true;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Nuevo módulo' : 'Editar módulo'),
        content: StatefulBuilder(
          builder: (ctx, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codigoCtrl,
                decoration: const InputDecoration(labelText: 'Código'),
              ),
              const SizedBox(height: 10),
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
      'CODIGO': codigoCtrl.text.trim(),
      'NOMBRE': nombreCtrl.text.trim(),
      'ACTIVO': activo,
    };

    try {
      final api = ref.read(accessApiProvider);
      if (existing == null) {
        await api.createBackendModulo(payload);
      } else {
        await api.updateBackendModulo(existing.id, payload);
      }
      if (!context.mounted) return;
      ref.invalidate(backendModulosProvider);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}
