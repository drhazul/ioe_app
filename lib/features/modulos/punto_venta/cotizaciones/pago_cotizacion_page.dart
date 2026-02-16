import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ioe_app/core/api_error.dart';
import 'package:ioe_app/core/auth/auth_controller.dart';

import 'cotizaciones_providers.dart';
import 'pago_cotizacion_models.dart';
import 'pago_cotizacion_providers.dart';
import 'detalle_cot/pvticketlog_providers.dart';

class PagoCotizacionPage extends ConsumerStatefulWidget {
  const PagoCotizacionPage({
    super.key,
    required this.idfol,
    required this.initialTipoTran,
    required this.initialRqfac,
  });

  final String idfol;
  final String initialTipoTran;
  final bool initialRqfac;

  @override
  ConsumerState<PagoCotizacionPage> createState() => _PagoCotizacionPageState();
}

class _PagoCotizacionPageState extends ConsumerState<PagoCotizacionPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(pagoCotizacionControllerProvider(widget.idfol).notifier).initialize(
            tipotran: widget.initialTipoTran,
            rqfac: widget.initialRqfac,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pagoCotizacionControllerProvider(widget.idfol));
    final notifier = ref.read(pagoCotizacionControllerProvider(widget.idfol).notifier);

    final total = state.totales?.total ?? 0;
    final sumPagos = state.sumPagos;
    final faltante = _round2(total > sumPagos ? total - sumPagos : 0.0);
    final cambio = _round2(sumPagos > total ? sumPagos - total : 0.0);
    final canFinalize = !state.submitting && state.formas.isNotEmpty && total > 0 && sumPagos >= total;

    return Scaffold(
      appBar: AppBar(
        title: Text('Pago y cierre - ${widget.idfol}'),
      ),
      body: state.loading && !state.initialized
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _ContextCard(state: state),
                const SizedBox(height: 12),
                _TipoCierreCard(
                  state: state,
                  onTipoChanged: (value) => notifier.setTipoTran(value),
                  onRqfacChanged: (value) => notifier.setRqfac(value),
                ),
                const SizedBox(height: 12),
                _TotalesCard(state: state, loading: state.loading),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Formas de pago',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                            FilledButton.icon(
                              onPressed: state.submitting
                                  ? null
                                  : () => _addForma(context, state),
                              icon: const Icon(Icons.add),
                              label: const Text('Agregar'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (state.formas.isEmpty)
                          const Text('Sin formas agregadas')
                        else
                          Column(
                            children: state.formas.map((item) {
                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.payments_outlined),
                                title: Text('${item.form} - ${_money(item.impp)}'),
                                subtitle: item.aut == null || item.aut!.isEmpty
                                    ? null
                                    : Text('Ref: ${item.aut}'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Editar',
                                      onPressed: state.submitting
                                          ? null
                                          : () => _editForma(context, state, item),
                                      icon: const Icon(Icons.edit_outlined),
                                    ),
                                    IconButton(
                                      tooltip: 'Eliminar',
                                      onPressed: state.submitting
                                          ? null
                                          : () => notifier.removeForma(item.id),
                                      icon: const Icon(Icons.delete_outline),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total: ${_money(total)}'),
                        Text('Pagos: ${_money(sumPagos)}'),
                        Text('Faltante: ${_money(faltante)}'),
                        Text('Cambio: ${_money(cambio)}'),
                      ],
                    ),
                  ),
                ),
                if ((state.error ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    state.error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: canFinalize ? () => _finalizar(context, state) : null,
                  icon: state.submitting
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: Text(state.submitting ? 'Finalizando...' : 'Finalizar cierre'),
                ),
              ],
            ),
    );
  }

  Future<void> _addForma(BuildContext context, PagoCotizacionState state) async {
    final result = await _showFormaDialog(
      context,
      state: state,
      existing: state.formas,
    );
    if (result == null) return;
    ref.read(pagoCotizacionControllerProvider(widget.idfol).notifier).addForma(
          form: result.form,
          impp: result.impp,
          aut: result.aut,
        );
  }

  Future<void> _editForma(
    BuildContext context,
    PagoCotizacionState state,
    PagoCierreFormaDraft item,
  ) async {
    final result = await _showFormaDialog(
      context,
      state: state,
      existing: state.formas.where((e) => e.id != item.id).toList(),
      initial: item,
    );
    if (result == null) return;
    ref.read(pagoCotizacionControllerProvider(widget.idfol).notifier).updateForma(
          item.id,
          form: result.form,
          impp: result.impp,
          aut: result.aut,
        );
  }

  Future<void> _finalizar(BuildContext context, PagoCotizacionState state) async {
    final auth = ref.read(authControllerProvider);
    final idopv = (auth.username ?? '').trim().isEmpty ? null : auth.username;

    try {
      final result = await ref
          .read(pagoCotizacionControllerProvider(widget.idfol).notifier)
          .finalizar(idopv: idopv);

      if (!context.mounted) return;

      ref.invalidate(cotizacionProvider(widget.idfol));
      ref.invalidate(cotizacionesListProvider);
      ref.invalidate(pvTicketLogListProvider(widget.idfol));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cierre completado. Total ${_money(result.totales.total)} | Cambio ${_money(result.cambio)}',
          ),
        ),
      );

      context.go('/punto-venta/cotizaciones');
    } catch (e) {
      if (!context.mounted) return;
      final msg = apiErrorMessage(e, fallback: 'No se pudo finalizar el cierre');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<_FormaDialogResult?> _showFormaDialog(
    BuildContext context, {
    required PagoCotizacionState state,
    required List<PagoCierreFormaDraft> existing,
    PagoCierreFormaDraft? initial,
  }) async {
    const formas = <String>[
      'EFECTIVO',
      'TARJETA',
      'CHEQUE',
      'TRANSFERENCIA',
      'CREDITO',
      'DEUDOR',
    ];

    String form = initial?.form ?? formas.first;
    final importeCtrl = TextEditingController(
      text: initial == null ? '' : initial.impp.toStringAsFixed(2),
    );
    final autCtrl = TextEditingController(text: initial?.aut ?? '');
    String? error;

    final result = await showDialog<_FormaDialogResult>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(initial == null ? 'Agregar forma' : 'Editar forma'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: form,
                    decoration: const InputDecoration(
                      labelText: 'Forma',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: formas
                        .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => form = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: importeCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Importe',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: autCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Autorizacion / referencia',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  if ((error ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(error!, style: const TextStyle(color: Colors.red)),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    final value = double.tryParse(
                      importeCtrl.text.trim().replaceAll(',', '.'),
                    );
                    if (value == null || value <= 0) {
                      setState(() => error = 'Importe invalido');
                      return;
                    }

                    if (state.tipotran == 'CA' && existing.isNotEmpty) {
                      final first = existing.first.form.toUpperCase().trim();
                      if (first != form.toUpperCase().trim()) {
                        setState(
                          () => error =
                              'En cierre CA solo se permite una forma (${existing.first.form})',
                        );
                        return;
                      }
                    }

                    Navigator.of(context).pop(
                      _FormaDialogResult(
                        form: form,
                        impp: _round2(value),
                        aut: autCtrl.text.trim().isEmpty ? null : autCtrl.text.trim(),
                      ),
                    );
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    importeCtrl.dispose();
    autCtrl.dispose();
    return result;
  }
}

class _ContextCard extends StatelessWidget {
  const _ContextCard({required this.state});

  final PagoCotizacionState state;

  @override
  Widget build(BuildContext context) {
    final ctx = state.context;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Contexto del folio', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Folio: ${ctx?.idfol ?? state.idfol}'),
            Text('Sucursal: ${ctx?.suc ?? '-'}'),
            Text('Cliente: ${ctx?.clien?.toString() ?? '-'}'),
            Text('Estado: ${ctx?.esta ?? '-'}'),
            Text('Items: ${ctx?.itemsCount ?? 0}'),
          ],
        ),
      ),
    );
  }
}

class _TipoCierreCard extends StatelessWidget {
  const _TipoCierreCard({
    required this.state,
    required this.onTipoChanged,
    required this.onRqfacChanged,
  });

  final PagoCotizacionState state;
  final ValueChanged<String> onTipoChanged;
  final ValueChanged<bool> onRqfacChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tipo de cierre', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment<String>(value: 'CA', label: Text('CA - Cotizacion Abierta')),
                ButtonSegment<String>(value: 'VF', label: Text('VF - Venta Finalizada')),
              ],
              selected: {state.tipotran},
              onSelectionChanged: (value) {
                if (value.isEmpty) return;
                onTipoChanged(value.first);
              },
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Requiere factura (RQFAC)'),
              subtitle: const Text('Aplica para VF cuando la sucursal usa IVA no integrado'),
              value: state.tipotran == 'CA' ? false : state.rqfac,
              onChanged: state.tipotran == 'CA' ? null : onRqfacChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalesCard extends StatelessWidget {
  const _TotalesCard({required this.state, required this.loading});

  final PagoCotizacionState state;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final totales = state.totales;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Totales calculados por backend',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                if (loading) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
            const SizedBox(height: 8),
            Text('Total base: ${_money(totales?.totalBase ?? 0)}'),
            Text('Subtotal: ${_money(totales?.subtotal ?? 0)}'),
            Text('IVA: ${_money(totales?.iva ?? 0)}'),
            Text('Total final: ${_money(totales?.total ?? 0)}'),
            Text(
              'IVA integrado sucursal: ${totales == null ? '-' : ((totales.ivaIntegrado ?? 1) == -1 ? 'SI' : 'NO')}',
            ),
          ],
        ),
      ),
    );
  }
}

class _FormaDialogResult {
  _FormaDialogResult({
    required this.form,
    required this.impp,
    required this.aut,
  });

  final String form;
  final double impp;
  final String? aut;
}

String _money(double value) => '\$${value.toStringAsFixed(2)}';

double _round2(double value) =>
    (value.isFinite ? (value * 100).roundToDouble() / 100 : 0.0);
