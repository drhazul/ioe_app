import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ioe_app/core/api_error.dart';
import 'inventarios_models.dart';
import 'inventarios_providers.dart';

class InventariosPage extends ConsumerWidget {
  const InventariosPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(inventariosListProvider);
    final allowedAsync = ref.watch(inventariosAllowedSucProvider);
    final selectedSuc = ref.watch(inventariosSelectedSucProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventarios (DAT_CONT_CTRL)'),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(inventariosListProvider),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refrescar',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/inventarios/new'),
        child: const Icon(Icons.add),
      ),
      body: dataAsync.when(
        data: (rows) {
          final allowed = allowedAsync.asData?.value ?? const <String>[];
          final effectiveSuc = allowed.isNotEmpty
              ? (selectedSuc != null && allowed.contains(selectedSuc) ? selectedSuc : allowed.first)
              : null;

          final list = RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(inventariosListProvider);
              await ref.read(inventariosListProvider.future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: rows.length,
              itemBuilder: (_, index) => _InventarioTile(model: rows[index]),
              separatorBuilder: (context, _) => const SizedBox(height: 8),
            ),
          );

          if (allowed.isEmpty) return list;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: DropdownButtonFormField<String>(
                  initialValue: effectiveSuc,
                  decoration: const InputDecoration(
                    labelText: 'Sucursal',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    for (final suc in allowed)
                      DropdownMenuItem<String>(
                        value: suc,
                        child: Text(suc),
                      ),
                  ],
                  onChanged: (value) {
                    ref.read(inventariosSelectedSucProvider.notifier).state = value;
                  },
                ),
              ),
              const SizedBox(height: 8),
              Expanded(child: list),
            ],
          );
        },
        error: (e, _) => Center(child: Text('Error: $e')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _InventarioTile extends ConsumerStatefulWidget {
  const _InventarioTile({required this.model});

  final DatContCtrlModel model;

  @override
  ConsumerState<_InventarioTile> createState() => _InventarioTileState();
}

class _InventarioTileState extends ConsumerState<_InventarioTile> {
  bool _uploading = false;
  bool _applying = false;

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
    final hasCont = (model.cont ?? '').trim().isNotEmpty;

    final subtitle = [
      if (model.esta != null && model.esta!.isNotEmpty) 'Estado: ${model.esta}',
      if (model.suc != null && model.suc!.isNotEmpty) 'Suc: ${model.suc}',
      if (model.tipocont != null && model.tipocont!.isNotEmpty) 'Tipo: ${model.tipocont}',
      if (model.fcnc != null) 'FCNC: ${_fmtDate(model.fcnc)}',
    ].join(' · ');

    final artaj = _fmtNumber(model.artaj);
    final artcont = _fmtNumber(model.artcont);
    final status = (model.esta ?? '').trim().toUpperCase();
    final isAdjusted = status == 'AJUSTADO' || status == 'CERRADO_AJUSTADO';

    final secondary = [
      if (model.totalItems != null) 'Items: ${model.totalItems}',
      if (model.fileName != null && model.fileName!.isNotEmpty) 'Archivo: ${model.fileName}',
      if (model.fcnaj != null) 'FCNAJ: ${_fmtDate(model.fcnaj)}',
      if (artaj != null) 'ARTAJ: $artaj',
      if (artcont != null) 'ARTCONT: $artcont',
    ].join(' · ');

    final title = (model.cont != null && model.cont!.isNotEmpty) ? 'CONT: ${model.cont}' : 'TOKEN: ${model.tokenreg}';

    final busy = _uploading || _applying;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SelectionArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: Theme.of(context).textTheme.titleMedium),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(subtitle),
                        ],
                        if (secondary.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          // Slightly muted secondary line using alpha without deprecated withOpacity.
                          Builder(builder: (context) {
                            final color = Theme.of(context).textTheme.bodySmall?.color;
                            final adjusted = color?.withValues(alpha: 0.8);
                            return Text(
                              secondary,
                              style: TextStyle(color: adjusted),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  tooltip: 'Eliminar',
                  onPressed: (busy || isAdjusted) ? null : () => _confirmDelete(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: (!hasCont || busy || isAdjusted) ? null : _pickAndUploadExcel,
                  icon: _uploading
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.upload_file),
                  label: Text(_uploading ? 'Subiendo...' : 'Subir Excel'),
                ),
                OutlinedButton.icon(
                  onPressed: (!hasCont || busy || isAdjusted) ? null : _applyAdjustment,
                  icon: _applying
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.check_circle_outline),
                  label: Text(_applying ? 'Aplicando...' : 'Aplicar ajuste'),
                ),
                OutlinedButton.icon(
                  onPressed: hasCont ? () => _goToDetalle(context) : null,
                  icon: const Icon(Icons.list_alt),
                  label: const Text('Ver detalle'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar registro'),
        content: Text('¿Eliminar TOKEN ${widget.model.tokenreg}?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Eliminar')),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      await ref.read(inventariosApiProvider).delete(widget.model.tokenreg);
      ref.invalidate(inventariosListProvider);
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Registro eliminado')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
    }
  }

  Future<void> _pickAndUploadExcel() async {
    if (_uploading || _applying) return;
    final cont = widget.model.cont?.trim();
    if (cont == null || cont.isEmpty) {
      _showMessage('CONT no disponible para este registro');
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx', 'xls'],
      withData: true,
    );
    if (!mounted || result == null || result.files.isEmpty) return;

    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      _showMessage('No se pudo leer el archivo seleccionado');
      return;
    }

    setState(() => _uploading = true);
    try {
      final suc = widget.model.suc?.trim();
      final res = await ref
          .read(inventariosApiProvider)
          .uploadItems(cont: cont, bytes: bytes, filename: file.name, suc: suc);
      ref.invalidate(inventariosListProvider);
      if (!mounted) return;
      final items = res.totalItems ?? 0;
      final detail = items > 0 ? '$items items' : 'sin conteos';
      final detLabel = res.totalDet == null ? detail : '$detail · det: ${res.totalDet}';
      _showMessage('Archivo ${file.name} subido ($detLabel)');
    } on DioException catch (e) {
      if (mounted) _showMessage('Error al subir: ${apiErrorMessage(e)}');
    } catch (e) {
      if (mounted) _showMessage('Error al subir: ${apiErrorMessage(e)}');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _applyAdjustment() async {
    if (_uploading || _applying) return;
    final cont = widget.model.cont?.trim();
    if (cont == null || cont.isEmpty) {
      _showMessage('CONT no disponible para este registro');
      return;
    }

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aplicar ajuste'),
        content: const Text(
          '¿Deseas aplicar el ajuste del conteo? Esto generará movimientos 701/702 en MB51 y actualizará STOCK. '
          'Esta acción NO se puede repetir.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Aplicar ajuste')),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _applying = true);
    try {
      final suc = widget.model.suc?.trim();
      final res = await ref.read(inventariosApiProvider).applyAdjustment(cont, suc: suc);
      ref.invalidate(inventariosListProvider);
      if (!mounted) return;
      final doc701 = res.docp701 ?? '-';
      final doc702 = res.docp702 ?? '-';
      final movs = res.movimientosInsertados?.toString() ?? '-';
      _showMessage('Ajuste aplicado. 701: $doc701 · 702: $doc702 · Movs: $movs');
    } on DioException catch (e) {
      if (!mounted) return;
      if (e.response?.statusCode == 409) {
        _showMessage('Ya fue ajustado anteriormente');
      } else {
        _showMessage('Error al aplicar ajuste: ${apiErrorMessage(e)}');
      }
    } catch (e) {
      if (mounted) _showMessage('Error al aplicar ajuste: ${apiErrorMessage(e)}');
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  void _goToDetalle(BuildContext context) {
    final cont = widget.model.cont?.trim();
    if (cont == null || cont.isEmpty) {
      _showMessage('CONT no disponible para este registro');
      return;
    }
    context.go('/inventarios/${Uri.encodeComponent(cont)}/det');
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _fmtDate(DateTime? value) => value?.toIso8601String() ?? '';

  String? _fmtNumber(double? value) {
    if (value == null) return null;
    final asInt = value.toInt();
    if (asInt.toDouble() == value) return asInt.toString();
    return value.toStringAsFixed(2);
  }
}
