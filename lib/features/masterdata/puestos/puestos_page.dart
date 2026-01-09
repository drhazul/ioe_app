import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'puestos_models.dart';
import 'puestos_providers.dart';

class PuestosPage extends ConsumerWidget {
  const PuestosPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final puestosAsync = ref.watch(puestosListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Puestos'),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(puestosListProvider),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refrescar',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/masterdata/puestos/new'),
        child: const Icon(Icons.add),
      ),
      body: puestosAsync.when(
        data: (puestos) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(puestosListProvider);
            await ref.read(puestosListProvider.future);
          },
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: puestos.length,
            itemBuilder: (_, index) => _PuestoTile(model: puestos[index], ref: ref),
            separatorBuilder: (_, index) => const SizedBox(height: 8),
          ),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _PuestoTile extends StatelessWidget {
  const _PuestoTile({required this.model, required this.ref});

  final PuestoModel model;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(model.nombre),
        subtitle: Text(model.deptoNombre != null ? 'Depto: ${model.deptoNombre}' : 'IDDEPTO: ${model.idDepto}'),
        leading: Icon(model.activo ? Icons.check_circle : Icons.cancel, color: model.activo ? Colors.green : Colors.red),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => context.go('/masterdata/puestos/${model.id}'),
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
        title: const Text('Eliminar puesto'),
        content: Text('¿Eliminar "${model.nombre}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Eliminar')),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;
    try {
      await ref.read(puestosApiProvider).deletePuesto(model.id);
      ref.invalidate(puestosListProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Puesto eliminado')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
    }
  }
}
