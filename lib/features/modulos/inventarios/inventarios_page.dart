import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ioe_app/core/api_error.dart';
import 'package:ioe_app/core/auth/auth_controller.dart';
import 'inventarios_models.dart';
import 'inventarios_providers.dart';

String _compactLogValue(dynamic value, {int max = 800}) {
  if (value == null) return '-';
  final text = value is String ? value : value.toString();
  if (text.length <= max) return text;
  return '${text.substring(0, max)}...';
}

class InventariosPage extends ConsumerStatefulWidget {
  const InventariosPage({super.key});

  @override
  ConsumerState<InventariosPage> createState() => _InventariosPageState();
}

class _InventariosPageState extends ConsumerState<InventariosPage> {
  final TextEditingController _conteoSearchController = TextEditingController();
  final TextEditingController _fechaConteoController = TextEditingController();
  String _appliedConteoSearch = '';
  DateTime? _draftFechaConteo;
  DateTime? _appliedFechaConteo;

  @override
  void dispose() {
    _conteoSearchController.dispose();
    _fechaConteoController.dispose();
    super.dispose();
  }

  void _setDraftFechaConteo(DateTime? value) {
    _draftFechaConteo = value;
    _fechaConteoController.text = value == null ? '' : _fmtDateOnly(value);
  }

  Future<void> _pickFechaConteo() async {
    final now = DateTime.now();
    final initialDate = _draftFechaConteo ?? _appliedFechaConteo ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 20),
      lastDate: DateTime(now.year + 20),
      helpText: 'Seleccionar fecha de conteo',
    );
    if (!mounted || picked == null) return;
    setState(() => _setDraftFechaConteo(picked));
  }

  void _applyFilters() {
    setState(() {
      _appliedConteoSearch = _conteoSearchController.text.trim();
      _appliedFechaConteo = _draftFechaConteo;
    });
  }

  void _clearFilters() {
    setState(() {
      _conteoSearchController.clear();
      _appliedConteoSearch = '';
      _appliedFechaConteo = null;
      _setDraftFechaConteo(null);
    });
  }

  bool _matchesFechaConteo(DateTime? value) {
    final appliedDate = _appliedFechaConteo;
    if (appliedDate == null) return true;
    if (value == null) return false;
    return DateUtils.isSameDay(value.toLocal(), appliedDate);
  }

  List<DatContCtrlModel> _applyRowsFilters(List<DatContCtrlModel> rows) {
    final search = _appliedConteoSearch.trim().toLowerCase();
    return rows.where((row) {
      final cont = (row.cont ?? '').trim().toLowerCase();
      final matchesName = search.isEmpty || cont.contains(search);
      final matchesDate = _matchesFechaConteo(row.fcnc);
      return matchesName && matchesDate;
    }).toList();
  }

  String _fmtDateOnly(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString().padLeft(4, '0');
    return '$day/$month/$year';
  }

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(inventariosListProvider);
    final allowedAsync = ref.watch(inventariosAllowedSucProvider);
    final selectedSuc = ref.watch(inventariosSelectedSucProvider);
    final auth = ref.watch(authControllerProvider);
    final isAdmin = (auth.roleId ?? 0) == 1;

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
          final rowSucs = <String>{};
          for (final row in rows) {
            final suc = (row.suc ?? '').trim();
            if (suc.isNotEmpty) rowSucs.add(suc);
          }

          final sucOptionsSet = <String>{...allowed, if (isAdmin) ...rowSucs};
          final sucOptions = sucOptionsSet.toList()..sort();
          final effectiveSuc =
              selectedSuc != null && sucOptions.contains(selectedSuc)
              ? selectedSuc
              : (!isAdmin && sucOptions.isNotEmpty ? sucOptions.first : null);
          final canChangeSucursal =
              sucOptions.isNotEmpty &&
              (isAdmin ||
                  (effectiveSuc != null && allowed.contains(effectiveSuc)));
          final filteredRows = _applyRowsFilters(rows);

          final list = RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(inventariosListProvider);
              await ref.read(inventariosListProvider.future);
            },
            child: filteredRows.isEmpty
                ? ListView(
                    padding: const EdgeInsets.all(24),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 80),
                      Center(
                        child: Text(
                          'No hay conteos que coincidan con los filtros',
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: filteredRows.length,
                    itemBuilder: (_, index) =>
                        _InventarioTile(model: filteredRows[index]),
                    separatorBuilder: (context, _) => const SizedBox(height: 8),
                  ),
          );

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 160,
                        child: DropdownButtonFormField<String>(
                          initialValue: effectiveSuc,
                          hint: const Text('Todas'),
                          decoration: const InputDecoration(
                            labelText: 'Sucursal',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: [
                            for (final suc in sucOptions)
                              DropdownMenuItem<String>(
                                value: suc,
                                child: Text(suc),
                              ),
                          ],
                          onChanged: canChangeSucursal
                              ? (value) {
                                  ref
                                          .read(
                                            inventariosSelectedSucProvider
                                                .notifier,
                                          )
                                          .state =
                                      value;
                                }
                              : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 360,
                        child: TextField(
                          controller: _conteoSearchController,
                          textInputAction: TextInputAction.search,
                          decoration: const InputDecoration(
                            labelText: 'Coincidencia de nombre de conteo',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onSubmitted: (_) => _applyFilters(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 170,
                        child: TextField(
                          controller: _fechaConteoController,
                          readOnly: true,
                          onTap: _pickFechaConteo,
                          decoration: InputDecoration(
                            labelText: 'Fecha de conteo',
                            border: const OutlineInputBorder(),
                            isDense: true,
                            suffixIcon: IconButton(
                              tooltip: _draftFechaConteo == null
                                  ? 'Seleccionar fecha'
                                  : 'Quitar fecha',
                              icon: Icon(
                                _draftFechaConteo == null
                                    ? Icons.calendar_today
                                    : Icons.clear,
                              ),
                              onPressed: _draftFechaConteo == null
                                  ? _pickFechaConteo
                                  : () => setState(
                                      () => _setDraftFechaConteo(null),
                                    ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _applyFilters,
                        icon: const Icon(Icons.filter_list),
                        label: const Text('Filtrar'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _clearFilters,
                        icon: const Icon(Icons.clear),
                        label: const Text('Limpiar'),
                      ),
                    ],
                  ),
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
    final artaj = _fmtNumber(model.artaj);
    final artcont = _fmtNumber(model.artcont);

    final summary = [
      if (model.esta != null && model.esta!.isNotEmpty) 'Estado: ${model.esta}',
      if (model.suc != null && model.suc!.isNotEmpty) 'Suc: ${model.suc}',
      if (model.tipocont != null && model.tipocont!.isNotEmpty)
        'Tipo: ${model.tipocont}',
      if (model.fcnc != null) 'FCNC: ${_fmtDate(model.fcnc)}',
      if (model.totalItems != null) 'Items: ${model.totalItems}',
      if (model.fileName != null && model.fileName!.isNotEmpty)
        'Archivo: ${model.fileName}',
      if (model.fcnaj != null) 'FCNAJ: ${_fmtDate(model.fcnaj)}',
      if (artaj != null) 'ARTAJ: $artaj',
      if (artcont != null) 'ARTCONT: $artcont',
    ].join(' · ');
    final status = (model.esta ?? '').trim().toUpperCase();
    final isAdjusted = status == 'AJUSTADO' || status == 'CERRADO_AJUSTADO';

    final title = (model.cont != null && model.cont!.isNotEmpty)
        ? 'CONT: ${model.cont}'
        : 'TOKEN: ${model.tokenreg}';

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
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (summary.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            summary,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  tooltip: 'Eliminar',
                  onPressed: (busy || isAdjusted)
                      ? null
                      : () => _confirmDelete(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: (!hasCont || busy || isAdjusted)
                      ? null
                      : _pickAndUploadExcel,
                  icon: _uploading
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_file),
                  label: Text(_uploading ? 'Subiendo...' : 'Subir Excel'),
                ),
                OutlinedButton.icon(
                  onPressed: (!hasCont || busy || isAdjusted)
                      ? null
                      : _applyAdjustment,
                  icon: _applying
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
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

    if (confirmed != true) return;
    try {
      await ref.read(inventariosApiProvider).delete(widget.model.tokenreg);
      ref.invalidate(inventariosListProvider);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Registro eliminado')),
      );
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
      final detLabel = res.totalDet == null
          ? detail
          : '$detail · det: ${res.totalDet}';
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
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Aplicar ajuste'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _applying = true);
    try {
      final suc = widget.model.suc?.trim();
      final res = await ref
          .read(inventariosApiProvider)
          .applyAdjustment(cont, suc: suc);
      ref.invalidate(inventariosListProvider);
      if (!mounted) return;
      final doc701 = res.docp701 ?? '-';
      final doc702 = res.docp702 ?? '-';
      final movs = res.movimientosInsertados?.toString() ?? '-';
      _showMessage(
        'Ajuste aplicado. 701: $doc701 · 702: $doc702 · Movs: $movs',
      );
    } on DioException catch (e) {
      if (!mounted) return;
      debugPrint(
        '[inventarios.applyAdjustment] cont=$cont suc=${widget.model.suc?.trim()} '
        'type=${e.type} status=${e.response?.statusCode} '
        'body=${_compactLogValue(e.response?.data)}',
      );
      if (e.response?.statusCode == 409) {
        _showMessage('Ya fue ajustado anteriormente');
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        final suc = widget.model.suc?.trim();
        final confirmed = await _confirmAdjustmentAfterTimeout(
          cont: cont,
          suc: suc,
        );
        if (!mounted) return;
        if (confirmed) {
          ref.invalidate(inventariosListProvider);
          _showMessage(
            'El ajuste se confirmó correctamente después del tiempo de espera.',
          );
        } else {
          _showMessage(
            'Tiempo de espera agotado al aplicar ajuste. '
            'Verifica conexión/servidor e intenta nuevamente.',
          );
        }
      } else {
        _showMessage('Error al aplicar ajuste: ${apiErrorMessage(e)}');
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Error al aplicar ajuste: ${apiErrorMessage(e)}');
      }
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  Future<bool> _confirmAdjustmentAfterTimeout({
    required String cont,
    String? suc,
  }) async {
    final contKey = cont.trim().toUpperCase();
    final sucKey = suc?.trim();

    for (var i = 0; i < 6; i++) {
      if (i > 0) {
        await Future<void>.delayed(const Duration(seconds: 2));
      }
      try {
        final rows = await ref
            .read(inventariosApiProvider)
            .fetchAll(suc: sucKey);
        final match = rows.where((row) {
          final rowCont = (row.cont ?? '').trim().toUpperCase();
          return rowCont == contKey;
        });
        if (match.isEmpty) continue;

        final status = (match.first.esta ?? '').trim().toUpperCase();
        debugPrint(
          '[inventarios.applyAdjustment] timeout-check attempt=${i + 1} '
          'cont=$contKey suc=${sucKey ?? '-'} status=$status',
        );
        if (status == 'AJUSTADO' || status == 'CERRADO_AJUSTADO') {
          return true;
        }
      } catch (_) {
        // sigue intentando hasta agotar reintentos
      }
    }
    return false;
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

  String _fmtDate(DateTime? value) {
    if (value == null) return '';
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString().padLeft(4, '0');
    return '$day/$month/$year';
  }

  String? _fmtNumber(double? value) {
    if (value == null) return null;
    final asInt = value.toInt();
    if (asInt.toDouble() == value) return asInt.toString();
    return value.toStringAsFixed(2);
  }
}
