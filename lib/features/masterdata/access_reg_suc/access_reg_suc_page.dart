import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'access_reg_suc_models.dart';
import 'access_reg_suc_providers.dart';

class AccessRegSucPage extends ConsumerWidget {
  const AccessRegSucPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(accessRegSucListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Acceso por sucursal'),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(accessRegSucListProvider),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refrescar',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/masterdata/access-reg-suc/new'),
        child: const Icon(Icons.add),
      ),
      body: dataAsync.when(
        data: (rows) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(accessRegSucListProvider);
            await ref.read(accessRegSucListProvider.future);
          },
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: rows.length,
            itemBuilder: (_, index) => _AccessRegSucTile(model: rows[index], ref: ref),
            separatorBuilder: (_, _) => const SizedBox(height: 8),
          ),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _AccessRegSucTile extends StatelessWidget {
  const _AccessRegSucTile({required this.model, required this.ref});

  final AccessRegSucModel model;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final title = '${model.modulo} · ${model.suc}';
    final subtitle = 'Usuario: ${model.usuario}';

    return Card(
      child: ListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        leading: Icon(model.activo ? Icons.check_circle : Icons.cancel, color: model.activo ? Colors.green : Colors.red),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => context.go(
                '/masterdata/access-reg-suc/${Uri.encodeComponent(model.modulo)}/${Uri.encodeComponent(model.usuario)}/${Uri.encodeComponent(model.suc)}',
              ),
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
        title: const Text('Eliminar acceso'),
        content: Text('¿Eliminar ${model.usuario} en ${model.modulo} / ${model.suc}?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Eliminar')),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;
    try {
      await ref.read(accessRegSucApiProvider).delete(model.modulo, model.usuario, model.suc);
      ref.invalidate(accessRegSucListProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Acceso eliminado')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
    }
  }
}
