import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'sucursales_models.dart';
import 'sucursales_providers.dart';

class SucursalesPage extends ConsumerWidget {
  const SucursalesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sucursalesAsync = ref.watch(sucursalesListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sucursales'),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(sucursalesListProvider),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refrescar',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/masterdata/sucursales/new'),
        child: const Icon(Icons.add),
      ),
      body: sucursalesAsync.when(
        data: (sucursales) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(sucursalesListProvider);
            await ref.read(sucursalesListProvider.future);
          },
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: sucursales.length,
            itemBuilder: (_, index) => _SucursalTile(model: sucursales[index], ref: ref),
            separatorBuilder: (_, index) => const SizedBox(height: 8),
          ),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _SucursalTile extends StatelessWidget {
  const _SucursalTile({required this.model, required this.ref});

  final SucursalModel model;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final details = [
      if ((model.desc ?? '').isNotEmpty) model.desc,
      if ((model.zona ?? '').isNotEmpty) 'Zona: ${model.zona}',
      if ((model.rfc ?? '').isNotEmpty) 'RFC: ${model.rfc}',
    ].whereType<String>().join(' · ');

    return Card(
      child: ListTile(
        title: Text('SUC ${model.suc}'),
        subtitle: details.isEmpty ? null : Text(details),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => context.go('/masterdata/sucursales/${model.suc}'),
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
        title: const Text('Eliminar sucursal'),
        content: Text('¿Eliminar la sucursal ${model.suc}?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Eliminar')),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;
    try {
      final errMsg = await ref.read(sucursalesApiProvider).deleteSucursal(model.suc);
      if (!context.mounted) return;
      if (errMsg != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errMsg)));
        return;
      }
      ref.invalidate(sucursalesListProvider);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sucursal eliminada')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
    }
  }
}
