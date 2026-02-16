import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ioe_app/core/api_error.dart';

import 'ctrl_ctas_models.dart';
import 'ctrl_ctas_providers.dart';

class CtrlCtasDetallePage extends ConsumerWidget {
  const CtrlCtasDetallePage({super.key, required this.filtros});

  final CtrlCtasFiltros filtros;

  String _fmtMoney(double value) => value.toStringAsFixed(2);

  String _fmtDate(DateTime? value) {
    if (value == null) return '-';
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    final hh = value.hour.toString().padLeft(2, '0');
    final mm = value.minute.toString().padLeft(2, '0');
    return '$d/$m/$y $hh:$mm';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (filtros.idfols.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalle por Transaccion')),
        body: const Center(child: Text('Debes seleccionar al menos un IDFOL')),
      );
    }

    final dataAsync = ref.watch(ctrlCtasDetalleProvider(filtros));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle por Transaccion'),
        actions: [
          IconButton(
            tooltip: 'Refrescar',
            onPressed: () => ref.invalidate(ctrlCtasDetalleProvider(filtros)),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Text('IDFOL: ', style: TextStyle(fontWeight: FontWeight.w600)),
                    Expanded(child: Text(filtros.idfols.join(', '))),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: dataAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Error: ${apiErrorMessage(error)}')),
              data: (items) {
                if (items.isEmpty) {
                  return const Center(child: Text('Sin resultados'));
                }

                return Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
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
                                DataColumn(label: Text('FCND')),
                                DataColumn(label: Text('NDOC')),
                                DataColumn(label: Text('SUC')),
                                DataColumn(label: Text('CLIENT')),
                                DataColumn(label: Text('Razon social')),
                                DataColumn(label: Text('CTA')),
                                DataColumn(label: Text('CLSD')),
                                DataColumn(label: Text('IDFOL')),
                                DataColumn(label: Text('RTXT')),
                                DataColumn(label: Text('IMPT')),
                                DataColumn(label: Text('IDOPV')),
                              ],
                              rows: [
                                for (final row in items)
                                  DataRow(
                                    cells: [
                                      DataCell(Text(_fmtDate(row.fcnd))),
                                      DataCell(Text(row.ndoc ?? '-')),
                                      DataCell(Text(row.suc ?? '-')),
                                      DataCell(Text(row.client ?? '-')),
                                      DataCell(Text(row.razonSocial ?? 'Sin nombre')),
                                      DataCell(Text(row.cta ?? '-')),
                                      DataCell(Text(row.clsd ?? '-')),
                                      DataCell(Text(row.idfol ?? '-')),
                                      DataCell(Text(row.rtxt ?? '-')),
                                      DataCell(Text(_fmtMoney(row.impt))),
                                      DataCell(Text(row.idopv ?? '-')),
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
          ),
        ],
      ),
    );
  }
}
