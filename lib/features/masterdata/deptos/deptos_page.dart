import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'deptos_models.dart';
import 'deptos_providers.dart';

class DeptosPage extends ConsumerWidget {
  const DeptosPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deptosAsync = ref.watch(deptosListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Departamentos'),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(deptosListProvider),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refrescar',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/masterdata/deptos/new'),
        child: const Icon(Icons.add),
      ),
      body: deptosAsync.when(
        data: (deptos) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(deptosListProvider);
            await ref.read(deptosListProvider.future);
          },
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: deptos.length,
            itemBuilder: (_, index) => _DeptoTile(depto: deptos[index], ref: ref),
            separatorBuilder: (_, index) => const SizedBox(height: 8),
          ),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _DeptoTile extends StatelessWidget {
  const _DeptoTile({required this.depto, required this.ref});

  final DeptoModel depto;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(depto.nombre),
        leading: Icon(depto.activo ? Icons.check_circle : Icons.cancel, color: depto.activo ? Colors.green : Colors.red),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => context.go('/masterdata/deptos/${depto.id}'),
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
        title: const Text('Eliminar departamento'),
        content: Text('¿Seguro de eliminar ${depto.nombre}?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Eliminar')),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;
    try {
      await ref.read(deptosApiProvider).deleteDepto(depto.id);
      ref.invalidate(deptosListProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Departamento eliminado')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
    }
  }
}
