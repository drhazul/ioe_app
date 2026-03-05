import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ioe_app/core/api_error.dart';

import 'retiros_models.dart';
import 'retiros_providers.dart';

class RetiroEfectivoPage extends ConsumerStatefulWidget {
  const RetiroEfectivoPage({
    super.key,
    required this.idfor,
    required this.idret,
    this.isModal = false,
  });

  final String idfor;
  final String idret;
  final bool isModal;

  @override
  ConsumerState<RetiroEfectivoPage> createState() => _RetiroEfectivoPageState();
}

class _RetiroEfectivoPageState extends ConsumerState<RetiroEfectivoPage> {
  final Map<String, TextEditingController> _ctdaCtrls = {};
  bool _saving = false;

  @override
  void dispose() {
    for (final ctrl in _ctdaCtrls.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.idret.trim().isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalle efectivo')),
        body: const Center(
          child: Text('No se recibió idret para cargar denominaciones.'),
        ),
      );
    }

    final detailAsync = ref.watch(retiroDetailProvider(widget.idret));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            if (widget.isModal) {
              Navigator.of(context).pop();
              return;
            }
            context.go('/retiros/${Uri.encodeComponent(widget.idret)}');
          },
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text('Efectivo ${widget.idfor}'),
        actions: [
          IconButton(
            tooltip: 'Refrescar',
            onPressed: _saving
                ? null
                : () => ref.invalidate(retiroDetailProvider(widget.idret)),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (detail) {
          final row = _findDetalle(detail.detalles, widget.idfor);
          if (row == null) {
            return const Center(
              child: Text('No se encontró el detalle EFECTIVO solicitado.'),
            );
          }
          final isAbierto = detail.header.isAbierto;
          final efectivo = [...row.efectivo]
            ..sort((a, b) => b.deno.compareTo(a.deno));
          _syncControllers(efectivo);

          final total = _round2(
            efectivo.fold<double>(
              0,
              (sum, item) =>
                  sum + (item.deno * (_readCtda(item.id, item.ctda))),
            ),
          );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Detalle ${row.id} - ${row.forma}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text('Importe actual: ${_money(row.impf)}'),
                      Text('Total UI: ${_money(total)}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      const Row(
                        children: [
                          SizedBox(
                            width: 120,
                            child: Text(
                              'Denominación',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'CTDA',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          SizedBox(
                            width: 120,
                            child: Text(
                              'Total',
                              textAlign: TextAlign.right,
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const Divider(),
                      ...efectivo.map((item) {
                        final ctda = _readCtda(item.id, item.ctda);
                        final totalRow = _round2(item.deno * ctda);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 120,
                                child: Text(_money(item.deno)),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: _ctdaCtrls[item.id],
                                  enabled: isAbierto && !_saving,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              SizedBox(
                                width: 120,
                                child: Text(
                                  _money(totalRow),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const Divider(),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Total',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          Text(
                            _money(total),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: isAbierto && !_saving ? () => _saveBatch(row) : null,
                icon: _saving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('Guardar denominaciones'),
              ),
            ],
          );
        },
      ),
    );
  }

  RetiroDetalleItem? _findDetalle(List<RetiroDetalleItem> rows, String idfor) {
    final id = idfor.trim();
    for (final row in rows) {
      if (row.id == id) return row;
    }
    return null;
  }

  void _syncControllers(List<RetiroEfectivoItem> rows) {
    final ids = rows.map((e) => e.id).toSet();
    final toRemove = _ctdaCtrls.keys.where((id) => !ids.contains(id)).toList();
    for (final id in toRemove) {
      _ctdaCtrls[id]?.dispose();
      _ctdaCtrls.remove(id);
    }

    for (final row in rows) {
      if (_ctdaCtrls.containsKey(row.id)) continue;
      _ctdaCtrls[row.id] = TextEditingController(
        text: row.ctda.toString(),
      );
    }
  }

  double _readCtda(String id, double fallback) {
    final raw = _ctdaCtrls[id]?.text.trim() ?? '';
    if (raw.isEmpty) return fallback;
    return double.tryParse(raw.replaceAll(',', '.')) ?? fallback;
  }

  Future<void> _saveBatch(RetiroDetalleItem row) async {
    final updates = row.efectivo
        .map((item) {
          final value = _readCtda(item.id, item.ctda);
          return {
            'deno': item.deno,
            'ctda': value < 0 ? 0 : value,
          };
        })
        .toList(growable: false);

    setState(() => _saving = true);
    try {
      await ref.read(retirosApiProvider).setEfectivoBatch(
            idfor: row.id,
            items: updates,
          );
      ref.invalidate(retiroDetailProvider(widget.idret));
      ref.invalidate(retirosTodayProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Denominaciones actualizadas')),
      );
    } catch (e) {
      if (!mounted) return;
      _showError(apiErrorMessage(e, fallback: 'No se pudo guardar efectivo'));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  double _round2(double value) =>
      (value.isFinite ? (value * 100).roundToDouble() / 100 : 0);

  String _money(double value) => '\$${value.toStringAsFixed(2)}';

  void _showError(String message) {
    if (!mounted) return;
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
}
