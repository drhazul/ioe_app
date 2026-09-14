import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/api_error.dart';
import '../../data/devolucion_proveedor_api.dart';
import '../../domain/devolucion_proveedor_models.dart';
import '../../providers/devolucion_proveedor_providers.dart';
import '../import/devolucion_proveedor_excel.dart';

class DevolucionProveedorDetailPage extends ConsumerStatefulWidget {
  const DevolucionProveedorDetailPage({super.key, required this.doc});
  final String doc;
  @override
  ConsumerState<DevolucionProveedorDetailPage> createState() =>
      _DevolucionProveedorDetailPageState();
}

class _DevolucionProveedorDetailPageState
    extends ConsumerState<DevolucionProveedorDetailPage> {
  bool _working = false;
  Future<DevSourceDocument>? _sourceFuture;
  String? _sourceKey;
  final Set<String> _selectedSourceItems = <String>{};
  bool _sourceSelectionHydrated = false;
  static const _sourcePageSize = 100;
  int _sourcePage = 1;
  final _filterSearch = TextEditingController();
  final _filterDepa = TextEditingController();
  final _filterSubd = TextEditingController();
  final _filterClas = TextEditingController();
  final _filterScla = TextEditingController();
  final _filterScla2 = TextEditingController();
  final _filterSph = TextEditingController();
  final _filterCyl = TextEditingController();
  final _filterAdic = TextEditingController();
  String _filterSearchBy = 'ART';
  String _appliedFilter = '';

  @override
  void dispose() {
    _filterSearch.dispose();
    _filterDepa.dispose();
    _filterSubd.dispose();
    _filterClas.dispose();
    _filterScla.dispose();
    _filterScla2.dispose();
    _filterSph.dispose();
    _filterCyl.dispose();
    _filterAdic.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(devDocumentProvider(widget.doc));
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Las altas y ediciones se guardan en la API inmediatamente.
            // Invalidar ambas consultas evita mostrar datos obsoletos al volver.
            ref.invalidate(devDocumentProvider(widget.doc));
            ref.invalidate(devDocumentsProvider);
            context.go('/modulos/devoluciones-proveedor');
          },
        ),
        title: Text('Devolución a Proveedor ${devDocumentFolio(widget.doc)}'),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(devDocumentProvider(widget.doc)),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            apiErrorMessage(e, fallback: 'No fue posible abrir la devolución.'),
          ),
        ),
        data: _content,
      ),
    );
  }

  Widget _content(DevDocument doc) {
    // Una selección representa los detalles que ya fueron capturados. Al
    // regresar a un documento se reconstruye desde la información persistida.
    if (doc.oc.trim().isNotEmpty || doc.receipt.trim().isNotEmpty) {
      if (!_sourceSelectionHydrated) {
        _selectedSourceItems.addAll(doc.details.map((detail) => detail.art));
        _sourceSelectionHydrated = true;
      }
    }
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _summary(doc),
            const SizedBox(height: 12),
            _actions(doc),
            const SizedBox(height: 12),
            _searchFilters(doc),
            const SizedBox(height: 12),
            _sourceSection(doc),
            if (doc.oc.trim().isEmpty &&
                doc.receipt.trim().isEmpty &&
                doc.details.isNotEmpty) ...[
              const SizedBox(height: 12),
              _detailsTable(doc),
            ],
            const SizedBox(height: 12),
            const SizedBox(height: 60),
          ],
        ),
        if (_working)
          const ColoredBox(
            color: Color(0x55000000),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Widget _searchFilters(DevDocument doc) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Filtros de búsqueda'),
      const SizedBox(height: 4),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          SizedBox(
            width: 150,
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'SUC'),
              child: Text(doc.suc),
            ),
          ),
          SizedBox(
            width: 150,
            child: DropdownButtonFormField<String>(
              initialValue: _filterSearchBy,
              decoration: const InputDecoration(labelText: 'Buscar por'),
              items: const [
                DropdownMenuItem(value: 'ART', child: Text('ART')),
                DropdownMenuItem(value: 'UPC', child: Text('UPC')),
                DropdownMenuItem(value: 'DESC', child: Text('Descripción')),
              ],
              onChanged: (value) =>
                  setState(() => _filterSearchBy = value ?? 'ART'),
            ),
          ),
          _filterField(_filterSearch, 'Buscar', 270),
          _filterField(_filterDepa, 'DEPA', 120),
          _filterField(_filterSubd, 'SUBD', 120),
          _filterField(_filterClas, 'CLAS', 120),
          _filterField(_filterScla, 'SCLA', 120),
          _filterField(_filterScla2, 'SCLA2', 120),
          _filterField(_filterSph, 'SPH', 120),
          _filterField(_filterCyl, 'CYL', 120),
          _filterField(_filterAdic, 'ADIC', 120),
          FilledButton.icon(
            onPressed: () => setState(() {
              _appliedFilter = _filterSearch.text.trim().toLowerCase();
              _sourcePage = 1;
            }),
            icon: const Icon(Icons.search),
            label: const Text('Buscar'),
          ),
          OutlinedButton.icon(
            onPressed: () => setState(() {
              for (final controller in [
                _filterSearch,
                _filterDepa,
                _filterSubd,
                _filterClas,
                _filterScla,
                _filterScla2,
                _filterSph,
                _filterCyl,
                _filterAdic,
              ]) {
                controller.clear();
              }
              _appliedFilter = '';
              _sourcePage = 1;
            }),
            icon: const Icon(Icons.refresh),
            label: const Text('Limpiar'),
          ),
        ],
      ),
    ],
  );

  Widget _filterField(
    TextEditingController controller,
    String label,
    double width,
  ) => SizedBox(
    width: width,
    child: TextField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
    ),
  );

  Widget _summary(DevDocument doc) => Card(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: BorderSide(color: Colors.grey.shade300),
    ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Proveedor: ${doc.provider}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Chip(
                label: Text(doc.status),
                visualDensity: VisualDensity.compact,
              ),
              Text('Sucursal: ${doc.suc}'),
              Text('Almacén: ${doc.warehouse}'),
              Text('Tipo: ${doc.typeDescription}'),
              Text(
                'Orden de compra: ${doc.oc.isEmpty ? 'No relacionada' : doc.oc}',
              ),
              Text(
                'Recepción: ${doc.receipt.isEmpty ? 'No relacionada' : doc.receipt}',
              ),
              Text('Cantidad: ${doc.quantity.toStringAsFixed(2)}'),
              Text('Importe: \$${doc.amount.toStringAsFixed(2)}'),
            ],
          ),
          if (doc.obs.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Observaciones: ${doc.obs}'),
          ],
          if (doc.rejectionReason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Motivo de rechazo: ${doc.rejectionReason}',
              style: const TextStyle(color: Colors.red),
            ),
          ],
          if (doc.status == 'PENDIENTE') ...[
            const SizedBox(height: 8),
            const Text(
              'Las cantidades están reservadas. DAT_ART.STOCK se afectará únicamente al autorizar.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _actions(DevDocument doc) {
    final actions = <Widget>[];
    if (doc.status == 'BORRADOR') {
      if (doc.oc.trim().isEmpty && doc.receipt.trim().isEmpty) {
        actions.add(
          FilledButton.icon(
            onPressed: () => _addItem(doc),
            icon: const Icon(Icons.add),
            label: const Text('Agregar artículo'),
          ),
        );
        actions.add(
          OutlinedButton.icon(
            onPressed: () => _importExcel(doc),
            icon: const Icon(Icons.upload_file),
            label: const Text('Importar Excel'),
          ),
        );
      }
      final hasSelected = doc.oc.trim().isEmpty && doc.receipt.trim().isEmpty
          ? doc.details.isNotEmpty
          : _selectedSourceItems.isNotEmpty;
      actions.add(
        OutlinedButton.icon(
          onPressed: () => _addDocumentEvidence(doc),
          icon: const Icon(Icons.add_a_photo_outlined),
          label: Text(
            doc.details.any((detail) => detail.evidenceCount > 0)
                ? 'Cambiar evidencia'
                : 'Agregar evidencia',
          ),
        ),
      );
      actions.add(
        FilledButton.icon(
          onPressed: doc.details.isEmpty || !hasSelected
              ? null
              : () => _confirmAction(
                  doc,
                  'solicitar',
                  'Enviar a autorización',
                  'Se validará disponibilidad y se reservarán las cantidades.',
                  closeOnSuccess: true,
                ),
          icon: const Icon(Icons.send),
          label: const Text('Enviar a autorización'),
        ),
      );
      actions.add(
        OutlinedButton.icon(
          onPressed: () =>
              _reasonAction(doc, 'cancelar', 'Cancelar devolución'),
          icon: const Icon(Icons.cancel_outlined),
          label: const Text('Cancelar'),
        ),
      );
    }
    if (doc.status != 'BORRADOR') {
      actions.add(
        OutlinedButton.icon(
          onPressed: () => _showDocumentEvidence(doc),
          icon: const Icon(Icons.visibility_outlined),
          label: const Text('Ver evidencia'),
        ),
      );
    }
    return actions.isEmpty
        ? const SizedBox.shrink()
        : Wrap(spacing: 8, runSpacing: 8, children: actions);
  }

  // Kept as a reusable table renderer for future detail-only views.
  // ignore: unused_element
  Widget _detailsTable(DevDocument doc) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 24,
          horizontalMargin: 8,
          columns: [
            const DataColumn(label: Text('ART')),
            const DataColumn(label: Text('UPC')),
            const DataColumn(label: Text('Descripción')),
            DataColumn(
              label: Text(
                doc.oc.trim().isNotEmpty
                    ? 'Solicitado'
                    : (doc.receipt.trim().isNotEmpty
                          ? 'Disponible'
                          : 'Disponible'),
              ),
              numeric: true,
            ),
            const DataColumn(label: Text('Cantidad a devolver'), numeric: true),
            const DataColumn(label: Text('Importe total'), numeric: true),
            const DataColumn(label: Text('Lote')),
            const DataColumn(label: Text('Motivo de devolución')),
            const DataColumn(label: Text('Acciones')),
          ],
          rows: doc.details.map((detail) {
            return DataRow(
              cells: [
                DataCell(Text(detail.art)),
                DataCell(Text(detail.upc)),
                DataCell(SizedBox(width: 280, child: Text(detail.description))),
                DataCell(Text(detail.available.toStringAsFixed(2))),
                DataCell(Text(detail.quantity.toStringAsFixed(2))),
                DataCell(Text('\$${detail.amount.toStringAsFixed(2)}')),
                DataCell(Text(detail.lot.trim().isEmpty ? '—' : detail.lot)),
                DataCell(
                  SizedBox(
                    width: 210,
                    child: Text(
                      '${detail.reasonCode} · ${detail.reasonDescription}',
                    ),
                  ),
                ),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Editar artículo',
                        onPressed: doc.editable
                            ? () => _editItem(doc, detail)
                            : null,
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: 'Eliminar artículo',
                        onPressed: doc.editable
                            ? () => _removeItem(doc, detail)
                            : null,
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    ),
  );

  String _formatDate(DateTime? value) {
    if (value == null) return '—';
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  Widget _sourceSection(DevDocument doc) {
    final order = doc.oc.trim();
    final receipt = doc.receipt.trim();
    if (order.isEmpty && receipt.isEmpty) {
      return const SizedBox.shrink();
    }
    final key = '$order|$receipt';
    if (_sourceKey != key) {
      _sourceKey = key;
      _sourcePage = 1;
      _sourceFuture = ref
          .read(devolucionProveedorApiProvider)
          .sourceDocument(order: order, receipt: receipt);
    }
    return FutureBuilder<DevSourceDocument>(
      future: _sourceFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(),
            ),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No fue posible cargar el documento origen: ${snapshot.error ?? 'sin datos'}.',
              ),
            ),
          );
        }
        final source = snapshot.data!;
        final isOrderSource = order.isNotEmpty;
        final filteredItems = _appliedFilter.isEmpty
            ? source.items
            : source.items.where((item) {
                final value = switch (_filterSearchBy) {
                  'UPC' => item.upc,
                  'DESC' => item.description,
                  _ => item.art,
                };
                return value.toLowerCase().contains(_appliedFilter);
              }).toList();
        final visibleItems = doc.status == 'BORRADOR'
            ? filteredItems
            : filteredItems
                  .where(
                    (item) =>
                        doc.details.any((detail) => detail.art == item.art),
                  )
                  .toList();
        final pageCount = (visibleItems.length / _sourcePageSize).ceil();
        final int currentPage = pageCount == 0
            ? 1
            : _sourcePage.clamp(1, pageCount).toInt();
        final start = (currentPage - 1) * _sourcePageSize;
        final pageItems = visibleItems
            .skip(start)
            .take(_sourcePageSize)
            .toList();
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${source.kind}: ${source.document}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sucursal: ${source.suc}   Proveedor: ${source.provider}   '
                  'Almacén: ${source.warehouse}   Fecha: ${_formatDate(source.date)}',
                ),
                const SizedBox(height: 8),
                if (visibleItems.isEmpty)
                  Text(
                    source.items.isEmpty
                        ? 'El documento origen no contiene artículos.'
                        : 'No hay artículos seleccionados en esta devolución.',
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (pageCount > 1)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              tooltip: 'Página anterior',
                              onPressed: currentPage > 1
                                  ? () => setState(
                                      () => _sourcePage = currentPage - 1,
                                    )
                                  : null,
                              icon: const Icon(Icons.chevron_left),
                            ),
                            Text('Página $currentPage de $pageCount'),
                            IconButton(
                              tooltip: 'Página siguiente',
                              onPressed: currentPage < pageCount
                                  ? () => setState(
                                      () => _sourcePage = currentPage + 1,
                                    )
                                  : null,
                              icon: const Icon(Icons.chevron_right),
                            ),
                          ],
                        ),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: [
                            DataColumn(
                              label: Checkbox(
                                value:
                                    pageItems.isNotEmpty &&
                                    pageItems.every(
                                      (item) => _selectedSourceItems.contains(
                                        item.art,
                                      ),
                                    ),
                                onChanged: doc.status == 'BORRADOR' && !_working
                                    ? (value) => _setSourceItemsSelected(
                                        doc,
                                        pageItems,
                                        value == true,
                                      )
                                    : null,
                              ),
                            ),
                            const DataColumn(label: Text('ART')),
                            const DataColumn(label: Text('UPC')),
                            const DataColumn(label: Text('Descripción')),
                            if (isOrderSource)
                              DataColumn(
                                label: Text('Solicitada'),
                                numeric: true,
                              )
                            else
                              DataColumn(
                                label: Text('Disponible'),
                                numeric: true,
                              ),
                            const DataColumn(
                              label: Text('Cantidad a devolver'),
                              numeric: true,
                            ),
                            DataColumn(
                              label: Text('Importe total'),
                              numeric: true,
                            ),
                            const DataColumn(label: Text('Lote')),
                            const DataColumn(
                              label: Text('Motivo de devolución'),
                            ),
                            const DataColumn(label: Text('Acciones')),
                          ],
                          rows: pageItems.map((item) {
                            DevDetail? captured;
                            for (final detail in doc.details) {
                              if (detail.art == item.art) {
                                captured = detail;
                                break;
                              }
                            }
                            final availableQty = isOrderSource
                                ? item.ordered
                                : (item.received > 0
                                      ? item.received
                                      : item.ordered);
                            final selected = _selectedSourceItems.contains(
                              item.art,
                            );
                            return DataRow(
                              cells: [
                                DataCell(
                                  Checkbox(
                                    value: _selectedSourceItems.contains(
                                      item.art,
                                    ),
                                    onChanged:
                                        doc.status == 'BORRADOR' && !_working
                                        ? (value) => _setSourceItemsSelected(
                                            doc,
                                            [item],
                                            value == true,
                                          )
                                        : null,
                                  ),
                                ),
                                DataCell(Text(item.art)),
                                DataCell(Text(item.upc)),
                                DataCell(Text(item.description)),
                                DataCell(Text(availableQty.toStringAsFixed(2))),
                                DataCell(
                                  Text(
                                    captured?.quantity.toStringAsFixed(2) ??
                                        (selected
                                            ? availableQty.toStringAsFixed(2)
                                            : '—'),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    captured == null
                                        ? (selected
                                              ? '\$${(availableQty * item.cost).toStringAsFixed(2)}'
                                              : '')
                                        : '\$${captured.amount.toStringAsFixed(2)}',
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    captured?.lot.trim().isNotEmpty == true
                                        ? captured!.lot
                                        : '—',
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    captured == null
                                        ? '—'
                                        : '${captured.reasonCode} · ${captured.reasonDescription}',
                                  ),
                                ),
                                DataCell(
                                  GestureDetector(
                                    onTap:
                                        doc.status == 'BORRADOR' &&
                                            (captured != null ||
                                                _selectedSourceItems.contains(
                                                  item.art,
                                                ))
                                        ? () => captured == null
                                              ? _addItem(doc, item)
                                              : _editItem(doc, captured)
                                        : null,
                                    child: Icon(
                                      Icons.edit_outlined,
                                      color:
                                          doc.status == 'BORRADOR' &&
                                              (captured != null ||
                                                  _selectedSourceItems.contains(
                                                    item.art,
                                                  ))
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.primary
                                          : Colors.grey,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _addItem(DevDocument doc, [DevSourceItem? sourceItem]) async {
    try {
      final reasons = await ref.read(devReasonsProvider.future);
      if (!mounted) return;
      final data = await showDialog<_ItemData>(
        context: context,
        builder: (_) => _AddItemDialog(
          suc: doc.suc,
          provider: doc.providerId,
          reasons: reasons,
          api: ref.read(devolucionProveedorApiProvider),
          initialArticle: sourceItem?.toArticle(),
          initialQuantity: sourceItem == null
              ? null
              : (sourceItem.pending > 0
                    ? sourceItem.pending
                    : sourceItem.received > 0
                    ? sourceItem.received
                    : sourceItem.ordered),
        ),
      );
      if (data == null) return;
      final saved = await _run(
        () => ref
            .read(devolucionProveedorApiProvider)
            .addDetail(
              doc.doc,
              article: data.article,
              quantity: data.quantity,
              reason: data.reason,
              lot: data.lot,
              expiration: data.expiration,
              evidenceName: data.evidence?.name,
              evidenceMimeType: data.evidence?.mimeType,
              evidenceContent: data.evidence?.content,
            ),
      );
      if (saved) await _syncSelections(doc);
    } catch (e) {
      _error(e);
    }
  }

  Future<void> _setSourceItemsSelected(
    DevDocument doc,
    List<DevSourceItem> items,
    bool selected,
  ) async {
    if (items.isEmpty || _working) return;
    try {
      final api = ref.read(devolucionProveedorApiProvider);
      final uniqueItems = {
        for (final item in items) item.art: item,
      }.values.toList();
      final capturedByArticle = {
        for (final detail in doc.details) detail.art: detail,
      };
      final reasons = selected
          ? await ref.read(devReasonsProvider.future)
          : const <DevOption>[];
      if (selected && reasons.isEmpty) {
        throw const FormatException(
          'No hay motivos de devolución configurados.',
        );
      }

      final saved = await _run(() async {
        var updated = doc;
        for (final item in uniqueItems) {
          final captured = capturedByArticle[item.art];
          if (selected && captured == null) {
            final quantity = item.pending > 0
                ? item.pending
                : (item.received > 0 ? item.received : item.ordered);
            if (quantity <= 0) continue;
            updated = await api.addDetail(
              doc.doc,
              article: item.toArticle(),
              quantity: quantity,
              reason: reasons.first.id,
            );
          } else if (!selected && captured != null) {
            updated = await api.removeDetail(doc.doc, captured.idpd);
          }
        }
        return updated;
      });
      if (!saved || !mounted) return;
      setState(() {
        if (selected) {
          _selectedSourceItems.addAll(uniqueItems.map((item) => item.art));
        } else {
          _selectedSourceItems.removeAll(uniqueItems.map((item) => item.art));
        }
      });
    } catch (e) {
      _error(e);
    }
  }

  Future<void> _addDocumentEvidence(DevDocument doc) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final file = picked?.files.single;
    if (file == null || file.bytes == null) return;
    final mime = file.extension == null
        ? 'image/jpeg'
        : 'image/${file.extension!.toLowerCase() == 'jpg' ? 'jpeg' : file.extension!.toLowerCase()}';
    await _run(
      () => ref
          .read(devolucionProveedorApiProvider)
          .documentEvidence(
            doc.doc,
            name: file.name,
            mimeType: mime,
            content: 'data:$mime;base64,${base64Encode(file.bytes!)}',
          ),
    );
  }

  Future<void> _showDocumentEvidence(DevDocument doc) async {
    setState(() => _working = true);
    try {
      final items = await ref
          .read(devolucionProveedorApiProvider)
          .documentEvidences(doc.doc);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => _EvidenceDialog(article: doc.doc, items: items),
      );
    } catch (e) {
      _error(e);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _importExcel(DevDocument doc) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx', 'xls'],
      withData: true,
    );
    final file = picked?.files.single;
    if (file == null || file.bytes == null) return;
    try {
      final rows = parseDevolucionProveedorExcel(file.bytes!);
      final reasons = await ref.read(devReasonsProvider.future);
      if (reasons.isEmpty) {
        throw const FormatException(
          'No hay motivos de devolución configurados.',
        );
      }
      final saved = await _run(() async {
        DevDocument? result;
        for (final row in rows) {
          result = await ref
              .read(devolucionProveedorApiProvider)
              .addDetail(
                doc.doc,
                article: DevArticle(
                  art: row.art,
                  upc: '',
                  description: row.description,
                  cost: 0,
                  stock: row.quantity,
                  available: row.quantity,
                  unit: '',
                ),
                quantity: row.quantity,
                reason: reasons.first.id,
              );
        }
        return result!;
      });
      if (saved) await _syncSelections(doc);
    } catch (e) {
      _error(e);
    }
  }

  Future<void> _removeItem(DevDocument doc, DevDetail detail) async {
    final ok =
        await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Eliminar artículo'),
            content: Text('¿Eliminar ${detail.art} de la devolución?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('No'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        ) ??
        false;
    if (ok) {
      await _run(
        () => ref
            .read(devolucionProveedorApiProvider)
            .removeDetail(doc.doc, detail.idpd),
      );
    }
  }

  Future<void> _syncSelections(DevDocument doc) async {
    try {
      final refreshed = await ref
          .read(devolucionProveedorApiProvider)
          .fetchOne(doc.doc);
      if (!mounted) return;
      setState(() {
        if (refreshed.oc.trim().isNotEmpty ||
            refreshed.receipt.trim().isNotEmpty) {
          _selectedSourceItems.addAll(
            refreshed.details.map((detail) => detail.art),
          );
        }
      });
    } catch (_) {
      // El guardado ya fue exitoso; si falla la sincronización visual, se
      // volverá a hidratar al abrir nuevamente el documento.
    }
  }

  Future<void> _editItem(DevDocument doc, DevDetail detail) async {
    try {
      final api = ref.read(devolucionProveedorApiProvider);
      final reasons = await ref.read(devReasonsProvider.future);
      if (!mounted) return;
      final data = await showDialog<_EditItemData>(
        context: context,
        builder: (_) => _EditItemDialog(detail: detail, reasons: reasons),
      );
      if (data == null) return;
      await _run(
        () => api.updateDetail(
          doc.doc,
          detail.idpd,
          quantity: data.quantity,
          reason: data.reason,
          lot: data.lot,
          expiration: data.expiration,
        ),
      );
    } catch (e) {
      _error(e);
    }
  }

  // Kept for detail-only views where evidence can be opened separately.
  // ignore: unused_element
  Future<void> _showEvidences(DevDocument doc, DevDetail detail) async {
    setState(() => _working = true);
    try {
      final items = await ref
          .read(devolucionProveedorApiProvider)
          .evidences(doc.doc, detail.idpd);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => _EvidenceDialog(article: detail.art, items: items),
      );
    } catch (e) {
      _error(e);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _confirmAction(
    DevDocument doc,
    String action,
    String title,
    String message, {
    bool closeOnSuccess = false,
  }) async {
    final ok =
        await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Confirmar'),
              ),
            ],
          ),
        ) ??
        false;
    if (ok) {
      final success = await _run(() async {
        if (action == 'solicitar') {
          final unselected = doc.oc.trim().isEmpty && doc.receipt.trim().isEmpty
              ? <DevDetail>[]
              : doc.details
                    .where(
                      (detail) => !_selectedSourceItems.contains(detail.art),
                    )
                    .toList();
          if (unselected.isEmpty) {
            return ref
                .read(devolucionProveedorApiProvider)
                .action(doc.doc, action);
          }
          DevDocument? updated;
          for (final detail in unselected) {
            updated = await ref
                .read(devolucionProveedorApiProvider)
                .removeDetail(doc.doc, detail.idpd);
          }
          return updated!;
        }
        return ref.read(devolucionProveedorApiProvider).action(doc.doc, action);
      });
      if (success && closeOnSuccess && mounted) {
        context.go('/modulos/devoluciones-proveedor');
      }
    }
  }

  Future<void> _reasonAction(
    DevDocument doc,
    String action,
    String title,
  ) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Motivo / observaciones',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason != null && (action == 'cancelar' || reason.isNotEmpty)) {
      await _run(
        () => ref
            .read(devolucionProveedorApiProvider)
            .action(doc.doc, action, reason: reason),
      );
    }
  }

  Future<bool> _run(Future<DevDocument> Function() operation) async {
    setState(() => _working = true);
    try {
      await operation();
      ref.invalidate(devDocumentProvider(widget.doc));
      ref.invalidate(devDocumentsProvider);
      return true;
    } catch (e) {
      _error(e);
      return false;
    } finally {
      if (mounted) {
        setState(() => _working = false);
      }
    }
  }

  void _error(Object e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            apiErrorMessage(e, fallback: 'No fue posible completar la acción.'),
          ),
        ),
      );
    }
  }
}

class _ItemData {
  const _ItemData(
    this.article,
    this.quantity,
    this.reason,
    this.lot,
    this.expiration,
    this.evidence,
  );
  final DevArticle article;
  final double quantity;
  final int reason;
  final String lot;
  final String expiration;
  final _ItemEvidence? evidence;
}

class _ItemEvidence {
  const _ItemEvidence({
    required this.name,
    required this.mimeType,
    required this.content,
  });

  final String name;
  final String mimeType;
  final String content;
}

class _EditItemData {
  const _EditItemData({
    required this.quantity,
    required this.reason,
    required this.lot,
    required this.expiration,
  });

  final double quantity;
  final int reason;
  final String lot;
  final String expiration;
}

class _EditItemDialog extends StatefulWidget {
  const _EditItemDialog({required this.detail, required this.reasons});

  final DevDetail detail;
  final List<DevOption> reasons;

  @override
  State<_EditItemDialog> createState() => _EditItemDialogState();
}

class _EditItemDialogState extends State<_EditItemDialog> {
  late final TextEditingController _quantity;
  late final TextEditingController _lot;
  late final TextEditingController _expiration;
  late int? _reason;

  @override
  void initState() {
    super.initState();
    _quantity = TextEditingController(
      text: widget.detail.quantity.toStringAsFixed(2),
    );
    _lot = TextEditingController(text: widget.detail.lot);
    _expiration = TextEditingController(
      text: _dateText(widget.detail.expiration),
    );
    _reason = widget.reasons.any((reason) => reason.id == widget.detail.reason)
        ? widget.detail.reason
        : null;
  }

  @override
  void dispose() {
    _quantity.dispose();
    _lot.dispose();
    _expiration.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Editar artículo'),
    insetPadding: const EdgeInsets.all(16),
    content: SizedBox(
      width: 520,
      height: 330,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${widget.detail.art} | ${widget.detail.description}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text('Disponible: ${widget.detail.available.toStringAsFixed(2)}'),
              const SizedBox(height: 12),
              TextField(
                controller: _quantity,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Cantidad *',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _reason,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Motivo *',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: widget.reasons
                    .map(
                      (reason) => DropdownMenuItem(
                        value: reason.id,
                        child: Text(
                          '${reason.code} · ${reason.label}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _reason = value),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _lot,
                decoration: const InputDecoration(
                  labelText: 'Lote de caducidad (si aplica)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _expiration,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Caducidad (si aplica)',
                  hintText: 'AAAA-MM-DD',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  suffixIcon: IconButton(
                    tooltip: 'Seleccionar caducidad',
                    onPressed: _pickExpiration,
                    icon: const Icon(Icons.calendar_month),
                  ),
                ),
                onTap: _pickExpiration,
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: _canSave ? _save : null,
        child: const Text('Guardar'),
      ),
    ],
  );

  bool get _canSave {
    final quantity = double.tryParse(
      _quantity.text.trim().replaceAll(',', '.'),
    );
    return quantity != null && quantity > 0 && _reason != null;
  }

  Future<void> _pickExpiration() async {
    final now = DateTime.now();
    final initial = DateTime.tryParse(_expiration.text.trim()) ?? now;
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 20, 12, 31),
    );
    if (selected == null || !mounted) return;
    setState(() => _expiration.text = _dateText(selected));
  }

  void _save() {
    final quantity = double.tryParse(
      _quantity.text.trim().replaceAll(',', '.'),
    );
    if (quantity == null || quantity <= 0 || _reason == null) return;
    if (quantity > widget.detail.available &&
        quantity > widget.detail.quantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La cantidad supera la disponibilidad.')),
      );
      return;
    }
    Navigator.pop(
      context,
      _EditItemData(
        quantity: quantity,
        reason: _reason!,
        lot: _lot.text.trim(),
        expiration: _expiration.text.trim(),
      ),
    );
  }

  String _dateText(DateTime? value) {
    if (value == null) return '';
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}

Uint8List? _decodeEvidenceContent(String content) {
  try {
    final encoded = content.contains(',')
        ? content.substring(content.indexOf(',') + 1)
        : content;
    return base64Decode(encoded);
  } catch (_) {
    return null;
  }
}

class _EvidenceDialog extends StatefulWidget {
  const _EvidenceDialog({required this.article, required this.items});

  final String article;
  final List<DevEvidence> items;

  @override
  State<_EvidenceDialog> createState() => _EvidenceDialogState();
}

class _EvidenceDialogState extends State<_EvidenceDialog> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final panelWidth = (size.width - 72).clamp(300.0, 560.0);
    final panelHeight = (size.height - 210).clamp(280.0, 410.0);
    return AlertDialog(
      insetPadding: const EdgeInsets.all(20),
      title: Text('Evidencia · ${widget.article}'),
      content: SizedBox(
        width: panelWidth,
        height: panelHeight,
        child: widget.items.isEmpty
            ? const Center(child: Text('No hay evidencia disponible.'))
            : Column(
                children: [
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: PageView.builder(
                          controller: _controller,
                          itemCount: widget.items.length,
                          onPageChanged: (value) =>
                              setState(() => _index = value),
                          itemBuilder: (context, index) {
                            final bytes = _decodeEvidenceContent(
                              widget.items[index].content,
                            );
                            return bytes == null
                                ? const Center(
                                    child: Text(
                                      'La imagen no se pudo mostrar.',
                                    ),
                                  )
                                : InteractiveViewer(
                                    minScale: 0.5,
                                    maxScale: 5,
                                    child: Center(
                                      child: Image.memory(
                                        bytes,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  );
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (widget.items.length > 1)
                        IconButton(
                          tooltip: 'Anterior',
                          onPressed: _index == 0
                              ? null
                              : () => _controller.previousPage(
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeOut,
                                ),
                          icon: const Icon(Icons.chevron_left),
                        ),
                      Expanded(
                        child: Text(
                          widget.items[_index].name.isEmpty
                              ? 'Evidencia ${_index + 1}'
                              : widget.items[_index].name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text('${_index + 1} de ${widget.items.length}'),
                      if (widget.items.length > 1)
                        IconButton(
                          tooltip: 'Siguiente',
                          onPressed: _index == widget.items.length - 1
                              ? null
                              : () => _controller.nextPage(
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeOut,
                                ),
                          icon: const Icon(Icons.chevron_right),
                        ),
                    ],
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

class _AddItemDialog extends StatefulWidget {
  const _AddItemDialog({
    required this.suc,
    required this.provider,
    required this.reasons,
    required this.api,
    this.initialArticle,
    this.initialQuantity,
  });
  final String suc;
  final int provider;
  final List<DevOption> reasons;
  final DevolucionProveedorApi api;
  final DevArticle? initialArticle;
  final double? initialQuantity;
  @override
  State<_AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<_AddItemDialog> {
  final _search = TextEditingController(),
      _depa = TextEditingController(),
      _subd = TextEditingController(),
      _clas = TextEditingController(),
      _scla = TextEditingController(),
      _scla2 = TextEditingController(),
      _sph = TextEditingController(),
      _cyl = TextEditingController(),
      _adic = TextEditingController(),
      _quantity = TextEditingController(text: '1'),
      _lot = TextEditingController(),
      _expiration = TextEditingController();
  List<DevArticle> _articles = const [];
  DevArticle? _article;
  int? _reason;
  bool _loading = false;
  bool _searched = false;
  String _searchBy = 'ART';
  Uint8List? _evidenceBytes;
  String? _evidenceName;
  String? _evidenceMimeType;

  @override
  void initState() {
    super.initState();
    _article = widget.initialArticle;
    if (widget.initialQuantity != null && widget.initialQuantity! > 0) {
      _quantity.text = widget.initialQuantity!.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _depa.dispose();
    _subd.dispose();
    _clas.dispose();
    _scla.dispose();
    _scla2.dispose();
    _sph.dispose();
    _cyl.dispose();
    _adic.dispose();
    _quantity.dispose();
    _lot.dispose();
    _expiration.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(_article == null ? 'Agregar artículo' : 'Capturar artículo'),
    insetPadding: const EdgeInsets.all(16),
    content: SizedBox(
      width: _article == null ? 720 : 520,
      height: _article == null ? 540 : 300,
      child: _article == null ? _searchPanel() : _capturePanel(),
    ),
    actions: [
      if (_article != null)
        TextButton.icon(
          onPressed: () => setState(() {
            _article = null;
            _clearCapture();
          }),
          icon: const Icon(Icons.arrow_back),
          label: const Text('Regresar'),
        ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(_article == null ? 'Cerrar' : 'Cancelar'),
      ),
      if (_article != null)
        FilledButton(
          onPressed: _canSave ? _save : null,
          child: const Text('Agregar'),
        ),
    ],
  );

  Widget _searchPanel() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Filtros de búsqueda',
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
              initialValue: widget.suc,
              decoration: const InputDecoration(
                labelText: 'SUC',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                DropdownMenuItem(value: widget.suc, child: Text(widget.suc)),
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
                DropdownMenuItem(value: 'TODO', child: Text('Todos')),
              ],
              onChanged: (value) => setState(() => _searchBy = value ?? 'ART'),
            ),
          ),
          SizedBox(
            width: 270,
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(
                labelText: 'Buscar',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (_) => _find(),
            ),
          ),
          _filterField(_depa, 'DEPA'),
          _filterField(_subd, 'SUBD'),
          _filterField(_clas, 'CLAS'),
          _filterField(_scla, 'SCLA'),
          _filterField(_scla2, 'SCLA2'),
          _filterField(_sph, 'SPH'),
          _filterField(_cyl, 'CYL'),
          _filterField(_adic, 'ADIC'),
          FilledButton.icon(
            onPressed: _loading ? null : _find,
            icon: const Icon(Icons.search),
            label: const Text('Buscar'),
          ),
          OutlinedButton.icon(
            onPressed: _loading ? null : _clearSearch,
            icon: const Icon(Icons.refresh),
            label: const Text('Limpiar'),
          ),
        ],
      ),
      const SizedBox(height: 10),
      if (_loading) const LinearProgressIndicator(minHeight: 2),
      if (_loading) const SizedBox(height: 8),
      Expanded(child: _resultsPanel()),
    ],
  );

  Widget _filterField(TextEditingController controller, String label) =>
      SizedBox(
        width: 118,
        child: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          onSubmitted: (_) => _find(),
        ),
      );

  bool get _canSave {
    final quantity = double.tryParse(
      _quantity.text.trim().replaceAll(',', '.'),
    );
    return _article != null &&
        _reason != null &&
        quantity != null &&
        quantity > 0;
  }

  Widget _resultsPanel() {
    if (!_searched) {
      return const Center(
        child: Text('Capture un criterio y presione Buscar.'),
      );
    }
    if (!_loading && _articles.isEmpty) {
      return const Center(child: Text('Sin artículos para el filtro.'));
    }
    return ListView.builder(
      itemCount: _articles.length,
      itemBuilder: (context, index) {
        final article = _articles[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          title: Text('${article.art} | ${article.description}'),
          subtitle: Text(
            'Costo \$${article.cost.toStringAsFixed(2)} · Disponible ${article.available.toStringAsFixed(2)}',
          ),
          trailing: IconButton.outlined(
            tooltip: 'Agregar artículo',
            icon: const Icon(Icons.add),
            onPressed: () => _selectArticle(article),
          ),
          onTap: () => _selectArticle(article),
        );
      },
    );
  }

  Widget _capturePanel() => DecoratedBox(
    decoration: BoxDecoration(
      border: Border.all(color: Colors.black12),
      borderRadius: BorderRadius.circular(6),
    ),
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _article == null
                ? 'Selecciona un artículo'
                : '${_article!.art} | ${_article!.description}',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          if (_article != null)
            Text('Disponible: ${_article!.available.toStringAsFixed(2)}'),
          const SizedBox(height: 12),
          TextField(
            controller: _quantity,
            enabled: _article != null,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Cantidad *',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _reason,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Motivo *',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: widget.reasons
                .map(
                  (reason) => DropdownMenuItem(
                    value: reason.id,
                    child: Text(
                      '${reason.code} · ${reason.label}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: _article == null
                ? null
                : (value) => setState(() => _reason = value),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _lot,
            enabled: _article != null,
            decoration: const InputDecoration(
              labelText: 'Lote de caducidad (si aplica)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _expiration,
            enabled: _article != null,
            readOnly: true,
            decoration: InputDecoration(
              labelText: 'Caducidad (si aplica)',
              hintText: 'AAAA-MM-DD',
              border: const OutlineInputBorder(),
              isDense: true,
              suffixIcon: IconButton(
                tooltip: 'Seleccionar caducidad',
                onPressed: _article == null ? null : _pickExpiration,
                icon: const Icon(Icons.calendar_month),
              ),
            ),
            onTap: _article == null ? null : _pickExpiration,
          ),
        ],
      ),
    ),
  );
  Future<void> _find() async {
    setState(() {
      _loading = true;
      _searched = true;
    });
    try {
      final result = await widget.api.articles(
        suc: widget.suc,
        provider: widget.provider,
        search: _search.text.trim(),
        searchBy: _searchBy,
        depa: _depa.text,
        subd: _subd.text,
        clas: _clas.text,
        scla: _scla.text,
        scla2: _scla2.text,
        sph: _sph.text,
        cyl: _cyl.text,
        adic: _adic.text,
      );
      if (mounted) {
        setState(() {
          _articles = result.items;
          if (!_articles.any((article) => article.art == _article?.art)) {
            _article = null;
          }
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudieron cargar artículos: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _clearSearch() {
    setState(() {
      _search.clear();
      _depa.clear();
      _subd.clear();
      _clas.clear();
      _scla.clear();
      _scla2.clear();
      _sph.clear();
      _cyl.clear();
      _adic.clear();
      _searchBy = 'ART';
      _articles = const [];
      _searched = false;
      _article = null;
      _clearCapture();
    });
  }

  void _selectArticle(DevArticle article) {
    setState(() {
      if (_article?.art != article.art) _clearCapture();
      _article = article;
    });
  }

  void _clearCapture() {
    _quantity.text = '1';
    _lot.clear();
    _expiration.clear();
    _reason = null;
    _evidenceBytes = null;
    _evidenceName = null;
    _evidenceMimeType = null;
  }

  Future<void> _pickExpiration() async {
    final now = DateTime.now();
    final initial = DateTime.tryParse(_expiration.text.trim()) ?? now;
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 20, 12, 31),
    );
    if (selected == null || !mounted) return;
    final month = selected.month.toString().padLeft(2, '0');
    final day = selected.day.toString().padLeft(2, '0');
    setState(() => _expiration.text = '${selected.year}-$month-$day');
  }

  void _save() {
    final quantity = double.tryParse(
      _quantity.text.trim().replaceAll(',', '.'),
    );
    if (_article == null ||
        _reason == null ||
        quantity == null ||
        quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona artículo, cantidad y motivo.'),
        ),
      );
      return;
    }
    if (quantity > _article!.available) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La cantidad supera la disponibilidad.')),
      );
      return;
    }
    Navigator.pop(
      context,
      _ItemData(
        _article!,
        quantity,
        _reason!,
        _lot.text.trim(),
        _expiration.text.trim(),
        _evidenceBytes == null ||
                _evidenceName == null ||
                _evidenceMimeType == null
            ? null
            : _ItemEvidence(
                name: _evidenceName!,
                mimeType: _evidenceMimeType!,
                content:
                    'data:${_evidenceMimeType!};base64,${base64Encode(_evidenceBytes!)}',
              ),
      ),
    );
  }
}
