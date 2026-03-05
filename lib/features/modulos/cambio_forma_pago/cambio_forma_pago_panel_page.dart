import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ioe_app/core/api_error.dart';
import 'package:ioe_app/core/auth/auth_controller.dart';
import 'package:ioe_app/features/masterdata/sucursales/sucursales_providers.dart';
import 'package:ioe_app/features/modulos/punto_venta/cotizaciones/pago/ref_detalle/ref_detalle_models.dart';
import 'package:ioe_app/features/modulos/punto_venta/cotizaciones/pago/ref_detalle/ref_detalle_providers.dart';

import 'cambio_forma_pago_models.dart';
import 'cambio_forma_pago_providers.dart';

class CambioFormaPagoPanelPage extends ConsumerStatefulWidget {
  const CambioFormaPagoPanelPage({super.key});

  @override
  ConsumerState<CambioFormaPagoPanelPage> createState() =>
      _CambioFormaPagoPanelPageState();
}

class _CambioFormaPagoPanelPageState
    extends ConsumerState<CambioFormaPagoPanelPage> {
  final Map<String, bool> _savingByIdf = {};
  final Map<String, String> _selectedFormByIdf = {};
  final TextEditingController _idfolSearchCtrl = TextEditingController();
  final TextEditingController _clienSearchCtrl = TextEditingController();
  bool _redirectScheduled = false;

  @override
  void dispose() {
    _idfolSearchCtrl.dispose();
    _clienSearchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(cambioFormaPagoSessionProvider);
    final validSession = session;
    final todayFilter = ref.watch(cambioFormaPagoTodayFilterProvider);

    if (validSession == null) {
      _redirectToAuth(
        message: 'Se requiere autorizacion supervisor para continuar.',
      );
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final catalogAsync = ref.watch(cambioFormaPagoCatalogProvider);
    final todayAsync = ref.watch(cambioFormaPagoTodayProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/punto-venta'),
          tooltip: 'Regresar',
        ),
        title: const Text('Cambio de forma de pago'),
        actions: [
          IconButton(
            tooltip: 'Refrescar',
            onPressed: () {
              ref.invalidate(cambioFormaPagoCatalogProvider);
              ref.invalidate(cambioFormaPagoTodayProvider);
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF6F2EB), Color(0xFFEFE7DB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: catalogAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorBlock(
            message: apiErrorMessage(e, fallback: 'No se pudo cargar catalogo'),
            onRetry: () => ref.invalidate(cambioFormaPagoCatalogProvider),
          ),
          data: (catalog) => todayAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _ErrorBlock(
              message: apiErrorMessage(e, fallback: 'No se pudo cargar panel'),
              onRetry: () => ref.invalidate(cambioFormaPagoTodayProvider),
            ),
            data: (rows) {
              final sortedRows = [...rows]
                ..sort((a, b) {
                  final aTime = a.fcn?.millisecondsSinceEpoch ?? 0;
                  final bTime = b.fcn?.millisecondsSinceEpoch ?? 0;
                  final byDate = bTime.compareTo(aTime);
                  if (byDate != 0) return byDate;
                  final byFolio = b.idfol.compareTo(a.idfol);
                  if (byFolio != 0) return byFolio;
                  return b.idf.compareTo(a.idf);
                });
              final sortedCatalog = [...catalog]
                ..sort((a, b) => a.form.compareTo(b.form));
              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(cambioFormaPagoCatalogProvider);
                  ref.invalidate(cambioFormaPagoTodayProvider);
                  await Future.wait([
                    ref.read(cambioFormaPagoCatalogProvider.future),
                    ref.read(cambioFormaPagoTodayProvider.future),
                  ]);
                },
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      elevation: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Wrap(
                          spacing: 16,
                          runSpacing: 8,
                          children: [
                            Text(
                              'Supervisor: ${validSession.supervisorId}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text('Registros: ${sortedRows.length}'),
                            const Text(
                              'Fecha: hoy',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Card(
                      elevation: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            SizedBox(
                              width: 220,
                              child: TextField(
                                controller: _idfolSearchCtrl,
                                textInputAction: TextInputAction.search,
                                onSubmitted: (_) => _applySearch(),
                                decoration: const InputDecoration(
                                  labelText: 'Buscar IDFOL',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 220,
                              child: TextField(
                                controller: _clienSearchCtrl,
                                textInputAction: TextInputAction.search,
                                onSubmitted: (_) => _applySearch(),
                                decoration: const InputDecoration(
                                  labelText: 'Buscar CLIEN',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                            FilledButton.icon(
                              onPressed: _applySearch,
                              icon: const Icon(Icons.search),
                              label: const Text('Buscar'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _clearSearch,
                              icon: const Icon(Icons.clear),
                              label: const Text('Limpiar'),
                            ),
                            Text(
                              'Filtro actual: IDFOL="${todayFilter.idfol.trim().isEmpty ? '*' : todayFilter.idfol.trim()}" | CLIEN="${todayFilter.clien.trim().isEmpty ? '*' : todayFilter.clien.trim()}"',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (sortedRows.isEmpty)
                      const Card(
                        elevation: 0,
                        child: Padding(
                          padding: EdgeInsets.all(14),
                          child: Text('No hay cambios de forma de pago para hoy.'),
                        ),
                      )
                    else
                      _buildTable(
                        rows: sortedRows,
                        catalog: sortedCatalog,
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _applySearch() {
    final idfol = _idfolSearchCtrl.text.trim();
    final clien = _clienSearchCtrl.text.trim();
    ref.read(cambioFormaPagoTodayFilterProvider.notifier).state =
        CambioFormaPagoTodayFilter(idfol: idfol, clien: clien);
    ref.invalidate(cambioFormaPagoTodayProvider);
  }

  void _clearSearch() {
    _idfolSearchCtrl.clear();
    _clienSearchCtrl.clear();
    ref.read(cambioFormaPagoTodayFilterProvider.notifier).state =
        const CambioFormaPagoTodayFilter();
    ref.invalidate(cambioFormaPagoTodayProvider);
  }

  Widget _buildTable({
    required List<CambioFormaPagoItem> rows,
    required List<CambioFormaPagoCatalogItem> catalog,
  }) {
    return Card(
      elevation: 0,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 1320),
          child: Column(
            children: [
              Container(
                color: Colors.grey.shade200,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: const Row(
                  children: [
                    SizedBox(
                      width: 140,
                      child: Text('FCN',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    SizedBox(
                      width: 100,
                      child: Text('AUT',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    SizedBox(
                      width: 170,
                      child: Text('IDFOL',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    SizedBox(
                      width: 170,
                      child:
                          Text('IDF', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    SizedBox(
                      width: 250,
                      child: Text('FORM (editable)',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    SizedBox(
                      width: 120,
                      child: Text('IMPD',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    SizedBox(
                      width: 180,
                      child: Text('AUT FORM',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    SizedBox(
                      width: 150,
                      child: Text('ACCION',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ...rows.map(
                (row) => _buildTableRow(
                  row: row,
                  catalog: catalog,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableRow({
    required CambioFormaPagoItem row,
    required List<CambioFormaPagoCatalogItem> catalog,
  }) {
    final hasIdf = row.idf.trim().isNotEmpty;
    final normalizedCurrent = row.form.trim().toUpperCase();
    final rowCatalog = _catalogForRow(
      currentForm: normalizedCurrent,
      baseCatalog: catalog,
    );
    final saving = _savingByIdf[row.idf] == true;
    final pending = (_selectedFormByIdf[row.idf] ?? normalizedCurrent)
        .trim()
        .toUpperCase();
    final value = rowCatalog.any((item) => item.form == pending)
        ? pending
        : (rowCatalog.any((item) => item.form == normalizedCurrent)
              ? normalizedCurrent
              : null);
    final canApply =
        hasIdf &&
        !saving &&
        value != null &&
        value.trim().toUpperCase() != normalizedCurrent;

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              SizedBox(
                width: 140,
                child: Text(_fmtDateTime(row.fcn)),
              ),
              SizedBox(
                width: 100,
                child: Text(row.autAsvr.isEmpty ? '-' : row.autAsvr),
              ),
              SizedBox(
                width: 170,
                child: Text(row.idfol, overflow: TextOverflow.ellipsis),
              ),
              SizedBox(
                width: 170,
                child: Text(row.idf, overflow: TextOverflow.ellipsis),
              ),
              SizedBox(
                width: 250,
                child: rowCatalog.isEmpty
                    ? Text(
                        row.form.isEmpty ? '-' : row.form,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      )
                    : DropdownButtonFormField<String>(
                        key: ValueKey('${row.idf}::$value'),
                        initialValue: value,
                        isExpanded: true,
                        icon: saving
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.arrow_drop_down),
                        items: rowCatalog
                            .map(
                              (item) => DropdownMenuItem<String>(
                                value: item.form,
                                enabled:
                                    !item.isBlocked || item.form == normalizedCurrent,
                                child: Text(
                                  item.isBlocked && item.form != normalizedCurrent
                                      ? '${item.form} (BLOQ)'
                                      : item.form,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: saving
                            ? null
                            : !hasIdf
                            ? null
                            : (selected) => _onSelectForm(
                                  row: row,
                                  selectedForm: selected,
                                  selectedCatalog: rowCatalog,
                                ),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                      ),
              ),
              SizedBox(
                width: 120,
                child: Text(
                  _money(row.impd),
                  textAlign: TextAlign.right,
                ),
              ),
              SizedBox(
                width: 180,
                child: Text(
                  row.autForm.trim().isEmpty ? '-' : row.autForm.trim(),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(
                width: 150,
                child: FilledButton(
                  onPressed: canApply
                      ? () => _applyFormChange(
                            row: row,
                            selectedCatalog: rowCatalog,
                          )
                      : null,
                  child: saving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Aplicar'),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }

  List<CambioFormaPagoCatalogItem> _catalogForRow({
    required String currentForm,
    required List<CambioFormaPagoCatalogItem> baseCatalog,
  }) {
    final byForm = <String, CambioFormaPagoCatalogItem>{};
    for (final item in baseCatalog) {
      final current = byForm[item.form];
      if (current == null || item.bloq < current.bloq) {
        byForm[item.form] = item;
      }
    }
    final forms = byForm.values.toList(growable: true);
    if (currentForm.isNotEmpty &&
        !forms.any((item) => item.form == currentForm)) {
      forms.insert(
        0,
        CambioFormaPagoCatalogItem(
          form: currentForm,
          tipotran: '',
          bloq: 1,
        ),
      );
    }
    forms.sort((a, b) => a.form.compareTo(b.form));
    return forms;
  }

  void _onSelectForm({
    required CambioFormaPagoItem row,
    required String? selectedForm,
    required List<CambioFormaPagoCatalogItem> selectedCatalog,
  }) {
    final nextForm = (selectedForm ?? '').trim().toUpperCase();
    if (nextForm.isEmpty) return;

    final currentForm = row.form.trim().toUpperCase();
    final selectedItem = selectedCatalog.firstWhere(
      (item) => item.form == nextForm,
      orElse: () => CambioFormaPagoCatalogItem(form: nextForm, tipotran: '', bloq: 0),
    );
    if (selectedItem.isBlocked && selectedItem.form != currentForm) {
      _showSnack('La forma seleccionada esta bloqueada.');
      return;
    }

    setState(() {
      _selectedFormByIdf[row.idf] = nextForm;
    });
  }

  Future<void> _applyFormChange({
    required CambioFormaPagoItem row,
    required List<CambioFormaPagoCatalogItem> selectedCatalog,
  }) async {
    if (row.idf.trim().isEmpty) {
      _showSnack('El registro no tiene IDF y no puede actualizarse.');
      return;
    }
    final currentForm = row.form.trim().toUpperCase();
    final nextForm = (_selectedFormByIdf[row.idf] ?? currentForm)
        .trim()
        .toUpperCase();
    if (nextForm.isEmpty || nextForm == currentForm) return;

    final selectedItem = selectedCatalog.firstWhere(
      (item) => item.form == nextForm,
      orElse: () => CambioFormaPagoCatalogItem(form: nextForm, tipotran: '', bloq: 0),
    );
    if (selectedItem.isBlocked && selectedItem.form != currentForm) {
      _showSnack('La forma seleccionada esta bloqueada.');
      return;
    }

    final sessionNotifier = ref.read(cambioFormaPagoSessionProvider.notifier);
    final validSession = sessionNotifier.readValidSession();
    if (validSession == null) {
      _redirectToAuth(message: 'Se requiere autorización de supervisor.');
      return;
    }

    setState(() => _savingByIdf[row.idf] = true);
    try {
      String? autToSend =
          row.autForm.trim().isEmpty ? null : row.autForm.trim();
      var clearAut = false;

      final fromEfectivoToOther =
          currentForm == 'EFECTIVO' && nextForm != 'EFECTIVO';
      final fromOtherToEfectivo =
          currentForm != 'EFECTIVO' && nextForm == 'EFECTIVO';

      if (fromEfectivoToOther) {
        final refResult = await _openRefDetalleForTransition(
          row: row,
          tipo: nextForm,
          initialIdref: autToSend,
        );
        if (!mounted) return;
        final idref = (refResult?.idref ?? '').trim();
        if (idref.isEmpty) {
          _showSnack(
            'No se generó/asignó referencia. El cambio no fue aplicado.',
          );
          return;
        }
        autToSend = idref;
      } else if (fromOtherToEfectivo) {
        final currentAut = row.autForm.trim();
        await _openRefDetalleForTransition(
          row: row,
          tipo: currentForm,
          initialIdref: currentAut.isEmpty ? null : currentAut,
        );
        if (!mounted) return;
        if (currentAut.isNotEmpty) {
          final stillExists = await _referenceExists(
            idfol: row.idfol,
            idref: currentAut,
          );
          if (!mounted) return;
          if (stillExists) {
            _showSnack(
              'Debe eliminar la referencia $currentAut antes de cambiar a EFECTIVO.',
            );
            return;
          }
        }
        clearAut = true;
        autToSend = null;
      }

      final result = await ref.read(cambioFormaPagoApiProvider).updateForma(
            idf: row.idf,
            newForm: nextForm,
            aut: autToSend,
            clearAut: clearAut,
            overrideToken: validSession.overrideToken,
            authPassword: validSession.authPassword,
          );
      ref.invalidate(cambioFormaPagoTodayProvider);

      if (!mounted) return;
      setState(() => _selectedFormByIdf.remove(row.idf));

      final before = result.beforeForm.isEmpty ? currentForm : result.beforeForm;
      final after = result.afterForm.isEmpty ? nextForm : result.afterForm;
      final afterAut = result.afterAut.trim();
      final autMsg = afterAut.isEmpty ? 'AUT limpio' : 'AUT $afterAut';
      _showSnack('IDF ${row.idf}: FORM $before -> $after | $autMsg');
    } catch (e) {
      if (!mounted) return;
      if (e is DioException) {
        final status = e.response?.statusCode ?? 0;
        if (status == 401 || status == 403) {
          ref.read(cambioFormaPagoSessionProvider.notifier).clear();
          _redirectToAuth(
            message: 'Se requiere autorización de supervisor.',
          );
          return;
        }
      }
      _showSnack(
        apiErrorMessage(e, fallback: 'No se pudo actualizar la forma.'),
      );
    } finally {
      if (mounted) {
        setState(() => _savingByIdf.remove(row.idf));
      }
    }
  }

  Future<RefDetalleSelectionResult?> _openRefDetalleForTransition({
    required CambioFormaPagoItem row,
    required String tipo,
    String? initialIdref,
  }) async {
    final idfol = row.idfol.trim();
    if (idfol.isEmpty) {
      _showSnack('No se pudo resolver IDFOL para gestionar referencia.');
      return null;
    }

    final suc = row.suc.trim();
    if (suc.isEmpty) {
      _showSnack('No se pudo resolver SUC para gestionar referencia.');
      return null;
    }

    final opvAuth = (ref.read(authControllerProvider).username ?? '').trim();
    final opv = opvAuth.isNotEmpty ? opvAuth : row.opvm.trim();
    if (opv.isEmpty) {
      _showSnack('No se pudo resolver OPV para gestionar referencia.');
      return null;
    }

    final idc = row.clien ?? 0;
    if (idc <= 0) {
      _showSnack('No se pudo resolver cliente para gestionar referencia.');
      return null;
    }

    final sucursales = await ref.read(sucursalesListProvider.future);
    final sucFound = sucursales.where((s) => s.suc.trim() == suc).toList();
    final rfcEmisor = sucFound.isEmpty ? '' : (sucFound.first.rfc ?? '').trim();
    if (!mounted) return null;
    if (rfcEmisor.isEmpty) {
      _showSnack('No se encontró RFC emisor para la sucursal $suc.');
      return null;
    }

    final impt = row.impd <= 0 ? 0.01 : row.impd;
    final maxImpt = row.impd <= 0 ? 0.01 : row.impd;

    final args = RefDetallePageArgs(
      idfol: idfol,
      suc: suc,
      idc: idc,
      opv: opv,
      rfcEmisor: rfcEmisor,
      tipo: tipo.trim().toUpperCase(),
      impt: impt,
      maxImpt: maxImpt,
      rqfac: false,
      initialIdref: (initialIdref ?? '').trim().isEmpty
          ? null
          : initialIdref!.trim(),
    );

    final result = await context.push<RefDetalleSelectionResult>(
      '/punto-venta/cotizaciones/${Uri.encodeComponent(idfol)}/ref-detalle',
      extra: args,
    );
    if (!mounted) return null;
    return result;
  }

  Future<bool> _referenceExists({
    required String idfol,
    required String idref,
  }) async {
    final wanted = idref.trim().toUpperCase();
    if (wanted.isEmpty) return false;
    final refs = await ref.read(refDetalleApiProvider).fetchByFolio(idfol: idfol);
    for (final item in refs) {
      if (item.idref.trim().toUpperCase() == wanted) {
        return true;
      }
    }
    return false;
  }

  void _redirectToAuth({String? message}) {
    if (_redirectScheduled) return;
    _redirectScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if ((message ?? '').trim().isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message!.trim())),
        );
      }
      context.go('/cambio-forma-pago/auth');
    });
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _fmtDateTime(DateTime? value) {
    if (value == null) return '-';
    final local = value.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd $hh:$min';
  }

  String _money(double value) {
    return '\$${value.toStringAsFixed(2)}';
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(message),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
