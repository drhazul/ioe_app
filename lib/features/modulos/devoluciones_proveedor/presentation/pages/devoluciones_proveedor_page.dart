import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../../../../../core/api_error.dart';
import '../../domain/devolucion_proveedor_models.dart';
import '../../providers/devolucion_proveedor_providers.dart';
import '../pdf/devolucion_proveedor_pdf.dart';

class DevolucionesProveedorPage extends ConsumerStatefulWidget {
  const DevolucionesProveedorPage({super.key});
  @override
  ConsumerState<DevolucionesProveedorPage> createState() =>
      _DevolucionesProveedorPageState();
}

class _DevolucionesProveedorPageState
    extends ConsumerState<DevolucionesProveedorPage> {
  static const _allowedBranches = {'DF01', 'DF04', 'DF05', 'DF06'};

  final _documentController = TextEditingController();
  final _dateController = TextEditingController();
  int _page = 1;
  String _status = '';
  String _suc = '';
  int? _provider;
  bool _hasAppliedFilters = false;
  String _appliedDocument = '';
  String _appliedStatus = '';
  String _appliedSuc = '';
  String _appliedDate = '';
  int? _appliedProvider;
  final Set<String> _selectedDocs = {};
  String? _processingDoc;
  bool _printingDocument = false;

  @override
  void dispose() {
    _documentController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  DevFilters get _filters => DevFilters(
    page: _page,
    document: _appliedDocument,
    suc: _appliedSuc,
    provider: _appliedProvider,
    status: _appliedStatus,
    date: _appliedDate,
  );

  @override
  Widget build(BuildContext context) {
    final docs = _hasAppliedFilters
        ? ref.watch(devDocumentsProvider(_filters))
        : null;
    final providersAsync = ref.watch(devProvidersProvider);
    final branches = List<DevBranch>.of(
      ref.watch(devBranchesProvider).value ?? const <DevBranch>[],
    )..retainWhere((branch) => _allowedBranches.contains(branch.suc));
    branches.sort((a, b) => a.suc.compareTo(b.suc));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Devoluciones a proveedor'),
        actions: [
          IconButton(
            onPressed: _selectedDocs.isNotEmpty ? _sendSelectedToTransit : null,
            icon: const Icon(Icons.local_shipping_outlined),
            tooltip: 'Enviar a tránsito',
          ),
          IconButton(
            onPressed: _selectedDocs.isNotEmpty && !_printingDocument
                ? _printSelectedDocument
                : null,
            icon: _printingDocument
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.print_outlined),
            tooltip: _selectedDocs.isEmpty
                ? 'Seleccione un documento para imprimir'
                : 'Imprimir ${_selectedDocs.length} documento(s)',
          ),
          IconButton(
            onPressed: _newDocument,
            icon: const Icon(Icons.add),
            tooltip: 'Nueva devolución',
          ),
          IconButton(
            onPressed: _hasAppliedFilters
                ? () => ref.invalidate(devDocumentsProvider(_filters))
                : null,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 260,
                  child: TextField(
                    controller: _documentController,
                    decoration: const InputDecoration(
                      labelText: 'Documento',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _applyFilters(),
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: DropdownButtonFormField<String>(
                    initialValue: _suc,
                    decoration: const InputDecoration(
                      labelText: 'Sucursal',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('Todas')),
                      ...branches.map(
                        (x) =>
                            DropdownMenuItem(value: x.suc, child: Text(x.suc)),
                      ),
                    ],
                    onChanged: (v) => setState(() {
                      _suc = v ?? '';
                    }),
                  ),
                ),
                SizedBox(
                  width: 290,
                  child: providersAsync.when(
                    data: (items) {
                      final providers = List<DevProvider>.of(items)
                        ..sort((a, b) => a.id.compareTo(b.id));
                      return DropdownButtonFormField<int>(
                        initialValue: _provider,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Proveedor',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem<int>(
                            value: null,
                            child: Text('Todos'),
                          ),
                          ...providers.map(
                            (provider) => DropdownMenuItem<int>(
                              value: provider.id,
                              child: Text(
                                '${provider.id} - ${provider.name}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (value) => setState(() => _provider = value),
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (error, _) => Text('Proveedores: $error'),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: const InputDecoration(
                      labelText: 'Estatus',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: '', child: Text('Todos')),
                      DropdownMenuItem(
                        value: 'BORRADOR',
                        child: Text('BORRADOR'),
                      ),
                      DropdownMenuItem(
                        value: 'AUTORIZADA',
                        child: Text('AUTORIZADA'),
                      ),
                      DropdownMenuItem(
                        value: 'RECHAZADA',
                        child: Text('NO ACEPTADA'),
                      ),
                      DropdownMenuItem(
                        value: 'EN_TRANSITO',
                        child: Text('EN TRANSITO'),
                      ),
                      DropdownMenuItem(
                        value: 'RECIBIDA',
                        child: Text('RECIBIDA'),
                      ),
                      DropdownMenuItem(
                        value: 'PENDIENTE',
                        child: Text('PENDIENTE'),
                      ),
                      DropdownMenuItem(
                        value: 'CANCELADA',
                        child: Text('CANCELADA'),
                      ),
                    ],
                    onChanged: (v) => setState(() {
                      _status = v ?? '';
                    }),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: _dateController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Fecha',
                      hintText: 'YYYY-MM-DD',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      suffixIcon: IconButton(
                        tooltip: 'Seleccionar fecha',
                        icon: const Icon(Icons.calendar_month),
                        onPressed: _pickDate,
                      ),
                    ),
                    onTap: _pickDate,
                  ),
                ),
                FilledButton.icon(
                  onPressed: _applyFilters,
                  icon: const Icon(Icons.search),
                  label: const Text('Consultar'),
                ),
                OutlinedButton.icon(
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Limpiar'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: docs == null
                ? const Center(
                    child: Text('Capture al menos un filtro para consultar.'),
                  )
                : docs.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(
                      child: Text(
                        apiErrorMessage(
                          e,
                          fallback: 'No fue posible consultar devoluciones.',
                        ),
                      ),
                    ),
                    data: (result) => ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        _DocumentsTable(
                          result: result,
                          selectedDocs: _selectedDocs,
                          onSelected: (document, selected) => setState(() {
                            if (selected) {
                              _selectedDocs.add(document.doc);
                            } else {
                              _selectedDocs.remove(document.doc);
                            }
                          }),
                          onPageChanged: (page) => setState(() => _page = page),
                          onOpen: (document) => context.go(
                            '/modulos/devoluciones-proveedor/${Uri.encodeComponent(document.doc)}',
                          ),
                          onAction: _runDocumentAction,
                          processingDoc: _processingDoc,
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _applyFilters() {
    final document = _documentController.text.trim();
    final date = _dateController.text.trim();
    if (document.isEmpty &&
        _suc.isEmpty &&
        _provider == null &&
        _status.isEmpty &&
        date.isEmpty) {
      setState(() {
        _hasAppliedFilters = false;
        _selectedDocs.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Capture al menos un filtro.')),
      );
      return;
    }

    setState(() {
      _appliedDocument = document;
      _appliedSuc = _suc;
      _appliedProvider = _provider;
      _appliedStatus = _status;
      _appliedDate = date;
      _page = 1;
      _hasAppliedFilters = true;
      _selectedDocs.clear();
    });
  }

  void _clearFilters() {
    setState(() {
      _documentController.clear();
      _dateController.clear();
      _suc = '';
      _provider = null;
      _status = '';
      _appliedDocument = '';
      _appliedSuc = '';
      _appliedProvider = null;
      _appliedStatus = '';
      _appliedDate = '';
      _page = 1;
      _hasAppliedFilters = false;
      _selectedDocs.clear();
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = DateTime.tryParse(_dateController.text.trim()) ?? now;
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (selected == null || !mounted) return;
    setState(() => _dateController.text = _date(selected));
  }

  Future<void> _newDocument() async {
    try {
      final values = await Future.wait([
        ref.read(devBranchesProvider.future),
        ref.read(devProvidersProvider.future),
        ref.read(devTypesProvider.future),
      ]);
      if (!mounted) return;
      final branches = List<DevBranch>.of(values[0] as List<DevBranch>)
        ..retainWhere((branch) => _allowedBranches.contains(branch.suc))
        ..sort((a, b) => a.suc.compareTo(b.suc));
      final providers = List<DevProvider>.of(values[1] as List<DevProvider>)
        ..sort((a, b) => a.id.compareTo(b.id));
      final result = await showDialog<_NewDevData>(
        context: context,
        builder: (_) => _NewDevDialog(
          branches: branches,
          providers: providers,
          types: values[2] as List<DevOption>,
        ),
      );
      if (result == null || !mounted) return;
      final created = await ref
          .read(devolucionProveedorApiProvider)
          .create(
            suc: result.suc,
            provider: result.provider,
            type: result.type,
            oc: result.oc,
            receipt: result.receipt,
            obs: result.obs,
          );
      if (!mounted) return;
      ref.invalidate(devDocumentsProvider);
      context.go(
        '/modulos/devoluciones-proveedor/${Uri.encodeComponent(created.doc)}?nuevo=1',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              apiErrorMessage(
                e,
                fallback: 'No fue posible crear la devolución.',
              ),
            ),
          ),
        );
      }
    }
  }

  Future<void> _runDocumentAction(DevDocument document, String action) async {
    String? reason;
    if (action == 'rechazar') {
      final controller = TextEditingController();
      reason = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Rechazar devolución'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Motivo del rechazo *',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isNotEmpty) Navigator.pop(dialogContext, value);
              },
              child: const Text('Rechazar'),
            ),
          ],
        ),
      );
      controller.dispose();
      if (reason == null || !mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Confirmar rechazo'),
          content: Text(
            '¿Desea rechazar la devolución ${devolucionDocumentNumber(document.doc)}?\n\nMotivo: $reason',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Confirmar'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    } else {
      final label = switch (action) {
        'autorizar' => 'autorizar',
        'recibir' => 'marcar como recibida',
        'cancelar' => 'cancelar',
        _ => action,
      };
      final message = action == 'autorizar'
          ? 'Al autorizar se descontará el stock y se registrará el movimiento 102.'
          : '¿Desea $label la devolución ${devolucionDocumentNumber(document.doc)}?';
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Confirmar $label'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Confirmar'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() => _processingDoc = document.doc);
    try {
      await ref
          .read(devolucionProveedorApiProvider)
          .action(document.doc, action, reason: reason);
      ref.invalidate(devDocumentsProvider);
      if (!mounted) return;
      setState(() => _selectedDocs.remove(document.doc));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Acción ejecutada en ${devolucionDocumentNumber(document.doc)}.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              apiErrorMessage(
                error,
                fallback: 'No fue posible actualizar la devolución.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _processingDoc = null);
    }
  }

  Future<void> _sendSelectedToTransit() async {
    final documents = _selectedDocs.toList(growable: false);
    if (documents.isEmpty) return;
    final api = ref.read(devolucionProveedorApiProvider);
    List<DevDocument> selected;
    try {
      selected = await Future.wait(documents.map(api.fetchOne));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(apiErrorMessage(error))));
      }
      return;
    }
    final first = selected.first;
    final valid = selected.every(
      (document) =>
          document.status == 'AUTORIZADA' &&
          document.suc == first.suc &&
          document.providerId == first.providerId,
    );
    if (!valid) {
      final reason = selected.any((document) => document.status != 'AUTORIZADA')
          ? 'Todos los documentos deben tener estatus AUTORIZADA.'
          : 'Los documentos deben pertenecer a la misma sucursal y proveedor.';
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(reason)));
      }
      return;
    }
    if (!mounted) return;
    final data = await showDialog<_ShipmentData>(
      context: context,
      builder: (_) => _ShipmentDialog(
        count: 1,
        title: 'Enviar devolución a tránsito',
        actionLabel: 'Continuar',
      ),
    );
    if (data == null || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmar envío a tránsito'),
        content: Text(
          '¿Desea enviar ${documents.length} documento(s) a tránsito con la guía ${data.tracking}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _processingDoc = documents.first);
    try {
      for (final doc in documents) {
        setState(() => _processingDoc = doc);
        await ref
            .read(devolucionProveedorApiProvider)
            .transit(
              doc,
              carrier: data.carrier,
              tracking: data.tracking,
              boxes: data.boxes,
              rma: data.rma,
              obs: data.obs,
            );
      }
      ref.invalidate(devDocumentsProvider);
      if (!mounted) return;
      setState(() => _selectedDocs.removeAll(documents));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${documents.length} documento(s) enviado(s) a tránsito.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              apiErrorMessage(
                error,
                fallback: 'No fue posible enviar la devolución a tránsito.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _processingDoc = null);
    }
  }

  Future<void> _printSelectedDocument() async {
    final selectedDocs = _selectedDocs.toList(growable: false);
    if (selectedDocs.isEmpty || _printingDocument) return;
    setState(() => _printingDocument = true);
    try {
      final api = ref.read(devolucionProveedorApiProvider);
      final documents = await Future.wait(selectedDocs.map(api.fetchOne));
      final bytes = await buildDevolucionesProveedorPdf(documents);
      final fileName = devolucionesProveedorPdfFileName(documents);
      await Printing.layoutPdf(
        name: fileName,
        format: PdfPageFormat.letter,
        dynamicLayout: false,
        onLayout: (_) async => bytes,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              apiErrorMessage(
                error,
                fallback: 'No fue posible generar el PDF del documento.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _printingDocument = false);
    }
  }
}

class _DocumentsTable extends StatelessWidget {
  const _DocumentsTable({
    required this.result,
    required this.selectedDocs,
    required this.onSelected,
    required this.onPageChanged,
    required this.onOpen,
    required this.onAction,
    required this.processingDoc,
  });

  final DevPaged<DevDocument> result;
  final Set<String> selectedDocs;
  final void Function(DevDocument document, bool selected) onSelected;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<DevDocument> onOpen;
  final void Function(DevDocument document, String action) onAction;
  final String? processingDoc;

  @override
  Widget build(BuildContext context) {
    final totalPages = result.total <= 0
        ? 1
        : ((result.total + result.limit - 1) ~/ result.limit);
    final from = result.total == 0 ? 0 : ((result.page - 1) * result.limit) + 1;
    final to = ((result.page - 1) * result.limit + result.items.length).clamp(
      0,
      result.total,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Devoluciones $from-$to de ${result.total}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                _PageIconButton(
                  tooltip: 'Primera página',
                  icon: Icons.first_page,
                  enabled: result.page > 1,
                  onPressed: () => onPageChanged(1),
                ),
                _PageIconButton(
                  tooltip: 'Página anterior',
                  icon: Icons.chevron_left,
                  enabled: result.page > 1,
                  onPressed: () => onPageChanged(result.page - 1),
                ),
                Text('Página ${result.page} de $totalPages'),
                _PageIconButton(
                  tooltip: 'Página siguiente',
                  icon: Icons.chevron_right,
                  enabled: result.page < totalPages,
                  onPressed: () => onPageChanged(result.page + 1),
                ),
                _PageIconButton(
                  tooltip: 'Última página',
                  icon: Icons.last_page,
                  enabled: result.page < totalPages,
                  onPressed: () => onPageChanged(totalPages),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (result.items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No hay devoluciones para los filtros seleccionados.',
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Seleccionar')),
                    DataColumn(label: Text('Documento')),
                    DataColumn(label: Text('Sucursal')),
                    DataColumn(label: Text('Proveedor')),
                    DataColumn(label: Text('Estatus')),
                    DataColumn(label: Text('Fecha')),
                    DataColumn(label: Text('Artículos'), numeric: true),
                    DataColumn(label: Text('Cantidad'), numeric: true),
                    DataColumn(label: Text('Importe'), numeric: true),
                    DataColumn(
                      label: SizedBox(width: 268, child: Text('Acciones')),
                    ),
                  ],
                  rows: [
                    for (final document in result.items)
                      DataRow(
                        cells: [
                          DataCell(
                            Checkbox(
                              value: selectedDocs.contains(document.doc),
                              onChanged: (value) =>
                                  onSelected(document, value ?? false),
                            ),
                          ),
                          DataCell(
                            Text(devolucionDocumentNumber(document.doc)),
                            onTap: () => onOpen(document),
                          ),
                          DataCell(Text(document.suc)),
                          DataCell(
                            SizedBox(
                              width: 260,
                              child: Text(document.provider),
                            ),
                          ),
                          DataCell(Text(_displayStatus(document.status))),
                          DataCell(Text(_date(document.date))),
                          DataCell(Text('${document.lines}')),
                          DataCell(Text(document.quantity.toStringAsFixed(2))),
                          DataCell(
                            Text('\$${document.amount.toStringAsFixed(2)}'),
                          ),
                          DataCell(
                            _DocumentActions(
                              document: document,
                              processing: processingDoc == document.doc,
                              onOpen: () => onOpen(document),
                              onAction: (action) => onAction(document, action),
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
    );
  }
}

class _DocumentActions extends StatelessWidget {
  const _DocumentActions({
    required this.document,
    required this.processing,
    required this.onOpen,
    required this.onAction,
  });

  final DevDocument document;
  final bool processing;
  final VoidCallback onOpen;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    final status = document.status;
    final canOperate = !processing && status != 'CANCELADA';
    return SizedBox(
      width: 268,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            tooltip: 'Ver detalle',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.visibility),
            onPressed: processing ? null : onOpen,
          ),
          IconButton(
            tooltip: 'Autorizar',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.verified_outlined),
            onPressed: canOperate && status == 'PENDIENTE'
                ? () => onAction('autorizar')
                : null,
          ),
          IconButton(
            tooltip: 'Rechazar',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.thumb_down_alt_outlined),
            onPressed: canOperate && status == 'PENDIENTE'
                ? () => onAction('rechazar')
                : null,
          ),
          IconButton(
            tooltip: 'Marcar como recibida',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.move_to_inbox_outlined),
            onPressed: canOperate && status == 'EN_TRANSITO'
                ? () => onAction('recibir')
                : null,
          ),
          IconButton(
            tooltip: 'Cancelar',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.cancel_outlined),
            onPressed: canOperate ? () => onAction('cancelar') : null,
          ),
        ],
      ),
    );
  }
}

class _PageIconButton extends StatelessWidget {
  const _PageIconButton({
    required this.tooltip,
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton.outlined(
    tooltip: tooltip,
    visualDensity: VisualDensity.compact,
    onPressed: enabled ? onPressed : null,
    icon: Icon(icon),
  );
}

String _displayStatus(String status) => switch (status) {
  'RECHAZADA' => 'NO ACEPTADA',
  'EN_TRANSITO' => 'EN TRANSITO',
  _ => status,
};

String _date(DateTime? value) {
  if (value == null) return '';
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

class _NewDevData {
  const _NewDevData(
    this.suc,
    this.provider,
    this.type,
    this.oc,
    this.receipt,
    this.obs,
  );
  final String suc;
  final int provider;
  final int type;
  final String oc;
  final String receipt;
  final String obs;
}

class _ShipmentData {
  const _ShipmentData(
    this.carrier,
    this.tracking,
    this.boxes,
    this.rma,
    this.obs,
  );
  final String carrier;
  final String tracking;
  final int boxes;
  final String rma;
  final String obs;
}

class _ShipmentDialog extends StatefulWidget {
  const _ShipmentDialog({
    required this.count,
    this.title,
    this.actionLabel = 'Consolidar',
  });
  final int count;
  final String? title;
  final String actionLabel;
  @override
  State<_ShipmentDialog> createState() => _ShipmentDialogState();
}

class _ShipmentDialogState extends State<_ShipmentDialog> {
  final carrier = TextEditingController();
  final tracking = TextEditingController();
  final boxes = TextEditingController(text: '1');
  final rma = TextEditingController();
  final obs = TextEditingController();

  @override
  void dispose() {
    carrier.dispose();
    tracking.dispose();
    boxes.dispose();
    rma.dispose();
    obs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title ?? 'Consolidar ${widget.count} devoluciones'),
    content: SizedBox(
      width: 480,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: carrier,
            decoration: const InputDecoration(labelText: 'Transportista *'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: tracking,
            decoration: const InputDecoration(labelText: 'Número de guía *'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: boxes,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Cajas *'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: rma,
            decoration: const InputDecoration(labelText: 'Usuario que entrega'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: obs,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Observaciones'),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          final count = int.tryParse(boxes.text.trim());
          if (carrier.text.trim().isEmpty ||
              tracking.text.trim().isEmpty ||
              count == null ||
              count <= 0) {
            return;
          }
          Navigator.pop(
            context,
            _ShipmentData(
              carrier.text.trim(),
              tracking.text.trim(),
              count,
              rma.text.trim(),
              obs.text.trim(),
            ),
          );
        },
        child: Text(widget.actionLabel),
      ),
    ],
  );
}

class _NewDevDialog extends StatefulWidget {
  const _NewDevDialog({
    required this.branches,
    required this.providers,
    required this.types,
  });
  final List<DevBranch> branches;
  final List<DevProvider> providers;
  final List<DevOption> types;
  @override
  State<_NewDevDialog> createState() => _NewDevDialogState();
}

class _NewDevDialogState extends State<_NewDevDialog> {
  final _receipt = TextEditingController(), _obs = TextEditingController();
  String? _suc;
  int? _provider, _type;
  @override
  void dispose() {
    _receipt.dispose();
    _obs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Nueva devolución'),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _suc,
              decoration: const InputDecoration(labelText: 'Sucursal *'),
              items: widget.branches
                  .map(
                    (x) => DropdownMenuItem(
                      value: x.suc,
                      child: Text('${x.suc} ${x.name}'),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _suc = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _provider,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Proveedor *'),
              items: widget.providers
                  .map(
                    (x) => DropdownMenuItem(
                      value: x.id,
                      child: Text(
                        '${x.id} - ${x.name}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _provider = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _type,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Tipo de devolución *',
              ),
              items: widget.types
                  .map(
                    (x) => DropdownMenuItem(value: x.id, child: Text(x.label)),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _type = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _receipt,
              decoration: const InputDecoration(
                labelText: 'Recepción/documento de entrada (opcional)',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _obs,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Observaciones'),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: _suc == null || _provider == null || _type == null
            ? null
            : () => Navigator.pop(
                context,
                _NewDevData(
                  _suc!,
                  _provider!,
                  _type!,
                  '',
                  _receipt.text.trim(),
                  _obs.text.trim(),
                ),
              ),
        child: const Text('Crear'),
      ),
    ],
  );
}
