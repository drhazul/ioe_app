import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/cat_ctas_providers.dart';
import '../domain/cat_cta.dart';

class CatCtasListPage extends ConsumerStatefulWidget {
  const CatCtasListPage({super.key});

  @override
  ConsumerState<CatCtasListPage> createState() => _CatCtasListPageState();
}

class _CatCtasListPageState extends ConsumerState<CatCtasListPage> {
  late final TextEditingController _searchCtrl;
  late final TextEditingController _sucCtrl;

  @override
  void initState() {
    super.initState();
    final query = ref.read(catCtasQueryProvider);
    _searchCtrl = TextEditingController(text: query.search ?? '');
    _sucCtrl = TextEditingController(text: query.suc ?? '');
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _sucCtrl.dispose();
    super.dispose();
  }

  void _applyFilters() {
    final current = ref.read(catCtasQueryProvider);
    ref.read(catCtasQueryProvider.notifier).state = current.copyWith(
          search: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
          suc: _sucCtrl.text.trim().isEmpty ? null : _sucCtrl.text.trim(),
          page: 1,
        );
  }

  void _clearFilters() {
    _searchCtrl.clear();
    _sucCtrl.clear();
    ref.read(catCtasQueryProvider.notifier).state = const CatCtasQuery();
  }

  void _goToPage(int page) {
    final current = ref.read(catCtasQueryProvider);
    ref.read(catCtasQueryProvider.notifier).state = current.copyWith(page: page);
  }

  Future<void> _confirmDelete(CatCta item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar cuenta'),
        content: Text('¿Eliminar la cuenta ${item.cta}?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Eliminar')),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      await ref.read(catCtasRepoProvider).delete(item.cta);
      ref.invalidate(catCtasListProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cuenta eliminada')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(catCtasQueryProvider);
    final pageAsync = ref.watch(catCtasListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catalogo Cuentas'),
        actions: [
          IconButton(
            tooltip: 'Refrescar',
            onPressed: () => ref.invalidate(catCtasListProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/masterdata/cat-ctas/new'),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Buscar CTA / descripcion / relacion',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _applyFilters(),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 130,
                  child: TextField(
                    controller: _sucCtrl,
                    decoration: const InputDecoration(
                      labelText: 'SUC',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _applyFilters(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _applyFilters,
                  icon: const Icon(Icons.search),
                  label: const Text('Filtrar'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.clear),
                  label: const Text('Limpiar'),
                ),
              ],
            ),
          ),
          Expanded(
            child: pageAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Error: $error')),
              data: (page) {
                if (page.items.isEmpty) {
                  return const Center(child: Text('Sin cuentas para mostrar'));
                }

                final totalPages = page.limit <= 0 ? 1 : ((page.total + page.limit - 1) ~/ page.limit);
                final canPrev = query.page > 1;
                final canNext = query.page < totalPages;

                return Column(
                  children: [
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () async {
                          ref.invalidate(catCtasListProvider);
                          await ref.read(catCtasListProvider.future);
                        },
                        child: ListView.separated(
                          padding: const EdgeInsets.all(12),
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: page.items.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (_, index) {
                            final item = page.items[index];
                            final details = [
                              if ((item.dcta ?? '').trim().isNotEmpty) item.dcta,
                              if ((item.relacion ?? '').trim().isNotEmpty) 'Relacion: ${item.relacion}',
                              if ((item.suc ?? '').trim().isNotEmpty) 'SUC: ${item.suc}',
                            ].whereType<String>().join(' · ');

                            return Card(
                              child: ListTile(
                                title: Text(item.cta),
                                subtitle: details.isEmpty ? null : Text(details),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      onPressed: () => context.go('/masterdata/cat-ctas/${Uri.encodeComponent(item.cta)}'),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete),
                                      onPressed: () => _confirmDelete(item),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text('Total: ${page.total}'),
                          const SizedBox(width: 12),
                          OutlinedButton(
                            onPressed: canPrev ? () => _goToPage(query.page - 1) : null,
                            child: const Text('Anterior'),
                          ),
                          const SizedBox(width: 8),
                          Text('Pagina ${query.page} / $totalPages'),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: canNext ? () => _goToPage(query.page + 1) : null,
                            child: const Text('Siguiente'),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
