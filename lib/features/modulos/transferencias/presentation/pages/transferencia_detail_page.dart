import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../domain/transferencia_models.dart';
import '../../providers/transferencia_provider.dart';

class TransferenciaDetailPage extends ConsumerWidget {
  const TransferenciaDetailPage({super.key, required this.doc});

  final String doc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncDoc = ref.watch(transferenciaDetalleProvider(doc));
    return Scaffold(
      appBar: AppBar(
        title: Text('Transferencia $doc'),
        actions: [
          IconButton(
            tooltip: 'Refrescar',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(transferenciaDetalleProvider(doc)),
          ),
        ],
      ),
      body: asyncDoc.when(
        data: (item) => _TransferenciaDetailBody(item: item),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(_friendlyError(error))),
      ),
    );
  }
}

class _TransferenciaDetailBody extends ConsumerWidget {
  const _TransferenciaDetailBody({required this.item});

  final TransferenciaDocModel item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _HeaderCard(item: item),
        const SizedBox(height: 10),
        _ActionBar(item: item),
        const SizedBox(height: 10),
        _DetalleTable(item: item),
      ],
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.item});

  final TransferenciaDocModel item;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            Text(
              'DOC: ${item.doc}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('Estatus: ${item.estatus}'),
            Text('Origen: ${item.sucSal}'),
            Text('Destino: ${item.sucEnt}'),
            Text('Motivo: ${item.mtv}'),
            Text('Prioridad: ${item.prio}'),
            Text('Cantidad: ${item.ctd.toStringAsFixed(2)}'),
            Text('Importe: ${_money(item.imp)}'),
            if ((item.txt ?? '').isNotEmpty) Text('Obs: ${item.txt}'),
            if (item.paqueteria != null)
              Text(
                'Guía: ${item.paqueteria!.emp ?? '-'} ${item.paqueteria!.numGuia ?? ''}',
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionBar extends ConsumerWidget {
  const _ActionBar({required this.item});

  final TransferenciaDocModel item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estatus = item.estatus;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (estatus == 'BORRADOR')
          FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Agregar artículo'),
            onPressed: () => _addArticulo(context, ref),
          ),
        if (estatus == 'BORRADOR')
          FilledButton.icon(
            icon: const Icon(Icons.send),
            label: const Text('Enviar a autorización'),
            onPressed: () => _runAction(context, ref, 'enviar'),
          ),
        if (estatus == 'PENDIENTE')
          FilledButton.icon(
            icon: const Icon(Icons.check_circle),
            label: const Text('Liberar'),
            onPressed: () => _runAction(context, ref, 'liberar'),
          ),
        if (estatus == 'PENDIENTE')
          OutlinedButton.icon(
            icon: const Icon(Icons.cancel),
            label: const Text('Rechazar'),
            onPressed: () => _reject(context, ref),
          ),
        if (estatus == 'LIBERADA')
          FilledButton.icon(
            icon: const Icon(Icons.inventory_2),
            label: const Text('Preparar'),
            onPressed: () => _runAction(context, ref, 'preparar'),
          ),
        if (estatus == 'PREPARACION')
          FilledButton.icon(
            icon: const Icon(Icons.local_shipping),
            label: const Text('Enviar a tránsito'),
            onPressed: () => _sendTransit(context, ref),
          ),
        if (estatus == 'TRANSITO')
          FilledButton.icon(
            icon: const Icon(Icons.move_to_inbox),
            label: const Text('Confirmar recepción'),
            onPressed: () => _runAction(context, ref, 'recibir'),
          ),
        if (estatus == 'REVISANDO' || estatus == 'INCIDENCIA')
          FilledButton.icon(
            icon: const Icon(Icons.task_alt),
            label: const Text('Contabilizar'),
            onPressed: () => _runAction(context, ref, 'contabilizar'),
          ),
        OutlinedButton.icon(
          icon: const Icon(Icons.picture_as_pdf),
          label: const Text('PDF envío'),
          onPressed: () => _printPdf(item),
        ),
      ],
    );
  }

  Future<void> _addArticulo(BuildContext context, WidgetRef ref) async {
    final added = await showDialog<bool>(
      context: context,
      builder: (_) => _AddArticuloDialog(doc: item),
    );
    if (added == true) ref.invalidate(transferenciaDetalleProvider(item.doc));
  }

  Future<void> _reject(BuildContext context, WidgetRef ref) async {
    final obs = await _askText(context, 'Rechazar solicitud', 'Motivo');
    if (obs == null) return;
    if (!context.mounted) return;
    await _runAction(context, ref, 'rechazar', data: {'txt': obs});
  }

  Future<void> _sendTransit(BuildContext context, WidgetRef ref) async {
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _TransitDialog(),
    );
    if (data == null) return;
    if (!context.mounted) return;
    await _runAction(context, ref, 'transito', data: data);
  }

  Future<void> _runAction(
    BuildContext context,
    WidgetRef ref,
    String action, {
    Map<String, dynamic>? data,
  }) async {
    try {
      await ref
          .read(transferenciaApiProvider)
          .action(item.doc, action, data: data);
      ref.invalidate(transferenciaDetalleProvider(item.doc));
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Acción completada.')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(e))));
    }
  }
}

class _DetalleTable extends ConsumerWidget {
  const _DetalleTable({required this.item});

  final TransferenciaDocModel item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (item.detalle.isEmpty) {
      return const Card(
        elevation: 0,
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('Sin artículos capturados.'),
        ),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('ART')),
          DataColumn(label: Text('Descripción')),
          DataColumn(label: Text('Exis O')),
          DataColumn(label: Text('Exis D')),
          DataColumn(label: Text('Solicitada')),
          DataColumn(label: Text('Liberada')),
          DataColumn(label: Text('Recibida')),
          DataColumn(label: Text('Dif')),
          DataColumn(label: Text('Total')),
          DataColumn(label: Text('Acciones')),
        ],
        rows: item.detalle
            .map(
              (row) => DataRow(
                cells: [
                  DataCell(Text(row.art)),
                  DataCell(
                    SizedBox(
                      width: 260,
                      child: Text(row.des, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                  DataCell(Text(row.exisS.toStringAsFixed(2))),
                  DataCell(Text(row.exisD.toStringAsFixed(2))),
                  DataCell(Text(row.ctd.toStringAsFixed(2))),
                  DataCell(Text(row.ctdLib.toStringAsFixed(2))),
                  DataCell(Text(row.ctdR.toStringAsFixed(2))),
                  DataCell(Text(row.difR.toStringAsFixed(2))),
                  DataCell(Text(_money(row.ctotal))),
                  DataCell(
                    Wrap(
                      spacing: 4,
                      children: [
                        if (item.estatus == 'PENDIENTE')
                          IconButton(
                            tooltip: 'Cantidad liberada',
                            icon: const Icon(Icons.rule),
                            onPressed: () => _editNumber(
                              context,
                              ref,
                              row,
                              'ctdLib',
                              row.ctdLib == 0 ? row.ctd : row.ctdLib,
                            ),
                          ),
                        if (item.estatus == 'TRANSITO')
                          IconButton(
                            tooltip: 'Cantidad recibida',
                            icon: const Icon(Icons.inventory),
                            onPressed: () => _editNumber(
                              context,
                              ref,
                              row,
                              'ctdR',
                              row.ctdR == 0 ? row.ctdLib : row.ctdR,
                            ),
                          ),
                        if (item.estatus == 'BORRADOR')
                          IconButton(
                            tooltip: 'Eliminar',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _delete(context, ref, row),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            )
            .toList(),
      ),
    );
  }

  Future<void> _editNumber(
    BuildContext context,
    WidgetRef ref,
    TransferenciaDetalleModel row,
    String field,
    double current,
  ) async {
    final raw = await _askText(
      context,
      'Actualizar cantidad',
      field,
      initial: current.toStringAsFixed(2),
    );
    if (raw == null) return;
    final value = double.tryParse(raw.replaceAll(',', '.'));
    if (value == null || value < 0) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cantidad inválida.')));
      return;
    }
    try {
      await ref
          .read(transferenciaApiProvider)
          .updateDetalle(
            item.doc,
            row.idpd,
            ctdLib: field == 'ctdLib' ? value : null,
            ctdR: field == 'ctdR' ? value : null,
          );
      ref.invalidate(transferenciaDetalleProvider(item.doc));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(e))));
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    TransferenciaDetalleModel row,
  ) async {
    try {
      await ref
          .read(transferenciaApiProvider)
          .removeDetalle(item.doc, row.idpd);
      ref.invalidate(transferenciaDetalleProvider(item.doc));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(e))));
    }
  }
}

class _AddArticuloDialog extends ConsumerStatefulWidget {
  const _AddArticuloDialog({required this.doc});

  final TransferenciaDocModel doc;

  @override
  ConsumerState<_AddArticuloDialog> createState() => _AddArticuloDialogState();
}

class _AddArticuloDialogState extends ConsumerState<_AddArticuloDialog> {
  final _searchCtrl = TextEditingController();
  final _ctdCtrl = TextEditingController(text: '1');
  final _depaCtrl = TextEditingController();
  final _subdCtrl = TextEditingController();
  final _clasCtrl = TextEditingController();
  final _sclaCtrl = TextEditingController();
  final _scla2Ctrl = TextEditingController();
  final _sphCtrl = TextEditingController();
  final _cylCtrl = TextEditingController();
  final _adicCtrl = TextEditingController();
  List<TransferenciaArticuloModel> _items = const [];
  TransferenciaArticuloModel? _selected;
  String _searchBy = 'ART';
  bool _loading = false;
  bool _addedAny = false;
  bool get _showLegacySearch => false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _ctdCtrl.dispose();
    _depaCtrl.dispose();
    _subdCtrl.dispose();
    _clasCtrl.dispose();
    _sclaCtrl.dispose();
    _scla2Ctrl.dispose();
    _sphCtrl.dispose();
    _cylCtrl.dispose();
    _adicCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Agregar artículo'),
      content: SizedBox(
        width: 720,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _filters(context),
            const SizedBox(height: 10),
            if (_showLegacySearch)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Buscar ART/UPC/descripción',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _search(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _loading ? null : _search,
                    icon: const Icon(Icons.search),
                    label: const Text('Buscar'),
                  ),
                ],
              ),
            const SizedBox(height: 10),
            if (_loading) const LinearProgressIndicator(),
            SizedBox(
              height: 260,
              child: ListView.builder(
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final item = _items[index];
                  final selected = item.art == _selected?.art;
                  return ListTile(
                    selected: selected,
                    title: Text('${item.art} | ${item.des}'),
                    subtitle: Text(
                      'Origen ${item.stockSal} | Destino ${item.stockEnt} | Costo ${_money(item.ctop)}',
                    ),
                    trailing: IconButton(
                      tooltip: 'Agregar cantidad',
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () => _askQuantityAndAdd(item),
                    ),
                    onTap: () => _askQuantityAndAdd(item),
                  );
                },
              ),
            ),
            if (_showLegacySearch)
              TextField(
                controller: _ctdCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Cantidad',
                  border: OutlineInputBorder(),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(_addedAny),
          child: const Text('Cerrar'),
        ),
        if (_showLegacySearch)
          FilledButton(
            onPressed: _selected == null ? null : _add,
            child: const Text('Agregar'),
          ),
      ],
    );
  }

  Widget _filters(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Filtros de busqueda',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 150,
              child: DropdownButtonFormField<String>(
                initialValue: widget.doc.sucSal,
                decoration: const InputDecoration(
                  labelText: 'SUC',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  DropdownMenuItem(
                    value: widget.doc.sucSal,
                    child: Text(widget.doc.sucSal),
                  ),
                ],
                onChanged: null,
              ),
            ),
            SizedBox(
              width: 150,
              child: DropdownButtonFormField<String>(
                initialValue: _searchBy,
                decoration: const InputDecoration(
                  labelText: 'Buscar por',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: 'ART', child: Text('ART')),
                  DropdownMenuItem(value: 'UPC', child: Text('UPC')),
                  DropdownMenuItem(value: 'DES', child: Text('DES')),
                ],
                onChanged: (value) =>
                    setState(() => _searchBy = value ?? 'ART'),
              ),
            ),
            SizedBox(
              width: 270,
              child: TextField(
                controller: _searchCtrl,
                decoration: const InputDecoration(
                  labelText: 'Buscar',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: (_) => _search(),
              ),
            ),
            _filterField(_depaCtrl, 'DEPA'),
            _filterField(_subdCtrl, 'SUBD'),
            _filterField(_clasCtrl, 'CLAS'),
            _filterField(_sclaCtrl, 'SCLA'),
            _filterField(_scla2Ctrl, 'SCLA2'),
            _filterField(_sphCtrl, 'SPH'),
            _filterField(_cylCtrl, 'CYL'),
            _filterField(_adicCtrl, 'ADIC'),
            FilledButton.icon(
              onPressed: _loading ? null : _search,
              icon: const Icon(Icons.search),
              label: const Text('Buscar'),
            ),
            OutlinedButton.icon(
              onPressed: _clearFilters,
              icon: const Icon(Icons.refresh),
              label: const Text('Limpiar'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _filterField(TextEditingController controller, String label) {
    return SizedBox(
      width: 118,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        onSubmitted: (_) => _search(),
      ),
    );
  }

  Future<void> _search() async {
    setState(() => _loading = true);
    try {
      final res = await ref
          .read(transferenciaApiProvider)
          .articulos(
            sucSal: widget.doc.sucSal,
            sucEnt: widget.doc.sucEnt,
            search: _searchCtrl.text,
            searchBy: _searchBy,
            depa: _depaCtrl.text,
            subd: _subdCtrl.text,
            clas: _clasCtrl.text,
            scla: _sclaCtrl.text,
            scla2: _scla2Ctrl.text,
            sph: _sphCtrl.text,
            cyl: _cylCtrl.text,
            adic: _adicCtrl.text,
            limit: 50,
          );
      if (!mounted) return;
      setState(() {
        _items = res.items;
        _selected = res.items.isEmpty ? null : res.items.first;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(e))));
    }
  }

  void _clearFilters() {
    setState(() {
      _searchCtrl.clear();
      _depaCtrl.clear();
      _subdCtrl.clear();
      _clasCtrl.clear();
      _sclaCtrl.clear();
      _scla2Ctrl.clear();
      _sphCtrl.clear();
      _cylCtrl.clear();
      _adicCtrl.clear();
      _searchBy = 'ART';
      _items = const [];
      _selected = null;
    });
  }

  Future<void> _askQuantityAndAdd(TransferenciaArticuloModel item) async {
    final raw = await _askText(
      context,
      'Cantidad a pedir',
      'Cantidad para ${item.art}',
      initial: '1',
    );
    if (raw == null) return;
    final ctd = double.tryParse(raw.replaceAll(',', '.'));
    if (ctd == null || ctd <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cantidad invÃ¡lida.')));
      return;
    }
    try {
      await ref
          .read(transferenciaApiProvider)
          .addDetalle(widget.doc.doc, art: item.art, ctd: ctd);
      if (!mounted) return;
      setState(() => _addedAny = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ArtÃ­culo ${item.art} agregado.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(e))));
    }
  }

  Future<void> _add() async {
    final selected = _selected;
    final ctd = double.tryParse(_ctdCtrl.text.replaceAll(',', '.'));
    if (selected == null || ctd == null || ctd <= 0) return;
    try {
      await ref
          .read(transferenciaApiProvider)
          .addDetalle(widget.doc.doc, art: selected.art, ctd: ctd);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(e))));
    }
  }
}

class _TransitDialog extends StatefulWidget {
  const _TransitDialog();

  @override
  State<_TransitDialog> createState() => _TransitDialogState();
}

class _TransitDialogState extends State<_TransitDialog> {
  final _empCtrl = TextEditingController();
  final _guiaCtrl = TextEditingController();
  final _respCtrl = TextEditingController();
  final _txtCtrl = TextEditingController();

  @override
  void dispose() {
    _empCtrl.dispose();
    _guiaCtrl.dispose();
    _respCtrl.dispose();
    _txtCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Datos de envío'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _empCtrl,
              decoration: const InputDecoration(labelText: 'Paquetería'),
            ),
            TextField(
              controller: _guiaCtrl,
              decoration: const InputDecoration(labelText: 'Número de guía'),
            ),
            TextField(
              controller: _respCtrl,
              decoration: const InputDecoration(labelText: 'Responsable'),
            ),
            TextField(
              controller: _txtCtrl,
              decoration: const InputDecoration(labelText: 'Observaciones'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop({
            'emp': _empCtrl.text,
            'numGuia': _guiaCtrl.text,
            'resp': _respCtrl.text,
            'txt': _txtCtrl.text,
          }),
          child: const Text('Enviar'),
        ),
      ],
    );
  }
}

Future<String?> _askText(
  BuildContext context,
  String title,
  String label, {
  String? initial,
}) {
  final ctrl = TextEditingController(text: initial ?? '');
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctrl,
        decoration: InputDecoration(labelText: label),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(ctrl.text),
          child: const Text('Aceptar'),
        ),
      ],
    ),
  );
}

Future<void> _printPdf(TransferenciaDocModel item) async {
  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.letter,
      build: (_) => [
        pw.Text(
          'Transferencia entre sucursales',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'DOC ${item.doc} | ${item.sucSal} -> ${item.sucEnt} | ${item.estatus}',
        ),
        pw.Text(
          'Motivo: ${item.mtv} | Prioridad: ${item.prio} | Fecha: ${_fmtDate(item.fcnd)}',
        ),
        if (item.paqueteria != null)
          pw.Text(
            'Paquetería: ${item.paqueteria!.emp ?? '-'} | Guía: ${item.paqueteria!.numGuia ?? '-'} | Responsable: ${item.paqueteria!.resp ?? '-'}',
          ),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          headers: const [
            'ART',
            'Descripción',
            'Solicitada',
            'Liberada',
            'Recibida',
            'Dif',
          ],
          data: item.detalle
              .map(
                (x) => [
                  x.art,
                  x.des,
                  x.ctd.toStringAsFixed(2),
                  x.ctdLib.toStringAsFixed(2),
                  x.ctdR.toStringAsFixed(2),
                  x.difR.toStringAsFixed(2),
                ],
              )
              .toList(),
          cellStyle: const pw.TextStyle(fontSize: 8),
          headerStyle: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    ),
  );
  await Printing.layoutPdf(onLayout: (_) async => doc.save());
}

String _friendlyError(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['message'] != null) return '${data['message']}';
    return error.message ?? 'No fue posible completar la operación.';
  }
  return error.toString();
}

String _fmtDate(DateTime? value) {
  if (value == null) return '-';
  return '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

String _money(double value) => '\$${value.toStringAsFixed(2)}';
