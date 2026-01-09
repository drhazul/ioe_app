import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'users_models.dart';
import 'users_providers.dart';

class UsersPage extends ConsumerWidget {
  const UsersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(usersListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Usuarios'),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(usersListProvider),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refrescar',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/masterdata/users/new'),
        child: const Icon(Icons.add),
      ),
      body: usersAsync.when(
        data: (users) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(usersListProvider);
            await ref.read(usersListProvider.future);
          },
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: users.length,
            itemBuilder: (_, index) => _UserTile(user: users[index], ref: ref),
            separatorBuilder: (_, index) => const SizedBox(height: 8),
          ),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user, required this.ref});

  final UserModel user;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final role = user.rolNombre ?? 'Rol ${user.idRol}';
    final depto = user.deptoNombre != null ? 'Depto: ${user.deptoNombre}' : null;
    final puesto = user.puestoNombre != null ? 'Puesto: ${user.puestoNombre}' : null;
    final suc = user.suc != null ? 'Suc: ${user.suc}' : null;

    return Card(
      child: ListTile(
        title: Text('${user.displayName} (${user.username})'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${user.mail} · $role · Estatus: ${user.estatus}'),
            if (depto != null || puesto != null || suc != null)
              Text([depto, puesto, suc].where((v) => v != null).join(' · ')),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => context.go('/masterdata/users/${user.id}'),
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
        title: const Text('Eliminar usuario'),
        content: Text('¿Eliminar a ${user.username}?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Eliminar')),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;
    try {
      await ref.read(usersApiProvider).deleteUser(user.id);
      ref.invalidate(usersListProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usuario eliminado')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
    }
  }
}
