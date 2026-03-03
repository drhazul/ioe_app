import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ioe_app/core/api_error.dart';

import 'ps_models.dart';
import 'ps_providers.dart';

const List<String> _formasPago = [
  'EFECTIVO',
  'TARJETA',
  'CHEQUE',
  'TRANSFERENCIA',
  'DEPOSITO 3RO',
  'CREDITO',
  'DEUDOR',
];

class PsPagoPage extends ConsumerStatefulWidget {
  const PsPagoPage({super.key, required this.idFol});

  final String idFol;

  @override
  ConsumerState<PsPagoPage> createState() => _PsPagoPageState();
}

class _PsPagoPageState extends ConsumerState<PsPagoPage> {
  String _form = 'EFECTIVO';
  final _imppCtrl = TextEditingController();
  final _autCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.invalidate(psPagoSummaryProvider(widget.idFol));
      ref.invalidate(psFormasPagoProvider(widget.idFol));
    });
  }

  @override
  void dispose() {
    _imppCtrl.dispose();
    _autCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(psPagoSummaryProvider(widget.idFol));
    final formasAsync = ref.watch(psFormasPagoProvider(widget.idFol));

    return Scaffold(
      appBar: AppBar(
        title: Text('PS Pago - ${widget.idFol}'),
        actions: [
          IconButton(
            tooltip: 'Refrescar',
            onPressed: () {
              ref.invalidate(psPagoSummaryProvider(widget.idFol));
              ref.invalidate(psFormasPagoProvider(widget.idFol));
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: summaryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (summary) {
          final isPagado = summary.esta == 'PAGADO';
          final canTerminar = summary.restante <= 0.0001;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SummaryCard(summary: summary),
              const SizedBox(height: 12),
              if (!isPagado) _AddFormaCard(
                form: _form,
                imppCtrl: _imppCtrl,
                autCtrl: _autCtrl,
                saving: _saving,
                onFormChanged: (value) => setState(() => _form = value),
                onSave: _addForma,
              ),
              if (!isPagado) const SizedBox(height: 12),
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Formas de pago', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      formasAsync.when(
                        loading: () => const CircularProgressIndicator(),
                        error: (e, _) => Text('Error: $e'),
                        data: (formas) {
                          if (formas.isEmpty) {
                            return const Text('Sin formas registradas');
                          }
                          return Column(
                            children: formas.map((item) {
                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text('${item.form} - ${_money(item.impp)}'),
                                subtitle: (item.aut ?? '').trim().isEmpty
                                    ? null
                                    : Text('Ref: ${item.aut}'),
                                trailing: isPagado
                                    ? null
                                    : IconButton(
                                        tooltip: 'Eliminar',
                                        onPressed: _saving
                                            ? null
                                            : () => _deleteForma(item),
                                        icon: const Icon(Icons.delete_outline),
                                      ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _saving || !canTerminar ? null : _terminar,
                icon: const Icon(Icons.lock),
                label: const Text('Terminar (TRANSMITIR)'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _saving
                    ? null
                    : () => context.go('/ps/${Uri.encodeComponent(widget.idFol)}'),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Regresar a detalle'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addForma() async {
    final impp = double.tryParse(_imppCtrl.text.trim().replaceAll(',', '.'));
    if (impp == null || impp <= 0) {
      _showError('Capture un importe válido');
      return;
    }

    final needsAut = _form.toUpperCase() != 'EFECTIVO';
    final aut = _autCtrl.text.trim();
    if (needsAut && aut.isEmpty) {
      _showError('La forma seleccionada requiere autorización/referencia');
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(psApiProvider).addFormaPago(
            idFol: widget.idFol,
            form: _form,
            impp: impp,
            aut: needsAut ? aut : null,
          );
      ref.invalidate(psPagoSummaryProvider(widget.idFol));
      ref.invalidate(psFormasPagoProvider(widget.idFol));
      if (!mounted) return;
      setState(() {
        _imppCtrl.clear();
        _autCtrl.clear();
        _form = 'EFECTIVO';
      });
    } catch (e) {
      if (!mounted) return;
      _showError(apiErrorMessage(e, fallback: 'No se pudo agregar forma de pago'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteForma(PsFormaPagoItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar forma de pago'),
        content: Text('¿Eliminar la forma ${item.form}?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Eliminar')),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _saving = true);
    try {
      await ref.read(psApiProvider).deleteFormaPago(
            idFol: widget.idFol,
            idF: item.idf,
          );
      ref.invalidate(psPagoSummaryProvider(widget.idFol));
      ref.invalidate(psFormasPagoProvider(widget.idFol));
    } catch (e) {
      if (!mounted) return;
      _showError(apiErrorMessage(e, fallback: 'No se pudo eliminar forma de pago'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _terminar() async {
    setState(() => _saving = true);
    try {
      await ref.read(psApiProvider).terminar(widget.idFol);
      ref.invalidate(psFoliosProvider);
      if (!mounted) return;
      context.go('/ps');
    } catch (e) {
      if (!mounted) return;
      _showError(apiErrorMessage(e, fallback: 'No se pudo terminar folio PS'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          FilledButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Aceptar')),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final PsPagoSummary summary;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Resumen de pago', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            _row('IDFOL', summary.idfol),
            _row('SUC', summary.suc.isEmpty ? '-' : summary.suc),
            _row('ESTA', summary.esta.isEmpty ? '-' : summary.esta),
            _row('Total', _money(summary.total)),
            _row('Pagado', _money(summary.pagado)),
            _row('Restante', _money(summary.restante)),
            _row('Cambio', _money(summary.cambio)),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _AddFormaCard extends StatelessWidget {
  const _AddFormaCard({
    required this.form,
    required this.imppCtrl,
    required this.autCtrl,
    required this.saving,
    required this.onFormChanged,
    required this.onSave,
  });

  final String form;
  final TextEditingController imppCtrl;
  final TextEditingController autCtrl;
  final bool saving;
  final ValueChanged<String> onFormChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final needsAut = form.toUpperCase() != 'EFECTIVO';

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Agregar forma de pago', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    initialValue: form,
                    items: _formasPago
                        .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                        .toList(),
                    onChanged: saving
                        ? null
                        : (value) {
                            if (value == null) return;
                            onFormChanged(value);
                          },
                    decoration: const InputDecoration(
                      labelText: 'Forma',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: imppCtrl,
                    enabled: !saving,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Importe',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                if (needsAut)
                  SizedBox(
                    width: 260,
                    child: TextField(
                      controller: autCtrl,
                      enabled: !saving,
                      decoration: const InputDecoration(
                        labelText: 'Autorización / referencia',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                FilledButton.icon(
                  onPressed: saving ? null : onSave,
                  icon: saving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add),
                  label: const Text('Agregar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _money(double value) => '\$${value.toStringAsFixed(2)}';
