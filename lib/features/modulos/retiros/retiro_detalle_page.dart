import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ioe_app/core/api_error.dart';

import 'retiro_efectivo_page.dart';
import 'retiros_models.dart';
import 'retiros_providers.dart';

class RetiroDetallePage extends ConsumerStatefulWidget {
  const RetiroDetallePage({super.key, required this.idret});

  final String idret;

  @override
  ConsumerState<RetiroDetallePage> createState() => _RetiroDetallePageState();
}

class _RetiroDetallePageState extends ConsumerState<RetiroDetallePage> {
  final TextEditingController _impfCtrl = TextEditingController();
  String? _selectedForma;
  bool _saving = false;

  @override
  void dispose() {
    _impfCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(retiroDetailProvider(widget.idret));
    final formsAsync = ref.watch(retirosFormasCatalogProvider);

    final forms = formsAsync.valueOrNull
            ?.where((item) => !item.isBlocked)
            .toList(growable: false) ??
        const <RetiroFormaCatalogItem>[];
    final selectedForma = _resolveSelectedForma(forms);

    return Scaffold(
      appBar: AppBar(
        title: Text('Retiro ${widget.idret}'),
        actions: [
          IconButton(
            tooltip: 'Refrescar',
            onPressed: _saving
                ? null
                : () {
                    ref.invalidate(retiroDetailProvider(widget.idret));
                    ref.invalidate(retirosFormasCatalogProvider);
                  },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (detail) {
          final header = detail.header;
          final isAbierto = header.isAbierto;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _HeaderCard(header: header, total: detail.total),
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Agregar forma',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: selectedForma,
                        items: forms
                            .map(
                              (item) => DropdownMenuItem<String>(
                                value: item.form,
                                child: Text(item.form),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: isAbierto && !_saving
                            ? (value) {
                                setState(() {
                                  _selectedForma = value;
                                  _impfCtrl.clear();
                                });
                              }
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Forma',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      if (selectedForma != null && selectedForma != 'EFECTIVO') ...[
                        const SizedBox(height: 10),
                        TextField(
                          controller: _impfCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          enabled: isAbierto && !_saving,
                          decoration: const InputDecoration(
                            labelText: 'Importe',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed:
                            isAbierto && !_saving && forms.isNotEmpty && selectedForma != null
                                ? () => _addDetalle(selectedForma)
                                : null,
                        icon: _saving
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.add),
                        label: const Text('Agregar detalle'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Detalles',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      if (detail.detalles.isEmpty)
                        const Text('Sin detalles capturados')
                      else
                        ...detail.detalles.map(
                          (item) => _DetalleTile(
                            item: item,
                            canEdit: isAbierto && !_saving,
                            onOpenEfectivo: item.isEfectivo
                                ? () {
                                    _openEfectivo(
                                      idfor: item.id,
                                      idret: header.idret,
                                    );
                                  }
                                : null,
                            onDelete: () => _deleteDetalle(item.id),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: isAbierto && !_saving ? _finalize : null,
                icon: _saving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: const Text('Finalizar retiro'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addDetalle(String? forma) async {
    if (forma == null) {
      _showError('Seleccione una forma');
      return;
    }
    final normalized = forma.trim().toUpperCase();
    if (normalized.isEmpty) {
      _showError('Seleccione una forma');
      return;
    }

    double? impf;
    if (normalized != 'EFECTIVO') {
      impf = double.tryParse(_impfCtrl.text.trim().replaceAll(',', '.'));
      if (impf == null || impf <= 0) {
        _showError('Capture un importe mayor a 0');
        return;
      }
    }

    setState(() => _saving = true);
    try {
      await ref.read(retirosApiProvider).addDetalle(
            idret: widget.idret,
            forma: normalized,
            impf: impf,
          );
      _impfCtrl.clear();
      ref.invalidate(retiroDetailProvider(widget.idret));
      ref.invalidate(retirosTodayProvider);
    } catch (e) {
      if (!mounted) return;
      _showError(apiErrorMessage(e, fallback: 'No se pudo agregar detalle'));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _deleteDetalle(String idfor) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar detalle'),
        content: const Text('¿Desea eliminar este detalle?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _saving = true);
    try {
      await ref.read(retirosApiProvider).deleteDetalle(idfor);
      ref.invalidate(retiroDetailProvider(widget.idret));
      ref.invalidate(retirosTodayProvider);
    } catch (e) {
      if (!mounted) return;
      _showError(apiErrorMessage(e, fallback: 'No se pudo eliminar detalle'));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _finalize() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Finalizar retiro'),
        content: const Text('¿Finalizar retiro parcial?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Finalizar'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _saving = true);
    try {
      await ref.read(retirosApiProvider).finalize(widget.idret);
      ref.invalidate(retiroDetailProvider(widget.idret));
      ref.invalidate(retirosTodayProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Retiro finalizado')),
      );
    } catch (e) {
      if (!mounted) return;
      _showError(apiErrorMessage(e, fallback: 'No se pudo finalizar retiro'));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _openEfectivo({required String idfor, required String idret}) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 1100,
            maxHeight: 760,
          ),
          child: RetiroEfectivoPage(
            idfor: idfor,
            idret: idret,
            isModal: true,
          ),
        ),
      ),
    );
    if (!mounted) return;
    ref.invalidate(retiroDetailProvider(widget.idret));
    ref.invalidate(retirosTodayProvider);
  }

  String? _resolveSelectedForma(List<RetiroFormaCatalogItem> forms) {
    if (forms.isEmpty) return null;

    if (_selectedForma != null &&
        forms.any((item) => item.form == _selectedForma)) {
      return _selectedForma;
    }

    final hasEfectivo = forms.any((f) => f.form == 'EFECTIVO');
    return hasEfectivo ? 'EFECTIVO' : forms.first.form;
  }

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

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.header, required this.total});

  final RetiroHeader header;
  final double total;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Encabezado',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            _row('IDRET', header.idret),
            _row('OPV', header.opv ?? '-'),
            _row('TER', header.ter ?? '-'),
            _row('FCNR', header.fcnr?.toLocal().toString() ?? '-'),
            _row('ESTA', header.esta),
            _row('IMPR', _money(header.impr)),
            _row('Total detalle', _money(total)),
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
            width: 96,
            child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _money(double value) => '\$${value.toStringAsFixed(2)}';
}

class _DetalleTile extends StatelessWidget {
  const _DetalleTile({
    required this.item,
    required this.canEdit,
    this.onOpenEfectivo,
    required this.onDelete,
  });

  final RetiroDetalleItem item;
  final bool canEdit;
  final VoidCallback? onOpenEfectivo;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text('${item.forma} - ${_money(item.impf)}'),
      subtitle: item.isEfectivo
          ? Text('Denominaciones: ${item.efectivo.length}')
          : null,
      trailing: Wrap(
        spacing: 4,
        children: [
          if (item.isEfectivo)
            OutlinedButton(
              onPressed: onOpenEfectivo,
              child: const Text('Detalle efectivo'),
            ),
          IconButton(
            tooltip: 'Eliminar',
            onPressed: canEdit ? onDelete : null,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }

  String _money(double value) => '\$${value.toStringAsFixed(2)}';
}
