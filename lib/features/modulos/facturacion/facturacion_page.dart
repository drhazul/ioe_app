import 'dart:convert';
import 'dart:math' as math;
import 'package:excel/excel.dart' as xls;
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ioe_app/core/auth/auth_controller.dart';
import 'package:ioe_app/features/masterdata/sucursales/sucursales_models.dart';
import 'package:ioe_app/features/masterdata/sucursales/sucursales_providers.dart';
import 'package:ioe_app/features/modulos/punto_venta/clientes/datcatreg_models.dart';
import 'package:ioe_app/features/modulos/punto_venta/clientes/datcatreg_providers.dart';
import 'package:ioe_app/features/modulos/punto_venta/clientes/datcatuso_models.dart';
import 'package:ioe_app/features/modulos/punto_venta/clientes/datcatuso_providers.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'facturacion_providers.dart';

enum _FacturacionColumn {
  selector,
  estatus,
  rfcEmisor,
  usoCfdi,
  clien,
  rfcReceptor,
  razonSocial,
  idFol,
  fcn,
  impt,
  fPago,
  metodo,
  autRef,
  tipoFact,
}

class _EmitirOutcome {
  const _EmitirOutcome({
    required this.ok,
    required this.message,
    required this.pdfOpened,
  });

  final bool ok;
  final String message;
  final bool pdfOpened;
}

class FacturacionPage extends ConsumerStatefulWidget {
  const FacturacionPage({super.key});

  @override
  ConsumerState<FacturacionPage> createState() => _FacturacionPageState();
}

class _FacturacionPageState extends ConsumerState<FacturacionPage> {
  // Configuración visual para ajuste en runtime.
  static const List<String> _estatusFilterOptions = <String>[
    'PENDIENTE',
    'CANCELACION PENDIENTE',
    'FACTURADO',
    'FACTURADO Y CANCELACION PENDIENTE',
    'CON ERROR',
  ];

  static const double _kMinFontScale = 0.80;
  static const double _kMaxFontScale = 1.40;
  static const double _kDefaultFontScale = 1.00;
  static const int _kFontScaleDivisions = 60;
  static const String _kClienteSelectDefault = 'SELECCIONAR';
  static const int _kClienteRegimenDefault = 0;
  static const double _kMinColumnGap = 2;
  static const double _kMaxColumnGap = 24;
  static const double _kMinGenericColumnWidth = 56;
  static const double _kMaxGenericColumnWidth = 420;
  static const double _kMinFontSize = 9;
  static const double _kMaxFontSize = 30;

  static const double _dWSelector = 56;
  static const double _dWRfcEmisor = 130;
  static const double _dWUsoCfdi = 72;
  static const double _dWClien = 90;
  static const double _dWRfcReceptor = 140;
  static const double _dWRazonSocial = 260;
  static const double _dWIdFol = 190;
  static const double _dWFcn = 100;
  static const double _dWImpt = 90;
  static const double _dWFPago = 70;
  static const double _dWMetodo = 82;
  static const double _dWAutRef = 140;
  static const double _dWTipoFact = 100;
  static const double _dWEstatus = 100;
  static const double _dColumnGap = 8;

  static const double _dFontBodySmall = 12;
  static const double _dFontBodyMedium = 14;
  static const double _dFontBodyLarge = 14;
  static const double _dFontLabelSmall = 11;
  static const double _dFontLabelMedium = 12;
  static const double _dFontLabelLarge = 13;
  static const double _dFontTitleSmall = 14;
  static const double _dFontTitleMedium = 16;
  static const double _dFontTitleLarge = 20;
  static const double _dFontAppBarTitle = 16;
  static const double _dFontButton = 13;
  static const double _dFontDataHeader = 12;
  static const double _dFontDataCell = 13;

  static const String _pFontScale = 'facturacion.ui.font_scale';
  static const String _pWSelector = 'facturacion.ui.w_selector';
  static const String _pWRfcEmisor = 'facturacion.ui.w_rfc_emisor';
  static const String _pWUsoCfdi = 'facturacion.ui.w_uso_cfdi';
  static const String _pWClien = 'facturacion.ui.w_clien';
  static const String _pWRfcReceptor = 'facturacion.ui.w_rfc_receptor';
  static const String _pWRazonSocial = 'facturacion.ui.w_razon_social';
  static const String _pWIdFol = 'facturacion.ui.w_idfol';
  static const String _pWFcn = 'facturacion.ui.w_fcn';
  static const String _pWImpt = 'facturacion.ui.w_impt';
  static const String _pWFPago = 'facturacion.ui.w_fpago';
  static const String _pWMetodo = 'facturacion.ui.w_metodo';
  static const String _pWAutRef = 'facturacion.ui.w_aut_ref';
  static const String _pWTipoFact = 'facturacion.ui.w_tipo_fact';
  static const String _pWEstatus = 'facturacion.ui.w_estatus';
  static const String _pColumnGap = 'facturacion.ui.column_gap';
  static const String _pFontBodySmall = 'facturacion.ui.font_body_small';
  static const String _pFontBodyMedium = 'facturacion.ui.font_body_medium';
  static const String _pFontBodyLarge = 'facturacion.ui.font_body_large';
  static const String _pFontLabelSmall = 'facturacion.ui.font_label_small';
  static const String _pFontLabelMedium = 'facturacion.ui.font_label_medium';
  static const String _pFontLabelLarge = 'facturacion.ui.font_label_large';
  static const String _pFontTitleSmall = 'facturacion.ui.font_title_small';
  static const String _pFontTitleMedium = 'facturacion.ui.font_title_medium';
  static const String _pFontTitleLarge = 'facturacion.ui.font_title_large';
  static const String _pFontAppBarTitle = 'facturacion.ui.font_appbar_title';
  static const String _pFontButton = 'facturacion.ui.font_button';
  static const String _pFontDataHeader = 'facturacion.ui.font_data_header';
  static const String _pFontDataCell = 'facturacion.ui.font_data_cell';

  double _facturacionFontScale = _kDefaultFontScale;
  double _wSelector = _dWSelector;
  double _wRfcEmisor = _dWRfcEmisor;
  double _wUsoCfdi = _dWUsoCfdi;
  double _wClien = _dWClien;
  double _wRfcReceptor = _dWRfcReceptor;
  double _wRazonSocial = _dWRazonSocial;
  double _wIdFol = _dWIdFol;
  double _wFcn = _dWFcn;
  double _wImpt = _dWImpt;
  double _wFPago = _dWFPago;
  double _wMetodo = _dWMetodo;
  double _wAutRef = _dWAutRef;
  double _wTipoFact = _dWTipoFact;
  double _wEstatus = _dWEstatus;
  double _columnGap = _dColumnGap;

  double _fontBodySmall = _dFontBodySmall;
  double _fontBodyMedium = _dFontBodyMedium;
  double _fontBodyLarge = _dFontBodyLarge;
  double _fontLabelSmall = _dFontLabelSmall;
  double _fontLabelMedium = _dFontLabelMedium;
  double _fontLabelLarge = _dFontLabelLarge;
  double _fontTitleSmall = _dFontTitleSmall;
  double _fontTitleMedium = _dFontTitleMedium;
  double _fontTitleLarge = _dFontTitleLarge;
  double _fontAppBarTitle = _dFontAppBarTitle;
  double _fontButton = _dFontButton;
  double _fontDataHeader = _dFontDataHeader;
  double _fontDataCell = _dFontDataCell;

  final ScrollController _mainTableHorizontalController = ScrollController();
  static const double _kRowHorizontalPadding = 6;

  double get _kTableContentWidth =>
      _wSelector +
      _wEstatus +
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
      (_columnGap * 14);

  double get _kTableWidth =>
      _kTableContentWidth + (_kRowHorizontalPadding * 2);

  double get _gridRowVerticalPadding {
    final computed = (_fontDataCell * _facturacionFontScale * 0.42) - 1;
    return computed.clamp(6, 22).toDouble();
  }

  @override
  void initState() {
    super.initState();
    _loadUiPrefs();
  }

  @override
  void dispose() {
    _mainTableHorizontalController.dispose();
    super.dispose();
  }

  Future<void> _loadUiPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _facturacionFontScale = _readPrefDouble(
        prefs,
        _pFontScale,
        _kDefaultFontScale,
        min: _kMinFontScale,
        max: _kMaxFontScale,
      );

      _wSelector = _readPrefDouble(
        prefs,
        _pWSelector,
        _dWSelector,
        min: 50,
        max: 120,
      );
      _wRfcEmisor = _readPrefDouble(
        prefs,
        _pWRfcEmisor,
        _dWRfcEmisor,
        min: 80,
      );
      _wUsoCfdi = _readPrefDouble(
        prefs,
        _pWUsoCfdi,
        _dWUsoCfdi,
        min: 70,
      );
      _wClien = _readPrefDouble(
        prefs,
        _pWClien,
        _dWClien,
        min: 70,
      );
      _wRfcReceptor = _readPrefDouble(
        prefs,
        _pWRfcReceptor,
        _dWRfcReceptor,
        min: 90,
      );
      _wRazonSocial = _readPrefDouble(
        prefs,
        _pWRazonSocial,
        _dWRazonSocial,
        min: 130,
      );
      _wIdFol = _readPrefDouble(
        prefs,
        _pWIdFol,
        _dWIdFol,
        min: 110,
      );
      _wFcn = _readPrefDouble(prefs, _pWFcn, _dWFcn, min: 80);
      _wImpt = _readPrefDouble(prefs, _pWImpt, _dWImpt, min: 80);
      _wFPago = _readPrefDouble(prefs, _pWFPago, _dWFPago, min: 70);
      _wMetodo = _readPrefDouble(prefs, _pWMetodo, _dWMetodo, min: 80);
      _wAutRef = _readPrefDouble(prefs, _pWAutRef, _dWAutRef, min: 95);
      _wTipoFact = _readPrefDouble(
        prefs,
        _pWTipoFact,
        _dWTipoFact,
        min: 90,
      );
      _wEstatus = _readPrefDouble(
        prefs,
        _pWEstatus,
        _dWEstatus,
        min: 90,
      );
      _columnGap = _readPrefDouble(
        prefs,
        _pColumnGap,
        _dColumnGap,
        min: _kMinColumnGap,
        max: _kMaxColumnGap,
      );

      _fontBodySmall = _readPrefDouble(
        prefs,
        _pFontBodySmall,
        _dFontBodySmall,
        min: _kMinFontSize,
        max: _kMaxFontSize,
      );
      _fontBodyMedium = _readPrefDouble(
        prefs,
        _pFontBodyMedium,
        _dFontBodyMedium,
        min: _kMinFontSize,
        max: _kMaxFontSize,
      );
      _fontBodyLarge = _readPrefDouble(
        prefs,
        _pFontBodyLarge,
        _dFontBodyLarge,
        min: _kMinFontSize,
        max: _kMaxFontSize,
      );
      _fontLabelSmall = _readPrefDouble(
        prefs,
        _pFontLabelSmall,
        _dFontLabelSmall,
        min: _kMinFontSize,
        max: _kMaxFontSize,
      );
      _fontLabelMedium = _readPrefDouble(
        prefs,
        _pFontLabelMedium,
        _dFontLabelMedium,
        min: _kMinFontSize,
        max: _kMaxFontSize,
      );
      _fontLabelLarge = _readPrefDouble(
        prefs,
        _pFontLabelLarge,
        _dFontLabelLarge,
        min: _kMinFontSize,
        max: _kMaxFontSize,
      );
      _fontTitleSmall = _readPrefDouble(
        prefs,
        _pFontTitleSmall,
        _dFontTitleSmall,
        min: _kMinFontSize,
        max: _kMaxFontSize,
      );
      _fontTitleMedium = _readPrefDouble(
        prefs,
        _pFontTitleMedium,
        _dFontTitleMedium,
        min: _kMinFontSize,
        max: _kMaxFontSize,
      );
      _fontTitleLarge = _readPrefDouble(
        prefs,
        _pFontTitleLarge,
        _dFontTitleLarge,
        min: _kMinFontSize,
        max: _kMaxFontSize,
      );
      _fontAppBarTitle = _readPrefDouble(
        prefs,
        _pFontAppBarTitle,
        _dFontAppBarTitle,
        min: _kMinFontSize,
        max: _kMaxFontSize,
      );
      _fontButton = _readPrefDouble(
        prefs,
        _pFontButton,
        _dFontButton,
        min: _kMinFontSize,
        max: _kMaxFontSize,
      );
      _fontDataHeader = _readPrefDouble(
        prefs,
        _pFontDataHeader,
        _dFontDataHeader,
        min: _kMinFontSize,
        max: _kMaxFontSize,
      );
      _fontDataCell = _readPrefDouble(
        prefs,
        _pFontDataCell,
        _dFontDataCell,
        min: _kMinFontSize,
        max: _kMaxFontSize,
      );
    });
  }

  Future<void> _saveUiPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_pFontScale, _facturacionFontScale);
    await prefs.setDouble(_pWSelector, _wSelector);
    await prefs.setDouble(_pWRfcEmisor, _wRfcEmisor);
    await prefs.setDouble(_pWUsoCfdi, _wUsoCfdi);
    await prefs.setDouble(_pWClien, _wClien);
    await prefs.setDouble(_pWRfcReceptor, _wRfcReceptor);
    await prefs.setDouble(_pWRazonSocial, _wRazonSocial);
    await prefs.setDouble(_pWIdFol, _wIdFol);
    await prefs.setDouble(_pWFcn, _wFcn);
    await prefs.setDouble(_pWImpt, _wImpt);
    await prefs.setDouble(_pWFPago, _wFPago);
    await prefs.setDouble(_pWMetodo, _wMetodo);
    await prefs.setDouble(_pWAutRef, _wAutRef);
    await prefs.setDouble(_pWTipoFact, _wTipoFact);
    await prefs.setDouble(_pWEstatus, _wEstatus);
    await prefs.setDouble(_pColumnGap, _columnGap);
    await prefs.setDouble(_pFontBodySmall, _fontBodySmall);
    await prefs.setDouble(_pFontBodyMedium, _fontBodyMedium);
    await prefs.setDouble(_pFontBodyLarge, _fontBodyLarge);
    await prefs.setDouble(_pFontLabelSmall, _fontLabelSmall);
    await prefs.setDouble(_pFontLabelMedium, _fontLabelMedium);
    await prefs.setDouble(_pFontLabelLarge, _fontLabelLarge);
    await prefs.setDouble(_pFontTitleSmall, _fontTitleSmall);
    await prefs.setDouble(_pFontTitleMedium, _fontTitleMedium);
    await prefs.setDouble(_pFontTitleLarge, _fontTitleLarge);
    await prefs.setDouble(_pFontAppBarTitle, _fontAppBarTitle);
    await prefs.setDouble(_pFontButton, _fontButton);
    await prefs.setDouble(_pFontDataHeader, _fontDataHeader);
    await prefs.setDouble(_pFontDataCell, _fontDataCell);
  }

  double _readPrefDouble(
    SharedPreferences prefs,
    String key,
    double fallback, {
    double? min,
    double? max,
  }) {
    final value = prefs.getDouble(key) ?? fallback;
    var result = value;
    if (min != null) result = math.max(min, result);
    if (max != null) result = math.min(max, result);
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final providerRef = ref;
    final facturacionTheme = _buildFacturacionTheme(context);
    final appBar = AppBar(
      title: const Text('Facturación (Sandbox)'),
      actions: [
        TextButton.icon(
          onPressed: () => context.push('/facturacion-view'),
          icon: const Icon(Icons.receipt_long, size: 18),
          label: const Text('REGISTROS FACTURADOS'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            textStyle: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: TextButton.icon(
            onPressed: _openUiSettingsDialog,
            icon: const Icon(Icons.tune, size: 18),
            label: const Text('Configurar'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              textStyle: Theme.of(context).textTheme.labelLarge,
            ),
          ),
        ),
      ],
    );
    final auth = providerRef.watch(authControllerProvider);

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

    final pendientesAsync = providerRef.watch(facturasPendientesProvider);
    final currentEstatusFilter = providerRef.watch(facturacionFilterEstatusProvider);

    return Theme(
      data: facturacionTheme,
      child: Scaffold(
        appBar: appBar,
        body: pendientesAsync.when(
        data: (pageData) {
          final filterIds =
              ref.watch(facturacionIdFolSelectionFilterProvider).toSet();
          var rows = _sortRowsByFcnDesc(pageData.data);
          var page = pageData.page;
          var pageSize = pageData.pageSize;
          var total = pageData.total;
          var totalPages = pageData.totalPages;

          if (filterIds.isNotEmpty) {
            rows = rows
                .where((row) =>
                    filterIds.contains(
                      _pickText(row, const ['IDFOL', 'idfol']).toUpperCase(),
                    ) &&
                    _pickText(row, const ['ESTATUS', 'estatus'])
                            .toUpperCase() ==
                        'PENDIENTE')
                .toList();
            total = rows.length;
            totalPages = rows.isEmpty ? 0 : 1;
            page = 1;
            pageSize = rows.length;
          }

          if (totalPages > 0 && page > totalPages) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              providerRef.read(facturacionPageProvider.notifier).state = totalPages;
            });
            return const Center(child: CircularProgressIndicator());
          }

          final rawSelectedIdFol = providerRef.watch(selectedFacturaIdFolProvider);
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
              providerRef.read(selectedFacturaIdFolProvider.notifier).state = null;
            });
          }
          final selectedRow = selectedIdFol == null
              ? null
              : _findRowById(rows, selectedIdFol);

          final rawSelectedForUnificacion = providerRef.watch(
            selectedFacturasUnificacionProvider,
          );
          final visibleIds = rows
              .map((row) => _pickText(row, const ['IDFOL', 'idfol']).toUpperCase())
              .where((id) => id != '-')
              .toSet();
            final selectedForUnificacion = rawSelectedForUnificacion
                .where(visibleIds.contains)
                .toSet();
            if (!_sameStringSet(rawSelectedForUnificacion, selectedForUnificacion)) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                providerRef.read(selectedFacturasUnificacionProvider.notifier).state =
                    selectedForUnificacion;
              });
            }

          final idFilterSet =
              providerRef.watch(facturacionIdFolSelectionFilterProvider);
          if (idFilterSet.isNotEmpty &&
              !_sameStringSet(selectedForUnificacion, idFilterSet)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              providerRef.read(selectedFacturasUnificacionProvider.notifier).state =
                  idFilterSet;
            });
          }

          if (rows.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  _buildTopSection(
                    context,
                    providerRef,
                    selectedIdFol,
                    selectedRow,
                    selectedForUnificacion,
                    visibleRows: rows,
                  ),
                  const SizedBox(height: 12),
                  _buildPaginationBar(
                    context,
                    providerRef,
                    total: total,
                    page: page,
                    pageSize: pageSize,
                    totalPages: totalPages,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Sin registros con estatus ${currentEstatusFilter.trim().isEmpty ? 'PENDIENTE' : currentEstatusFilter}',
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
                _buildTopSection(
                  context,
                  ref,
                  selectedIdFol,
                  selectedRow,
                  selectedForUnificacion,
                  visibleRows: rows,
                ),
                const SizedBox(height: 12),
                _buildPaginationBar(
                  context,
                  providerRef,
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
                    child: Scrollbar(
                      controller: _mainTableHorizontalController,
                      thumbVisibility: true,
                      trackVisibility: true,
                      scrollbarOrientation: ScrollbarOrientation.bottom,
                      child: SingleChildScrollView(
                        controller: _mainTableHorizontalController,
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: _kTableWidth,
                          child: Column(
                            children: [
                              _buildHeaderRow(context),
                              Expanded(
                                child: SelectionArea(
                                  child: RadioGroup<String>(
                                    groupValue: selectedIdFol,
                                    onChanged: (value) {
                                      if (value == null) return;
                                      if (value.trim().isEmpty || value == '-') {
                                        return;
                                      }
                                      providerRef
                                          .read(selectedFacturaIdFolProvider.notifier)
                                          .state = value;
                                    },
                                    child: ListView.separated(
                                      itemCount: rows.length,
                                      separatorBuilder: (_, _) =>
                                          const Divider(height: 1),
                                      itemBuilder: (_, i) => _buildDataRow(
                                        providerRef,
                                        rows[i],
                                        selectedIdFolsForUnificacion:
                                            selectedForUnificacion,
                                      ),
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
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error cargando pendientes: $e')),
        ),
      ),
    );
  }

  ThemeData _buildFacturacionTheme(BuildContext context) {
    final base = Theme.of(context);
    final scale = _facturacionFontScale;
    double fontSize(double raw) => raw * scale;

    final t = base.textTheme;
    final textTheme = t.copyWith(
      bodySmall: (t.bodySmall ?? const TextStyle()).copyWith(
        fontSize: fontSize(_fontBodySmall),
      ),
      bodyMedium: (t.bodyMedium ?? const TextStyle()).copyWith(
        fontSize: fontSize(_fontBodyMedium),
      ),
      bodyLarge: (t.bodyLarge ?? const TextStyle()).copyWith(
        fontSize: fontSize(_fontBodyLarge),
      ),
      labelSmall: (t.labelSmall ?? const TextStyle()).copyWith(
        fontSize: fontSize(_fontLabelSmall),
      ),
      labelMedium: (t.labelMedium ?? const TextStyle()).copyWith(
        fontSize: fontSize(_fontLabelMedium),
      ),
      labelLarge: (t.labelLarge ?? const TextStyle()).copyWith(
        fontSize: fontSize(_fontLabelLarge),
      ),
      titleSmall: (t.titleSmall ?? const TextStyle()).copyWith(
        fontSize: fontSize(_fontTitleSmall),
      ),
      titleMedium: (t.titleMedium ?? const TextStyle()).copyWith(
        fontSize: fontSize(_fontTitleMedium),
      ),
      titleLarge: (t.titleLarge ?? const TextStyle()).copyWith(
        fontSize: fontSize(_fontTitleLarge),
      ),
    );

    final buttonStyle = (textTheme.labelLarge ?? const TextStyle()).copyWith(
      fontSize: fontSize(_fontButton),
      fontWeight: FontWeight.w600,
    );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: base.appBarTheme.copyWith(
        titleTextStyle: (base.appBarTheme.titleTextStyle ??
                textTheme.titleMedium ??
                const TextStyle(fontWeight: FontWeight.w600))
            .copyWith(
          fontSize: fontSize(_fontAppBarTitle),
        ),
        toolbarTextStyle: (base.appBarTheme.toolbarTextStyle ??
                textTheme.bodyMedium ??
                const TextStyle())
            .copyWith(
          fontSize: fontSize(_fontBodyMedium),
        ),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        labelStyle: (
          base.inputDecorationTheme.labelStyle ??
              textTheme.bodySmall ??
              const TextStyle()
        ).copyWith(
          fontSize: fontSize(_fontLabelSmall),
        ),
        hintStyle: (
          base.inputDecorationTheme.hintStyle ??
              textTheme.bodySmall ??
              const TextStyle()
        ).copyWith(
          fontSize: fontSize(_fontLabelSmall),
        ),
      ),
      dataTableTheme: base.dataTableTheme.copyWith(
        headingTextStyle: (
          base.dataTableTheme.headingTextStyle ??
              (textTheme.labelMedium ?? const TextStyle())
        ).copyWith(
          fontWeight: FontWeight.w700,
          fontSize: fontSize(_fontDataHeader),
        ),
        dataTextStyle: (
          base.dataTableTheme.dataTextStyle ??
              textTheme.bodySmall ??
              const TextStyle()
        ).copyWith(
          fontSize: fontSize(_fontDataCell),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(textStyle: buttonStyle),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(textStyle: buttonStyle),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(textStyle: buttonStyle),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(textStyle: buttonStyle),
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
          _headerCell(
            'Sel',
            _wSelector,
            textStyle,
            textAlign: TextAlign.center,
            resizable: true,
            onResizeDelta: (delta) =>
                _resizeColumn(_FacturacionColumn.selector, delta),
          ),
          _headerCell(
            'ESTATUS',
            _wEstatus,
            textStyle,
            resizable: true,
            onResizeDelta: (delta) =>
                _resizeColumn(_FacturacionColumn.estatus, delta),
          ),
          _headerCell(
            'RfcEmisor',
            _wRfcEmisor,
            textStyle,
            resizable: true,
            onResizeDelta: (delta) =>
                _resizeColumn(_FacturacionColumn.rfcEmisor, delta),
          ),
          _headerCell(
            'Us Cfdi',
            _wUsoCfdi,
            textStyle,
            resizable: true,
            onResizeDelta: (delta) =>
                _resizeColumn(_FacturacionColumn.usoCfdi, delta),
          ),
          _headerCell(
            'CLIEN',
            _wClien,
            textStyle,
            resizable: true,
            onResizeDelta: (delta) =>
                _resizeColumn(_FacturacionColumn.clien, delta),
          ),
          _headerCell(
            'RfcReceptor',
            _wRfcReceptor,
            textStyle,
            resizable: true,
            onResizeDelta: (delta) =>
                _resizeColumn(_FacturacionColumn.rfcReceptor, delta),
          ),
          _headerCell(
            'Nombre/Razon Social',
            _wRazonSocial,
            textStyle,
            resizable: true,
            onResizeDelta: (delta) =>
                _resizeColumn(_FacturacionColumn.razonSocial, delta),
          ),
          _headerCell(
            'IDFOL',
            _wIdFol,
            textStyle,
            resizable: true,
            onResizeDelta: (delta) =>
                _resizeColumn(_FacturacionColumn.idFol, delta),
          ),
          _headerCell(
            'FCN',
            _wFcn,
            textStyle,
            resizable: true,
            onResizeDelta: (delta) =>
                _resizeColumn(_FacturacionColumn.fcn, delta),
          ),
          _headerCell(
            'IMPT',
            _wImpt,
            textStyle,
            textAlign: TextAlign.right,
            resizable: true,
            onResizeDelta: (delta) =>
                _resizeColumn(_FacturacionColumn.impt, delta),
          ),
          _headerCell(
            'F. Pago',
            _wFPago,
            textStyle,
            resizable: true,
            onResizeDelta: (delta) =>
                _resizeColumn(_FacturacionColumn.fPago, delta),
          ),
          _headerCell(
            'MetodoD',
            _wMetodo,
            textStyle,
            resizable: true,
            onResizeDelta: (delta) =>
                _resizeColumn(_FacturacionColumn.metodo, delta),
          ),
          _headerCell(
            'N°Aut o Ref',
            _wAutRef,
            textStyle,
            resizable: true,
            onResizeDelta: (delta) =>
                _resizeColumn(_FacturacionColumn.autRef, delta),
          ),
          _headerCell(
            'Tipofact',
            _wTipoFact,
            textStyle,
            resizable: true,
            onResizeDelta: (delta) =>
                _resizeColumn(_FacturacionColumn.tipoFact, delta),
          ),
        ],
      ),
    );
  }

  Widget _buildTopSection(
    BuildContext context,
    WidgetRef ref,
    String? selectedIdFol,
    Map<String, dynamic>? selectedRow,
    Set<String> selectedIdFolsForUnificacion, {
    required List<Map<String, dynamic>> visibleRows,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 1150;
        final filters = _buildFiltersPanel(context, ref);
        final actions = _buildTopActions(
          context,
          ref,
          selectedIdFol,
          selectedRow,
          selectedIdFolsForUnificacion,
          visibleRows: visibleRows,
        );

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

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: filters),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: actions),
              ],
            ),
          ],
        );
      },
    );
  }

  void _resizeColumn(_FacturacionColumn column, double delta) {
    setState(() {
      switch (column) {
        case _FacturacionColumn.selector:
          _wSelector = _clampColumnWidth(_wSelector + delta, min: 50, max: 120);
          break;
        case _FacturacionColumn.estatus:
          _wEstatus = _clampColumnWidth(_wEstatus + delta, min: 90, max: 220);
          break;
        case _FacturacionColumn.rfcEmisor:
          _wRfcEmisor = _clampColumnWidth(_wRfcEmisor + delta, min: 80);
          break;
        case _FacturacionColumn.usoCfdi:
          _wUsoCfdi = _clampColumnWidth(_wUsoCfdi + delta, min: 70, max: 180);
          break;
        case _FacturacionColumn.clien:
          _wClien = _clampColumnWidth(_wClien + delta, min: 70, max: 180);
          break;
        case _FacturacionColumn.rfcReceptor:
          _wRfcReceptor = _clampColumnWidth(_wRfcReceptor + delta, min: 90);
          break;
        case _FacturacionColumn.razonSocial:
          _wRazonSocial = _clampColumnWidth(_wRazonSocial + delta, min: 130);
          break;
        case _FacturacionColumn.idFol:
          _wIdFol = _clampColumnWidth(_wIdFol + delta, min: 110);
          break;
        case _FacturacionColumn.fcn:
          _wFcn = _clampColumnWidth(_wFcn + delta, min: 80, max: 180);
          break;
        case _FacturacionColumn.impt:
          _wImpt = _clampColumnWidth(_wImpt + delta, min: 80, max: 180);
          break;
        case _FacturacionColumn.fPago:
          _wFPago = _clampColumnWidth(_wFPago + delta, min: 70, max: 180);
          break;
        case _FacturacionColumn.metodo:
          _wMetodo = _clampColumnWidth(_wMetodo + delta, min: 80, max: 180);
          break;
        case _FacturacionColumn.autRef:
          _wAutRef = _clampColumnWidth(_wAutRef + delta, min: 95);
          break;
        case _FacturacionColumn.tipoFact:
          _wTipoFact = _clampColumnWidth(_wTipoFact + delta, min: 90, max: 210);
          break;
      }
    });
  }

  double _clampColumnWidth(
    double value, {
    double min = _kMinGenericColumnWidth,
    double max = _kMaxGenericColumnWidth,
  }) {
    return value.clamp(min, max).toDouble();
  }

  Widget _buildResizeHandle({
    required void Function(double delta) onDelta,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (details) => onDelta(details.delta.dx),
        onHorizontalDragEnd: (_) => _saveUiPrefs(),
        child: SizedBox(
          width: double.infinity,
          height: 26,
          child: Center(
            child: Container(
              width: 2,
              height: 18,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _restoreDefaultFonts({bool includeScale = false}) {
    setState(() {
      if (includeScale) {
        _facturacionFontScale = _kDefaultFontScale;
      }
      _fontBodySmall = _dFontBodySmall;
      _fontBodyMedium = _dFontBodyMedium;
      _fontBodyLarge = _dFontBodyLarge;
      _fontLabelSmall = _dFontLabelSmall;
      _fontLabelMedium = _dFontLabelMedium;
      _fontLabelLarge = _dFontLabelLarge;
      _fontTitleSmall = _dFontTitleSmall;
      _fontTitleMedium = _dFontTitleMedium;
      _fontTitleLarge = _dFontTitleLarge;
      _fontAppBarTitle = _dFontAppBarTitle;
      _fontButton = _dFontButton;
      _fontDataHeader = _dFontDataHeader;
      _fontDataCell = _dFontDataCell;
    });
  }

  void _restoreDefaultColumns() {
    setState(() {
      _wSelector = _dWSelector;
      _wEstatus = _dWEstatus;
      _wRfcEmisor = _dWRfcEmisor;
      _wUsoCfdi = _dWUsoCfdi;
      _wClien = _dWClien;
      _wRfcReceptor = _dWRfcReceptor;
      _wRazonSocial = _dWRazonSocial;
      _wIdFol = _dWIdFol;
      _wFcn = _dWFcn;
      _wImpt = _dWImpt;
      _wFPago = _dWFPago;
      _wMetodo = _dWMetodo;
      _wAutRef = _dWAutRef;
      _wTipoFact = _dWTipoFact;
      _columnGap = _dColumnGap;
    });
  }

  Future<void> _resetAllUiPrefs() async {
    _restoreDefaultFonts(includeScale: true);
    _restoreDefaultColumns();
    await _saveUiPrefs();
  }

  Future<void> _openUiSettingsDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            void updateLive(VoidCallback updater) {
              setState(updater);
              setDialogState(() {});
            }

            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980, maxHeight: 740),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Configuración visual de Facturación',
                        style: Theme.of(dialogContext).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ajusta fuentes y anchos de columnas. Los cambios se guardan en este navegador.',
                        style: Theme.of(dialogContext).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildConfigSectionTitle(dialogContext, 'Escala Global'),
                              _buildConfigSlider(
                                context: dialogContext,
                                label: 'Escala general',
                                value: _facturacionFontScale,
                                min: _kMinFontScale,
                                max: _kMaxFontScale,
                                divisions: _kFontScaleDivisions,
                                displayValue:
                                    '${_facturacionFontScale.toStringAsFixed(2)}x',
                                onChanged: (value) {
                                  updateLive(() {
                                    _facturacionFontScale = double.parse(
                                      value.toStringAsFixed(2),
                                    );
                                  });
                                },
                                onChangeEnd: (_) => _saveUiPrefs(),
                              ),
                              const SizedBox(height: 10),
                              _buildConfigSectionTitle(
                                dialogContext,
                                'Fuentes por componente',
                              ),
                              _buildConfigSlider(
                                context: dialogContext,
                                label: 'AppBar título',
                                value: _fontAppBarTitle,
                                min: 10,
                                max: 28,
                                divisions: 72,
                                onChanged: (value) =>
                                    updateLive(() => _fontAppBarTitle = value),
                                onChangeEnd: (_) => _saveUiPrefs(),
                              ),
                              _buildConfigSlider(
                                context: dialogContext,
                                label: 'Título grande',
                                value: _fontTitleLarge,
                                min: _kMinFontSize,
                                max: _kMaxFontSize,
                                divisions: 84,
                                onChanged: (value) =>
                                    updateLive(() => _fontTitleLarge = value),
                                onChangeEnd: (_) => _saveUiPrefs(),
                              ),
                              _buildConfigSlider(
                                context: dialogContext,
                                label: 'Título mediano',
                                value: _fontTitleMedium,
                                min: _kMinFontSize,
                                max: _kMaxFontSize,
                                divisions: 84,
                                onChanged: (value) =>
                                    updateLive(() => _fontTitleMedium = value),
                                onChangeEnd: (_) => _saveUiPrefs(),
                              ),
                              _buildConfigSlider(
                                context: dialogContext,
                                label: 'Título pequeño',
                                value: _fontTitleSmall,
                                min: _kMinFontSize,
                                max: _kMaxFontSize,
                                divisions: 84,
                                onChanged: (value) =>
                                    updateLive(() => _fontTitleSmall = value),
                                onChangeEnd: (_) => _saveUiPrefs(),
                              ),
                              _buildConfigSlider(
                                context: dialogContext,
                                label: 'Etiqueta grande',
                                value: _fontLabelLarge,
                                min: _kMinFontSize,
                                max: _kMaxFontSize,
                                divisions: 84,
                                onChanged: (value) =>
                                    updateLive(() => _fontLabelLarge = value),
                                onChangeEnd: (_) => _saveUiPrefs(),
                              ),
                              _buildConfigSlider(
                                context: dialogContext,
                                label: 'Etiqueta mediana',
                                value: _fontLabelMedium,
                                min: _kMinFontSize,
                                max: _kMaxFontSize,
                                divisions: 84,
                                onChanged: (value) =>
                                    updateLive(() => _fontLabelMedium = value),
                                onChangeEnd: (_) => _saveUiPrefs(),
                              ),
                              _buildConfigSlider(
                                context: dialogContext,
                                label: 'Etiqueta pequeña',
                                value: _fontLabelSmall,
                                min: _kMinFontSize,
                                max: _kMaxFontSize,
                                divisions: 84,
                                onChanged: (value) =>
                                    updateLive(() => _fontLabelSmall = value),
                                onChangeEnd: (_) => _saveUiPrefs(),
                              ),
                              _buildConfigSlider(
                                context: dialogContext,
                                label: 'Texto body grande',
                                value: _fontBodyLarge,
                                min: _kMinFontSize,
                                max: _kMaxFontSize,
                                divisions: 84,
                                onChanged: (value) =>
                                    updateLive(() => _fontBodyLarge = value),
                                onChangeEnd: (_) => _saveUiPrefs(),
                              ),
                              _buildConfigSlider(
                                context: dialogContext,
                                label: 'Texto body mediano',
                                value: _fontBodyMedium,
                                min: _kMinFontSize,
                                max: _kMaxFontSize,
                                divisions: 84,
                                onChanged: (value) =>
                                    updateLive(() => _fontBodyMedium = value),
                                onChangeEnd: (_) => _saveUiPrefs(),
                              ),
                              _buildConfigSlider(
                                context: dialogContext,
                                label: 'Texto body pequeño',
                                value: _fontBodySmall,
                                min: _kMinFontSize,
                                max: _kMaxFontSize,
                                divisions: 84,
                                onChanged: (value) =>
                                    updateLive(() => _fontBodySmall = value),
                                onChangeEnd: (_) => _saveUiPrefs(),
                              ),
                              _buildConfigSlider(
                                context: dialogContext,
                                label: 'Texto botones',
                                value: _fontButton,
                                min: _kMinFontSize,
                                max: _kMaxFontSize,
                                divisions: 84,
                                onChanged: (value) =>
                                    updateLive(() => _fontButton = value),
                                onChangeEnd: (_) => _saveUiPrefs(),
                              ),
                              _buildConfigSlider(
                                context: dialogContext,
                                label: 'Header tabla',
                                value: _fontDataHeader,
                                min: _kMinFontSize,
                                max: _kMaxFontSize,
                                divisions: 84,
                                onChanged: (value) =>
                                    updateLive(() => _fontDataHeader = value),
                                onChangeEnd: (_) => _saveUiPrefs(),
                              ),
                              _buildConfigSlider(
                                context: dialogContext,
                                label: 'Celdas tabla',
                                value: _fontDataCell,
                                min: _kMinFontSize,
                                max: _kMaxFontSize,
                                divisions: 84,
                                onChanged: (value) =>
                                    updateLive(() => _fontDataCell = value),
                                onChangeEnd: (_) => _saveUiPrefs(),
                              ),
                              const SizedBox(height: 10),
                              _buildConfigSectionTitle(
                                dialogContext,
                                'Ancho por columna',
                              ),
                              _buildConfigSlider(
                                context: dialogContext,
                                label: 'Selector',
                                value: _wSelector,
                                min: 50,
                                max: 120,
                                divisions: 70,
                                onChanged: (value) =>
                                    updateLive(() => _wSelector = value),
                                onChangeEnd: (_) => _saveUiPrefs(),
                              ),
                              _buildConfigSlider(
                                context: dialogContext,
                                label: 'ESTATUS',
                                value: _wEstatus,
                                min: 90,
                                max: 260,
                                divisions: 170,
                                onChanged: (value) =>
                                    updateLive(() => _wEstatus = value),
                                onChangeEnd: (_) => _saveUiPrefs(),
                              ),
                              _buildConfigSlider(
                                context: dialogContext,
                                label: 'RfcEmisor',
                                value: _wRfcEmisor,
                                min: 80,
                                max: 420,
                                divisions: 170,
                                onChanged: (value) =>
                                    updateLive(() => _wRfcEmisor = value),
                                onChangeEnd: (_) => _saveUiPrefs(),
                              ),
                              _buildConfigSlider(
                                context: dialogContext,
                                label: 'Us Cfdi',
                                value: _wUsoCfdi,
                                min: 70,
                                max: 220,
                                divisions: 150,
                                onChanged: (value) =>
                                    updateLive(() => _wUsoCfdi = value),
                                onChangeEnd: (_) => _saveUiPrefs(),
                              ),
                              _buildConfigSlider(
                                context: dialogContext,
                                label: 'CLIEN',
                                value: _wClien,
                                min: 70,
                                max: 220,
                                divisions: 150,
                                onChanged: (value) =>
                                    updateLive(() => _wClien = value),
                                onChangeEnd: (_) => _saveUiPrefs(),
                              ),
                              _buildConfigSlider(
                                context: dialogContext,
                                label: 'RfcReceptor',
                                value: _wRfcReceptor,
                                min: 90,
                                max: 420,
                                divisions: 165,
                                onChanged: (value) =>
                                    updateLive(() => _wRfcReceptor = value),
                                onChangeEnd: (_) => _saveUiPrefs(),
                              ),
                              _buildConfigSlider(
                                context: dialogContext,
                                label: 'Nombre/Razon Social',
                                value: _wRazonSocial,
                                min: 130,
                                max: 520,
                                divisions: 195,
                                onChanged: (value) =>
                                    updateLive(() => _wRazonSocial = value),
                                onChangeEnd: (_) => _saveUiPrefs(),
                              ),
                              _buildConfigSlider(
                                context: dialogContext,
                                label: 'IDFOL',
                                value: _wIdFol,
                                min: 110,
                                max: 420,
                                divisions: 155,
                                onChanged: (value) =>
                                    updateLive(() => _wIdFol = value),
                                onChangeEnd: (_) => _saveUiPrefs(),
                              ),
                              _buildConfigSlider(
                                context: dialogContext,
                                label: 'FCN',
                                value: _wFcn,
                                min: 80,
                                max: 220,
                                divisions: 140,
                                onChanged: (value) =>
                                    updateLive(() => _wFcn = value),
                                onChangeEnd: (_) => _saveUiPrefs(),
                              ),
                              _buildConfigSlider(
                                context: dialogContext,
                                label: 'IMPT',
                                value: _wImpt,
                                min: 80,
                                max: 220,
                                divisions: 140,
                                onChanged: (value) =>
                                    updateLive(() => _wImpt = value),
                                onChangeEnd: (_) => _saveUiPrefs(),
                              ),
                              _buildConfigSlider(
                                context: dialogContext,
                                label: 'F. Pago',
                                value: _wFPago,
                                min: 70,
                                max: 220,
                                divisions: 150,
                                onChanged: (value) =>
                                    updateLive(() => _wFPago = value),
                                onChangeEnd: (_) => _saveUiPrefs(),
                              ),
                              _buildConfigSlider(
                                context: dialogContext,
                                label: 'MetodoD',
                                value: _wMetodo,
                                min: 80,
                                max: 220,
                                divisions: 140,
                                onChanged: (value) =>
                                    updateLive(() => _wMetodo = value),
                                onChangeEnd: (_) => _saveUiPrefs(),
                              ),
                              _buildConfigSlider(
                                context: dialogContext,
                                label: 'N°Aut o Ref',
                                value: _wAutRef,
                                min: 95,
                                max: 420,
                                divisions: 162,
                                onChanged: (value) =>
                                    updateLive(() => _wAutRef = value),
                                onChangeEnd: (_) => _saveUiPrefs(),
                              ),
                              _buildConfigSlider(
                                context: dialogContext,
                                label: 'Tipofact',
                                value: _wTipoFact,
                                min: 90,
                                max: 260,
                                divisions: 170,
                                onChanged: (value) =>
                                    updateLive(() => _wTipoFact = value),
                                onChangeEnd: (_) => _saveUiPrefs(),
                              ),
                              _buildConfigSlider(
                                context: dialogContext,
                                label: 'Separación entre campos',
                                value: _columnGap,
                                min: _kMinColumnGap,
                                max: _kMaxColumnGap,
                                divisions: 44,
                                onChanged: (value) =>
                                    updateLive(() => _columnGap = value),
                                onChangeEnd: (_) => _saveUiPrefs(),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        alignment: WrapAlignment.end,
                        runSpacing: 8,
                        spacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: () {
                              _restoreDefaultFonts();
                              setDialogState(() {});
                              _saveUiPrefs();
                            },
                            child: const Text('Restablecer fuentes'),
                          ),
                          OutlinedButton(
                            onPressed: () {
                              _restoreDefaultColumns();
                              setDialogState(() {});
                              _saveUiPrefs();
                            },
                            child: const Text('Restablecer columnas'),
                          ),
                          OutlinedButton(
                            onPressed: () async {
                              await _resetAllUiPrefs();
                              if (!dialogContext.mounted) return;
                              setDialogState(() {});
                            },
                            child: const Text('Restablecer todo'),
                          ),
                          FilledButton(
                            onPressed: () {
                              _saveUiPrefs();
                              Navigator.of(dialogContext).pop();
                            },
                            child: const Text('Cerrar'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildConfigSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }

  Widget _buildConfigSlider({
    required BuildContext context,
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
    ValueChanged<double>? onChangeEnd,
    String? displayValue,
  }) {
    final safeValue = value.clamp(min, max).toDouble();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 210,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: Slider(
              min: min,
              max: max,
              divisions: divisions,
              value: safeValue,
              label: displayValue ?? safeValue.toStringAsFixed(1),
              onChanged: onChanged,
              onChangeEnd: onChangeEnd,
            ),
          ),
          SizedBox(
            width: 62,
            child: Text(
              displayValue ?? safeValue.toStringAsFixed(1),
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
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
    ref.read(selectedFacturasUnificacionProvider.notifier).state = <String>{};
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
    ref.read(selectedFacturasUnificacionProvider.notifier).state = <String>{};
    ref.invalidate(facturasPendientesProvider);
  }

  void _clearFilters(WidgetRef ref) {
    ref.read(facturacionDraftFilterSucProvider.notifier).state = '';
    ref.read(facturacionDraftFilterEstatusProvider.notifier).state = 'PENDIENTE';
    ref.read(facturacionDraftFilterRazonSocialProvider.notifier).state = '';
    ref.read(facturacionDraftFilterRfcReceptorProvider.notifier).state = '';
    ref.read(facturacionDraftFilterClienProvider.notifier).state = '';
    ref.read(facturacionDraftFilterIdFolProvider.notifier).state = '';
    ref.read(facturacionDraftFilterTipoFactProvider.notifier).state = '';

    ref.read(facturacionFilterSucProvider.notifier).state = '';
    ref.read(facturacionFilterEstatusProvider.notifier).state = 'PENDIENTE';
    ref.read(facturacionFilterRazonSocialProvider.notifier).state = '';
    ref.read(facturacionFilterRfcReceptorProvider.notifier).state = '';
    ref.read(facturacionFilterClienProvider.notifier).state = '';
    ref.read(facturacionFilterIdFolProvider.notifier).state = '';
    ref.read(facturacionFilterTipoFactProvider.notifier).state = '';

    ref.read(facturacionFilterInputRevisionProvider.notifier).state++;
    _setPage(ref, 1);
    ref.read(selectedFacturasUnificacionProvider.notifier).state = <String>{};
    ref.read(facturacionIdFolSelectionFilterProvider.notifier).state = <String>{};
    ref.invalidate(facturasPendientesProvider);
  }

  Widget _buildFiltersPanel(BuildContext context, WidgetRef ref) {
    final revision = ref.watch(facturacionFilterInputRevisionProvider);
    final draftSuc = ref.watch(facturacionDraftFilterSucProvider);
    final draftEstatus = ref.watch(facturacionDraftFilterEstatusProvider);
    final draftTipoFact = ref.watch(facturacionDraftFilterTipoFactProvider);
    final sucursales = ref.watch(sucursalesListProvider).maybeWhen(
          data: (items) {
            final ordered = [...items];
            ordered.sort((a, b) => a.suc.compareTo(b.suc));
            return ordered;
          },
          orElse: () => const <SucursalModel>[],
        );
    final sucItems = <DropdownMenuItem<String>>[
      const DropdownMenuItem(
        value: '',
        child: Text('TODAS'),
      ),
      ...sucursales.map((sucursal) {
        final desc = (sucursal.desc ?? '').trim();
        final label =
            desc.isEmpty ? sucursal.suc : '${sucursal.suc} - $desc';
        return DropdownMenuItem<String>(
          value: sucursal.suc,
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }),
    ];
    final selectedDraftSuc = sucItems.any((item) => item.value == draftSuc)
        ? draftSuc
        : '';
    final selectedDraftEstatus = _estatusFilterOptions.contains(draftEstatus)
        ? draftEstatus
        : _estatusFilterOptions.first;
    const tipoFactItems = <DropdownMenuItem<String>>[
      DropdownMenuItem(
        value: '',
        child: Text('TODOS'),
      ),
      DropdownMenuItem(
        value: 'INDIVIDUAL',
        child: Text('INDIVIDUAL'),
      ),
      DropdownMenuItem(
        value: 'CREDITO',
        child: Text('CREDITO'),
      ),
    ];
    final selectedDraftTipoFact = tipoFactItems.any(
      (item) => item.value == draftTipoFact,
    )
        ? draftTipoFact
        : '';

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
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey(
                      'ff-suc-$revision-$selectedDraftSuc-${sucItems.length}',
                    ),
                    initialValue: selectedDraftSuc,
                    isExpanded: true,
                    items: sucItems,
                    onChanged: (value) {
                      ref.read(facturacionDraftFilterSucProvider.notifier).state =
                          value ?? '';
                    },
                    decoration: inputDecoration.copyWith(labelText: 'SUC'),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('ff-estatus-$revision-$selectedDraftEstatus'),
                    initialValue: selectedDraftEstatus,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(
                        value: 'PENDIENTE',
                        child: Text('PENDIENTE'),
                      ),
                      DropdownMenuItem(
                        value: 'CANCELACION PENDIENTE',
                        child: Text('CANCELACION PENDIENTE'),
                      ),
                      DropdownMenuItem(
                        value: 'FACTURADO',
                        child: Text('FACTURADO'),
                      ),
                      DropdownMenuItem(
                        value: 'FACTURADO Y CANCELACION PENDIENTE',
                        child: Text('FACTURADO Y CANCELACION PENDIENTE'),
                      ),
                      DropdownMenuItem(
                        value: 'CON ERROR',
                        child: Text('CON ERROR'),
                      ),
                    ],
                    onChanged: (value) {
                      ref
                          .read(facturacionDraftFilterEstatusProvider.notifier)
                          .state = value ?? 'PENDIENTE';
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
                  child: DropdownButtonFormField<String>(
                    key: ValueKey(
                      'ff-tipofact-$revision-$selectedDraftTipoFact',
                    ),
                    initialValue: selectedDraftTipoFact,
                    isExpanded: true,
                    items: tipoFactItems,
                    onChanged: (value) {
                      ref
                          .read(facturacionDraftFilterTipoFactProvider.notifier)
                          .state = value ?? '';
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
    Set<String> selectedIdFolsForUnificacion, {
    required List<Map<String, dynamic>> visibleRows,
  }) {
    final selectedStatus = selectedRow == null
        ? '-'
        : _pickText(selectedRow, const ['ESTATUS', 'estatus']);
    final selectedCfdiStatus = selectedRow == null
        ? '-'
        : _pickText(selectedRow, const ['CFDI_STATUS', 'cfdi_status']);
    final selectedCfdiError = selectedRow == null
        ? '-'
        : _pickText(selectedRow, const ['CFDI_ERROR_MSG', 'cfdi_error_msg']);
    final selectedIds = selectedIdFolsForUnificacion.toList()..sort();
    final canUnificar = selectedIds.length >= 2;
    final canReversar =
        selectedRow != null && _isRowReversibleForUnificacion(selectedRow);
    final grupoReversar = selectedRow == null
        ? ''
        : _pickText(selectedRow, const ['GRUPMASI', 'grupmasi']);

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
            Text(
              'CFDI_STATUS: $selectedCfdiStatus',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (selectedCfdiError != '-' && selectedCfdiError.isNotEmpty)
              Text(
                'CFDI_ERROR_MSG: $selectedCfdiError',
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 4),
            Text(
              'Seleccionados para unificación: ${selectedIds.length}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed:
                      canUnificar ? () => _onUnificarSeleccion(ref, selectedIds) : null,
                  child: const Text('UNIFICAR'),
                ),
                OutlinedButton(
                  onPressed: canReversar
                      ? () => _onReversarUnificacion(
                            ref,
                            selectedIdFol ?? '',
                            grupoReversar,
                          )
                      : null,
                  child: const Text('REVERSAR UNIFICACIÓN'),
                ),
                OutlinedButton(
                  onPressed: selectedIdFol == null
                      ? null
                      : () => _onValidar(ref, selectedIdFol),
                  child: const Text('Validar'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _openIdFolSelectorDialog(
                    context: context,
                    ref: ref,
                    visibleRows: visibleRows,
                  ),
                  icon: const Icon(Icons.upload_file, size: 18),
                  label: const Text('Cargar IDFOL'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openIdFolSelectorDialog({
    required BuildContext context,
    required WidgetRef ref,
    required List<Map<String, dynamic>> visibleRows,
  }) async {
    if (!mounted) return;
    final manualController = TextEditingController();
    var validating = false;
    var lastValidationMsg = '';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final selectorState = ref.read(facturacionIdFolSelectorProvider);

            Future<void> addManual() async {
              final value = manualController.text.trim();
              if (value.isEmpty) return;
              ref.read(facturacionIdFolSelectorProvider.notifier).add(value);
              manualController.clear();
              setDialogState(() {
                lastValidationMsg = '';
              });
            }

            Future<void> importExcel() async {
              try {
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: const ['xlsx', 'xls'],
                  withData: true,
                );
                if (!context.mounted) return;
                if (result == null || result.files.isEmpty) return;
                final file = result.files.first;
                final bytes = file.bytes;
                if (bytes == null) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No se pudo leer el archivo seleccionado.'),
                    ),
                  );
                  return;
                }
                final ids = _extractIdFolsFromExcel(bytes);
                if (ids.isEmpty) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('El archivo no tiene datos en la primera columna.'),
                    ),
                  );
                  return;
                }
                ref
                    .read(facturacionIdFolSelectorProvider.notifier)
                    .setAll(ids, append: true);
                setDialogState(() {
                  lastValidationMsg =
                      'Se agregaron ${ids.length} IDFOL de ${file.name.isNotEmpty ? file.name : 'Excel'}.';
                });
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _formatActionError('No se pudo leer el Excel', e),
                    ),
                  ),
                );
              }
            }

            Future<void> validar() async {
              if (selectorState.idFols.isEmpty || validating) return;
              if (selectorState.idFols.length > 500) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('El límite es de 500 IDFOL por validación.'),
                  ),
                );
                return;
              }
              setDialogState(() {
                validating = true;
                lastValidationMsg = '';
              });
              try {
                final api = ref.read(facturacionApiProvider);
                final res = await api.validarIdFolsPendientes(
                  selectorState.idFols,
                );
                if (!context.mounted) return;
                final validos = (res['validos'] is List)
                    ? (res['validos'] as List)
                        .whereType<Map>()
                        .map(
                          (row) => _firstNonEmptyText(
                            [row['idFol'], row['IDFOL']],
                          ).toUpperCase(),
                        )
                        .where((id) => id.isNotEmpty)
                        .toList()
                    : const <String>[];
                final rechazados = (res['rechazados'] is List)
                    ? (res['rechazados'] as List)
                        .whereType<Map>()
                        .map(
                          (row) => FacturacionIdFolIssue(
                            idFol: _firstNonEmptyText(
                              [row['idFol'], row['IDFOL']],
                            ).toUpperCase(),
                            motivo: _firstNonEmptyText(
                              [row['motivo'], row['MOTIVO']],
                              fallback: 'ERROR',
                            ),
                          ),
                        )
                        .toList()
                    : const <FacturacionIdFolIssue>[];
                ref
                    .read(facturacionIdFolSelectorProvider.notifier)
                    .setValidation(validos, rechazados);
                setDialogState(() {
                  lastValidationMsg =
                      'Válidos (PENDIENTE): ${validos.length} | Rechazados: ${rechazados.length}';
                });
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _formatActionError('No se pudo validar la lista', e),
                    ),
                  ),
                );
              } finally {
                setDialogState(() {
                  validating = false;
                });
              }
            }

            void seleccionar() {
              final validos = selectorState.validos.toSet();
              if (!selectorState.validated || validos.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Valida la lista antes de presionar "SELECCIONAR relacionados".',
                    ),
                  ),
                );
                return;
              }
              ref
                  .read(facturacionIdFolSelectionFilterProvider.notifier)
                  .state = validos;
              ref.read(facturacionPageSizeProvider.notifier).state = 100;
              ref.read(facturacionPageProvider.notifier).state = 1;
              ref.read(selectedFacturasUnificacionProvider.notifier).state =
                  validos;
              ref.read(selectedFacturaIdFolProvider.notifier).state =
                  validos.isNotEmpty ? validos.first : null;
              ref.invalidate(facturasPendientesProvider);
              final result = _applyValidatedSelection(
                ref: ref,
                validos: validos,
                visibleRows: visibleRows,
              );
              Navigator.of(dialogContext).pop();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    result['applied'] == 0
                        ? 'No hay folios PENDIENTE de la lista en la página actual.'
                        : 'Seleccionados ${result['applied']} en la página | Fuera de página: ${result['outOfView']} | En página con otro estatus: ${result['skippedNotPending']}.',
                  ),
                ),
              );
            }

            return Dialog(
              insetPadding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Marcar folios por IDFOL',
                          style: Theme.of(dialogContext)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Captura manual o carga un Excel con una columna IDFOL. Solo se seleccionan folios con ESTATUS "PENDIENTE" visibles en la consulta.',
                          style: Theme.of(dialogContext).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: manualController,
                                onSubmitted: (_) => addManual(),
                                decoration: const InputDecoration(
                                  labelText: 'Agregar IDFOL',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: addManual,
                              child: const Text('Agregar'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: importExcel,
                          icon: const Icon(Icons.file_upload_outlined, size: 18),
                          label: const Text('Cargar Excel (columna IDFOL)'),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Capturados: ${selectorState.idFols.length} | Validados PENDIENTE: ${selectorState.validos.length}',
                          style: Theme.of(dialogContext).textTheme.bodySmall,
                        ),
                        if (lastValidationMsg.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            lastValidationMsg,
                            style: Theme.of(dialogContext)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.green[800]),
                          ),
                        ],
                        if (selectorState.idFols.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: selectorState.idFols.map((id) {
                              return InputChip(
                                label: Text(id),
                                onDeleted: () {
                                  ref
                                      .read(facturacionIdFolSelectorProvider.notifier)
                                      .remove(id);
                                  setDialogState(() {});
                                },
                              );
                            }).toList(),
                          ),
                        ],
                        if (selectorState.issues.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            'Observaciones',
                            style: Theme.of(dialogContext).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: selectorState.issues.take(6).map((issue) {
                              return Text(
                                '${issue.idFol}: ${issue.motivo}',
                                style: Theme.of(dialogContext)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: const Color(0xFFB71C1C)),
                              );
                            }).toList(),
                          ),
                          if (selectorState.issues.length > 6)
                            Text(
                              '+${selectorState.issues.length - 6} adicionales...',
                              style: Theme.of(dialogContext).textTheme.bodySmall,
                            ),
                        ],
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            FilledButton(
                              onPressed: validating || selectorState.idFols.isEmpty
                                  ? null
                                  : validar,
                              child: validating
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Text('Validar'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.tonal(
                              onPressed: validating
                                  ? null
                                  : selectorState.idFols.isEmpty
                                      ? null
                                      : () {
                                          ref
                                              .read(
                                                facturacionIdFolSelectorProvider.notifier,
                                              )
                                              .clear();
                                          setDialogState(() {
                                            lastValidationMsg = '';
                                          });
                                        },
                              child: const Text('Limpiar'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: validating ||
                                      !selectorState.validated ||
                                      selectorState.validos.isEmpty
                                  ? null
                                  : seleccionar,
                              child: const Text('SELECCIONAR relacionados'),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () => Navigator.of(dialogContext).pop(),
                              child: const Text('Cerrar'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    manualController.dispose();
  }

  List<String> _extractIdFolsFromExcel(Uint8List bytes) {
    final excel = xls.Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) return const <String>[];
    final sheet = excel.tables.values.first;
    final out = <String>[];
    for (var r = 0; r < sheet.rows.length; r++) {
      final row = sheet.rows[r];
      if (row.isEmpty) continue;
      final text = _excelCellToText(row.first);
      if (text.isEmpty) continue;
      if (r == 0 && text.toUpperCase() == 'IDFOL') continue;
      out.add(text);
    }
    return out;
  }

  String _excelCellToText(xls.Data? cell) {
    if (cell == null) return '';
    final raw = cell.value;
    if (raw == null) return '';
    return '$raw'.trim();
  }

  Map<String, int> _applyValidatedSelection({
    required WidgetRef ref,
    required Set<String> validos,
    required List<Map<String, dynamic>> visibleRows,
  }) {
    final normalizedValidos = validos
        .map((id) => id.trim().toUpperCase())
        .where((id) => id.isNotEmpty && id != '-')
        .toSet();
    final selected = <String>{};
    var skippedNotPending = 0;
    // Selecciona sobre la página visible ya filtrada.
    for (final row in visibleRows) {
      final id = _pickText(row, const ['IDFOL', 'idfol']).toUpperCase();
      if (id.isEmpty || id == '-') continue;
      if (!normalizedValidos.contains(id)) continue;
      final estatus = _pickText(row, const ['ESTATUS', 'estatus']).toUpperCase();
      if (estatus != 'PENDIENTE') {
        skippedNotPending++;
        continue;
      }
      selected.add(id);
    }
    final outOfView = normalizedValidos.length - selected.length;
    ref.read(selectedFacturasUnificacionProvider.notifier).state = selected;
    ref.read(selectedFacturaIdFolProvider.notifier).state =
        selected.isNotEmpty ? selected.first : null;
    return {
      'applied': selected.length,
      'outOfView': outOfView < 0 ? 0 : outOfView,
      'skippedNotPending': skippedNotPending,
    };
  }

  Widget _buildDataRow(
    WidgetRef ref,
    Map<String, dynamic> row,
    {
    required Set<String> selectedIdFolsForUnificacion,
  }) {
    final idFol = _pickText(row, const ['IDFOL', 'idfol']);
    final normalizedIdFol = idFol.toUpperCase();
    final canSelect = idFol != '-';
    final canSelectForUnificacion = _isRowEligibleForUnificacion(row);
    final isSelectedForUnificacion =
        canSelect && selectedIdFolsForUnificacion.contains(normalizedIdFol);

    final rfcEmisor = _pickText(row, const ['RFCEMISOR', 'RfcEmisor']);
    final usoCfdi = _pickText(row, const ['USOCFDI', 'UsoCfdi']);
    final clien = _formatClienteNumero(
      _pickValue(row, const ['CLIEN', 'CLIENTE', 'client']),
    );
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
              ref
                  .read(facturacionIdFolSelectionFilterProvider.notifier)
                  .state = <String>{};
            }
          : null,
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: _gridRowVerticalPadding,
          horizontal: _kRowHorizontalPadding,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: _wSelector + _columnGap,
              child: Row(
                children: [
                  SizedBox(
                    width: _wSelector,
                    child: Align(
                      alignment: Alignment.center,
                      child: Wrap(
                        spacing: 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SizedBox(
                            width: 24,
                            child: Checkbox(
                              value:
                                  canSelectForUnificacion && isSelectedForUnificacion,
                              onChanged: canSelectForUnificacion
                                  ? (value) {
                                      _toggleUnificacionSelection(
                                        ref,
                                        normalizedIdFol,
                                        value ?? false,
                                      );
                                    }
                                  : null,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                          SizedBox(
                            width: 24,
                            child: IgnorePointer(
                              ignoring: !canSelect,
                              child: Radio<String>(
                                value: idFol,
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: _columnGap),
                ],
              ),
            ),
            _dataCell(estatus, _wEstatus),
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
          ],
        ),
      ),
    );
  }

  void _toggleUnificacionSelection(
    WidgetRef ref,
    String idFol,
    bool selected,
  ) {
    final normalized = idFol.trim().toUpperCase();
    if (normalized.isEmpty || normalized == '-') return;
    final current = ref.read(selectedFacturasUnificacionProvider);
    final next = <String>{...current};
    if (selected) {
      next.add(normalized);
    } else {
      next.remove(normalized);
    }
    ref.read(selectedFacturasUnificacionProvider.notifier).state = next;
  }

  bool _sameStringSet(Set<String> a, Set<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (final value in a) {
      if (!b.contains(value)) return false;
    }
    return true;
  }

  bool _isRowEligibleForUnificacion(Map<String, dynamic> row) {
    final idFol = _pickText(row, const ['IDFOL', 'idfol']);
    if (idFol == '-') return false;
    final estatus = _pickText(row, const ['ESTATUS', 'estatus']).toUpperCase();
    final grup = _pickText(row, const ['GRUPMASI', 'grupmasi']).toUpperCase();

    if (estatus.contains('ANULADO')) return false;
    if (estatus.contains('UNIFICADO')) return false;
    if (estatus.contains('FACTUR')) return false;
    if (estatus.contains('EXCEL GEN')) return false;
    if (grup.startsWith('U')) return false;
    return estatus == 'PENDIENTE';
  }

  bool _isRowReversibleForUnificacion(Map<String, dynamic> row) {
    final idFol = _pickText(row, const ['IDFOL', 'idfol']).toUpperCase();
    final grup = _pickText(row, const ['GRUPMASI', 'grupmasi']).toUpperCase();
    final estatus = _pickText(row, const ['ESTATUS', 'estatus']).toUpperCase();
    if (idFol == '-' || grup == '-' || grup.isEmpty) return false;
    if (!grup.startsWith('U')) return false;
    if (idFol != grup) return false;
    if (estatus == 'ANULADO') return false;
    return true;
  }

  List<String> _toStringList(dynamic raw) {
    if (raw is List) {
      return raw
          .map((item) {
            if (item is Map) {
              final map = Map<String, dynamic>.from(item);
              return _firstNonEmptyText([
                map['message'],
                map['msg'],
                map['value'],
                map['text'],
              ]);
            }
            return _asCleanText(item);
          })
          .where((text) => text.isNotEmpty)
          .toList();
    }

    final text = _asCleanText(raw);
    if (text.isEmpty) return const <String>[];
    try {
      final parsed = jsonDecode(text);
      if (parsed is List) {
        return _toStringList(parsed);
      }
    } catch (_) {
      return <String>[text];
    }
    return <String>[text];
  }

  Future<void> _onUnificarSeleccion(
    WidgetRef ref,
    List<String> selectedIdFols,
  ) async {
    final ids = selectedIdFols
        .map((id) => id.trim().toUpperCase())
        .where((id) => id.isNotEmpty && id != '-')
        .toList();

    if (ids.length < 2) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona al menos 2 tickets para unificar.'),
        ),
      );
      return;
    }

    if (!mounted) return;
    try {
      final api = ref.read(facturacionApiProvider);
      final preview = await api.previewUnificacion(ids);
      if (!mounted) return;

      final valid = _asBool(preview['valid'] ?? preview['VALIDO']);
      final bloqueos = _toStringList(
        preview['bloqueos'] ?? preview['BLOQUEOS_JSON'],
      );
      final message = _asCleanText(preview['message'] ?? preview['MENSAJE']);

      if (!valid) {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('No se puede unificar'),
              content: SizedBox(
                width: 540,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.isEmpty
                            ? 'La selección no cumple las reglas de negocio.'
                            : message,
                      ),
                      if (bloqueos.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        for (final bloque in bloqueos)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text('• $bloque'),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('CERRAR'),
                ),
              ],
            );
          },
        );
        return;
      }

      final comentarioCtrl = TextEditingController();
      var confirmar = false;
      var comentarioUnificacion = '';
      try {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) {
            return StatefulBuilder(
              builder: (dialogContext, setDialogState) {
                return AlertDialog(
                  title: const Text('Confirmar unificación'),
                  content: SizedBox(
                    width: 640,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Tickets seleccionados: ${ids.length}'),
                          Text('Total: ${_formatMoney(preview['total'])}'),
                          Text(
                            'CLIEN: ${_formatClienteNumero(preview['clien'])}',
                          ),
                          Text(
                            'Forma pago: ${_asCleanText(preview['formaPago'])}',
                          ),
                          Text('TIPOVTA: ${_asCleanText(preview['tipoVta'])}'),
                          Text(
                            'RFC receptor: ${_asCleanText(preview['rfcReceptor'])}',
                          ),
                          Text(
                            'Razón social: ${_asCleanText(preview['razonSocialReceptor'])}',
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: comentarioCtrl,
                            maxLength: 500,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              labelText: 'Comentario (opcional)',
                            ),
                            onChanged: (_) => setDialogState(() {}),
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('CANCELAR'),
                    ),
                    FilledButton(
                      onPressed: () {
                        comentarioUnificacion = comentarioCtrl.text.trim();
                        confirmar = true;
                        Navigator.of(dialogContext).pop();
                      },
                      child: const Text('UNIFICAR'),
                    ),
                  ],
                );
              },
            );
          },
        );
      } finally {
        comentarioCtrl.dispose();
      }

      if (!confirmar) return;
      if (!mounted) return;

      final result = await api.crearUnificacion(
        ids,
        comentario: comentarioUnificacion,
      );
      if (!mounted) return;

      final grupoId = _asCleanText(result['grupoId']);
      final idFolUnificado = _asCleanText(result['idFolUnificado']);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unificación aplicada. Grupo: ${grupoId.isEmpty ? '-' : grupoId} | Folio: ${idFolUnificado.isEmpty ? '-' : idFolUnificado}',
          ),
        ),
      );

      ref.read(selectedFacturasUnificacionProvider.notifier).state = <String>{};
      ref.read(selectedFacturaIdFolProvider.notifier).state =
          idFolUnificado.isEmpty ? null : idFolUnificado;
      ref.invalidate(facturasPendientesProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_formatActionError('No se pudo unificar', e)),
        ),
      );
    }
  }

  Future<void> _onReversarUnificacion(
    WidgetRef ref,
    String selectedIdFol,
    String grupoIdRaw,
  ) async {
    final grupoId = grupoIdRaw.trim().toUpperCase();
    if (grupoId.isEmpty || !grupoId.startsWith('U')) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'El folio seleccionado no corresponde a una unificación reversible.',
          ),
        ),
      );
      return;
    }

    final motivoCtrl = TextEditingController();
    var motivoError = '';
    var confirmar = false;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              return AlertDialog(
                title: const Text('Reversar unificación'),
                content: SizedBox(
                  width: 560,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Folio seleccionado: $selectedIdFol'),
                        Text('Grupo: $grupoId'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: motivoCtrl,
                          maxLength: 500,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Motivo (obligatorio)',
                          ),
                          onChanged: (_) {
                            if (motivoError.isEmpty) return;
                            setDialogState(() {
                              motivoError = '';
                            });
                          },
                        ),
                        if (motivoError.isNotEmpty)
                          Text(
                            motivoError,
                            style: const TextStyle(color: Color(0xFFB71C1C)),
                          ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('CANCELAR'),
                  ),
                  FilledButton(
                    onPressed: () {
                      final motivo = motivoCtrl.text.trim();
                      if (motivo.isEmpty) {
                        setDialogState(() {
                          motivoError = 'Captura un motivo para continuar.';
                        });
                        return;
                      }
                      confirmar = true;
                      Navigator.of(dialogContext).pop();
                    },
                    child: const Text('REVERSAR'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (!confirmar) return;
      if (!mounted) return;

      final api = ref.read(facturacionApiProvider);
      final result = await api.reversarUnificacion(
        grupoId,
        motivo: motivoCtrl.text.trim(),
      );
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Reversa aplicada. Grupo: ${_asCleanText(result['grupoId'])}',
          ),
        ),
      );
      ref.read(selectedFacturasUnificacionProvider.notifier).state = <String>{};
      ref.read(selectedFacturaIdFolProvider.notifier).state = null;
      ref.invalidate(facturasPendientesProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _formatActionError('No se pudo reversar la unificación', e),
          ),
        ),
      );
    } finally {
      motivoCtrl.dispose();
    }
  }

  Future<void> _onValidar(WidgetRef ref, String idFol) async {
    if (!mounted) return;
    try {
      final api = ref.read(facturacionApiProvider);
      final result = await api.validar(idFol);
      if (!mounted) return;
      await _showDetalleValidacionDialog(
        idFol: idFol,
        result: result,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_formatActionError('No se pudo validar', e))),
      );
    }
  }

  Future<void> _showDetalleValidacionDialog({
    required String idFol,
    required Map<String, dynamic> result,
  }) async {
    if (!mounted) return;
    final api = ref.read(facturacionApiProvider);
    final validaciones = result['validaciones'] is Map
        ? Map<String, dynamic>.from(result['validaciones'] as Map)
        : const <String, dynamic>{};
    final totalesDetalle = result['totalesDetalle'] is Map
        ? Map<String, dynamic>.from(result['totalesDetalle'] as Map)
        : const <String, dynamic>{};
    final totales = result['totales'] is Map
        ? Map<String, dynamic>.from(result['totales'] as Map)
        : const <String, dynamic>{};
    final rows = (result['detalleArticulos'] is List)
        ? (result['detalleArticulos'] as List)
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .toList()
        : const <Map<String, dynamic>>[];

    final importeCuadra = _asBool(validaciones['importeCuadra']);
    final clienteFiscalCompleto = _asBool(validaciones['clienteFiscalCompleto']);
    final rfcGenerico = _asBool(validaciones['rfcGenerico']);
    final subtotalSatCuadra =
        validaciones.containsKey('subtotalSatCuadra')
            ? _asBool(validaciones['subtotalSatCuadra'])
            : true;
    final requiereAjusteSubtotalSat =
        validaciones.containsKey('requiereAjusteSubtotalSat')
            ? _asBool(validaciones['requiereAjusteSubtotalSat'])
            : false;
    final subtotalSatDiferencia =
        _asDouble(validaciones['subtotalSatDiferencia']) ?? 0;
    final camposFiscalesFaltantes =
        (validaciones['camposFiscalesFaltantes'] is List)
            ? (validaciones['camposFiscalesFaltantes'] as List)
                .map((e) => '$e'.trim())
                .where((e) => e.isNotEmpty)
                .toList()
            : const <String>[];
    final totalDetalle = _formatMoney(
      totalesDetalle['total'] ??
          rows.fold<double>(
            0,
            (acc, row) => acc + (_asDouble(row['Total']) ?? 0),
          ),
    );
    final totalCabecera = _formatMoney(
      totales['cabecera'] ?? totales['cabeceraOriginal'],
    );
    final diferencia = _formatMoney(totales['diferencia']);
    final clienteMap = _safeMap(result['cliente']);
    final headerMap = _safeMap(result['header']);
    final sucursalMap = _safeMap(result['sucursal']);
    final clienteId = _resolveClienteId(clienteMap);
    final rfcReceptor = _firstNonEmptyText([
      clienteMap['RFCRECEPTOR'],
      clienteMap['RfcReceptor'],
      headerMap['RfcReceptor'],
      headerMap['RFCRECEPTOR'],
    ], fallback: '-');
    final razonSocial = _firstNonEmptyText([
      clienteMap['RAZONSOCIALRECEPTOR'],
      clienteMap['RazonSocialReceptor'],
      headerMap['RazonSocialReceptor'],
      headerMap['RAZONSOCIALRECEPTOR'],
    ], fallback: '-');
    final regimenFiscal = _firstNonEmptyText([
      clienteMap['REGIMENFISCALRECEPTOR'],
      clienteMap['RegimenFiscalReceptor'],
      clienteMap['RegimenFiscalReceptorSAT'],
    ], fallback: '-');
    final usoCfdi = _firstNonEmptyText([
      clienteMap['USOCFDI'],
      clienteMap['UsoCfdi'],
      headerMap['UsoCfdi'],
      headerMap['USOCFDI'],
    ], fallback: '-');
    final codigoPostal = _firstNonEmptyText([
      clienteMap['CODIGOPOSTALRECEPTOR'],
      clienteMap['CodigoPostalReceptor'],
    ], fallback: '-');
    final emailReceptor = _firstNonEmptyText([
      clienteMap['EMAILRECEPTOR'],
      clienteMap['EmailReceptor'],
    ], fallback: '-');
    final rfcEmisor = _firstNonEmptyText([
      clienteMap['RFCEMISOR'],
      clienteMap['RfcEmisor'],
      headerMap['RfcEmisor'],
      headerMap['RFCEMISOR'],
      sucursalMap['RFC'],
    ], fallback: '-');
    final canFacturar = importeCuadra &&
        clienteFiscalCompleto &&
        camposFiscalesFaltantes.isEmpty &&
        rows.isNotEmpty;
    var facturando = false;
    var accionMsg = '';
    var accionError = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final media = MediaQuery.of(dialogContext).size;
        final maxWidth = math.min(media.width - 32, 1200.0);
        final maxHeight = media.height * 0.85;
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return Dialog(
              insetPadding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: maxWidth,
                  maxHeight: maxHeight,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Vista detalle factura',
                          style:
                              Theme.of(dialogContext).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ),
                      DefaultTextStyle(
                        style: Theme.of(dialogContext).textTheme.bodyMedium ??
                            const TextStyle(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Cabecera: $totalCabecera'),
                            Text('Detalle: $totalDetalle'),
                            Text('Diferencia: $diferencia'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('IDFOL: $idFol'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildValidationBadge(
                        'Importe cuadra',
                        importeCuadra,
                      ),
                      _buildValidationBadge(
                        'Cliente fiscal completo',
                        clienteFiscalCompleto,
                      ),
                      _buildValidationBadge(
                        requiereAjusteSubtotalSat
                            ? 'Subtotal SAT ajustable'
                            : 'Subtotal SAT listo',
                        subtotalSatCuadra || requiereAjusteSubtotalSat,
                      ),
                      _buildValidationBadge(
                        'Conceptos: ${rows.length}',
                        rows.isNotEmpty,
                      ),
                    ],
                  ),
                  if (requiereAjusteSubtotalSat) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Se detectó precisión decimal en conceptos '
                      '(diferencia SAT: ${subtotalSatDiferencia.toStringAsFixed(6)}). '
                      'Al emitir, backend aplicará redondeo SAT en subtotal para prevenir CFDI40108.',
                      style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF5D4037),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                  if (camposFiscalesFaltantes.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Campos fiscales obligatorios incompletos'
                      '${rfcGenerico ? ' (RFC genérico)' : ''}: '
                      '${camposFiscalesFaltantes.join(', ')}',
                      style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFFB71C1C),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  DecoratedBox(
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
                          Row(
                            children: [
                              Text(
                                'Datos fiscales del cliente',
                                style: Theme.of(dialogContext)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(width: 8),
                              if (clienteId != null)
                                Text(
                                  'IDC: $clienteId',
                                  style:
                                      Theme.of(dialogContext).textTheme.bodySmall,
                                ),
                              const Spacer(),
                              OutlinedButton(
                                onPressed: () async {
                                  final updated =
                                      await _showEditarClienteFiscalDialog(
                                    context: dialogContext,
                                    idFol: idFol,
                                    cliente: clienteMap,
                                    header: headerMap,
                                    sucursal: sucursalMap,
                                  );
                                  if (!updated || !dialogContext.mounted) return;
                                  Navigator.of(dialogContext).pop();
                                  final refreshed = await api.validar(idFol);
                                  if (!mounted) return;
                                  await _showDetalleValidacionDialog(
                                    idFol: idFol,
                                    result: refreshed,
                                  );
                                },
                                child: const Text('EDITAR'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            children: [
                              Text('RfcReceptor: $rfcReceptor'),
                              Text('RazonSocial: $razonSocial'),
                              Text('Regimen: $regimenFiscal'),
                              Text('UsoCfdi: $usoCfdi'),
                              Text('CodigoPostal: $codigoPostal'),
                              Text('Email: $emailReceptor'),
                              Text('RfcEmisor: $rfcEmisor'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: rows.isEmpty
                          ? const Center(
                              child: Text('Sin artículos relacionados al folio.'),
                            )
                          : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SingleChildScrollView(
                                child: DataTable(
                                  columnSpacing: 14,
                                  headingRowHeight: 40,
                                  dataRowMinHeight: 36,
                                  dataRowMaxHeight: 42,
                                  columns: const [
                                    DataColumn(label: Text('IDFOL')),
                                    DataColumn(label: Text('UPC')),
                                    DataColumn(label: Text('Descripcion')),
                                    DataColumn(label: Text('ClaveProdServ')),
                                    DataColumn(label: Text('Unidad')),
                                    DataColumn(label: Text('Cantidad')),
                                    DataColumn(label: Text('ValorUnitario')),
                                    DataColumn(label: Text('PVTAT')),
                                    DataColumn(label: Text('Impuesto')),
                                    DataColumn(label: Text('Total')),
                                  ],
                                  rows: rows.map((row) {
                                    return DataRow(
                                      cells: [
                                        DataCell(
                                          Text(
                                            _pickText(row, const ['IDFOL']),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            _pickText(row, const ['UPC']),
                                          ),
                                        ),
                                        DataCell(
                                          ConstrainedBox(
                                            constraints:
                                                const BoxConstraints(maxWidth: 260),
                                            child: Text(
                                              _pickText(row, const ['Descripcion']),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            _pickText(
                                              row,
                                              const ['ClaveProdServ'],
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            _pickText(row, const ['Unidad']),
                                          ),
                                        ),
                                        DataCell(
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: Text(
                                              _formatCantidad(row['Cantidad']),
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: Text(
                                              _formatMoney(row['ValorUnitario']),
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: Text(
                                              _formatMoney(row['PVTAT']),
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: Text(
                                              _formatMoney(row['Impuesto']),
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: Text(
                                              _formatMoney(row['Total']),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                    ),
                  ),
                      const SizedBox(height: 10),
                      if (accionMsg.isNotEmpty)
                        Text(
                          accionMsg,
                          style: TextStyle(
                            color: accionError
                                ? const Color(0xFFB71C1C)
                                : const Color(0xFF1B5E20),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Wrap(
                          spacing: 8,
                          children: [
                            OutlinedButton(
                              onPressed: facturando
                                  ? null
                                  : () => Navigator.of(dialogContext).pop(),
                              child: const Text('CERRAR'),
                            ),
                            FilledButton(
                              onPressed: (!canFacturar || facturando)
                                  ? null
                                  : () async {
                                      setDialogState(() {
                                        facturando = true;
                                        accionMsg = '';
                                        accionError = false;
                                      });

                                      try {
                                        final emit = await _emitirFacturaAndOpenPdf(
                                          ref,
                                          idFol,
                                        );
                                        if (!dialogContext.mounted) return;
                                        setDialogState(() {
                                          facturando = false;
                                          accionMsg = emit.message;
                                          accionError = !emit.ok;
                                        });

                                        if (!emit.ok) return;

                                        Navigator.of(dialogContext).pop();
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text(emit.message)),
                                        );
                                        if (!emit.pdfOpened) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Factura emitida, pero no se recibió PDF para vista previa.',
                                              ),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (!dialogContext.mounted) return;
                                        setDialogState(() {
                                          facturando = false;
                                          accionMsg = _formatActionError(
                                            'No se pudo emitir',
                                            e,
                                          );
                                          accionError = true;
                                        });
                                      }
                                    },
                              child: Text(
                                facturando
                                    ? 'FACTURANDO...'
                                    : 'REALIZAR FACTURA',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<bool> _showEditarClienteFiscalDialog({
    required BuildContext context,
    required String idFol,
    required Map<String, dynamic> cliente,
    required Map<String, dynamic> header,
    required Map<String, dynamic> sucursal,
  }) async {
    final api = ref.read(facturacionApiProvider);
    final clienteId = _resolveClienteId(cliente);
    if (clienteId == null || clienteId.trim().isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se identificó IDC del cliente para edición en este folio.',
            ),
          ),
        );
      }
      return false;
    }

    List<DatCatRegModel> regimenes = const [];
    List<DatCatUsoModel> usos = const [];
    List<SucursalModel> sucursales = const [];
    try {
      regimenes = await ref.read(datCatRegListProvider.future);
    } catch (_) {}
    try {
      usos = await ref.read(datCatUsoListProvider.future);
    } catch (_) {}
    try {
      sucursales = await ref.read(sucursalesListProvider.future);
    } catch (_) {}

    final razonCtrl = TextEditingController(
      text: _firstNonEmptyText([
        cliente['RAZONSOCIALRECEPTOR'],
        cliente['RazonSocialReceptor'],
        header['RazonSocialReceptor'],
        header['RAZONSOCIALRECEPTOR'],
      ]),
    );
    final rfcCtrl = TextEditingController(
      text: _firstNonEmptyText([
        cliente['RFCRECEPTOR'],
        cliente['RfcReceptor'],
        header['RfcReceptor'],
        header['RFCRECEPTOR'],
      ]).toUpperCase(),
    );
    final emailCtrl = TextEditingController(
      text: _firstNonEmptyText([
        cliente['EMAILRECEPTOR'],
        cliente['EmailReceptor'],
      ]),
    );
    final codigoPostalCtrl = TextEditingController(
      text: _firstNonEmptyText([
        cliente['CODIGOPOSTALRECEPTOR'],
        cliente['CodigoPostalReceptor'],
      ]),
    );
    final domicilioCtrl = TextEditingController(
      text: _firstNonEmptyText([cliente['DOMI'], cliente['Domicilio']]),
    );
    final ncelCtrl = TextEditingController(
      text: _firstNonEmptyText([cliente['NCEL'], cliente['Ncel']]),
    );
    final formKey = GlobalKey<FormState>();
    var saving = false;
    var info = '';
    var isError = false;

    var usoCfdiValue = _firstNonEmptyText(
      [
        cliente['USOCFDI'],
        cliente['UsoCfdi'],
        header['UsoCfdi'],
        header['USOCFDI'],
      ],
      fallback: _kClienteSelectDefault,
    );
    if (usoCfdiValue.isEmpty) usoCfdiValue = _kClienteSelectDefault;

    var regimenValue = _firstIntValue([
      cliente['REGIMENFISCALRECEPTOR'],
      cliente['RegimenFiscalReceptor'],
      cliente['RegimenFiscalReceptorSAT'],
    ]);

    var rfcEmisorValue = _firstNonEmptyText(
      [
        cliente['RFCEMISOR'],
        cliente['RfcEmisor'],
        header['RfcEmisor'],
        header['RFCEMISOR'],
        sucursal['RFC'],
      ],
      fallback: _kClienteSelectDefault,
    );
    if (rfcEmisorValue.isEmpty) rfcEmisorValue = _kClienteSelectDefault;

    final inputFormatter = FilteringTextInputFormatter.allow(
      RegExp(r'[a-zA-Z0-9@._\-\s&Ññ]'),
    );

    if (!context.mounted) return false;

    try {
      final updated = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              final usoItems = <DropdownMenuItem<String>>[
                _clienteMenuItem<String>(
                  _kClienteSelectDefault,
                  _kClienteSelectDefault,
                  0,
                ),
                for (var i = 0; i < usos.length; i++)
                  _clienteMenuItem<String>(
                    usos[i].usoCfdi,
                    '${usos[i].usoCfdi} - ${usos[i].descripcion ?? ''}',
                    i + 1,
                  ),
              ];
              if (usoCfdiValue != _kClienteSelectDefault &&
                  usoItems.every((item) => item.value != usoCfdiValue)) {
                usoItems.add(
                  _clienteMenuItem<String>(
                    usoCfdiValue,
                    '$usoCfdiValue - valor actual',
                    usoItems.length + 1,
                  ),
                );
              }

              final regimenItems = <DropdownMenuItem<int>>[
                _clienteMenuItem<int>(
                  _kClienteRegimenDefault,
                  _kClienteSelectDefault,
                  0,
                ),
                for (var i = 0; i < regimenes.length; i++)
                  _clienteMenuItem<int>(
                    regimenes[i].codigo,
                    '${regimenes[i].codigo} - ${regimenes[i].descripcion ?? ''}',
                    i + 1,
                  ),
              ];
              if (regimenValue > 0 &&
                  regimenItems.every((item) => item.value != regimenValue)) {
                regimenItems.add(
                  _clienteMenuItem<int>(
                    regimenValue,
                    '$regimenValue - valor actual',
                    regimenItems.length + 1,
                  ),
                );
              }

              final rfcByLabel = <String, String>{};
              for (final s in sucursales) {
                final rfc = _asCleanText(s.rfc).toUpperCase();
                if (rfc.isEmpty || rfcByLabel.containsKey(rfc)) continue;
                final baseLabel = _asCleanText(s.encar).isNotEmpty
                    ? _asCleanText(s.encar)
                    : _asCleanText(s.desc).isNotEmpty
                        ? _asCleanText(s.desc)
                        : s.suc;
                rfcByLabel[rfc] = '$baseLabel - $rfc';
              }
              final rfcItems = <DropdownMenuItem<String>>[
                _clienteMenuItem<String>(
                  _kClienteSelectDefault,
                  _kClienteSelectDefault,
                  0,
                ),
              ];
              var idx = 1;
              for (final entry in rfcByLabel.entries) {
                rfcItems.add(_clienteMenuItem<String>(entry.key, entry.value, idx));
                idx++;
              }
              if (rfcEmisorValue != _kClienteSelectDefault &&
                  rfcItems.every((item) => item.value != rfcEmisorValue)) {
                rfcItems.add(
                  _clienteMenuItem<String>(
                    rfcEmisorValue,
                    '$rfcEmisorValue - valor actual',
                    rfcItems.length + 1,
                  ),
                );
              }

              Future<void> onSave() async {
                if (!(formKey.currentState?.validate() ?? false)) return;
                setDialogState(() {
                  saving = true;
                  info = '';
                });
                final payload = <String, dynamic>{
                  'RAZONSOCIALRECEPTOR': razonCtrl.text.trim().toUpperCase(),
                  'RFCRECEPTOR': rfcCtrl.text.trim().toUpperCase(),
                  'EMAILRECEPTOR': emailCtrl.text.trim(),
                  'RFCEMISOR': rfcEmisorValue.trim(),
                  'USOCFDI': usoCfdiValue.trim(),
                  'CODIGOPOSTALRECEPTOR': codigoPostalCtrl.text.trim().toUpperCase(),
                  'REGIMENFISCALRECEPTOR': regimenValue,
                  'DOMI': domicilioCtrl.text.trim().isEmpty
                      ? null
                      : domicilioCtrl.text.trim(),
                  'NCEL': ncelCtrl.text.trim().isEmpty ? null : ncelCtrl.text.trim(),
                };
                try {
                  await api.actualizarClienteFiscal(clienteId, payload);
                  if (!dialogContext.mounted) return;
                  Navigator.of(dialogContext).pop(true);
                } catch (e) {
                  if (!dialogContext.mounted) return;
                  setDialogState(() {
                    saving = false;
                    info = _formatActionError('No se pudo guardar cliente', e);
                    isError = true;
                  });
                }
              }

              return Dialog(
                insetPadding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980, maxHeight: 720),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Edición de datos fiscales del cliente',
                            style: Theme.of(dialogContext)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'IDFOL: $idFol | IDC: $clienteId',
                            style: Theme.of(dialogContext).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: SingleChildScrollView(
                              child: Wrap(
                                spacing: 12,
                                runSpacing: 10,
                                children: [
                                  _buildClienteEditorField(
                                    context: dialogContext,
                                    label: 'RfcReceptor *',
                                    child: TextFormField(
                                      controller: rfcCtrl,
                                      enabled: !saving,
                                      textCapitalization:
                                          TextCapitalization.characters,
                                      inputFormatters: [inputFormatter],
                                      decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                      validator: _validateClienteRfc,
                                    ),
                                  ),
                                  _buildClienteEditorField(
                                    context: dialogContext,
                                    label: 'RazonSocialReceptor *',
                                    width: 360,
                                    child: TextFormField(
                                      controller: razonCtrl,
                                      enabled: !saving,
                                      textCapitalization:
                                          TextCapitalization.characters,
                                      inputFormatters: [inputFormatter],
                                      decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                      validator: _validateRequiredField,
                                    ),
                                  ),
                                  _buildClienteEditorField(
                                    context: dialogContext,
                                    label: 'EmailReceptor *',
                                    width: 280,
                                    child: TextFormField(
                                      controller: emailCtrl,
                                      enabled: !saving,
                                      decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                      validator: _validateRequiredField,
                                    ),
                                  ),
                                  _buildClienteEditorField(
                                    context: dialogContext,
                                    label: 'RegimenFiscalReceptor *',
                                    width: 300,
                                    child: DropdownButtonFormField<int>(
                                      initialValue: regimenItems.any(
                                        (item) => item.value == regimenValue,
                                      )
                                          ? regimenValue
                                          : _kClienteRegimenDefault,
                                      isExpanded: true,
                                      items: regimenItems,
                                      style: const TextStyle(fontSize: 11),
                                      onChanged: saving
                                          ? null
                                          : (value) => setDialogState(() {
                                                regimenValue = value ??
                                                    _kClienteRegimenDefault;
                                              }),
                                      decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                      validator: (value) =>
                                          (value ?? 0) <= 0 ? 'Requerido' : null,
                                    ),
                                  ),
                                  _buildClienteEditorField(
                                    context: dialogContext,
                                    label: 'UsoCfdi *',
                                    width: 300,
                                    child: DropdownButtonFormField<String>(
                                      initialValue: usoItems.any(
                                        (item) => item.value == usoCfdiValue,
                                      )
                                          ? usoCfdiValue
                                          : _kClienteSelectDefault,
                                      isExpanded: true,
                                      items: usoItems,
                                      style: const TextStyle(fontSize: 11),
                                      onChanged: saving
                                          ? null
                                          : (value) => setDialogState(() {
                                                usoCfdiValue = value ??
                                                    _kClienteSelectDefault;
                                              }),
                                      decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                      validator: (value) {
                                        final v = _asCleanText(value);
                                        if (v.isEmpty ||
                                            v == _kClienteSelectDefault) {
                                          return 'Requerido';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  _buildClienteEditorField(
                                    context: dialogContext,
                                    label: 'CodigoPostalReceptor *',
                                    child: TextFormField(
                                      controller: codigoPostalCtrl,
                                      enabled: !saving,
                                      textCapitalization:
                                          TextCapitalization.characters,
                                      inputFormatters: [inputFormatter],
                                      decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                      validator: _validateRequiredField,
                                    ),
                                  ),
                                  _buildClienteEditorField(
                                    context: dialogContext,
                                    label: 'RfcEmisor *',
                                    width: 300,
                                    child: DropdownButtonFormField<String>(
                                      initialValue: rfcItems.any(
                                        (item) => item.value == rfcEmisorValue,
                                      )
                                          ? rfcEmisorValue
                                          : _kClienteSelectDefault,
                                      isExpanded: true,
                                      items: rfcItems,
                                      style: const TextStyle(fontSize: 11),
                                      onChanged: saving
                                          ? null
                                          : (value) => setDialogState(() {
                                                rfcEmisorValue = value ??
                                                    _kClienteSelectDefault;
                                              }),
                                      decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                      validator: (value) {
                                        final v = _asCleanText(value);
                                        if (v.isEmpty ||
                                            v == _kClienteSelectDefault) {
                                          return 'Requerido';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  _buildClienteEditorField(
                                    context: dialogContext,
                                    label: 'Domicilio',
                                    width: 360,
                                    child: TextFormField(
                                      controller: domicilioCtrl,
                                      enabled: !saving,
                                      decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                  _buildClienteEditorField(
                                    context: dialogContext,
                                    label: 'Tel o Cel',
                                    width: 180,
                                    child: TextFormField(
                                      controller: ncelCtrl,
                                      enabled: !saving,
                                      keyboardType: TextInputType.phone,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(10),
                                      ],
                                      decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (info.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              info,
                              style: TextStyle(
                                color: isError
                                    ? const Color(0xFFB71C1C)
                                    : const Color(0xFF1B5E20),
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Wrap(
                              spacing: 8,
                              children: [
                                OutlinedButton(
                                  onPressed: saving
                                      ? null
                                      : () => Navigator.of(dialogContext).pop(false),
                                  child: const Text('CANCELAR'),
                                ),
                                FilledButton(
                                  onPressed: saving ? null : onSave,
                                  child: Text(
                                    saving
                                        ? 'GUARDANDO...'
                                        : 'GUARDAR DATOS CLIENTE',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
      return updated == true;
    } finally {
      razonCtrl.dispose();
      rfcCtrl.dispose();
      emailCtrl.dispose();
      codigoPostalCtrl.dispose();
      domicilioCtrl.dispose();
      ncelCtrl.dispose();
    }
  }

  Widget _buildValidationBadge(String label, bool isOk) {
    final bg = isOk ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE);
    final fg = isOk ? const Color(0xFF1B5E20) : const Color(0xFFB71C1C);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: fg.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          label,
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Future<_EmitirOutcome> _emitirFacturaAndOpenPdf(
    WidgetRef ref,
    String idFol,
  ) async {
    final api = ref.read(facturacionApiProvider);
    final result = await api.emitir(idFol);
    ref.invalidate(facturasPendientesProvider);

    final ok = _asBool(result['ok']);
    final successMsg = '${result['message'] ?? ''}'.trim();
    final message = ok
        ? (successMsg.isNotEmpty ? successMsg : 'Factura emitida correctamente')
        : _extractEmitirErrorMessage(result);

    var pdfOpened = false;
    if (ok) {
      pdfOpened = await _openPdfPreviewFromEmitResult(result, idFol);
    }

    return _EmitirOutcome(
      ok: ok,
      message: message,
      pdfOpened: pdfOpened,
    );
  }

  Future<bool> _openPdfPreviewFromEmitResult(
    Map<String, dynamic> result,
    String idFol,
  ) async {
    final pdfBase64 = _extractPdfBase64FromEmitResult(result);
    if (pdfBase64.isEmpty) return false;

    try {
      final bytes = base64Decode(base64.normalize(pdfBase64));
      if (bytes.isEmpty) return false;
      await Printing.layoutPdf(
        name: 'CFDI_$idFol.pdf',
        onLayout: (_) async => bytes,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  String _extractPdfBase64FromEmitResult(Map<String, dynamic> result) {
    final facturifyMap = _safeMap(result['facturify']);
    final facturifyDataMap = _safeMap(facturifyMap['data']);
    final facturifyNestedDataMap = _safeMap(facturifyDataMap['data']);

    final candidates = <dynamic>[
      result['pdf'],
      result['pdfBase64'],
      result['CFDI_PDF_BASE64'],
      facturifyMap['pdf'],
      facturifyMap['CFDI_PDF'],
      facturifyDataMap['pdf'],
      facturifyDataMap['CFDI_PDF'],
      facturifyNestedDataMap['pdf'],
      facturifyNestedDataMap['CFDI_PDF'],
    ];

    for (final candidate in candidates) {
      var text = _asCleanText(candidate);
      if (text.isEmpty) continue;
      final lower = text.toLowerCase();
      if (lower.startsWith('data:application/pdf;base64,')) {
        text = text.substring(text.indexOf(',') + 1);
      }
      text = text.replaceAll(RegExp(r'\s+'), '');
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  Widget _headerCell(
    String label,
    double width,
    TextStyle? style, {
    TextAlign textAlign = TextAlign.left,
    bool resizable = false,
    void Function(double delta)? onResizeDelta,
  }) {
    return SizedBox(
      width: width + _columnGap,
      child: Row(
        children: [
          SizedBox(
            width: width,
            child: Text(
              label,
              style: style,
              textAlign: textAlign,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: _columnGap,
            child: (resizable && onResizeDelta != null)
                ? _buildResizeHandle(onDelta: onResizeDelta)
                : null,
          ),
        ],
      ),
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
      width: width + _columnGap,
      child: Row(
        children: [
          SizedBox(
            width: width,
            child: Text(
              value,
              textAlign: resolvedTextAlign,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: _columnGap),
        ],
      ),
    );
  }

  Map<String, dynamic> _safeMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  String _asCleanText(dynamic value) {
    final text = '$value'.trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return '';
    return text;
  }

  String _firstNonEmptyText(
    List<dynamic> values, {
    String fallback = '',
  }) {
    for (final value in values) {
      final text = _asCleanText(value);
      if (text.isNotEmpty) return text;
    }
    return fallback;
  }

  int _firstIntValue(
    List<dynamic> values, {
    int fallback = _kClienteRegimenDefault,
  }) {
    for (final value in values) {
      final parsed = _asDouble(value);
      if (parsed == null) continue;
      return parsed.toInt();
    }
    return fallback;
  }

  String? _resolveClienteId(Map<String, dynamic> cliente) {
    final candidate = _firstNonEmptyText([
      cliente['IDC'],
      cliente['idc'],
    ]);
    if (candidate.isEmpty) return null;
    final numeric = num.tryParse(candidate);
    if (numeric == null) return candidate;
    if (numeric % 1 == 0) return numeric.toInt().toString();
    return numeric.toString();
  }

  String? _validateRequiredField(String? value) {
    final v = (value ?? '').trim().toUpperCase();
    if (v.isEmpty || v == _kClienteSelectDefault || v == 'COLOCAR') {
      return 'Requerido';
    }
    return null;
  }

  String? _validateClienteRfc(String? value) {
    final v = (value ?? '').trim().toUpperCase();
    if (v.isEmpty) return 'Requerido';
    if (v == 'XAXX010101000' || v == 'XEXX010101000') return null;
    final moral = RegExp(
      r'^[A-Z&Ñ]{3}\d{2}(0[1-9]|1[0-2])(0[1-9]|[12]\d|3[01])[A-Z0-9]{3}$',
    );
    final fisica = RegExp(
      r'^[A-Z&Ñ]{4}\d{2}(0[1-9]|1[0-2])(0[1-9]|[12]\d|3[01])[A-Z0-9]{3}$',
    );
    if (moral.hasMatch(v) || fisica.hasMatch(v)) return null;
    return 'RFC inválido';
  }

  DropdownMenuItem<T> _clienteMenuItem<T>(T value, String label, int index) {
    final bg = index.isEven
        ? Colors.grey.withValues(alpha: 0.08)
        : Colors.transparent;
    return DropdownMenuItem<T>(
      value: value,
      child: Container(
        width: double.infinity,
        color: bg,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Text(
          label,
          style: const TextStyle(fontSize: 11),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildClienteEditorField({
    required BuildContext context,
    required String label,
    required Widget child,
    double width = 220,
  }) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          child,
        ],
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

    double? value;
    if (rawValue is num) {
      value = rawValue.toDouble();
    } else {
      final normalized = text
          .replaceAll('\$', '')
          .replaceAll('MXN', '')
          .replaceAll(',', '')
          .trim();
      value = double.tryParse(normalized);
      if (value == null) {
        final match = RegExp(r'-?\d+(?:\.\d+)?').firstMatch(normalized);
        if (match != null) {
          value = double.tryParse(match.group(0)!);
        }
      }
    }
    if (value == null) return text;
    return '\$${value.toStringAsFixed(2)}';
  }

  String _formatCantidad(dynamic rawValue) {
    final value = _asDouble(rawValue);
    if (value == null) return _pickText({'v': rawValue}, const ['v']);
    final intValue = value.toInt();
    if (value == intValue.toDouble()) return '$intValue';
    return value.toStringAsFixed(2);
  }

  String _formatClienteNumero(dynamic rawValue) {
    if (rawValue == null) return '-';
    final text = _asCleanText(rawValue);
    if (text.isEmpty) return '-';

    final normalized = text.replaceAll(',', '').trim();
    if (RegExp(r'^[+-]?\d+$').hasMatch(normalized)) {
      return normalized.startsWith('+') ? normalized.substring(1) : normalized;
    }

    final sci = RegExp(
      r'^([+-]?)(\d+)(?:\.(\d+))?[eE]([+-]?\d+)$',
    ).firstMatch(normalized);
    if (sci == null) return text;

    final sign = sci.group(1) ?? '';
    final intPart = sci.group(2) ?? '';
    final fracPart = sci.group(3) ?? '';
    final exponent = int.tryParse(sci.group(4) ?? '');
    if (exponent == null) return text;

    var digits = '$intPart$fracPart';
    var pointIndex = intPart.length + exponent;

    if (pointIndex <= 0) {
      digits = '${List.filled(-pointIndex, '0').join()}$digits';
      pointIndex = 0;
    }
    if (pointIndex >= digits.length) {
      digits = '$digits${List.filled(pointIndex - digits.length, '0').join()}';
    }

    var whole = digits.substring(0, pointIndex);
    var frac = pointIndex < digits.length ? digits.substring(pointIndex) : '';

    whole = whole.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    if (whole.isEmpty) whole = '0';
    frac = frac.replaceFirst(RegExp(r'0+$'), '');

    final result = frac.isEmpty ? whole : '$whole.$frac';
    if (sign == '-' && result != '0') return '-$result';
    return result;
  }

  bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = '$value'.trim().toLowerCase();
    return text == '1' || text == 'true' || text == 'si' || text == 'yes';
  }

  double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse('$value'.replaceAll(',', '').trim());
  }

  String _formatActionError(String prefix, Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        final raw = data['message'];
        if (raw is List && raw.isNotEmpty) {
          return '$prefix: ${raw.first}';
        }
        if (raw != null) {
          return '$prefix: $raw';
        }
      }
      if (data is String && data.trim().isNotEmpty) {
        return '$prefix: $data';
      }
      if ((error.message ?? '').trim().isNotEmpty) {
        return '$prefix: ${error.message}';
      }
    }
    return '$prefix: $error';
  }

  String _extractEmitirErrorMessage(Map<String, dynamic> result) {
    final errors = <String>[];

    void collectErrors(dynamic rawErrors) {
      if (rawErrors is! List) return;
      for (final item in rawErrors) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final field = '${map['field'] ?? ''}'.trim();
        final msg = '${map['message'] ?? ''}'.trim();
        if (msg.isEmpty) continue;
        errors.add(field.isEmpty ? msg : '$field: $msg');
      }
    }

    collectErrors(result['errors']);
    if (result['facturify'] is Map) {
      final facturify = Map<String, dynamic>.from(result['facturify'] as Map);
      collectErrors(facturify['errors']);
      final facturifyMessage = '${facturify['message'] ?? ''}'.trim();
      if (errors.isEmpty && facturifyMessage.isNotEmpty) {
        errors.add(facturifyMessage);
      }
    }

    if (errors.isNotEmpty) {
      return 'No se pudo emitir: ${errors.join(' | ')}';
    }

    final direct = '${result['message'] ?? ''}'.trim();
    if (direct.isNotEmpty) {
      return direct;
    }

    final status = '${result['status'] ?? ''}'.trim();
    if (status.isNotEmpty) {
      return 'No se pudo emitir factura (status $status).';
    }

    return 'No se pudo emitir factura.';
  }

  List<Map<String, dynamic>> _sortRowsByFcnDesc(
    List<Map<String, dynamic>> rows,
  ) {
    final sorted = [...rows];
    sorted.sort((a, b) {
      final aDate = _parseRowDateTime(_pickValue(a, const ['FCN', 'fcn']));
      final bDate = _parseRowDateTime(_pickValue(b, const ['FCN', 'fcn']));

      if (aDate != null && bDate != null) {
        final cmp = bDate.compareTo(aDate);
        if (cmp != 0) return cmp;
      } else if (aDate == null && bDate != null) {
        return 1;
      } else if (aDate != null && bDate == null) {
        return -1;
      }

      final aId = _pickText(a, const ['IDFOL', 'idfol']);
      final bId = _pickText(b, const ['IDFOL', 'idfol']);
      return bId.compareTo(aId);
    });
    return sorted;
  }

  DateTime? _parseRowDateTime(dynamic rawValue) {
    if (rawValue == null) return null;
    if (rawValue is DateTime) return rawValue;

    final text = '$rawValue'.trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return null;

    final iso = DateTime.tryParse(text);
    if (iso != null) return iso;

    final dmy = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(text);
    if (dmy != null) {
      final day = int.tryParse(dmy.group(1) ?? '');
      final month = int.tryParse(dmy.group(2) ?? '');
      final year = int.tryParse(dmy.group(3) ?? '');
      if (day != null && month != null && year != null) {
        return DateTime(year, month, day);
      }
    }
    return null;
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
