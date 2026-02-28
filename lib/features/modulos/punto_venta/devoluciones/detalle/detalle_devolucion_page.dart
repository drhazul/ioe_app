import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ioe_app/core/api_error.dart';

import '../devoluciones_models.dart';
import '../devoluciones_providers.dart';

class DetalleDevolucionPage extends ConsumerStatefulWidget {
  const DetalleDevolucionPage({
    super.key,
    required this.idfolDev,
  });

  final String idfolDev;

  @override
  ConsumerState<DetalleDevolucionPage> createState() => _DetalleDevolucionPageState();
}

class _DetalleDevolucionPageState extends ConsumerState<DetalleDevolucionPage> {
  bool _loadingAction = false;

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(devolucionDetalleProvider(widget.idfolDev));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Selección de artículos'),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(devolucionDetalleProvider(widget.idfolDev)),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refrescar',
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
        child: detailAsync.when(
          data: (detail) {
            if (_isEstadoPagado(detail.header.estaDev)) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                context.go(
                  '/punto-venta/devoluciones/${Uri.encodeComponent(widget.idfolDev)}/pago',
                );
              });
              return const Center(child: CircularProgressIndicator());
            }
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(devolucionDetalleProvider(widget.idfolDev));
                await ref.read(devolucionDetalleProvider(widget.idfolDev).future);
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _HeaderCard(header: detail.header, summary: detail.summary),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: _loadingAction
                            ? null
                            : () => _devolverTodo(detail),
                        icon: const Icon(Icons.done_all),
                        label: const Text('Devolver TODO'),
                      ),
                      FilledButton.icon(
                        onPressed: detail.summary.linesSelected > 0
                            ? () => context.go(
                                  '/punto-venta/devoluciones/${Uri.encodeComponent(widget.idfolDev)}/detalle',
                                )
                            : null,
                        icon: const Icon(Icons.payments_outlined),
                        label: const Text('Ir Detalle devolución'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => context.go('/punto-venta/devoluciones'),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Regresar'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _LinesTable(
                    lines: detail.lines,
                    onEditCtdd: (line) => _editCtdd(line),
                  ),
                ],
              ),
            );
          },
          error: (e, _) => Center(child: Text('Error: $e')),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }

  Future<void> _devolverTodo(DevolucionDetalleResponse detail) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Devolver TODO'),
        content: Text(
          'Se establecerá CTDD disponible en líneas permitidas del folio ${detail.header.idfolDev}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _loadingAction = true);
    try {
      await ref.read(devolucionesApiProvider).devolverTodo(widget.idfolDev);
      ref.invalidate(devolucionDetalleProvider(widget.idfolDev));
    } catch (e) {
      if (!mounted) return;
      _showError(apiErrorMessage(e, fallback: 'No se pudo aplicar Devolver TODO'));
    } finally {
      if (mounted) {
        setState(() => _loadingAction = false);
      }
    }
  }

  Future<void> _editCtdd(DevolucionDetalleLine line) async {
    final ctrl = TextEditingController(
      text: line.ctdd == null ? '' : line.ctdd!.toStringAsFixed(4),
    );
    bool submitting = false;
    String? errorText;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> submit({required bool clear}) async {
            if (!clear) {
              final value = double.tryParse(ctrl.text.trim());
              if (value == null || value <= 0) {
                setDialogState(() => errorText = 'Capture un CTDD válido');
                return;
              }
            }
            setDialogState(() {
              submitting = true;
              errorText = null;
            });
            var closed = false;
            try {
              await ref.read(devolucionesApiProvider).updateCtdd(
                    idfolDev: widget.idfolDev,
                    lineId: line.id,
                    ctdd: clear ? null : double.parse(ctrl.text.trim()),
                  );
              ref.invalidate(devolucionDetalleProvider(widget.idfolDev));
              if (!ctx.mounted) return;
              closed = true;
              Navigator.of(ctx).pop();
            } catch (e) {
              if (ctx.mounted) {
                setDialogState(
                  () => errorText = apiErrorMessage(
                    e,
                    fallback: 'No se pudo actualizar CTDD',
                  ),
                );
              }
            } finally {
              if (!closed && ctx.mounted) {
                setDialogState(() => submitting = false);
              }
            }
          }

          return AlertDialog(
            title: Text('Editar CTDD (${line.id})'),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('DES: ${line.des ?? '-'}'),
                  const SizedBox(height: 6),
                  Text('Disponible: ${line.difd.toStringAsFixed(4)}'),
                  if ((line.ord ?? '').isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('ORD: ${line.ord}'),
                  ],
                  const SizedBox(height: 10),
                  TextField(
                    controller: ctrl,
                    enabled: !submitting,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'CTDD',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      errorText!,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: submitting ? null : () => Navigator.of(ctx).pop(),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: submitting ? null : () => submit(clear: true),
                child: const Text('Limpiar'),
              ),
              FilledButton(
                onPressed: submitting ? null : () => submit(clear: false),
                child: submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );

  }

  void _showError(String message) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  bool _isEstadoPagado(String? value) {
    final estado = (value ?? '').trim().toUpperCase();
    return estado.contains('PAGADO');
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.header,
    required this.summary,
  });

  final DevolucionDetalleHeader header;
  final DevolucionDetalleSummary summary;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 18,
          runSpacing: 8,
          children: [
            _kv('Folio devolución', header.idfolDev),
            _kv('Folio origen', header.idfolOrig),
            _kv('Sucursal', header.suc),
            _kv('AUT dev', header.autDev),
            _kv('AUT origen', header.autOrig),
            _kv('Cliente', header.clien?.toStringAsFixed(0) ?? '-'),
            _kv('Tipo', header.tipotran),
            _kv('Estado', header.estaDev ?? '-'),
            _kv('Líneas', summary.lines.toString()),
            _kv('Seleccionadas', summary.linesSelected.toString()),
            _kv('Total selección', '\$${summary.totalSeleccion.toStringAsFixed(2)}'),
            _kv('Total disponible', '\$${summary.totalDisponible.toStringAsFixed(2)}'),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return SizedBox(
      width: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            k,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(v),
        ],
      ),
    );
  }
}

class _LinesTable extends StatelessWidget {
  const _LinesTable({
    required this.lines,
    required this.onEditCtdd,
  });

  final List<DevolucionDetalleLine> lines;
  final ValueChanged<DevolucionDetalleLine> onEditCtdd;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Column(
        children: [
          Container(
            color: Colors.grey.shade200,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: const Row(
              children: [
                SizedBox(width: 250, child: Text('DES', style: TextStyle(fontWeight: FontWeight.w600))),
                SizedBox(width: 85, child: Text('CTD', style: TextStyle(fontWeight: FontWeight.w600))),
                SizedBox(width: 85, child: Text('PVTA', style: TextStyle(fontWeight: FontWeight.w600))),
                SizedBox(width: 95, child: Text('PVTAT', style: TextStyle(fontWeight: FontWeight.w600))),
                SizedBox(width: 130, child: Text('ORD', style: TextStyle(fontWeight: FontWeight.w600))),
                SizedBox(width: 100, child: Text('CTDD', style: TextStyle(fontWeight: FontWeight.w600))),
                SizedBox(width: 60),
              ],
            ),
          ),
          const Divider(height: 1),
          SizedBox(
            height: 460,
            child: ListView.separated(
              itemCount: lines.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, index) {
                final line = lines[index];
                return Container(
                  color: line.ordBloqueante ? Colors.red.withValues(alpha: 0.06) : null,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 250,
                        child: Text(line.des ?? '-', overflow: TextOverflow.ellipsis),
                      ),
                      SizedBox(width: 85, child: Text(line.ctd.toStringAsFixed(3))),
                      SizedBox(width: 85, child: Text('\$${line.pvta.toStringAsFixed(2)}')),
                      SizedBox(width: 95, child: Text('\$${line.pvtat.toStringAsFixed(2)}')),
                      SizedBox(
                        width: 130,
                        child: Text(
                          line.ordBloqueante
                              ? '${line.ord ?? '-'} (BLOQ)'
                              : (line.ord ?? '-'),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: line.ordBloqueante ? Colors.red.shade700 : null,
                            fontWeight: line.ordBloqueante ? FontWeight.w700 : null,
                          ),
                          ),
                        ),
                      SizedBox(
                        width: 100,
                        child: Text(
                          line.ctdd == null ? '-' : line.ctdd!.toStringAsFixed(3),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      SizedBox(
                        width: 60,
                        child: IconButton(
                          tooltip: 'Editar CTDD',
                          onPressed: () => onEditCtdd(line),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                        ),
                      ),
                    ],
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
