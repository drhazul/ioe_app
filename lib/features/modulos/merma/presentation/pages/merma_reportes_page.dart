import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/merma_reportes_provider.dart';
import '../widgets/merma_report_filters.dart';

class MermaReportesPage extends ConsumerStatefulWidget {
  const MermaReportesPage({super.key});

  @override
  ConsumerState<MermaReportesPage> createState() => _MermaReportesPageState();
}

class _MermaReportesPageState extends ConsumerState<MermaReportesPage> {
  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();
  String _endpoint = 'mensual';
  Map<String, dynamic> _query = const {};

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query;
    final provider = switch (_endpoint) {
      'mensual' => mermaReporteMensualProvider(query),
      'sucursal' => mermaReporteSucursalProvider(query),
      'taller' => mermaReporteTallerProvider(query),
      'producto' => mermaReporteProductoProvider(query),
      'motivos' => mermaReporteMotivosProvider(query),
      'comparativo' => mermaReporteComparativoProvider(query),
      'anual' => mermaReporteAnualProvider(query),
      _ => mermaReporteMensualProvider(query),
    };
    final asyncRows = ref.watch(provider);
    return Scaffold(
      appBar: AppBar(title: const Text('Reportes de merma')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          DropdownButtonFormField<String>(
            initialValue: _endpoint,
            decoration: const InputDecoration(
              labelText: 'Reporte',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'mensual', child: Text('Mensual general')),
              DropdownMenuItem(value: 'sucursal', child: Text('Por sucursal')),
              DropdownMenuItem(value: 'taller', child: Text('Por taller')),
              DropdownMenuItem(value: 'producto', child: Text('Por producto')),
              DropdownMenuItem(value: 'motivos', child: Text('Por motivos')),
              DropdownMenuItem(value: 'comparativo', child: Text('Comparativo mensual')),
              DropdownMenuItem(value: 'anual', child: Text('Acumulado anual')),
            ],
            onChanged: (value) => setState(() => _endpoint = value ?? 'mensual'),
          ),
          const SizedBox(height: 10),
          MermaReportFilters(
            fromCtrl: _fromCtrl,
            toCtrl: _toCtrl,
            onApply: () => setState(
              () => _query = {
                'from': _fromCtrl.text.trim(),
                'to': _toCtrl.text.trim(),
              },
            ),
          ),
          const SizedBox(height: 12),
          asyncRows.when(
            data: (rows) {
              if (rows.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: Text('Sin datos')),
                );
              }
              final columns = rows.first.keys.toList();
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: columns.map((col) => DataColumn(label: Text(col))).toList(),
                  rows: rows
                      .map(
                        (row) => DataRow(
                          cells: columns
                              .map((col) => DataCell(Text('${row[col] ?? ''}')))
                              .toList(),
                        ),
                      )
                      .toList(),
                ),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Text('Error: $error'),
          ),
        ],
      ),
    );
  }
}
