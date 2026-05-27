import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';

import '../../domain/merma_models.dart';
import '../../providers/merma_catalogs_provider.dart';
import '../../providers/merma_provider.dart';
import '../dialogs/merma_add_item_dialog.dart';
import '../dialogs/merma_anular_dialog.dart';
import '../dialogs/merma_etiqueta_dialog.dart';
import '../dialogs/merma_revision_dialog.dart';
import '../widgets/merma_item_table.dart';
import '../widgets/merma_status_chip.dart';
import '../widgets/merma_totals_card.dart';

class MermaDetailPage extends ConsumerStatefulWidget {
  const MermaDetailPage({
    super.key,
    required this.docmer,
    this.createdFromNew = false,
  });

  final String docmer;
  final bool createdFromNew;

  @override
  ConsumerState<MermaDetailPage> createState() => _MermaDetailPageState();
}

class _MermaDetailPageState extends ConsumerState<MermaDetailPage> {
  bool _processingExit = false;

  @override
  Widget build(BuildContext context) {
    final asyncDoc = ref.watch(mermaDetalleProvider(widget.docmer));
    final roleName = ref.watch(mermaCurrentRoleNameProvider).valueOrNull ?? '';
    final asyncMotivos = ref.watch(mermaMotivosProvider);
    final asyncAreas = ref.watch(mermaAreasProvider);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final allow = await _handleExit();
        if (!mounted || !allow) return;
        Navigator.of(this.context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Merma ${widget.docmer}'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              final allow = await _handleExit();
              if (!mounted || !allow) return;
              Navigator.of(this.context).pop();
            },
          ),
          actions: [
            IconButton(
              tooltip: 'Refrescar',
              onPressed: () =>
                  ref.invalidate(mermaDetalleProvider(widget.docmer)),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: asyncDoc.when(
          data: (doc) => ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  Text(
                    'DOCMER: ${doc.docmer}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('Sucursal: ${doc.suc}'),
                  Text('Usuario: ${doc.user}'),
                  MermaStatusChip(estatus: doc.estatus),
                ],
              ),
              const SizedBox(height: 10),
              MermaTotalsCard(narts: doc.narts, total: doc.total),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (!_isOnlyPrintMode(doc, roleName) && _editable(doc))
                    FilledButton.icon(
                      onPressed: () =>
                          _addItem(context, ref, doc, asyncMotivos, asyncAreas),
                      icon: const Icon(Icons.add),
                      label: const Text('Agregar artículo'),
                    ),
                  if (!_isOnlyPrintMode(doc, roleName) && _editable(doc))
                    OutlinedButton.icon(
                      onPressed: () =>
                          _solicitarAutorizacion(context, ref, doc),
                      icon: const Icon(Icons.send),
                      label: const Text('Solicitar autorización'),
                    ),
                  if (!_isOnlyPrintMode(doc, roleName) &&
                      doc.idEstatus == 2 &&
                      !_isEncargadoMermaRole(roleName))
                    OutlinedButton.icon(
                      onPressed: () => _revisar(context, ref, doc),
                      icon: const Icon(Icons.rule),
                      label: const Text('Revisar'),
                    ),
                  if (!_isOnlyPrintMode(doc, roleName) &&
                      doc.idEstatus == 2 &&
                      !_isEncargadoMermaRole(roleName))
                    FilledButton.icon(
                      onPressed: () => _contabilizar(context, ref, doc),
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Contabilizar'),
                    ),
                  if (!_isOnlyPrintMode(doc, roleName) &&
                      !_hideExtraButtonsForEncargado(roleName) &&
                      (doc.idEstatus == 1 ||
                          doc.idEstatus == 2 ||
                          doc.idEstatus == 4))
                    if (!widget.createdFromNew)
                    OutlinedButton.icon(
                      onPressed: () => _anular(context, ref, doc),
                      icon: const Icon(Icons.cancel),
                      label: const Text('Anular'),
                    ),
                  if (!_isOnlyPrintMode(doc, roleName) &&
                      !_hideExtraButtonsForEncargado(roleName) &&
                      !widget.createdFromNew)
                    OutlinedButton.icon(
                      onPressed: () =>
                          context.go('/modulos/merma/consulta/${doc.docmer}'),
                      icon: const Icon(Icons.visibility),
                      label: const Text('Ver en consulta'),
                    ),
                  if (_isOnlyPrintMode(doc, roleName))
                    FilledButton.icon(
                      onPressed: () => _openEtiqueta(context, ref, doc.docmer),
                      icon: const Icon(Icons.print),
                      label: const Text('Imprimir etiqueta'),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              MermaItemTable(
                items: doc.detalle,
                documentArea: doc.areaM,
                readOnly: _isOnlyPrintMode(doc, roleName) ? true : !_editable(doc),
                showEvidenceColumn: true,
                onEdit: _isOnlyPrintMode(doc, roleName)
                    ? null
                    : _editable(doc)
                    ? (item) => _editItem(
                        context,
                        ref,
                        doc,
                        item,
                        asyncMotivos,
                        asyncAreas,
                      )
                    : null,
                onDelete: _isOnlyPrintMode(doc, roleName)
                    ? null
                    : _editable(doc)
                    ? (item) => _removeItem(context, ref, doc, item)
                    : null,
              ),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Error: $error')),
        ),
      ),
    );
  }

  bool _editable(MermaDocModel doc) => doc.idEstatus == 1 || doc.idEstatus == 4;

  bool _hideExtraButtonsForEncargado(String roleName) {
    return _isEncargadoMermaRole(roleName);
  }

  bool _isEncargadoMermaRole(String roleName) {
    final role = roleName.trim().toUpperCase();
    return role.contains('ENCARGADO DE SUCURSAL') ||
        role.contains('ENCARGADO DE MERMA') ||
        (role.contains('ENCARGADO') && role.contains('MERMA'));
  }

  bool _isOnlyPrintMode(MermaDocModel doc, String roleName) {
    return doc.idEstatus == 5 && _canOnlyPrintEtiqueta(roleName);
  }

  bool _canOnlyPrintEtiqueta(String roleName) {
    final role = roleName.trim().toUpperCase();
    return role.contains('ENCARGADO DE SUCURSAL') ||
        role.contains('ADMINISTRADOR') ||
        role == 'ADMIN';
  }

  Future<bool> _handleExit() async {
    if (_processingExit) return false;
    if (!widget.createdFromNew) return true;

    MermaDocModel? doc;
    try {
      doc = await ref.read(mermaDetalleProvider(widget.docmer).future);
    } catch (_) {
      return true;
    }
    if (doc == null) return true;

    final empty = doc.detalle.isEmpty || doc.narts <= 0;
    if (!empty) return true;
    if (!mounted) return false;

    final decision = await showDialog<_ExitDecision>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Documento nuevo sin artículos'),
        content: const Text(
          'Este documento está vacío. ¿Deseas guardar el documento o cancelar su creación?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(_ExitDecision.stay),
            child: const Text('Seguir editando'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(_ExitDecision.save),
            child: const Text('Guardar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(ctx).pop(_ExitDecision.cancelCreation),
            child: const Text('Cancelar creación'),
          ),
        ],
      ),
    );

    if (decision == _ExitDecision.save) {
      return true;
    }
    if (decision != _ExitDecision.cancelCreation) {
      return false;
    }

    _processingExit = true;
    try {
      await ref.read(mermaApiProvider).deleteMerma(widget.docmer);
      // Invalida todas las combinaciones del family para evitar listas stale
      // cuando gestion esta usando otra llave (sucursal/filtros).
      ref.invalidate(mermaGestionCabecerasProvider);
      ref.invalidate(mermaDetalleProvider(widget.docmer));
      if (!mounted) return false;
      context.go('/modulos/merma/gestion');
      return false;
    } catch (e) {
      _processingExit = false;
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo cancelar el documento: ${_friendlyError(e)}',
          ),
        ),
      );
      return false;
    }
  }

  Future<void> _addItem(
    BuildContext context,
    WidgetRef ref,
    MermaDocModel doc,
    AsyncValue<List<MermaCatalogOptionModel>> asyncMotivos,
    AsyncValue<List<MermaCatalogOptionModel>> asyncAreas,
  ) async {
    final motivos =
        asyncMotivos.valueOrNull ?? const <MermaCatalogOptionModel>[];
    final areas = asyncAreas.valueOrNull ?? const <MermaCatalogOptionModel>[];
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => MermaAddItemDialog(
        motivos: motivos,
        areas: areas,
        suc: doc.suc,
        initialAreaM: '',
      ),
    );
    if (payload == null) return;
    try {
      final api = ref.read(mermaApiProvider);
      await api.addDetalle(
        doc.docmer,
        art: (payload['art'] ?? '').toString(),
        ctd: (payload['ctd'] as num).toDouble(),
        motM: (payload['motM'] as num).toInt(),
        areaM: (payload['areaM'] ?? '').toString(),
        respM: (payload['respM'] ?? '').toString(),
        obsM: (payload['obsM'] ?? '').toString(),
        eviM: (payload['eviM'] ?? '').toString(),
      );
      ref.invalidate(mermaDetalleProvider(doc.docmer));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(e))));
    }
  }

  Future<void> _editItem(
    BuildContext context,
    WidgetRef ref,
    MermaDocModel doc,
    MermaDetalleModel item,
    AsyncValue<List<MermaCatalogOptionModel>> asyncMotivos,
    AsyncValue<List<MermaCatalogOptionModel>> asyncAreas,
  ) async {
    final motivos =
        asyncMotivos.valueOrNull ?? const <MermaCatalogOptionModel>[];
    final areas = asyncAreas.valueOrNull ?? const <MermaCatalogOptionModel>[];
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => MermaAddItemDialog(
        motivos: motivos,
        areas: areas,
        suc: doc.suc,
        initialArt: item.art,
        initialCtd: item.ctd,
        initialMotM: item.motM,
        initialAreaM: item.areaM,
        initialRespM: item.respM,
        initialObsM: item.obsM,
        initialHasEvidence: item.evidencias > 0,
      ),
    );
    if (payload == null) return;
    try {
      final api = ref.read(mermaApiProvider);
      await api.updateDetalle(
        doc.docmer,
        item.idpd,
        ctd: (payload['ctd'] as num).toDouble(),
        motM: (payload['motM'] as num).toInt(),
        areaM: (payload['areaM'] ?? '').toString(),
        respM: (payload['respM'] ?? '').toString(),
        obsM: (payload['obsM'] ?? '').toString(),
        eviM: (payload['eviM'] ?? '').toString(),
      );
      ref.invalidate(mermaDetalleProvider(doc.docmer));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(e))));
    }
  }

  Future<void> _removeItem(
    BuildContext context,
    WidgetRef ref,
    MermaDocModel doc,
    MermaDetalleModel item,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar artículo'),
        content: Text('Se eliminará ${item.art} del documento ${doc.docmer}.'),
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
    if (ok != true) return;
    try {
      await ref.read(mermaApiProvider).removeDetalle(doc.docmer, item.idpd);
      ref.invalidate(mermaDetalleProvider(doc.docmer));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(e))));
    }
  }

  Future<void> _solicitarAutorizacion(
    BuildContext context,
    WidgetRef ref,
    MermaDocModel doc,
  ) async {
    try {
      await ref.read(mermaApiProvider).solicitarAutorizacion(doc.docmer);
      ref.invalidate(mermaDetalleProvider(doc.docmer));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(e))));
    }
  }

  Future<void> _revisar(
    BuildContext context,
    WidgetRef ref,
    MermaDocModel doc,
  ) async {
    final obs = await showDialog<String>(
      context: context,
      builder: (_) => const MermaRevisionDialog(),
    );
    if (obs == null) return;
    try {
      await ref.read(mermaApiProvider).revisar(doc.docmer, obs);
      ref.invalidate(mermaDetalleProvider(doc.docmer));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(e))));
    }
  }

  Future<void> _contabilizar(
    BuildContext context,
    WidgetRef ref,
    MermaDocModel doc,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar contabilización'),
        content: Text(
          'Se contabilizará el documento ${doc.docmer}. ¿Deseas continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final api = ref.read(mermaApiProvider);
      await api.contabilizar(doc.docmer);
      ref.invalidate(mermaDetalleProvider(doc.docmer));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(e))));
    }
  }

  Future<void> _anular(
    BuildContext context,
    WidgetRef ref,
    MermaDocModel doc,
  ) async {
    final obs = await showDialog<String>(
      context: context,
      builder: (_) => const MermaAnularDialog(),
    );
    if (obs == null) return;
    try {
      await ref.read(mermaApiProvider).anular(doc.docmer, obs);
      ref.invalidate(mermaDetalleProvider(doc.docmer));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(e))));
    }
  }

  Future<void> _openEtiqueta(
    BuildContext context,
    WidgetRef ref,
    String docmer,
  ) async {
    try {
      final data = await ref.read(mermaApiProvider).etiqueta(docmer);
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => MermaEtiquetaDialog(data: data),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(e))));
    }
  }

  String _friendlyError(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        final msg = (data['message'] ?? '').toString().trim();
        if (msg.isNotEmpty) return msg;
      }
      return error.message ?? 'No fue posible completar la accion.';
    }
    return error.toString();
  }
}

enum _ExitDecision { stay, save, cancelCreation }
