import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../reloj_checador/consultas/download_helper.dart';
import '../../domain/sugeridos_models.dart';
import '../../providers/sugeridos_provider.dart';

class OrdenCompraDetalleDialog extends ConsumerStatefulWidget {
  const OrdenCompraDetalleDialog({
    super.key,
    required this.doc,
    this.onChanged,
  });

  final SugeridoOrdenModel doc;
  final ValueChanged<SugeridoOrdenModel>? onChanged;

  @override
  ConsumerState<OrdenCompraDetalleDialog> createState() =>
      _OrdenCompraDetalleDialogState();
}

class _OrdenCompraDetalleDialogState
    extends ConsumerState<OrdenCompraDetalleDialog> {
  late SugeridoOrdenModel _doc;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _doc = widget.doc;
  }

  @override
  Widget build(BuildContext context) {
    final editable = _doc.estatus == 'ABIERTO';
    return AlertDialog(
      title: Text('O.C. ${_doc.nped}'),
      content: SizedBox(
        width: 980,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  Text('Sucursal: ${_doc.suc}'),
                  Text('Proveedor: ${_doc.alias ?? _doc.nprov}'),
                  Text('Estatus: ${_doc.estatus}'),
                  Text('Importe: ${_money(_doc.impp)}'),
                ],
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Pos')),
                    DataColumn(label: Text('Articulo')),
                    DataColumn(label: Text('Descripcion')),
                    DataColumn(label: Text('Cantidad'), numeric: true),
                    DataColumn(label: Text('Costo'), numeric: true),
                    DataColumn(label: Text('Total'), numeric: true),
                    DataColumn(label: Text('Acciones')),
                  ],
                  rows: [
                    for (final item in _doc.detalle.where((d) => d.bloq != -1))
                      DataRow(
                        cells: [
                          DataCell(Text('${item.pos}')),
                          DataCell(Text(item.art)),
                          DataCell(
                            SizedBox(width: 280, child: Text(item.des ?? '')),
                          ),
                          DataCell(Text(_num(item.ctdped))),
                          DataCell(Text(_money(item.cto))),
                          DataCell(Text(_money(item.ctot))),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Editar cantidad',
                                  icon: const Icon(Icons.edit),
                                  onPressed: editable && !_saving
                                      ? () => _editCantidad(item)
                                      : null,
                                ),
                                IconButton(
                                  tooltip: 'Eliminar articulo',
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: editable && !_saving
                                      ? () => _removeItem(item)
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (_saving)
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        OutlinedButton.icon(
          onPressed: _doc.detalle.isEmpty ? null : _exportCsv,
          icon: const Icon(Icons.table_view),
          label: const Text('Excel CSV'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _doc),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }

  Future<void> _editCantidad(SugeridoDetalleModel item) async {
    final ctrl = TextEditingController(text: _num(item.ctdped));
    final value = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cantidad ${item.art}'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Cantidad',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) =>
              Navigator.pop(context, double.tryParse(ctrl.text.trim())),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, double.tryParse(ctrl.text.trim())),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (value == null || value <= 0 || !mounted) return;
    await _runMutation(
      () => ref
          .read(sugeridosApiProvider)
          .updateDetalle(nped: _doc.nped, idped: item.idped, ctdped: value),
      'Cantidad actualizada.',
    );
  }

  Future<void> _removeItem(SugeridoDetalleModel item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar articulo'),
        content: Text('Se eliminara ${item.art} de la O.C.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _runMutation(
      () => ref
          .read(sugeridosApiProvider)
          .removeDetalle(nped: _doc.nped, idped: item.idped),
      'Articulo eliminado.',
    );
  }

  Future<void> _runMutation(
    Future<SugeridoOrdenModel> Function() action,
    String success,
  ) async {
    setState(() => _saving = true);
    try {
      final updated = await action();
      if (!mounted) return;
      setState(() => _doc = updated);
      widget.onChanged?.call(updated);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(success)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _exportCsv() async {
    final rows = <List<String>>[
      ['NPED', 'POS', 'ART', 'DES', 'CTDPED', 'UNCOM', 'CTO', 'TOTAL'],
      for (final item in _doc.detalle.where((d) => d.bloq != -1))
        [
          _doc.nped,
          '${item.pos}',
          item.art,
          item.des ?? '',
          _num(item.ctdped),
          item.uncom,
          _num(item.cto),
          _num(item.ctot),
        ],
    ];
    final csv = rows.map((row) => row.map(_csvCell).join(',')).join('\r\n');
    await saveBytesFile(
      Uint8List.fromList(utf8.encode(csv)),
      'OC_${_doc.nped}.csv',
      'text/csv;charset=utf-8',
    );
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Archivo CSV generado.')));
    }
  }
}

String _csvCell(String value) {
  final escaped = value.replaceAll('"', '""');
  return '"$escaped"';
}

String _num(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(2);
}

String _money(double value) => '\$${value.toStringAsFixed(2)}';
