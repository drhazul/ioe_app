import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../devoluciones_models.dart';
import '../devoluciones_providers.dart';

class DetalleDevolucionResumenPage extends ConsumerWidget {
  const DetalleDevolucionResumenPage({
    super.key,
    required this.idfolDev,
  });

  final String idfolDev;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detalleAsync = ref.watch(devolucionDetallePreparadoProvider(idfolDev));
    final appBarCanIrPago = detalleAsync.maybeWhen(
      data: (detalle) => detalle.items.isNotEmpty,
      orElse: () => false,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle devolución'),
        actions: [
          IconButton(
            tooltip: 'Ir a pago',
            onPressed: appBarCanIrPago
                ? () => context.go(
                      '/punto-venta/devoluciones/${Uri.encodeComponent(idfolDev)}/pago',
                    )
                : null,
            icon: const Icon(Icons.point_of_sale),
          ),
          IconButton(
            tooltip: 'Refrescar',
            onPressed: () => ref.invalidate(devolucionDetallePreparadoProvider(idfolDev)),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF6F2EB), Color(0xFFEFE7DB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: detalleAsync.when(
          data: (detalle) => RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(devolucionDetallePreparadoProvider(idfolDev));
              await ref.read(devolucionDetallePreparadoProvider(idfolDev).future);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _HeaderCard(detalle: detalle),
                const SizedBox(height: 12),
                _LinesTable(lines: detalle.items),
              ],
            ),
          ),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'No se pudo preparar detalle de devolución',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$error',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      FilledButton(
                        onPressed: () =>
                            ref.invalidate(devolucionDetallePreparadoProvider(idfolDev)),
                        child: const Text('Reintentar'),
                      ),
                      OutlinedButton(
                        onPressed: () => context.go(
                          '/punto-venta/devoluciones/${Uri.encodeComponent(idfolDev)}',
                        ),
                        child: const Text('Regresar selección'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.detalle});

  final DevolucionDetallePreparadoResponse detalle;

  @override
  Widget build(BuildContext context) {
    final contextData = detalle.context;
    final summary = detalle.summary;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 18,
          runSpacing: 8,
          children: [
            _kv('Folio devolución', contextData.idfolDev),
            _kv('Folio origen', contextData.idfolOrig),
            _kv('Sucursal', contextData.suc),
            _kv('Cliente', contextData.clien?.toStringAsFixed(0) ?? '-'),
            _kv('Líneas ticket', summary.lines.toString()),
            _kv('Total ticket', '\$${summary.total.toStringAsFixed(2)}'),
          ],
        ),
      ),
    );
  }

  Widget _kv(String key, String value) {
    return SizedBox(
      width: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            key,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          SelectableText(
            value,
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}

class _LinesTable extends StatelessWidget {
  const _LinesTable({required this.lines});

  final List<DevolucionDetallePreparadoItem> lines;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TableHeader(
              columns: const ['DES', 'CTD', 'PVTA', 'PVTAT', 'ORD'],
              widths: const [280, 90, 100, 110, 150],
            ),
            const Divider(height: 1),
            if (lines.isEmpty)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Sin artículos seleccionados para devolución.'),
              )
            else
              SizedBox(
                height: 380,
                child: ListView.separated(
                  itemCount: lines.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final line = lines[index];
                    return _TableRow(
                      children: [
                        _TableCell(
                          width: 280,
                          child: Text(
                            line.des ?? '-',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _TableCell(
                          width: 90,
                          child: Text(line.ctd.toStringAsFixed(3)),
                        ),
                        _TableCell(
                          width: 100,
                          child: Text('\$${line.pvta.toStringAsFixed(2)}'),
                        ),
                        _TableCell(
                          width: 110,
                          child: Text('\$${line.pvtat.toStringAsFixed(2)}'),
                        ),
                        _TableCell(
                          width: 150,
                          child: Text(line.ord ?? '-'),
                        ),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader({required this.columns, required this.widths});

  final List<String> columns;
  final List<double> widths;

  @override
  Widget build(BuildContext context) {
    return _TableRow(
      children: [
        for (var i = 0; i < columns.length; i++)
          _TableCell(
            width: widths[i],
            child: Text(
              columns[i],
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: children),
    );
  }
}

class _TableCell extends StatelessWidget {
  const _TableCell({required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: DefaultTextStyle.merge(
          style: const TextStyle(fontSize: 11),
          child: child,
        ),
      ),
    );
  }
}
