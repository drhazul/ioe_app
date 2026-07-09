import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'empresas_models.dart';
import 'empresas_providers.dart';

class EmpresasPage extends ConsumerWidget {
  const EmpresasPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final empresasAsync = ref.watch(empresasListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Empresas'),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(empresasListProvider),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refrescar',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/masterdata/empresas/new'),
        child: const Icon(Icons.add),
      ),
      body: empresasAsync.when(
        data: (items) => _EmpresasList(items: items, ref: ref),
        error: (e, _) => Center(child: Text('Error: $e')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _EmpresasList extends StatelessWidget {
  const _EmpresasList({required this.items, required this.ref});

  final List<EmpresaModel> items;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('No hay empresas registradas.'));
    }

    final sorted = [...items]
      ..sort((a, b) => a.razonSocial.compareTo(b.razonSocial));

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final item = sorted[index];
        final subtitle = <String>[
          item.correo,
          if ((item.rfc ?? '').isNotEmpty) 'RFC: ${item.rfc}',
          if ((item.telefono ?? '').isNotEmpty) 'Tel: ${item.telefono}',
        ].join('  |  ');

        return Card(
          child: ListTile(
            leading: const Icon(Icons.business),
            title: Text(item.razonSocial),
            subtitle: Text(subtitle),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'Editar',
                  onPressed: () =>
                      context.go('/masterdata/empresas/${item.idempresa}'),
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  tooltip: 'Eliminar',
                  onPressed: () => _confirmDelete(context, item),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, EmpresaModel item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar empresa'),
        content: Text('¿Seguro de eliminar ${item.razonSocial}?'),
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

    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(empresasApiProvider).deleteEmpresa(item.idempresa);
      ref.invalidate(empresasListProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Empresa eliminada')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
    }
  }
}
