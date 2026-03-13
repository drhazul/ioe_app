import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ioe_app/core/auth/auth_controller.dart';
import 'facturacion_providers.dart';

class FacturacionPage extends ConsumerWidget {
  const FacturacionPage({super.key});

  static const double _wRegistro = 54;
  static const double _wSelector = 56;
  static const double _wRfcEmisor = 130;
  static const double _wUsoCfdi = 72;
  static const double _wClien = 90;
  static const double _wRfcReceptor = 140;
  static const double _wRazonSocial = 260;
  static const double _wIdFol = 190;
  static const double _wFcn = 100;
  static const double _wImpt = 90;
  static const double _wFPago = 70;
  static const double _wMetodo = 82;
  static const double _wAutRef = 140;
  static const double _wTipoFact = 100;
  static const double _wEstatus = 100;
  static const double _kRowHorizontalPadding = 6;

  static const double _kTableContentWidth =
      _wRegistro +
      _wSelector +
      _wRfcEmisor +
      _wUsoCfdi +
      _wClien +
      _wRfcReceptor +
      _wRazonSocial +
      _wIdFol +
      _wFcn +
      _wImpt +
      _wFPago +
      _wMetodo +
      _wAutRef +
      _wTipoFact +
      _wEstatus;

  static const double _kTableWidth =
      _kTableContentWidth + (_kRowHorizontalPadding * 2);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appBar = AppBar(title: const Text('Facturación (Sandbox)'));
    final auth = ref.watch(authControllerProvider);

    if (auth.isLoading) {
      return Scaffold(
        appBar: appBar,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!auth.isAuthenticated) {
      return Scaffold(
        appBar: appBar,
        body: const Center(
          child: Text('Sesión no activa. Inicia sesión para consultar facturación.'),
        ),
      );
    }

    final pendientesAsync = ref.watch(facturasPendientesProvider);

    return Scaffold(
      appBar: appBar,
      body: pendientesAsync.when(
        data: (pageData) {
          final rows = pageData.data;
          final page = pageData.page;
          final pageSize = pageData.pageSize;
          final total = pageData.total;
          final totalPages = pageData.totalPages;

          if (totalPages > 0 && page > totalPages) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(facturacionPageProvider.notifier).state = totalPages;
            });
            return const Center(child: CircularProgressIndicator());
          }

          final rawSelectedIdFol = ref.watch(selectedFacturaIdFolProvider);
          final selectedIdFol = rows.any(
            (row) {
              final id = _pickText(row, const ['IDFOL', 'idfol']);
              return id == rawSelectedIdFol && id != '-';
            },
          )
              ? rawSelectedIdFol
              : null;
          if (rawSelectedIdFol != null && selectedIdFol == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(selectedFacturaIdFolProvider.notifier).state = null;
            });
          }
          final selectedRow = selectedIdFol == null
              ? null
              : _findRowById(rows, selectedIdFol);

          if (rows.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  _buildTopSection(context, ref, selectedIdFol, selectedRow),
                  const SizedBox(height: 12),
                  _buildPaginationBar(
                    context,
                    ref,
                    total: total,
                    page: page,
                    pageSize: pageSize,
                    totalPages: totalPages,
                  ),
                  const SizedBox(height: 12),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Sin registros con estatus PENDIENTE o CANCELACION PENDIENTE',
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _buildTopSection(context, ref, selectedIdFol, selectedRow),
                const SizedBox(height: 12),
                _buildPaginationBar(
                  context,
                  ref,
                  total: total,
                  page: page,
                  pageSize: pageSize,
                  totalPages: totalPages,
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: _kTableWidth,
                        child: Column(
                          children: [
                            _buildHeaderRow(context),
                            Expanded(
                              child: RadioGroup<String>(
                                groupValue: selectedIdFol,
                                onChanged: (value) {
                                  if (value == null) return;
                                  if (value.trim().isEmpty || value == '-') {
                                    return;
                                  }
                                  ref
                                      .read(selectedFacturaIdFolProvider.notifier)
                                      .state = value;
                                },
                                child: ListView.separated(
                                  itemCount: rows.length,
                                  separatorBuilder: (_, _) =>
                                      const Divider(height: 1),
                                  itemBuilder: (_, i) => _buildDataRow(
                                    ref,
                                    rows[i],
                                    ((page - 1) * pageSize) + i + 1,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error cargando pendientes: $e')),
      ),
    );
  }

  Widget _buildHeaderRow(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
        );
    return Container(
      color: const Color(0xFFEDEDED),
      padding: const EdgeInsets.symmetric(
        vertical: 10,
        horizontal: _kRowHorizontalPadding,
      ),
      child: Row(
        children: [
          _headerCell('#', _wRegistro, textStyle, textAlign: TextAlign.center),
          _headerCell('Sel', _wSelector, textStyle, textAlign: TextAlign.center),
          _headerCell('RfcEmisor', _wRfcEmisor, textStyle),
          _headerCell('Us Cfdi', _wUsoCfdi, textStyle),
          _headerCell('CLIEN', _wClien, textStyle),
          _headerCell('RfcReceptor', _wRfcReceptor, textStyle),
          _headerCell('Nombre/Razon Social', _wRazonSocial, textStyle),
          _headerCell('IDFOL', _wIdFol, textStyle),
          _headerCell('FCN', _wFcn, textStyle),
          _headerCell('IMPT', _wImpt, textStyle),
          _headerCell('F. Pago', _wFPago, textStyle),
          _headerCell('MetodoD', _wMetodo, textStyle),
          _headerCell('N°Aut o Ref', _wAutRef, textStyle),
          _headerCell('Tipofact', _wTipoFact, textStyle),
          _headerCell('ESTATUS', _wEstatus, textStyle),
        ],
      ),
    );
  }

  Widget _buildTopSection(
    BuildContext context,
    WidgetRef ref,
    String? selectedIdFol,
    Map<String, dynamic>? selectedRow,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 1150;
        final filters = _buildFiltersPanel(context, ref);
        final actions = _buildTopActions(context, ref, selectedIdFol, selectedRow);

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              filters,
              const SizedBox(height: 12),
              actions,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: filters),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: actions),
          ],
        );
      },
    );
  }

  Widget _buildPaginationBar(
    BuildContext context,
    WidgetRef ref, {
    required int total,
    required int page,
    required int pageSize,
    required int totalPages,
  }) {
    final firstRecord = total == 0 ? 0 : ((page - 1) * pageSize) + 1;
    final lastRecord = total == 0 ? 0 : math.min(page * pageSize, total);
    final displayPage = total == 0 ? 0 : page;
    final canPrev = page > 1;
    final canNext = totalPages > 0 && page < totalPages;

    final summary =
        'Registros totales: $total | Mostrando: $firstRecord-$lastRecord | Página: $displayPage/$totalPages';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 900) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(summary),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: canPrev ? () => _setPage(ref, page - 1) : null,
                        child: const Text('PAGINA ANTERIOR'),
                      ),
                      OutlinedButton(
                        onPressed: canNext ? () => _setPage(ref, page + 1) : null,
                        child: const Text('PAGINA SIGUIENTE'),
                      ),
                    ],
                  ),
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: Text(summary)),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: canPrev ? () => _setPage(ref, page - 1) : null,
                  child: const Text('PAGINA ANTERIOR'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: canNext ? () => _setPage(ref, page + 1) : null,
                  child: const Text('PAGINA SIGUIENTE'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _setPage(WidgetRef ref, int page) {
    if (page < 1) return;
    ref.read(selectedFacturaIdFolProvider.notifier).state = null;
    ref.read(facturacionPageProvider.notifier).state = page;
  }

  void _applyFilters(WidgetRef ref) {
    ref.read(facturacionFilterSucProvider.notifier).state =
        ref.read(facturacionDraftFilterSucProvider);
    ref.read(facturacionFilterEstatusProvider.notifier).state =
        ref.read(facturacionDraftFilterEstatusProvider);
    ref.read(facturacionFilterRazonSocialProvider.notifier).state =
        ref.read(facturacionDraftFilterRazonSocialProvider);
    ref.read(facturacionFilterRfcReceptorProvider.notifier).state =
        ref.read(facturacionDraftFilterRfcReceptorProvider);
    ref.read(facturacionFilterClienProvider.notifier).state =
        ref.read(facturacionDraftFilterClienProvider);
    ref.read(facturacionFilterIdFolProvider.notifier).state =
        ref.read(facturacionDraftFilterIdFolProvider);
    ref.read(facturacionFilterTipoFactProvider.notifier).state =
        ref.read(facturacionDraftFilterTipoFactProvider);

    _setPage(ref, 1);
    ref.invalidate(facturasPendientesProvider);
  }

  void _clearFilters(WidgetRef ref) {
    ref.read(facturacionDraftFilterSucProvider.notifier).state = '';
    ref.read(facturacionDraftFilterEstatusProvider.notifier).state = 'TODOS';
    ref.read(facturacionDraftFilterRazonSocialProvider.notifier).state = '';
    ref.read(facturacionDraftFilterRfcReceptorProvider.notifier).state = '';
    ref.read(facturacionDraftFilterClienProvider.notifier).state = '';
    ref.read(facturacionDraftFilterIdFolProvider.notifier).state = '';
    ref.read(facturacionDraftFilterTipoFactProvider.notifier).state = '';

    ref.read(facturacionFilterSucProvider.notifier).state = '';
    ref.read(facturacionFilterEstatusProvider.notifier).state = 'TODOS';
    ref.read(facturacionFilterRazonSocialProvider.notifier).state = '';
    ref.read(facturacionFilterRfcReceptorProvider.notifier).state = '';
    ref.read(facturacionFilterClienProvider.notifier).state = '';
    ref.read(facturacionFilterIdFolProvider.notifier).state = '';
    ref.read(facturacionFilterTipoFactProvider.notifier).state = '';

    ref.read(facturacionFilterInputRevisionProvider.notifier).state++;
    _setPage(ref, 1);
    ref.invalidate(facturasPendientesProvider);
  }

  Widget _buildFiltersPanel(BuildContext context, WidgetRef ref) {
    final revision = ref.watch(facturacionFilterInputRevisionProvider);
    final draftEstatus = ref.watch(facturacionDraftFilterEstatusProvider);

    final inputDecoration = InputDecoration(
      isDense: true,
      border: const OutlineInputBorder(),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      labelStyle: Theme.of(context).textTheme.bodySmall,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filtros',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SizedBox(
                  width: 110,
                  child: TextField(
                    key: ValueKey('ff-suc-$revision'),
                    onChanged: (value) {
                      ref.read(facturacionDraftFilterSucProvider.notifier).state =
                          value;
                    },
                    decoration: inputDecoration.copyWith(labelText: 'SUC'),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('ff-estatus-$revision-$draftEstatus'),
                    initialValue: draftEstatus,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'TODOS', child: Text('TODOS')),
                      DropdownMenuItem(
                        value: 'PENDIENTE',
                        child: Text('PENDIENTE'),
                      ),
                      DropdownMenuItem(
                        value: 'CANCELACION PENDIENTE',
                        child: Text('CANC. PEND.'),
                      ),
                    ],
                    onChanged: (value) {
                      ref
                          .read(facturacionDraftFilterEstatusProvider.notifier)
                          .state = value ?? 'TODOS';
                    },
                    decoration: inputDecoration.copyWith(labelText: 'ESTATUS'),
                  ),
                ),
                SizedBox(
                  width: 250,
                  child: TextField(
                    key: ValueKey('ff-razon-$revision'),
                    onChanged: (value) {
                      ref
                          .read(facturacionDraftFilterRazonSocialProvider.notifier)
                          .state = value;
                    },
                    decoration:
                        inputDecoration.copyWith(labelText: 'Razon social Receptor'),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextField(
                    key: ValueKey('ff-rfc-$revision'),
                    onChanged: (value) {
                      ref
                          .read(facturacionDraftFilterRfcReceptorProvider.notifier)
                          .state = value;
                    },
                    decoration:
                        inputDecoration.copyWith(labelText: 'RFC receptor'),
                  ),
                ),
                SizedBox(
                  width: 130,
                  child: TextField(
                    key: ValueKey('ff-clien-$revision'),
                    onChanged: (value) {
                      ref.read(facturacionDraftFilterClienProvider.notifier).state =
                          value;
                    },
                    decoration: inputDecoration.copyWith(labelText: 'CLIEN'),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextField(
                    key: ValueKey('ff-idfol-$revision'),
                    onChanged: (value) {
                      ref.read(facturacionDraftFilterIdFolProvider.notifier).state =
                          value;
                    },
                    decoration: inputDecoration.copyWith(labelText: 'IDFOL'),
                  ),
                ),
                SizedBox(
                  width: 140,
                  child: TextField(
                    key: ValueKey('ff-tipofact-$revision'),
                    onChanged: (value) {
                      ref
                          .read(facturacionDraftFilterTipoFactProvider.notifier)
                          .state = value;
                    },
                    decoration: inputDecoration.copyWith(labelText: 'Tipofact'),
                  ),
                ),
                FilledButton(
                  onPressed: () => _applyFilters(ref),
                  child: const Text('APLICAR FILTROS'),
                ),
                OutlinedButton(
                  onPressed: () => _clearFilters(ref),
                  child: const Text('LIMPIAR FILTROS'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopActions(
    BuildContext context,
    WidgetRef ref,
    String? selectedIdFol,
    Map<String, dynamic>? selectedRow,
  ) {
    final selectedStatus = selectedRow == null
        ? '-'
        : _pickText(selectedRow, const ['ESTATUS', 'estatus']);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              selectedIdFol == null
                  ? 'Selecciona un registro para habilitar acciones'
                  : 'Registro seleccionado: $selectedIdFol | Estatus: $selectedStatus',
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: selectedIdFol == null
                      ? null
                      : () => _onValidar(context, ref, selectedIdFol),
                  child: const Text('Validar'),
                ),
                ElevatedButton(
                  onPressed: selectedIdFol == null
                      ? null
                      : () => _onEmitir(context, ref, selectedIdFol),
                  child: const Text('REALIZAR FACTURA'),
                ),
                OutlinedButton(
                  onPressed: selectedIdFol == null
                      ? null
                      : () => _onRefrescarEstado(context, ref, selectedIdFol),
                  child: const Text('REFRESCAR ESTADO'),
                ),
                OutlinedButton(
                  onPressed: selectedIdFol == null
                      ? null
                      : () => _onReenviarEmail(context, ref, selectedIdFol),
                  child: const Text('REENVIAR XML/PDF'),
                ),
                OutlinedButton(
                  onPressed: selectedIdFol == null
                      ? null
                      : () => _onCancelar(context, ref, selectedIdFol),
                  child: const Text('CANCELAR'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataRow(
    WidgetRef ref,
    Map<String, dynamic> row,
    int registroNumero,
  ) {
    final idFol = _pickText(row, const ['IDFOL', 'idfol']);
    final canSelect = idFol != '-';

    final rfcEmisor = _pickText(row, const ['RFCEMISOR', 'RfcEmisor']);
    final usoCfdi = _pickText(row, const ['USOCFDI', 'UsoCfdi']);
    final clien = _pickText(row, const ['CLIEN', 'CLIENTE', 'client']);
    final rfcReceptor = _pickText(row, const ['RFCRECEPTOR', 'RfcReceptor']);
    final razonSocial = _pickText(row, const [
      'RAZONSOCIALRECEPTOR',
      'RazonSocialReceptor',
      'NOMBRE',
      'NOMBRE_CLIENTE'
    ]);
    final fcn = _formatDate(_pickValue(row, const ['FCN', 'fcn']));
    final impt = _formatMoney(_pickValue(row, const ['IMPT', 'impt']));
    final fPago = _pickText(row, const ['FORMAPAGO', 'FormaPagoSAT', 'FormaPago']);
    final metodo = _pickText(row, const ['METODODEPAGO', 'MetodoDePago']);
    final autRef = _pickText(row, const [
      'TARJETAULTIMOS4DIGITOS',
      'TarjetaUltimos4Digitos',
      'AUT',
      'aut',
      'NAUT'
    ]);
    final tipoFact = _pickText(row, const ['TIPOFACT', 'Tipofact']);
    final estatus = _pickText(row, const ['ESTATUS', 'estatus']);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: canSelect
          ? () {
              ref.read(selectedFacturaIdFolProvider.notifier).state = idFol;
            }
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 8,
          horizontal: _kRowHorizontalPadding,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _dataCell('$registroNumero', _wRegistro, textAlign: TextAlign.center),
            SizedBox(
              width: _wSelector,
              child: Align(
                alignment: Alignment.center,
                child: Radio<String>(
                  value: idFol,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
            _dataCell(rfcEmisor, _wRfcEmisor),
            _dataCell(usoCfdi, _wUsoCfdi),
            _dataCell(clien, _wClien),
            _dataCell(rfcReceptor, _wRfcReceptor),
            _dataCell(razonSocial, _wRazonSocial),
            _dataCell(idFol, _wIdFol),
            _dataCell(fcn, _wFcn),
            _dataCell(impt, _wImpt, alignRight: true),
            _dataCell(fPago, _wFPago),
            _dataCell(metodo, _wMetodo),
            _dataCell(autRef, _wAutRef),
            _dataCell(tipoFact, _wTipoFact),
            _dataCell(estatus, _wEstatus),
          ],
        ),
      ),
    );
  }

  Future<void> _onValidar(
    BuildContext context,
    WidgetRef ref,
    String idFol,
  ) async {
    final api = ref.read(facturacionApiProvider);
    final result = await api.validar(idFol);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Validación: ${result['validaciones'] ?? result.toString()}',
        ),
      ),
    );
  }

  Future<void> _onEmitir(
    BuildContext context,
    WidgetRef ref,
    String idFol,
  ) async {
    final api = ref.read(facturacionApiProvider);
    final result = await api.emitir(idFol);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${result['message'] ?? 'Emitido'}')),
    );
    ref.invalidate(facturasPendientesProvider);
  }

  Future<void> _onRefrescarEstado(
    BuildContext context,
    WidgetRef ref,
    String idFol,
  ) async {
    final api = ref.read(facturacionApiProvider);
    final result = await api.refrescarEstado(idFol);
    if (!context.mounted) return;
    final local = result['local'];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Estado actualizado: ${local?['ESTATUS'] ?? '-'} / ${local?['CFDI_STATUS'] ?? '-'}',
        ),
      ),
    );
    ref.invalidate(facturasPendientesProvider);
  }

  Future<void> _onReenviarEmail(
    BuildContext context,
    WidgetRef ref,
    String idFol,
  ) async {
    final api = ref.read(facturacionApiProvider);
    final result = await api.reenviarEmail(idFol);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Reenvío email: ${result['ok'] == true ? 'OK' : 'ERROR'}'),
      ),
    );
  }

  Future<void> _onCancelar(
    BuildContext context,
    WidgetRef ref,
    String idFol,
  ) async {
    final api = ref.read(facturacionApiProvider);
    final result = await api.cancelar(
      idFol,
      motivo: 'Cancelación manual desde IOE',
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${result['message'] ?? 'Cancelado'}')),
    );
    ref.invalidate(facturasPendientesProvider);
  }

  Widget _headerCell(
    String label,
    double width,
    TextStyle? style, {
    TextAlign textAlign = TextAlign.left,
  }) {
    return SizedBox(
      width: width,
      child: Text(label, style: style, textAlign: textAlign),
    );
  }

  Widget _dataCell(
    String value,
    double width, {
    bool alignRight = false,
    TextAlign? textAlign,
  }) {
    final resolvedTextAlign =
        textAlign ?? (alignRight ? TextAlign.right : TextAlign.left);
    return SizedBox(
      width: width,
      child: Text(
        value,
        textAlign: resolvedTextAlign,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  dynamic _pickValue(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key];
      if (value != null) return value;
    }
    return null;
  }

  String _pickText(Map<String, dynamic> row, List<String> keys) {
    final value = _pickValue(row, keys);
    final text = '$value'.trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return '-';
    return text;
  }

  String _formatDate(dynamic rawValue) {
    if (rawValue == null) return '-';
    final text = '$rawValue'.trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return '-';

    final date = DateTime.tryParse(text);
    if (date == null) return text;

    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final yyyy = date.year.toString().padLeft(4, '0');
    return '$dd/$mm/$yyyy';
  }

  String _formatMoney(dynamic rawValue) {
    if (rawValue == null) return '-';
    final text = '$rawValue'.trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return '-';

    final value = double.tryParse(text.replaceAll(',', ''));
    if (value == null) return text;
    return '\$${value.toStringAsFixed(2)}';
  }

  Map<String, dynamic>? _findRowById(
    List<Map<String, dynamic>> rows,
    String idFol,
  ) {
    for (final row in rows) {
      if (_pickText(row, const ['IDFOL', 'idfol']) == idFol) {
        return row;
      }
    }
    return null;
  }
}
