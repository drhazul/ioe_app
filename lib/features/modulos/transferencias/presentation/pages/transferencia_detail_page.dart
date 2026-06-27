import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:excel/excel.dart' as xls;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../../../core/auth/auth_controller.dart';
import '../../../../../core/storage.dart';
import '../../domain/transferencia_models.dart';
import '../../providers/transferencia_provider.dart';

class TransferenciaDetailPage extends ConsumerWidget {
  const TransferenciaDetailPage({
    super.key,
    required this.doc,
    this.reportMode = false,
  });

  final String doc;
  final bool reportMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncDoc = reportMode
        ? ref.watch(transferenciaReporteDetalleProvider(doc))
        : ref.watch(transferenciaDetalleProvider(doc));
    return Scaffold(
      appBar: AppBar(
        title: Text('Transferencia $doc'),
        actions: [
          IconButton(
            tooltip: 'Refrescar',
            icon: const Icon(Icons.refresh),
            onPressed: () => reportMode
                ? ref.invalidate(transferenciaReporteDetalleProvider(doc))
                : ref.invalidate(transferenciaDetalleProvider(doc)),
          ),
        ],
      ),
      body: asyncDoc.when(
        data: (item) =>
            _TransferenciaDetailBody(item: item, reportMode: reportMode),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(_friendlyError(error))),
      ),
    );
  }
}

class _TransferenciaDetailBody extends ConsumerStatefulWidget {
  const _TransferenciaDetailBody({
    required this.item,
    required this.reportMode,
  });

  final TransferenciaDocModel item;
  final bool reportMode;

  @override
  ConsumerState<_TransferenciaDetailBody> createState() =>
      _TransferenciaDetailBodyState();
}

class _TransferenciaDetailBodyState
    extends ConsumerState<_TransferenciaDetailBody> {
  final _reviewSearchCtrl = TextEditingController();
  final _reviewDepaCtrl = TextEditingController();
  final _reviewSubdCtrl = TextEditingController();
  final _reviewClasCtrl = TextEditingController();
  final _reviewSclaCtrl = TextEditingController();
  final _reviewScla2Ctrl = TextEditingController();
  final _reviewSphCtrl = TextEditingController();
  final _reviewCylCtrl = TextEditingController();
  final _reviewAdicCtrl = TextEditingController();
  String _reviewHierarchyKey = '';
  String _reviewSuc = '';
  String _reviewSearchBy = 'ART';
  String? _markedSeenKey;

  @override
  void dispose() {
    _reviewSearchCtrl.dispose();
    _reviewDepaCtrl.dispose();
    _reviewSubdCtrl.dispose();
    _reviewClasCtrl.dispose();
    _reviewSclaCtrl.dispose();
    _reviewScla2Ctrl.dispose();
    _reviewSphCtrl.dispose();
    _reviewCylCtrl.dispose();
    _reviewAdicCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final item = widget.item;
    final isJefeInventarios = auth.roleId == 2;
    final isSucursalSolicita =
        (auth.suc ?? '').trim().toUpperCase() ==
        item.sucEnt.trim().toUpperCase();
    final isSucursalSurtidora =
        (auth.suc ?? '').trim().toUpperCase() ==
        item.sucSal.trim().toUpperCase();
    if (!widget.reportMode) _markDetailNotificationSeen(auth, item);
    final showReviewFilters =
        !widget.reportMode && item.estatus == 'REVISANDO' && isSucursalSolicita;
    final isReportIncidenceWorkflow =
        widget.reportMode &&
        (item.hasIncidencia ||
            item.estatus == 'INCIDENCIA' ||
            item.estatus == 'REVISANDO');
    final reportIncidenceRows = item.detalle
        .where(
          (row) => (row.estatusR ?? '').trim().toUpperCase() == 'INCIDENCIA',
        )
        .toList();
    final showReportActionBar = isReportIncidenceWorkflow;
    final detailRows =
        widget.reportMode &&
            item.hasIncidencia &&
            reportIncidenceRows.isNotEmpty
        ? reportIncidenceRows
        : showReviewFilters
        ? _filteredReviewRows(item.detalle)
        : item.detalle;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _HeaderCard(item: item),
        const SizedBox(height: 10),
        if (showReviewFilters) ...[
          _ReviewFilterPanel(
            suc: _reviewSuc,
            searchBy: _reviewSearchBy,
            searchCtrl: _reviewSearchCtrl,
            depaCtrl: _reviewDepaCtrl,
            subdCtrl: _reviewSubdCtrl,
            clasCtrl: _reviewClasCtrl,
            sclaCtrl: _reviewSclaCtrl,
            scla2Ctrl: _reviewScla2Ctrl,
            sphCtrl: _reviewSphCtrl,
            cylCtrl: _reviewCylCtrl,
            adicCtrl: _reviewAdicCtrl,
            hierarchyValue: _reviewHierarchyKey,
            hierarchyOptions: _reviewHierarchyOptions(item.detalle),
            sucursales: _reviewSucursales(item),
            onSucChanged: (value) => setState(() => _reviewSuc = value ?? ''),
            onSearchByChanged: (value) =>
                setState(() => _reviewSearchBy = value ?? 'ART'),
            onHierarchyChanged: (value) => _applyReviewHierarchy(value),
            onFilterChanged: () => setState(() => _reviewHierarchyKey = ''),
            onApply: () => setState(() {}),
            onClear: _clearReviewFilters,
          ),
          const SizedBox(height: 10),
        ],
        if (!widget.reportMode) ...[
          _ActionBar(
            item: item,
            isSucursalSolicita: isSucursalSolicita,
            isSucursalSurtidora: isSucursalSurtidora,
            isJefeInventarios: isJefeInventarios,
            reportMode: widget.reportMode,
          ),
          if (showReviewFilters) ...[
            const SizedBox(height: 4),
            _FilteredArticleCount(count: detailRows.length),
          ],
          const SizedBox(height: 10),
        ] else if (widget.reportMode) ...[
          showReportActionBar
              ? _ActionBar(
                  item: item,
                  isSucursalSolicita: isSucursalSolicita,
                  isSucursalSurtidora: isSucursalSurtidora,
                  isJefeInventarios: isJefeInventarios,
                  reportMode: widget.reportMode,
                )
              : _DocumentEvidenceButton(item: item),
          const SizedBox(height: 10),
        ],
        _DetalleTable(
          item: item,
          rows: detailRows,
          isSucursalSolicita: isSucursalSolicita,
          isJefeInventarios: isJefeInventarios,
          isSucursalSurtidora: isSucursalSurtidora,
          reportMode: widget.reportMode,
        ),
      ],
    );
  }

  List<String> _reviewSucursales(TransferenciaDocModel item) {
    final values = {
      item.sucSal.trim().toUpperCase(),
      item.sucEnt.trim().toUpperCase(),
      ...item.detalle.map((row) => (row.suc ?? '').trim().toUpperCase()),
    }..removeWhere((value) => value.isEmpty);
    return values.toList()..sort();
  }

  List<_HierarchyFilterOption> _reviewHierarchyOptions(
    List<TransferenciaDetalleModel> rows,
  ) {
    final grouped = <String, _HierarchyFilterOption>{};
    for (final row in rows) {
      final option = _HierarchyFilterOption.fromRow(row);
      if (option == null) continue;
      final current = grouped[option.key];
      grouped[option.key] = current == null ? option : current.merge(row);
    }
    final options = grouped.values.toList()
      ..sort((a, b) => a.label.compareTo(b.label));
    return options;
  }

  void _applyReviewHierarchy(String? value) {
    if (value == null) return;
    final options = _reviewHierarchyOptions(widget.item.detalle);
    _HierarchyFilterOption? option;
    for (final item in options) {
      if (item.key == value) {
        option = item;
        break;
      }
    }
    setState(() {
      _reviewHierarchyKey = value;
      if (value.isEmpty || option == null) {
        _reviewDepaCtrl.clear();
        _reviewSubdCtrl.clear();
        _reviewClasCtrl.clear();
        _reviewSclaCtrl.clear();
        _reviewScla2Ctrl.clear();
        _reviewSphCtrl.clear();
        _reviewCylCtrl.clear();
        _reviewAdicCtrl.clear();
        return;
      }
      _reviewDepaCtrl.text = option.depa;
      _reviewSubdCtrl.text = option.subd;
      _reviewClasCtrl.text = option.clas;
      _reviewSclaCtrl.text = option.scla;
      _reviewScla2Ctrl.text = option.scla2;
      _reviewSphCtrl.clear();
      _reviewCylCtrl.clear();
      _reviewAdicCtrl.clear();
      if (!option.hasHierarchy) {
        _reviewSearchBy = 'ART';
        _reviewSearchCtrl.text = option.art;
      } else {
        _reviewSearchCtrl.clear();
      }
    });
  }

  List<TransferenciaDetalleModel> _filteredReviewRows(
    List<TransferenciaDetalleModel> rows,
  ) {
    return rows.where((row) {
      if (_reviewSuc.trim().isNotEmpty &&
          (row.suc ?? '').trim().toUpperCase() !=
              _reviewSuc.trim().toUpperCase()) {
        return false;
      }
      final search = _reviewSearchCtrl.text.trim().toUpperCase();
      if (search.isNotEmpty) {
        final value = switch (_reviewSearchBy) {
          'DES' => row.des,
          'UPC' => row.upc ?? '',
          _ => row.art,
        };
        if (!value.toUpperCase().contains(search)) return false;
      }
      return _matchesFilter(row.depa, _reviewDepaCtrl.text) &&
          _matchesFilter(row.subd, _reviewSubdCtrl.text) &&
          _matchesFilter(row.clas, _reviewClasCtrl.text) &&
          _matchesFilter(row.scla, _reviewSclaCtrl.text) &&
          _matchesFilter(row.scla2, _reviewScla2Ctrl.text) &&
          _matchesFilter(row.sph, _reviewSphCtrl.text) &&
          _matchesFilter(row.cyl, _reviewCylCtrl.text) &&
          _matchesFilter(row.adic, _reviewAdicCtrl.text);
    }).toList();
  }

  bool _matchesFilter(String? value, String filter) {
    final text = filter.trim().toUpperCase();
    if (text.isEmpty) return true;
    return (value ?? '').trim().toUpperCase().contains(text);
  }

  void _clearReviewFilters() {
    setState(() {
      _reviewSuc = '';
      _reviewSearchBy = 'ART';
      _reviewSearchCtrl.clear();
      _reviewDepaCtrl.clear();
      _reviewSubdCtrl.clear();
      _reviewClasCtrl.clear();
      _reviewSclaCtrl.clear();
      _reviewScla2Ctrl.clear();
      _reviewSphCtrl.clear();
      _reviewCylCtrl.clear();
      _reviewAdicCtrl.clear();
      _reviewHierarchyKey = '';
    });
  }

  void _markDetailNotificationSeen(dynamic auth, TransferenciaDocModel item) {
    final scope = _notificationSeenScope(auth);
    final key = _notificationKey(item);
    final markKey = '$scope::$key';
    if (_markedSeenKey == markKey) return;
    _markedSeenKey = markKey;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final storage = ref.read(storageProvider);
      final keys = await storage.getTransferSeenNotificationKeys(scope);
      if (keys.contains(key)) return;
      await storage.saveTransferSeenNotificationKeys(scope, {...keys, key});
      ref.invalidate(transferenciaNotificacionesProvider);
    });
  }

  String _notificationSeenScope(dynamic auth) {
    final user = auth.userId ?? auth.username ?? 'anon';
    final role = auth.roleId ?? 'sin_rol';
    final suc = (auth.suc ?? 'sin_suc').toString().trim().toUpperCase();
    return '$user|$role|$suc';
  }

  String _notificationKey(TransferenciaDocModel item) {
    return [
      item.doc.trim(),
      item.estatus.trim().toUpperCase(),
      item.sucSal.trim().toUpperCase(),
      item.sucEnt.trim().toUpperCase(),
    ].join('|');
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

class _HierarchyFilterOption {
  const _HierarchyFilterOption({
    required this.key,
    required this.art,
    required this.description,
    required this.depa,
    required this.subd,
    required this.clas,
    required this.scla,
    required this.scla2,
    required this.jerarquiaNombre,
    required this.sph,
    required this.cyl,
    required this.adic,
    required this.solicitada,
    required this.recibida,
  });

  final String key;
  final String art;
  final String description;
  final String depa;
  final String subd;
  final String clas;
  final String scla;
  final String scla2;
  final String jerarquiaNombre;
  final String sph;
  final String cyl;
  final String adic;
  final double solicitada;
  final double recibida;

  bool get hasHierarchy =>
      depa.isNotEmpty ||
      subd.isNotEmpty ||
      clas.isNotEmpty ||
      scla.isNotEmpty ||
      scla2.isNotEmpty;

  String get label {
    if (jerarquiaNombre.isNotEmpty) return jerarquiaNombre;
    final parts = <String>[
      if (scla2.isNotEmpty) 'SCLA2 $scla2',
      if (scla.isNotEmpty) 'SCLA $scla',
      if (clas.isNotEmpty) 'CLAS $clas',
      if (subd.isNotEmpty) 'SUBD $subd',
      if (depa.isNotEmpty) 'DEPA $depa',
    ];
    return parts.isEmpty ? art : parts.first;
  }

  static _HierarchyFilterOption? fromRow(TransferenciaDetalleModel row) {
    final depa = _cleanHierarchyValue(row.depa);
    final subd = _cleanHierarchyValue(row.subd);
    final clas = _cleanHierarchyValue(row.clas);
    final scla = _cleanHierarchyValue(row.scla);
    final scla2 = _cleanHierarchyValue(row.scla2);
    final sph = _cleanHierarchyValue(row.sph);
    final cyl = _cleanHierarchyValue(row.cyl);
    final adic = _cleanHierarchyValue(row.adic);
    final hasHierarchy = [
      depa,
      subd,
      clas,
      scla,
      scla2,
    ].any((value) => value.isNotEmpty);
    final art = row.art.trim();
    if (!hasHierarchy && art.isEmpty) return null;
    final key = hasHierarchy
        ? [depa, subd, clas, scla, scla2].join('|')
        : 'ART|$art';
    return _HierarchyFilterOption(
      key: key,
      art: art,
      description: row.des.trim(),
      depa: depa,
      subd: subd,
      clas: clas,
      scla: scla,
      scla2: scla2,
      jerarquiaNombre: (row.jerarquiaNombre ?? '').trim(),
      sph: sph,
      cyl: cyl,
      adic: adic,
      solicitada: row.ctd,
      recibida: row.ctdR,
    );
  }

  _HierarchyFilterOption merge(TransferenciaDetalleModel row) {
    return _HierarchyFilterOption(
      key: key,
      art: art,
      description: description,
      depa: depa,
      subd: subd,
      clas: clas,
      scla: scla,
      scla2: scla2,
      jerarquiaNombre: jerarquiaNombre,
      sph: sph,
      cyl: cyl,
      adic: adic,
      solicitada: solicitada + row.ctd,
      recibida: recibida + row.ctdR,
    );
  }

  static String _cleanHierarchyValue(String? value) {
    final text = (value ?? '').trim();
    if (text == '0' || text == '0.0' || text == '0.00') return '';
    return text;
  }
}

class _ReviewFilterPanel extends StatelessWidget {
  const _ReviewFilterPanel({
    required this.suc,
    required this.searchBy,
    required this.searchCtrl,
    required this.depaCtrl,
    required this.subdCtrl,
    required this.clasCtrl,
    required this.sclaCtrl,
    required this.scla2Ctrl,
    required this.sphCtrl,
    required this.cylCtrl,
    required this.adicCtrl,
    required this.hierarchyValue,
    required this.hierarchyOptions,
    required this.sucursales,
    required this.onSucChanged,
    required this.onSearchByChanged,
    required this.onHierarchyChanged,
    required this.onFilterChanged,
    required this.onApply,
    required this.onClear,
  });

  final String suc;
  final String searchBy;
  final TextEditingController searchCtrl;
  final TextEditingController depaCtrl;
  final TextEditingController subdCtrl;
  final TextEditingController clasCtrl;
  final TextEditingController sclaCtrl;
  final TextEditingController scla2Ctrl;
  final TextEditingController sphCtrl;
  final TextEditingController cylCtrl;
  final TextEditingController adicCtrl;
  final String hierarchyValue;
  final List<_HierarchyFilterOption> hierarchyOptions;
  final List<String> sucursales;
  final ValueChanged<String?> onSucChanged;
  final ValueChanged<String?> onSearchByChanged;
  final ValueChanged<String?> onHierarchyChanged;
  final VoidCallback onFilterChanged;
  final VoidCallback onApply;
  final VoidCallback onClear;

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
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String>(
                initialValue: suc,
                isDense: true,
                decoration: const InputDecoration(
                  labelText: 'SUC',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem(value: '', child: Text('Todas')),
                  ...sucursales.map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text(value)),
                  ),
                ],
                onChanged: onSucChanged,
              ),
            ),
            SizedBox(
              width: 150,
              child: DropdownButtonFormField<String>(
                initialValue: searchBy,
                isDense: true,
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
                onChanged: onSearchByChanged,
              ),
            ),
            SizedBox(
              width: 260,
              child: TextField(
                controller: searchCtrl,
                decoration: const InputDecoration(
                  labelText: 'Buscar',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: (_) => onApply(),
              ),
            ),
            _hierarchyDropdown(),
            _smallFilter('DEPA', depaCtrl),
            _smallFilter('SUBD', subdCtrl),
            _smallFilter('CLAS', clasCtrl),
            _smallFilter('SCLA', sclaCtrl),
            _smallFilter('SCLA2', scla2Ctrl),
            _smallFilter('SPH', sphCtrl),
            _smallFilter('CYL', cylCtrl),
            _smallFilter('ADIC', adicCtrl),
            FilledButton.icon(
              onPressed: onApply,
              icon: const Icon(Icons.search),
              label: const Text('Buscar'),
            ),
            OutlinedButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.refresh),
              label: const Text('Limpiar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hierarchyDropdown() {
    return SizedBox(
      width: 220,
      child: DropdownButtonFormField<String>(
        key: ValueKey('hierarchy-$hierarchyValue-${hierarchyOptions.length}'),
        initialValue: hierarchyValue,
        isDense: true,
        isExpanded: true,
        menuMaxHeight: 360,
        decoration: const InputDecoration(
          labelText: 'Jerarquia',
          border: OutlineInputBorder(),
          isDense: true,
        ),
        items: [
          const DropdownMenuItem(value: '', child: Text('Todas')),
          if (hierarchyOptions.isEmpty)
            const DropdownMenuItem(
              value: '__empty_hierarchy__',
              enabled: false,
              child: Text('Sin datos de jerarquia'),
            )
          else
            ...hierarchyOptions.map(
              (option) => DropdownMenuItem(
                value: option.key,
                child: Text(option.label, overflow: TextOverflow.ellipsis),
              ),
            ),
        ],
        onChanged: onHierarchyChanged,
      ),
    );
  }

  Widget _smallFilter(String label, TextEditingController controller) {
    return SizedBox(
      width: 110,
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        onSubmitted: (_) => onApply(),
        onChanged: (_) => onFilterChanged(),
      ),
    );
  }
}

class _ActionBar extends ConsumerWidget {
  const _ActionBar({
    required this.item,
    required this.isSucursalSolicita,
    required this.isSucursalSurtidora,
    required this.isJefeInventarios,
    this.reportMode = false,
  });

  final TransferenciaDocModel item;
  final bool isSucursalSolicita;
  final bool isSucursalSurtidora;
  final bool isJefeInventarios;
  final bool reportMode;

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
            onPressed: () => _confirmSendAuthorization(context, ref),
          ),
        if (estatus == 'BORRADOR')
          OutlinedButton.icon(
            icon: const Icon(Icons.upload_file),
            label: const Text('Importar archivo'),
            onPressed: () => _importArticuloFile(context, ref),
          ),
        if (estatus == 'PENDIENTE')
          FilledButton.icon(
            icon: const Icon(Icons.check_circle),
            label: const Text('Liberar'),
            onPressed: () => _confirmLiberar(context, ref),
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
        if (!isJefeInventarios &&
            !isSucursalSolicita &&
            isSucursalSurtidora &&
            estatus == 'PREPARACION')
          OutlinedButton.icon(
            icon: const Icon(Icons.photo_camera_outlined),
            label: Text(item.evidencias > 0 ? 'Cambiar foto' : 'Adjuntar foto'),
            onPressed: () => _addDocumentEvidence(context, ref),
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
            onPressed: () => _confirmContabilizar(context, ref),
          ),
        if (estatus == 'REVISANDO' || estatus == 'INCIDENCIA')
          OutlinedButton.icon(
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('Ver evidencia'),
            onPressed: () => _showDocumentEvidence(context),
          ),
        if (!isJefeInventarios && !isSucursalSolicita && estatus != 'LIBERADA')
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

  Future<void> _importArticuloFile(BuildContext context, WidgetRef ref) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx', 'xls', 'csv'],
      allowMultiple: false,
      withData: false,
      withReadStream: true,
    );
    final file = picked?.files.single;
    if (file == null) return;

    List<_ImportArticuloRow> rows;
    try {
      final bytes = await _readPickedFileBytes(file);
      rows = _parseArticuloFile(file.name, bytes);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(e))));
      return;
    }

    if (rows.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El archivo no contiene ART y DIFE validos.'),
        ),
      );
      return;
    }

    try {
      const batchSize = 750;
      var imported = 0;
      for (var start = 0; start < rows.length; start += batchSize) {
        final end = (start + batchSize).clamp(0, rows.length).toInt();
        final batch = rows.sublist(start, end);
        await ref
            .read(transferenciaApiProvider)
            .addDetalleBulk(
              item.doc,
              items: batch
                  .map(
                    (row) => {
                      'art': row.art,
                      'des': row.descripcion,
                      'ctd': row.cantidad,
                    },
                  )
                  .toList(growable: false),
            );
        imported += batch.length;
      }
      ref.invalidate(transferenciaDetalleProvider(item.doc));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Archivo importado. $imported articulos.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(e))));
    }
  }

  Future<void> _reject(BuildContext context, WidgetRef ref) async {
    final obs = await _askText(context, 'Rechazar solicitud', 'Motivo');
    if (obs == null) return;
    if (!context.mounted) return;
    await _runAction(context, ref, 'rechazar', data: {'txt': obs});
  }

  Future<void> _confirmLiberar(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Liberar transferencia'),
        content: Text(
          'Desea liberar la transferencia ${item.doc}? '
          'Se usara la cantidad liberada capturada; si no se capturo, se usara la cantidad solicitada. '
          'El proceso puede reducir el stock de ${item.sucSal}, incluso si queda por debajo del stock minimo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Liberar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await _runAction(context, ref, 'liberar', closeOnSuccess: true);
  }

  Future<void> _sendTransit(BuildContext context, WidgetRef ref) async {
    if (item.evidencias <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Debe adjuntar una evidencia del documento antes de enviar a transito.',
          ),
        ),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enviar a transito'),
        content: Text(
          'Desea enviar la transferencia ${item.doc} a transito? '
          'Se afectara la salida de inventario de ${item.sucSal}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _TransitDialog(),
    );
    if (data == null) return;
    if (!context.mounted) return;
    await _runAction(
      context,
      ref,
      'transito',
      data: data,
      closeOnSuccess: true,
    );
  }

  Future<void> _confirmSendAuthorization(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enviar a autorizacion'),
        content: Text(
          'Desea enviar la transferencia ${item.doc} a autorizacion? '
          'Se notificara al jefe de inventarios para su revision.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await _runAction(context, ref, 'enviar', closeOnSuccess: true);
  }

  Future<void> _addDocumentEvidence(BuildContext context, WidgetRef ref) async {
    final picked = await _pickEvidenceFromDialog(context);
    if (picked == null) return;

    try {
      final imgEvi = _buildEvidenceDataUrl(picked);
      await ref
          .read(transferenciaApiProvider)
          .addDocumentoEvidencia(
            item.doc,
            imgEvi: imgEvi,
            tipo: picked.mimeType,
          );
      ref.invalidate(transferenciaDetalleProvider(item.doc));
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Evidencia agregada.')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(e))));
    }
  }

  void _showDocumentEvidence(BuildContext context) {
    final url = (item.evidenciaUrl ?? '').trim();
    if (item.evidencias <= 0 || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este documento no tiene evidencia.')),
      );
      return;
    }
    _openEvidencePreview(context, url, mimeType: item.evidenciaMime);
  }

  Future<void> _confirmContabilizar(BuildContext context, WidgetRef ref) async {
    final incompleteRows = item.detalle.where((row) {
      final status = (row.estatusR ?? '').trim().toUpperCase();
      return !row.ctdRCapturada ||
          (status != 'CONTABILIZADO' && status != 'INCIDENCIA');
    }).toList();
    if (incompleteRows.isNotEmpty) {
      final arts = incompleteRows.map((row) => row.art).take(5).join(', ');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Todos los articulos deben tener cantidad recibida y estatus. Faltan: $arts',
          ),
        ),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Contabilizar transferencia'),
        content: Text(
          'Desea contabilizar la transferencia ${item.doc}? '
          'Se registraran los movimientos en MB51: salida de existencia de '
          '${item.sucSal} y entrada para ${item.sucEnt}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Contabilizar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await _runAction(context, ref, 'contabilizar', closeOnSuccess: true);
  }

  Future<void> _runAction(
    BuildContext context,
    WidgetRef ref,
    String action, {
    Map<String, dynamic>? data,
    bool closeOnSuccess = false,
  }) async {
    try {
      await ref
          .read(transferenciaApiProvider)
          .action(item.doc, action, data: data);
      ref.invalidate(transferenciasProvider);
      ref.invalidate(transferenciaReportesProvider);
      ref.invalidate(transferenciaDetalleProvider(item.doc));
      ref.invalidate(transferenciaReporteDetalleProvider(item.doc));
      ref.invalidate(transferenciaNotificacionesProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Acción completada.')));
      if (closeOnSuccess) {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(
            reportMode
                ? '/modulos/transferencias-reportes'
                : '/modulos/transferencias',
          );
        }
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(e))));
    }
  }
}

class _DocumentEvidenceButton extends StatelessWidget {
  const _DocumentEvidenceButton({required this.item});

  final TransferenciaDocModel item;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        icon: const Icon(Icons.photo_camera_outlined),
        label: const Text('Ver evidencia'),
        onPressed: () {
          final url = (item.evidenciaUrl ?? '').trim();
          if (item.evidencias <= 0 || url.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Este documento no tiene evidencia.'),
              ),
            );
            return;
          }
          _openEvidencePreview(context, url, mimeType: item.evidenciaMime);
        },
      ),
    );
  }
}

class _DetalleTable extends ConsumerWidget {
  const _DetalleTable({
    required this.item,
    required this.rows,
    required this.isSucursalSolicita,
    required this.isJefeInventarios,
    required this.isSucursalSurtidora,
    required this.reportMode,
  });

  final TransferenciaDocModel item;
  final List<TransferenciaDetalleModel> rows;
  final bool isSucursalSolicita;
  final bool isJefeInventarios;
  final bool isSucursalSurtidora;
  final bool reportMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (rows.isEmpty) {
      return const Card(
        elevation: 0,
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('Sin artículos capturados.'),
        ),
      );
    }
    final showSurtidorLayout =
        !reportMode &&
        isSucursalSurtidora &&
        !isJefeInventarios &&
        !isSucursalSolicita &&
        ['LIBERADA', 'PREPARACION'].contains(item.estatus);
    final showReceptionReviewLayout =
        !reportMode && isSucursalSolicita && item.estatus == 'REVISANDO';
    final showReportLayout = reportMode;
    final showInventoryChiefLayout =
        !showReportLayout &&
        !showReceptionReviewLayout &&
        !showSurtidorLayout &&
        isJefeInventarios;
    final canManageReportIncidence =
        showReportLayout &&
        (item.hasIncidencia ||
            item.estatus == 'INCIDENCIA' ||
            item.estatus == 'REVISANDO');
    return LayoutBuilder(
      builder: (context, constraints) {
        const reviewFixedWidth = 1046.0;
        final availableWidth = constraints.maxWidth;
        final reviewDescWidth =
            showReceptionReviewLayout &&
                availableWidth.isFinite &&
                availableWidth > reviewFixedWidth
            ? (availableWidth - reviewFixedWidth).clamp(190.0, 260.0).toDouble()
            : 220.0;
        const reportDescWidth = 190.0;
        const reportQtyWidth = 64.0;
        const reportMoneyWidth = 70.0;
        const reportDiffMoneyWidth = 82.0;
        const reportStatusWidth = 116.0;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing:
                showReceptionReviewLayout ||
                    showInventoryChiefLayout ||
                    showSurtidorLayout ||
                    showReportLayout
                ? 4
                : null,
            horizontalMargin:
                showReceptionReviewLayout ||
                    showInventoryChiefLayout ||
                    showSurtidorLayout ||
                    showReportLayout
                ? 8
                : null,
            headingRowHeight:
                showReceptionReviewLayout ||
                    showInventoryChiefLayout ||
                    showSurtidorLayout ||
                    showReportLayout
                ? 58
                : null,
            dataRowMinHeight:
                showReceptionReviewLayout ||
                    showInventoryChiefLayout ||
                    showSurtidorLayout ||
                    showReportLayout
                ? 50
                : null,
            dataRowMaxHeight:
                showReceptionReviewLayout ||
                    showInventoryChiefLayout ||
                    showSurtidorLayout ||
                    showReportLayout
                ? 50
                : null,
            columns: [
              showReportLayout
                  ? _col('Articulo', width: 72)
                  : showReceptionReviewLayout
                  ? _col('Articulo', width: 72)
                  : _col('Articulo', width: showInventoryChiefLayout ? 70 : 72),
              showReportLayout
                  ? _col(
                      'Descripcion',
                      width: reportDescWidth,
                      textAlign: TextAlign.left,
                    )
                  : showReceptionReviewLayout
                  ? _col(
                      'Descripcion',
                      width: reviewDescWidth,
                      textAlign: TextAlign.left,
                    )
                  : _col(
                      'Descripcion',
                      width: showInventoryChiefLayout ? 210 : 250,
                      textAlign: TextAlign.left,
                    ),
              if (showReportLayout) ...[
                _col(
                  'Cantidad\nSolicitada',
                  width: reportQtyWidth,
                  numeric: true,
                ),
                _col(
                  'Total\nSolicitado',
                  width: reportMoneyWidth,
                  numeric: true,
                ),
                _col(
                  'Cantidad\nLiberada',
                  width: reportQtyWidth,
                  numeric: true,
                ),
                _col('Total\nLiberado', width: reportMoneyWidth, numeric: true),
                _col(
                  'Cantidad\nRecibida',
                  width: reportQtyWidth,
                  numeric: true,
                ),
                _col('Total\nRecibido', width: reportMoneyWidth, numeric: true),
                _col(
                  'Diferencia\nRecibida',
                  width: reportQtyWidth,
                  numeric: true,
                ),
                _col(
                  'Diferencia Total\nRecibida',
                  width: reportDiffMoneyWidth,
                  numeric: true,
                ),
                _col('Estatus', width: reportStatusWidth),
              ] else if (showReceptionReviewLayout) ...[
                _col('Cantidad\nSolicitada', width: 74, numeric: true),
                _col('Total\nSolicitado', width: 78, numeric: true),
                _col('Cantidad\nLiberada', width: 74, numeric: true),
                _col('Total\nLiberado', width: 78, numeric: true),
                _col('Cantidad\nRecibida', width: 74, numeric: true),
                _col('Total\nRecibido', width: 78, numeric: true),
                _col('Diferencia\nRecibida', width: 74, numeric: true),
                _col('Diferencia Total\nRecibida', width: 88, numeric: true),
                _col('Estatus', width: 104),
              ] else if (showSurtidorLayout) ...[
                _col('Cantidad\nLiberada', width: 82, numeric: true),
                _col('Total\nLiberada', width: 82, numeric: true),
              ] else ...[
                if (isJefeInventarios) ...[
                  _col('Exis O', width: 66, numeric: true),
                  _col('Exis D', width: 66, numeric: true),
                ],
                _col(
                  'Cantidad\nSolicitada',
                  width: showInventoryChiefLayout ? 76 : 84,
                  numeric: true,
                ),
              ],
              if (!showReportLayout &&
                  !showReceptionReviewLayout &&
                  !showSurtidorLayout &&
                  isJefeInventarios) ...[
                _col('Cantidad\nLiberada', width: 76, numeric: true),
                _col('Total\nLiberada', width: 76, numeric: true),
              ] else if (!showReportLayout &&
                  !showReceptionReviewLayout &&
                  !showSurtidorLayout &&
                  !isSucursalSolicita) ...const [
                DataColumn(label: Text('Liberada')),
                DataColumn(label: Text('Recibida')),
                DataColumn(label: Text('Dif')),
              ],
              if (!showReportLayout &&
                  !showReceptionReviewLayout &&
                  !showSurtidorLayout)
                _col(
                  'Total',
                  width: showInventoryChiefLayout ? 76 : 86,
                  numeric: true,
                ),
              if (canManageReportIncidence)
                _col('Acciones', width: 96)
              else if (!showReportLayout && !showSurtidorLayout)
                showReceptionReviewLayout
                    ? _col('Acciones', width: 96)
                    : _col(
                        'Acciones',
                        width: showInventoryChiefLayout ? 74 : 96,
                      ),
            ],
            rows: rows.map((row) {
              final hasReceipt = row.ctdRCapturada;
              return DataRow(
                cells: [
                  DataCell(
                    showReportLayout
                        ? _cell(row.art, width: 72)
                        : showReceptionReviewLayout
                        ? _cell(row.art, width: 72)
                        : _cell(
                            row.art,
                            width: showInventoryChiefLayout ? 70 : 72,
                          ),
                  ),
                  DataCell(
                    SizedBox(
                      width: showReportLayout
                          ? reportDescWidth
                          : showReceptionReviewLayout
                          ? reviewDescWidth
                          : showInventoryChiefLayout
                          ? 210
                          : 250,
                      child: Text(
                        row.des,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  if (showReportLayout) ...[
                    DataCell(
                      _cell(row.ctd.toStringAsFixed(2), width: reportQtyWidth),
                    ),
                    DataCell(
                      _cell(_money(row.ctotal), width: reportMoneyWidth),
                    ),
                    DataCell(
                      _cell(
                        row.ctdLib.toStringAsFixed(2),
                        width: reportQtyWidth,
                      ),
                    ),
                    DataCell(
                      _cell(_money(row.ctolib), width: reportMoneyWidth),
                    ),
                    DataCell(
                      _cell(row.ctdR.toStringAsFixed(2), width: reportQtyWidth),
                    ),
                    DataCell(_cell(_money(row.ctoR), width: reportMoneyWidth)),
                    DataCell(
                      _cell(row.difR.toStringAsFixed(2), width: reportQtyWidth),
                    ),
                    DataCell(
                      _cell(_money(row.difctoR), width: reportDiffMoneyWidth),
                    ),
                    DataCell(
                      _cell(
                        _detailStatusLabel(row.estatusR),
                        width: reportStatusWidth,
                      ),
                    ),
                  ] else if (showReceptionReviewLayout) ...[
                    DataCell(_cell(row.ctd.toStringAsFixed(2), width: 74)),
                    DataCell(_cell(_money(row.ctotal), width: 78)),
                    DataCell(_cell(row.ctdLib.toStringAsFixed(2), width: 74)),
                    DataCell(_cell(_money(row.ctolib), width: 78)),
                    DataCell(
                      _cell(
                        hasReceipt ? row.ctdR.toStringAsFixed(2) : '',
                        width: 74,
                      ),
                    ),
                    DataCell(
                      _cell(hasReceipt ? _money(row.ctoR) : '', width: 78),
                    ),
                    DataCell(
                      _cell(
                        hasReceipt ? row.difR.toStringAsFixed(2) : '',
                        width: 74,
                      ),
                    ),
                    DataCell(
                      _cell(hasReceipt ? _money(row.difctoR) : '', width: 88),
                    ),
                    DataCell(
                      _cell(_detailStatusLabel(row.estatusR), width: 104),
                    ),
                  ] else if (showSurtidorLayout) ...[
                    DataCell(_cell(row.ctdLib.toStringAsFixed(2), width: 82)),
                    DataCell(_cell(_money(row.ctolib), width: 82)),
                  ] else ...[
                    if (isJefeInventarios) ...[
                      DataCell(_cell(row.exisS.toStringAsFixed(2), width: 66)),
                      DataCell(_cell(row.exisD.toStringAsFixed(2), width: 66)),
                    ],
                    DataCell(
                      _cell(
                        row.ctd.toStringAsFixed(2),
                        width: showInventoryChiefLayout ? 76 : 84,
                      ),
                    ),
                  ],
                  if (!showReportLayout &&
                      !showReceptionReviewLayout &&
                      !showSurtidorLayout &&
                      isJefeInventarios) ...[
                    DataCell(_cell(row.ctdLib.toStringAsFixed(2), width: 76)),
                    DataCell(_cell(_money(row.ctolib), width: 76)),
                  ] else if (!showReportLayout &&
                      !showReceptionReviewLayout &&
                      !showSurtidorLayout &&
                      !isSucursalSolicita) ...[
                    DataCell(Text(row.ctdLib.toStringAsFixed(2))),
                    DataCell(Text(row.ctdR.toStringAsFixed(2))),
                    DataCell(Text(row.difR.toStringAsFixed(2))),
                  ],
                  if (!showReportLayout &&
                      !showReceptionReviewLayout &&
                      !showSurtidorLayout)
                    DataCell(
                      _cell(
                        _money(row.ctotal),
                        width: showInventoryChiefLayout ? 76 : 86,
                      ),
                    ),
                  if (canManageReportIncidence)
                    DataCell(_actionsCell(context, ref, row))
                  else if (!showReportLayout && !showSurtidorLayout)
                    DataCell(_actionsCell(context, ref, row)),
                ],
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _actionsCell(
    BuildContext context,
    WidgetRef ref,
    TransferenciaDetalleModel row,
  ) {
    if (reportMode &&
        (item.hasIncidencia ||
            item.estatus == 'INCIDENCIA' ||
            item.estatus == 'REVISANDO')) {
      return _actionsBox([
        _actionButton(
          tooltip: 'Modificar incidencia',
          icon: Icons.edit_note,
          onPressed: () => _editReceipt(context, ref, row),
        ),
      ]);
    }

    if (isSucursalSurtidora &&
        !isJefeInventarios &&
        !isSucursalSolicita &&
        ['LIBERADA', 'PREPARACION'].contains(item.estatus)) {
      return _actionsBox(const []);
    }

    if (isJefeInventarios) {
      final actions = <Widget>[
        if (item.estatus == 'PENDIENTE')
          _actionButton(
            tooltip: 'Cantidad liberada',
            icon: Icons.rule,
            onPressed: () => _editNumber(
              context,
              ref,
              row,
              'ctdLib',
              row.ctdLib == 0 ? row.ctd : row.ctdLib,
            ),
          ),
      ];
      return _actionsBox(actions);
    }

    if (isSucursalSolicita && item.estatus == 'REVISANDO') {
      return _actionsBox([
        _actionButton(
          tooltip: 'Recepcion de articulo',
          icon: Icons.edit_note,
          onPressed: () => _editReceipt(context, ref, row),
        ),
      ]);
    }

    if (item.estatus == 'TRANSITO') {
      return _actionsBox(const []);
    }

    final actions = <Widget>[
      if (isSucursalSolicita && item.estatus == 'BORRADOR')
        _actionButton(
          tooltip: 'Cantidad solicitada',
          icon: Icons.edit_outlined,
          onPressed: () => _editNumber(context, ref, row, 'ctd', row.ctd),
        ),
      if (item.estatus == 'PENDIENTE')
        _actionButton(
          tooltip: 'Cantidad liberada',
          icon: Icons.rule,
          onPressed: () => _editNumber(
            context,
            ref,
            row,
            'ctdLib',
            row.ctdLib == 0 ? row.ctd : row.ctdLib,
          ),
        ),
      if (item.estatus == 'BORRADOR')
        _actionButton(
          tooltip: 'Eliminar',
          icon: Icons.delete_outline,
          onPressed: () => _delete(context, ref, row),
        ),
    ];

    return _actionsBox(actions);
  }

  Widget _actionsBox(List<Widget> actions) {
    return SizedBox(
      width: 96,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.max,
        children: actions,
      ),
    );
  }

  DataColumn _col(
    String label, {
    required double width,
    bool numeric = false,
    TextAlign textAlign = TextAlign.center,
  }) {
    return DataColumn(
      numeric: numeric,
      label: SizedBox(
        width: width,
        child: Text(
          label,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          textAlign: textAlign,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _cell(
    String value, {
    required double width,
    TextAlign textAlign = TextAlign.center,
  }) {
    return SizedBox(
      width: width,
      child: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: textAlign,
      ),
    );
  }

  String _detailStatusLabel(String? value) {
    final status = (value ?? '').trim().toUpperCase();
    return status.isEmpty ? '-' : status;
  }

  Widget _actionButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return SizedBox.square(
      dimension: 36,
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(icon, size: 18),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
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
            ctd: field == 'ctd' ? value : null,
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

  Future<void> _editReceipt(
    BuildContext context,
    WidgetRef ref,
    TransferenciaDetalleModel row,
  ) async {
    final data = await showDialog<_ReceiptEditResult>(
      context: context,
      builder: (_) => _ReceiptEditDialog(row: row),
    );
    if (data == null) return;
    try {
      await ref
          .read(transferenciaApiProvider)
          .updateDetalle(
            item.doc,
            row.idpd,
            ctdR: data.ctdR,
            estatusR: data.estatusR,
          );
      ref.invalidate(transferenciaDetalleProvider(item.doc));
      ref.invalidate(transferenciaReporteDetalleProvider(item.doc));
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

void _openEvidencePreview(
  BuildContext context,
  String url, {
  String? mimeType,
}) {
  final dataBytes = url.startsWith('data:image/')
      ? _decodeEvidenceDataUrl(url)
      : null;
  final lowerUrl = url.toLowerCase();
  final canShowNetwork =
      url.isNotEmpty &&
      ((mimeType ?? '').toLowerCase().startsWith('image/') ||
          lowerUrl.contains('.jpg') ||
          lowerUrl.contains('.jpeg') ||
          lowerUrl.contains('.png') ||
          lowerUrl.contains('.webp') ||
          lowerUrl.contains('.gif'));
  if (dataBytes == null && !canShowNetwork) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('La evidencia no es una imagen valida.')),
    );
    return;
  }

  showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              automaticallyImplyLeading: false,
              title: const Text('Evidencia'),
              actions: [
                IconButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Expanded(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4,
                child: dataBytes != null
                    ? Image.memory(
                        dataBytes,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Center(
                          child: Text('No se pudo cargar la imagen'),
                        ),
                      )
                    : Image.network(
                        url,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Center(
                          child: Text('No se pudo cargar la imagen'),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Uint8List? _decodeEvidenceDataUrl(String dataUrl) {
  final comma = dataUrl.indexOf(',');
  if (comma <= 0 || comma >= dataUrl.length - 1) return null;
  try {
    return base64Decode(dataUrl.substring(comma + 1));
  } catch (_) {
    return null;
  }
}

Future<_PickedEvidence?> _pickEvidenceFromDialog(BuildContext context) async {
  final source = await showDialog<_EvidenceInputSource>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Agregar evidencia'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined),
            title: const Text('Tomar foto'),
            onTap: () => Navigator.of(ctx).pop(_EvidenceInputSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Elegir de galeria'),
            onTap: () => Navigator.of(ctx).pop(_EvidenceInputSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.attach_file),
            title: const Text('Elegir archivo de imagen'),
            onTap: () => Navigator.of(ctx).pop(_EvidenceInputSource.file),
          ),
        ],
      ),
    ),
  );
  if (source == null) return null;
  return _pickEvidence(source);
}

Future<_PickedEvidence?> _pickEvidence(_EvidenceInputSource source) async {
  final imagePicker = ImagePicker();
  switch (source) {
    case _EvidenceInputSource.camera:
      final file = await imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (file == null) return null;
      return _prepareEvidence(
        bytes: await file.readAsBytes(),
        suggestedName: file.name,
        extensionHint: _extractExtension(file.name),
      );
    case _EvidenceInputSource.gallery:
      final file = await imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (file == null) return null;
      return _prepareEvidence(
        bytes: await file.readAsBytes(),
        suggestedName: file.name,
        extensionHint: _extractExtension(file.name),
      );
    case _EvidenceInputSource.file:
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
        allowMultiple: false,
      );
      if (picked == null || picked.files.isEmpty) return null;
      final file = picked.files.first;
      final data = file.bytes;
      if (data == null || data.isEmpty) return null;
      return _prepareEvidence(
        bytes: data,
        suggestedName: file.name,
        extensionHint: _extractExtension(file.name),
      );
  }
}

Future<_PickedEvidence> _prepareEvidence({
  required Uint8List bytes,
  required String suggestedName,
  String? extensionHint,
}) async {
  if (bytes.length <= 500) {
    throw Exception('La imagen debe ser mayor a 500 bytes.');
  }
  final compressed = await _compressImage(
    bytes,
    (extensionHint ?? '').toLowerCase(),
  );
  return _PickedEvidence(
    bytes: compressed.bytes,
    mimeType: compressed.mimeType,
    name: suggestedName.trim().isEmpty ? 'evidencia.jpg' : suggestedName,
  );
}

Future<_CompressedEvidence> _compressImage(
  Uint8List bytes,
  String extension,
) async {
  final originalMime = _mimeForExtension(extension);
  var bestBytes = bytes;
  var bestMime = originalMime;
  const maxBytes = 500 * 1024;
  const widths = [1280, 1024, 800, 640];
  const qualities = [78, 68, 58, 48];

  for (final width in widths) {
    for (final quality in qualities) {
      try {
        final compressed = await FlutterImageCompress.compressWithList(
          bytes,
          minWidth: width,
          minHeight: width,
          quality: quality,
          format: CompressFormat.jpeg,
        );
        if (compressed.isEmpty) continue;
        if (compressed.length < bestBytes.length ||
            bestBytes.length > maxBytes) {
          bestBytes = compressed;
          bestMime = 'image/jpeg';
        }
        if (bestBytes.length <= maxBytes) {
          return _CompressedEvidence(bestBytes, bestMime);
        }
      } catch (_) {}
    }
  }

  if (bestBytes.length <= maxBytes) {
    return _CompressedEvidence(bestBytes, bestMime);
  }
  throw Exception(
    'La imagen supera 500 KB aun despues de comprimirla. Intenta con otra foto mas ligera.',
  );
}

String _mimeForExtension(String extension) {
  if (extension == 'png') return 'image/png';
  if (extension == 'webp') return 'image/webp';
  if (extension == 'gif') return 'image/gif';
  return 'image/jpeg';
}

String _extractExtension(String name) {
  final index = name.lastIndexOf('.');
  if (index <= 0 || index >= name.length - 1) return '';
  return name.substring(index + 1);
}

String _buildEvidenceDataUrl(_PickedEvidence evidence) {
  return 'data:${evidence.mimeType};base64,${base64Encode(evidence.bytes)}';
}

enum _EvidenceInputSource { camera, gallery, file }

class _PickedEvidence {
  const _PickedEvidence({
    required this.bytes,
    required this.mimeType,
    required this.name,
  });

  final Uint8List bytes;
  final String mimeType;
  final String name;
}

class _CompressedEvidence {
  const _CompressedEvidence(this.bytes, this.mimeType);

  final Uint8List bytes;
  final String mimeType;
}

class _ReceiptEditResult {
  const _ReceiptEditResult({required this.ctdR, required this.estatusR});

  final double ctdR;
  final String estatusR;
}

class _ReceiptEditDialog extends StatefulWidget {
  const _ReceiptEditDialog({required this.row});

  final TransferenciaDetalleModel row;

  @override
  State<_ReceiptEditDialog> createState() => _ReceiptEditDialogState();
}

class _ReceiptEditDialogState extends State<_ReceiptEditDialog> {
  late final TextEditingController _ctdCtrl;
  late String _estatus;

  @override
  void initState() {
    super.initState();
    _ctdCtrl = TextEditingController(
      text: widget.row.ctdR == 0
          ? widget.row.ctdLib.toStringAsFixed(2)
          : widget.row.ctdR.toStringAsFixed(2),
    );
    final current = (widget.row.estatusR ?? '').trim().toUpperCase();
    _estatus = current == 'INCIDENCIA' ? 'INCIDENCIA' : 'CONTABILIZADO';
  }

  @override
  void dispose() {
    _ctdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctdR = double.tryParse(_ctdCtrl.text.replaceAll(',', '.')) ?? 0;
    final totalRecibido = ctdR * widget.row.ctop;
    final dif = widget.row.ctdLib - ctdR;
    final difTotal = dif * widget.row.ctop;
    return AlertDialog(
      title: Text('Recepcion ${widget.row.art}'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _ctdCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Cantidad recibida',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _estatus,
              decoration: const InputDecoration(
                labelText: 'Estatus',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'CONTABILIZADO',
                  child: Text('CONTABILIZADO'),
                ),
                DropdownMenuItem(
                  value: 'INCIDENCIA',
                  child: Text('INCIDENCIA'),
                ),
              ],
              onChanged: (value) =>
                  setState(() => _estatus = value ?? 'CONTABILIZADO'),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 14,
                runSpacing: 6,
                children: [
                  Text('Total recibido: ${_money(totalRecibido)}'),
                  Text('Dif: ${dif.toStringAsFixed(2)}'),
                  Text('Dif total: ${_money(difTotal)}'),
                ],
              ),
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
          onPressed: () {
            final value = double.tryParse(_ctdCtrl.text.replaceAll(',', '.'));
            if (value == null || value < 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cantidad invalida.')),
              );
              return;
            }
            Navigator.of(
              context,
            ).pop(_ReceiptEditResult(ctdR: value, estatusR: _estatus));
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _FilteredArticleCount extends StatelessWidget {
  const _FilteredArticleCount({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = count == 1
        ? '1 articulo filtrado'
        : '$count articulos filtrados';
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ImportArticuloRow {
  const _ImportArticuloRow({
    required this.art,
    required this.descripcion,
    required this.cantidad,
  });

  final String art;
  final String descripcion;
  final double cantidad;
}

Future<Uint8List> _readPickedFileBytes(PlatformFile file) async {
  final stream = file.readStream;
  if (stream != null) {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  }
  final bytes = file.bytes;
  if (bytes != null) return bytes;
  throw const FormatException('No fue posible leer el archivo seleccionado.');
}

List<_ImportArticuloRow> _parseArticuloFile(String name, Uint8List bytes) {
  final lowerName = name.toLowerCase();
  final rows = lowerName.endsWith('.csv')
      ? _parseCsvArticuloRows(bytes)
      : _parseExcelArticuloRows(bytes);
  if (rows.isEmpty) return const [];
  return _rowsToImportArticulos(rows);
}

List<List<String>> _parseExcelArticuloRows(Uint8List bytes) {
  final book = xls.Excel.decodeBytes(bytes);
  if (book.tables.isEmpty) return const [];
  final sheet = book.tables.values.first;
  return sheet.rows
      .map((row) => row.map(_excelCellText).toList(growable: false))
      .toList(growable: false);
}

String _excelCellText(xls.Data? cell) {
  final value = cell?.value;
  if (value == null) return '';
  if (value is xls.TextCellValue) return value.value.toString().trim();
  if (value is xls.IntCellValue) return value.value.toString();
  if (value is xls.DoubleCellValue) return value.value.toString();
  if (value is xls.BoolCellValue) return value.value ? 'true' : 'false';
  return value.toString().trim();
}

List<List<String>> _parseCsvArticuloRows(Uint8List bytes) {
  final content = utf8.decode(bytes, allowMalformed: true);
  return const LineSplitter()
      .convert(content)
      .where((line) => line.trim().isNotEmpty)
      .map(_parseCsvLine)
      .toList(growable: false);
}

List<String> _parseCsvLine(String line) {
  final values = <String>[];
  final buffer = StringBuffer();
  var quoted = false;
  for (var i = 0; i < line.length; i++) {
    final char = line[i];
    if (char == '"') {
      if (quoted && i + 1 < line.length && line[i + 1] == '"') {
        buffer.write('"');
        i++;
      } else {
        quoted = !quoted;
      }
    } else if (char == ',' && !quoted) {
      values.add(buffer.toString().trim());
      buffer.clear();
    } else {
      buffer.write(char);
    }
  }
  values.add(buffer.toString().trim());
  return values;
}

List<_ImportArticuloRow> _rowsToImportArticulos(List<List<String>> rows) {
  final headerIndex = rows.indexWhere((row) {
    final headers = row.map(_normalizeImportHeader).toList();
    return _findImportColumn(headers, const ['art', 'articulo']) >= 0 &&
        _findImportColumn(headers, const ['dife', 'cantidadsolicitada']) >= 0;
  });
  if (headerIndex < 0) {
    throw const FormatException(
      'No se encontraron encabezados ART y DIFE/Cantidad Solicitada.',
    );
  }
  final headers = rows[headerIndex].map(_normalizeImportHeader).toList();
  final artIndex = _findImportColumn(headers, const ['art', 'articulo']);
  final descIndex = _findImportColumn(headers, const [
    'descripcion',
    'descripcionarticulo',
    'desc',
    'descort',
  ]);
  final cantidadIndex = _findImportColumn(headers, const [
    'dife',
    'cantidadsolicitada',
    'cantidad',
    'solicitada',
    'ctdped',
    'sumadectdped',
  ]);

  final imported = <_ImportArticuloRow>[];
  for (final row in rows.skip(headerIndex + 1)) {
    final art = _rowValue(row, artIndex).trim();
    final cantidad = _parseImportNumber(_rowValue(row, cantidadIndex));
    if (art.isEmpty || cantidad == null || cantidad <= 0) continue;
    imported.add(
      _ImportArticuloRow(
        art: art,
        descripcion: descIndex >= 0 ? _rowValue(row, descIndex).trim() : '',
        cantidad: cantidad,
      ),
    );
  }
  return imported;
}

int _findImportColumn(List<String> headers, List<String> aliases) {
  for (var i = 0; i < headers.length; i++) {
    if (aliases.contains(headers[i])) return i;
  }
  return -1;
}

String _rowValue(List<String> row, int index) {
  if (index < 0 || index >= row.length) return '';
  return row[index];
}

String _normalizeImportHeader(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ñ', 'n')
      .replaceAll(RegExp(r'[^a-z0-9]'), '');
}

double? _parseImportNumber(String raw) {
  var text = raw.trim();
  if (text.isEmpty) return null;
  text = text.replaceAll(RegExp(r'[\$ ]'), '');
  if (text.contains(',') && text.contains('.')) {
    text = text.replaceAll(',', '');
  } else {
    text = text.replaceAll(',', '.');
  }
  return double.tryParse(text);
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
  final totalSolicitado = item.detalle.fold<double>(
    0,
    (sum, row) => sum + row.ctotal,
  );
  final totalLiberado = item.detalle.fold<double>(
    0,
    (sum, row) => sum + row.ctolib,
  );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.letter,
      margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 32),
      header: (_) => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 10),
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            bottom: pw.BorderSide(color: PdfColors.grey500, width: 0.6),
          ),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Transferencia entre sucursales',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.teal800,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  'Documento ${item.doc}',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Pagina ${context.pageNumber} de ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
        ),
      ),
      build: (_) => [
        pw.SizedBox(height: 14),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400, width: 0.6),
            borderRadius: pw.BorderRadius.circular(5),
          ),
          child: pw.Column(
            children: [
              pw.Row(
                children: [
                  _pdfInfo('Origen', item.sucSal),
                  _pdfInfo('Destino', item.sucEnt),
                  _pdfInfo('Fecha', _fmtDate(item.fcnd)),
                  _pdfInfo('Prioridad', item.prio),
                ],
              ),
              pw.SizedBox(height: 7),
              pw.Row(
                children: [
                  _pdfInfo('Motivo', item.mtv),
                  _pdfInfo('Cantidad', item.ctd.toStringAsFixed(2)),
                  _pdfInfo('Total solicitado', _money(item.imp)),
                  _pdfInfo('Total liberado', _money(totalLiberado)),
                ],
              ),
              if (item.paqueteria != null) ...[
                pw.SizedBox(height: 7),
                pw.Row(
                  children: [
                    _pdfInfo('Paqueteria', item.paqueteria!.emp ?? '-'),
                    _pdfInfo('Guia', item.paqueteria!.numGuia ?? '-'),
                    _pdfInfo('Responsable', item.paqueteria!.resp ?? '-'),
                    _pdfInfo('Observaciones', item.paqueteria!.txt ?? '-'),
                  ],
                ),
              ],
            ],
          ),
        ),
        pw.SizedBox(height: 16),
        pw.TableHelper.fromTextArray(
          border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.5),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.teal800),
          headers: const [
            'Articulo',
            'Descripcion',
            'Cantidad solicitada',
            'Total',
            'Cantidad liberada',
            'Total liberada',
          ],
          data: item.detalle
              .map(
                (x) => [
                  x.art,
                  x.des,
                  x.ctd.toStringAsFixed(2),
                  _money(x.ctotal),
                  x.ctdLib.toStringAsFixed(2),
                  _money(x.ctolib),
                ],
              )
              .toList(),
          columnWidths: {
            0: const pw.FixedColumnWidth(62),
            1: const pw.FlexColumnWidth(2.4),
            2: const pw.FixedColumnWidth(74),
            3: const pw.FixedColumnWidth(62),
            4: const pw.FixedColumnWidth(74),
            5: const pw.FixedColumnWidth(70),
          },
          cellAlignment: pw.Alignment.centerLeft,
          cellAlignments: {
            2: pw.Alignment.centerRight,
            3: pw.Alignment.centerRight,
            4: pw.Alignment.centerRight,
            5: pw.Alignment.centerRight,
          },
          cellPadding: const pw.EdgeInsets.symmetric(
            horizontal: 5,
            vertical: 6,
          ),
          cellStyle: const pw.TextStyle(fontSize: 8.5),
          headerStyle: pw.TextStyle(
            fontSize: 8.5,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
          ),
          headerPadding: const pw.EdgeInsets.symmetric(
            horizontal: 5,
            vertical: 6,
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Container(
            width: 210,
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
              borderRadius: pw.BorderRadius.circular(5),
            ),
            child: pw.Column(
              children: [
                _pdfTotalRow('Total solicitado', _money(totalSolicitado)),
                pw.SizedBox(height: 5),
                _pdfTotalRow('Total liberado', _money(totalLiberado)),
              ],
            ),
          ),
        ),
      ],
    ),
  );
  await Printing.layoutPdf(onLayout: (_) async => doc.save());
}

pw.Expanded _pdfInfo(String label, String value) {
  return pw.Expanded(
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          value.trim().isEmpty ? '-' : value,
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        ),
      ],
    ),
  );
}

pw.Widget _pdfTotalRow(String label, String value) {
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
      pw.Text(
        value,
        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
      ),
    ],
  );
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
