import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ioe_app/core/api_error.dart';

import 'ctrl_ctas_models.dart';
import 'ctrl_ctas_providers.dart';

class CtrlCtasResumenTransaccionPage extends ConsumerWidget {
  const CtrlCtasResumenTransaccionPage({super.key, required this.filtros});

  final CtrlCtasFiltros filtros;

  String _fmtMoney(double value) {
    return value.toStringAsFixed(2);
  }

  void _openDetalle(BuildContext context, CtrlCtasResumenTransItem row) {
    final idfol = (row.idfol ?? '').trim();
    if (idfol.isEmpty) return;
    final next = filtros.copyWith(idfols: [idfol]);
    context.go('/ctrl-ctas/detalle', extra: next.toJson());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(ctrlCtasResumenTransProvider(filtros));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resumen por Transaccion'),
        actions: [
          IconButton(
            tooltip: 'Refrescar',
            onPressed: () => ref.invalidate(ctrlCtasResumenTransProvider(filtros)),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: dataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: ${apiErrorMessage(error)}')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('Sin resultados'));
          }

          return Padding(
            padding: const EdgeInsets.all(12),
            child: Align(
              alignment: Alignment.topLeft,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Scrollbar(
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columnSpacing: 14,
                        horizontalMargin: 8,
                        headingRowHeight: 38,
                        dataRowMinHeight: 34,
                        dataRowMaxHeight: 40,
                        columns: const [
                          DataColumn(label: Text('CLIENT')),
                          DataColumn(label: Text('Razon social')),
                          DataColumn(label: Text('CTA')),
                          DataColumn(label: Text('IDFOL')),
                          DataColumn(label: Text('Total')),
                        ],
                        rows: [
                          for (final row in items)
                            DataRow(
                              cells: [
                                DataCell(
                                  Text(row.client),
                                  onTap: () => _openDetalle(context, row),
                                ),
                                DataCell(
                                  Text(row.razonSocial ?? 'Sin nombre'),
                                  onTap: () => _openDetalle(context, row),
                                ),
                                DataCell(
                                  Text(row.cta ?? '-'),
                                  onTap: () => _openDetalle(context, row),
                                ),
                                DataCell(
                                  Text(row.idfol ?? '-'),
                                  onTap: () => _openDetalle(context, row),
                                ),
                                DataCell(
                                  Text(_fmtMoney(row.total)),
                                  onTap: () => _openDetalle(context, row),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
