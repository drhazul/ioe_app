import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'facturacion_providers.dart';

class FacturacionPage extends ConsumerWidget {
  const FacturacionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendientesAsync = ref.watch(facturasPendientesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Facturación (Sandbox)')),
      body: pendientesAsync.when(
        data: (rows) {
          if (rows.isEmpty) {
            return const Center(child: Text('Sin pendientes por facturar'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final row = rows[i];
              final idFol = int.tryParse('${row['IDFOL'] ?? ''}') ?? 0;
              final estatus = '${row['ESTATUS'] ?? ''}';
              final impt = '${row['IMPT'] ?? ''}';
              return Card(
                child: ListTile(
                  title: Text('Folio $idFol'),
                  subtitle: Text('Estatus: $estatus  |  Importe: $impt'),
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () async {
                          final api = ref.read(facturacionApiProvider);
                          final result = await api.validar(idFol);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Validación: ${result['validaciones'] ?? result.toString()}')),
                            );
                          }
                        },
                        child: const Text('Validar'),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          final api = ref.read(facturacionApiProvider);
                          final result = await api.emitir(idFol);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${result['message'] ?? 'Emitido'}')),
                            );
                            ref.invalidate(facturasPendientesProvider);
                          }
                        },
                        child: const Text('REALIZAR FACTURA'),
                      ),
                      OutlinedButton(
                        onPressed: () async {
                          final api = ref.read(facturacionApiProvider);
                          final result = await api.cancelar(idFol, motivo: 'Cancelación manual desde IOE');
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${result['message'] ?? 'Cancelado'}')),
                            );
                            ref.invalidate(facturasPendientesProvider);
                          }
                        },
                        child: const Text('CANCELAR'),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error cargando pendientes: $e')),
      ),
    );
  }
}
