import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'roles_models.dart';
import 'roles_providers.dart';

class RolesPage extends ConsumerWidget {
  const RolesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rolesAsync = ref.watch(rolesListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Roles'),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(rolesListProvider),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refrescar',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/masterdata/roles/new'),
        child: const Icon(Icons.add),
      ),
      body: rolesAsync.when(
        data: (roles) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(rolesListProvider);
            await ref.read(rolesListProvider.future);
          },
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: roles.length,
            itemBuilder: (_, index) => _RoleTile(role: roles[index], ref: ref),
            separatorBuilder: (_, index) => const SizedBox(height: 8),
          ),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _RoleTile extends StatelessWidget {
  const _RoleTile({required this.role, required this.ref});

  final RoleModel role;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text('${role.codigo} - ${role.nombre}'),
        subtitle: Text(role.descripcion ?? 'Sin descripción'),
        leading: Icon(role.activo ? Icons.check_circle : Icons.cancel, color: role.activo ? Colors.green : Colors.red),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => context.go('/masterdata/roles/${role.id}'),
            ),
            IconButton(
              icon: const Icon(Icons.delete),
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
        title: const Text('Eliminar rol'),
        content: Text('¿Seguro de eliminar ${role.nombre}?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Eliminar')),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;
    try {
      await ref.read(rolesApiProvider).deleteRole(role.id);
      ref.invalidate(rolesListProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rol eliminado')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
    }
  }
}
