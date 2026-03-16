import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ioe_app/core/auth/auth_controller.dart';
import 'package:ioe_app/features/home/home_providers.dart';
import 'package:ioe_app/features/masterdata/sucursales/sucursales_models.dart';
import 'package:ioe_app/features/masterdata/sucursales/sucursales_providers.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'facturacionview_providers.dart';

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

class FacturacionViewPage extends ConsumerStatefulWidget {
  const FacturacionViewPage({super.key});

  @override
  ConsumerState<FacturacionViewPage> createState() => _FacturacionViewPageState();
}

class _FacturacionViewPageState extends ConsumerState<FacturacionViewPage> {
  // Configuración visual para ajuste en runtime.
  static const double _kMinFontScale = 0.80;
  static const double _kMaxFontScale = 1.40;
  static const double _kDefaultFontScale = 1.00;
  static const int _kFontScaleDivisions = 60;
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
      title: const Text('Facturación (Vista facturados)'),
      actions: [
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

    final modulos = providerRef.watch(homeModulesProvider).maybeWhen(
          data: (data) => data.modulos,
          orElse: () => const [],
        );
    final canManageFacturacion = _canManageFacturacionActions(
      roleId: auth.roleId,
      modules: modulos,
    );

    final pendientesAsync = providerRef.watch(facturasPendientesProvider);

    return Theme(
      data: facturacionTheme,
      child: Scaffold(
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
                    canManageActions: canManageFacturacion,
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
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Sin registros FACTURADO / CANCELACION PENDIENTE',
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
                  canManageActions: canManageFacturacion,
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
    {
    required bool canManageActions,
    }
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 1150;
        final filters = _buildFiltersPanel(context, ref);
        final actions = _buildTopActions(
          context,
          ref,
          selectedIdFol,
          selectedRow,
          canManageActions: canManageActions,
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
        facturacionViewEstatusFacturadoCancelPendiente;
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
    ref.read(facturacionDraftFilterEstatusProvider.notifier).state =
        facturacionViewEstatusFacturadoCancelPendiente;
    ref.read(facturacionDraftFilterRazonSocialProvider.notifier).state = '';
    ref.read(facturacionDraftFilterRfcReceptorProvider.notifier).state = '';
    ref.read(facturacionDraftFilterClienProvider.notifier).state = '';
    ref.read(facturacionDraftFilterIdFolProvider.notifier).state = '';
    ref.read(facturacionDraftFilterTipoFactProvider.notifier).state = '';

    ref.read(facturacionFilterSucProvider.notifier).state = '';
    ref.read(facturacionFilterEstatusProvider.notifier).state =
        facturacionViewEstatusFacturadoCancelPendiente;
    ref.read(facturacionFilterRazonSocialProvider.notifier).state = '';
    ref.read(facturacionFilterRfcReceptorProvider.notifier).state = '';
    ref.read(facturacionFilterClienProvider.notifier).state = '';
    ref.read(facturacionFilterIdFolProvider.notifier).state = '';
    ref.read(facturacionFilterTipoFactProvider.notifier).state = '';

    ref.read(facturacionFilterInputRevisionProvider.notifier).state++;
    _setPage(ref, 1);
    ref.read(selectedFacturasUnificacionProvider.notifier).state = <String>{};
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
                    key: ValueKey('ff-estatus-$revision-$draftEstatus'),
                    initialValue: draftEstatus,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(
                        value: facturacionViewEstatusFacturadoCancelPendiente,
                        child: Text('FACTURADO + CANC. PEND.'),
                      ),
                    ],
                    onChanged: (value) {
                      ref
                          .read(facturacionDraftFilterEstatusProvider.notifier)
                          .state =
                              value ?? facturacionViewEstatusFacturadoCancelPendiente;
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
    {
    required bool canManageActions,
    }
  ) {
    final selectedStatus = selectedRow == null
        ? '-'
        : _pickText(selectedRow, const ['ESTATUS', 'estatus']);
    final selectedCancelStatus = selectedRow == null
        ? '-'
        : _pickText(selectedRow, const [
            'CFDI_CANCEL_STATUS',
            'cfdi_cancel_status',
          ]);
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
              'CFDI_CANCEL_STATUS: $selectedCancelStatus',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (!canManageActions)
              Text(
                'Modo consulta: solo visualización de CFDI (PDF/XML).',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFFB71C1C),
                      fontWeight: FontWeight.w600,
                    ),
              ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: selectedIdFol == null
                      ? null
                      : () => _onVisualizarPdfXml(ref, selectedIdFol),
                  child: const Text('VISUALIZAR PDF/XML'),
                ),
                OutlinedButton(
                  onPressed: (!canManageActions || selectedIdFol == null)
                      ? null
                      : () => _onRefrescarEstado(ref, selectedIdFol),
                  child: const Text('REFRESCAR ESTADO'),
                ),
                OutlinedButton(
                  onPressed: (!canManageActions || selectedIdFol == null)
                      ? null
                      : () => _onReenviarEmail(ref, selectedIdFol),
                  child: const Text('REENVIAR XML/PDF'),
                ),
                OutlinedButton(
                  onPressed: (!canManageActions || selectedIdFol == null)
                      ? null
                      : () => _onCancelar(ref, selectedIdFol),
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

  bool _canManageFacturacionActions({
    required int? roleId,
    required List<dynamic> modules,
  }) {
    if ((roleId ?? 0) == 1) return true;
    final codes = modules
        .map((item) => _asCleanText((item as dynamic).codigo).toUpperCase())
        .where((code) => code.isNotEmpty)
        .toSet();
    return codes.contains('FACTURA') ||
        codes.contains('FACTURACION') ||
        codes.contains('PV_FACTURACION') ||
        codes.contains('FACT_IOE');
  }

  String _normalizeBase64Payload(String raw) {
    var value = raw.trim();
    final commaIndex = value.indexOf(',');
    if (value.startsWith('data:') && commaIndex >= 0) {
      value = value.substring(commaIndex + 1);
    }
    return value.replaceAll(RegExp(r'\s+'), '');
  }

  Future<bool> _openPdfFromBase64(String rawBase64, String idFol) async {
    final normalized = _normalizeBase64Payload(rawBase64);
    if (normalized.isEmpty) return false;
    try {
      final bytes = base64Decode(base64.normalize(normalized));
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

  Future<void> _showXmlDialogFromBase64(
    BuildContext dialogContext,
    String rawBase64,
    String idFol,
  ) async {
    final normalized = _normalizeBase64Payload(rawBase64);
    if (normalized.isEmpty) return;
    String xmlText = '';
    try {
      final bytes = base64Decode(base64.normalize(normalized));
      xmlText = utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      xmlText = '';
    }
    if (xmlText.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo visualizar XML del CFDI.')),
      );
      return;
    }

    await showDialog<void>(
      context: dialogContext,
      builder: (xmlContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980, maxHeight: 700),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'XML CFDI - $idFol',
                    style: Theme.of(xmlContext)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black12),
                        borderRadius: BorderRadius.circular(8),
                        color: const Color(0xFFFDFDFD),
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(12),
                        child: SelectableText(
                          xmlText,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: () => Navigator.of(xmlContext).pop(),
                      child: const Text('CERRAR'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _onVisualizarPdfXml(WidgetRef ref, String idFol) async {
    if (!mounted) return;
    final api = ref.read(facturacionApiProvider);
    Map<String, dynamic> result;
    try {
      result = await api.obtenerArtefactos(idFol);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo obtener PDF/XML: $e')),
      );
      return;
    }
    if (!mounted) return;

    final pdfBase64 = _asCleanText(result['pdfBase64']);
    final xmlBase64 = _asCleanText(result['xmlBase64']);
    final hasPdf = pdfBase64.isNotEmpty;
    final hasXml = xmlBase64.isNotEmpty;

    if (!hasPdf && !hasXml) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay PDF/XML disponibles para este folio.')),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Visualización CFDI'),
          content: Text('Folio: $idFol\nSelecciona el archivo a visualizar.'),
          actions: [
            if (hasXml)
              OutlinedButton(
                onPressed: () async {
                  await _showXmlDialogFromBase64(dialogContext, xmlBase64, idFol);
                },
                child: const Text('VER XML'),
              ),
            if (hasPdf)
              FilledButton(
                onPressed: () async {
                  final ok = await _openPdfFromBase64(pdfBase64, idFol);
                  if (!ok && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('No se pudo abrir PDF del CFDI.')),
                    );
                  }
                },
                child: const Text('VER PDF'),
              ),
            OutlinedButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('CERRAR'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _onRefrescarEstado(WidgetRef ref, String idFol) async {
    if (!mounted) return;
    final api = ref.read(facturacionApiProvider);
    final result = await api.refrescarEstado(idFol);
    if (!mounted) return;
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

  Future<void> _onReenviarEmail(WidgetRef ref, String idFol) async {
    if (!mounted) return;
    final api = ref.read(facturacionApiProvider);
    final result = await api.reenviarEmail(idFol);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Reenvío email: ${result['ok'] == true ? 'OK' : 'ERROR'}'),
      ),
    );
  }

  Future<void> _onCancelar(WidgetRef ref, String idFol) async {
    if (!mounted) return;
    final api = ref.read(facturacionApiProvider);
    final result = await api.cancelar(
      idFol,
      motivo: 'Cancelación manual desde IOE',
    );
    if (!mounted) return;
    final ok = _asBool(result['ok']);
    final message = _asCleanText(result['message']);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message.isNotEmpty
              ? message
              : (ok
                  ? 'Cancelación solicitada.'
                  : 'No se pudo cancelar CFDI.'),
        ),
        backgroundColor: ok ? null : const Color(0xFFB71C1C),
      ),
    );
    if (ok) {
      ref.invalidate(facturasPendientesProvider);
    }
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

  String _asCleanText(dynamic value) {
    final text = '$value'.trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return '';
    return text;
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


