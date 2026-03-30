import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ioe_app/core/api_error.dart';
import 'package:ioe_app/core/dio_provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../etiqueta/ticket_ords_legacy_layout.dart';
import 'ordenes_trabajo_models.dart';
import 'ordenes_trabajo_providers.dart';

class OrdenesTrabajoPage extends ConsumerStatefulWidget {
  const OrdenesTrabajoPage({
    super.key,
    this.panelMode = OrdenesTrabajoPanelMode.operativo,
    this.initialAction,
  });

  final OrdenesTrabajoPanelMode panelMode;
  final OrdenesTrabajoInitialAction? initialAction;

  @override
  ConsumerState<OrdenesTrabajoPage> createState() => _OrdenesTrabajoPageState();
}

class _OrdenesTrabajoPageState extends ConsumerState<OrdenesTrabajoPage> {
  static const String _recibirRolHint =
      'Los encargados de maquila solo pueden recibir ORDs TALLADO y los encargados de bisel solo ORDs BISELADO. Admin y jefe de taller pueden recibir ambas.';

  static const Map<String, double> _defaultColumnWidths = <String, double>{
    'SUC': 80,
    'TIPO': 95,
    'LABORATORIO': 170,
    'IORD': 145,
    'CLIENTE': 260,
    'ARTICULO': 120,
    'DESCRIPCION': 260,
    'CTD': 70,
    'FLUJO': 160,
    'ASIGNADO': 190,
    'F_SOL': 95,
    'F_ENT': 95,
  };
  static const Map<String, String> _columnTitles = <String, String>{
    'SUC': 'SUC',
    'TIPO': 'Tipo',
    'LABORATORIO': 'Laboratorio',
    'IORD': 'IORD',
    'CLIENTE': 'Cliente',
    'ARTICULO': 'Articulo',
    'DESCRIPCION': 'Descripcion',
    'CTD': 'CTD',
    'FLUJO': 'Flujo',
    'ASIGNADO': 'Asignado',
    'F_SOL': 'F. sol',
    'F_ENT': 'F. ent',
  };
  static const double _legacyEtiquetaWidthMm = 76;
  static const double _legacyEtiquetaHeightMm = 51;

  final _iordCtrl = TextEditingController();
  final _idfolCtrl = TextEditingController();
  final _clientCtrl = TextEditingController();
  final _sucCtrl = TextEditingController();
  final _ordEnviarCtrl = TextEditingController();
  String? _tipoValue;
  String? _laboratorioId;
  String? _estseguValue;
  String? _asignValue;

  DateTime? _fecIni;
  DateTime? _fecFin;

  bool _contextReady = false;
  bool _isAdmin = false;
  String _userSuc = '';
  bool _initialActionHandled = false;
  bool _loadingSucursalOptions = false;
  bool _loadingAsignadoOptions = false;
  String? _lastAsignadosSuc;
  List<OrdenTrabajoSucursalOption> _sucursalOptions =
      const <OrdenTrabajoSucursalOption>[];
  List<OrdenTrabajoColaboradorOption> _asignadoOptions =
      const <OrdenTrabajoColaboradorOption>[];

  final Set<String> _selectedIords = <String>{};
  double _filterFontSize = 13;
  double _tableFontSize = 13;
  final Map<String, double> _columnWidths = <String, double>{};
  double _columnWidthsFontRef = 13;

  @override
  void initState() {
    super.initState();
    _loadUserContext();
  }

  @override
  void dispose() {
    _iordCtrl.dispose();
    _idfolCtrl.dispose();
    _clientCtrl.dispose();
    _sucCtrl.dispose();
    _ordEnviarCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_contextReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final panelAsync = ref.watch(ordenesTrabajoPanelProvider);
    final panelData = panelAsync.valueOrNull;
    final selectedItem = _findSelected(
      panelData?.items ?? const <OrdenTrabajoItem>[],
    );
    _tryHandleInitialAction(panelData);
    _scheduleFilterCatalogSync(panelData?.roleCode);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: kToolbarHeight,
        leading: IconButton(
          tooltip: 'Regresar',
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.arrow_back),
        ),
        titleSpacing: 8,
        title: _buildAppBarTitle(selectedItem),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: TextButton.icon(
              onPressed: panelData == null
                  ? null
                  : () => _showOpcionesTrabajoDialog(selectedItem, panelData),
              style: _appBarActionButtonStyle(),
              icon: const Icon(Icons.widgets_outlined),
              label: const Text('Opciones de Trabajo'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: TextButton.icon(
              onPressed: panelData == null
                  ? null
                  : () => _showViewConfigDialog(
                      panelData,
                      _showAsignFilter(panelData.roleCode),
                    ),
              style: _appBarActionButtonStyle(),
              icon: const Icon(Icons.tune),
              label: const Text('Configuracion de Vista'),
            ),
          ),
          IconButton(
            tooltip: 'Refrescar',
            onPressed: _reload,
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.teal.shade900,
            ),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF7F3EC), Color(0xFFEFE6DA)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: panelAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('No se pudo cargar el panel: $error'),
            ),
          ),
          data: (panel) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildFiltersCard(panel),
                const SizedBox(height: 8),
                Expanded(child: _buildTable(panel)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFiltersCard(OrdenTrabajoPanelResponse panel) {
    final showAsign = _showAsignFilter(panel.roleCode);
    final flowOptions = panel.flowStatusOptions
        .where((item) => item.value.isNotEmpty)
        .toList(growable: false);
    final laboratorios = panel.laboratorios
        .where((item) => item.id > 0)
        .toList(growable: false);
    final laboratoriosByTipo = _filterLaboratoriosByTipo(
      laboratorios,
      _tipoValue,
      _sucCtrl.text,
    );
    final sucursalItems = _buildSucursalFilterItems(panel);
    final asignadoItems = _buildAsignadoFilterItems();
    final selectedSucValue = _selectedSucursalFilterValue;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filtros del panel',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: _filterFontSize + 1,
              ),
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final filtersWrap = Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _dropdownField(
                      label: 'Sucursal',
                      value: selectedSucValue,
                      width: 180,
                      items: sucursalItems,
                      onChanged: (value) {
                        final nextSuc = (value ?? '').trim();
                        setState(() {
                          _sucCtrl.text = nextSuc;
                          _asignValue = null;
                          _lastAsignadosSuc = null;
                          final laboratoriosCompatibles =
                              _filterLaboratoriosByTipo(
                                laboratorios,
                                _tipoValue,
                                nextSuc,
                              );
                          final selectedLabId = _parseLaboratorioId(
                            _laboratorioId ?? '',
                          );
                          if (selectedLabId != null &&
                              !laboratoriosCompatibles.any(
                                (item) => item.id == selectedLabId,
                              )) {
                            _laboratorioId = null;
                          }
                        });
                        unawaited(
                          _loadAsignadoOptionsForCurrentSuc(force: true),
                        );
                      },
                    ),
                    _filterField(_iordCtrl, 'IORD', width: 150),
                    _filterField(_idfolCtrl, 'IDFOL', width: 170),
                    _filterField(_clientCtrl, 'Cliente', width: 120),
                    _dropdownField(
                      label: 'Tipo',
                      value: _tipoValue,
                      width: 140,
                      items: const [
                        DropdownMenuItem<String>(
                          value: null,
                          child: Text('Todos'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'TALLADO',
                          child: Text('TALLADO'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'BISELADO',
                          child: Text('BISELADO'),
                        ),
                      ],
                      onChanged: (value) => setState(() {
                        _tipoValue = value;
                        final laboratoriosCompatibles =
                            _filterLaboratoriosByTipo(
                              laboratorios,
                              value,
                              _sucCtrl.text,
                            );
                        final selectedLabId = _parseLaboratorioId(
                          _laboratorioId ?? '',
                        );
                        if (selectedLabId == null) return;
                        if (!laboratoriosCompatibles.any(
                          (item) => item.id == selectedLabId,
                        )) {
                          _laboratorioId = null;
                        }
                      }),
                    ),
                    _dropdownField(
                      label: 'Laboratorio',
                      value: _laboratorioId,
                      width: 220,
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('Todos'),
                        ),
                        ...laboratoriosByTipo.map(
                          (item) => DropdownMenuItem<String>(
                            value: item.id.toString(),
                            child: Text(
                              item.lab.trim().isEmpty
                                  ? item.id.toString()
                                  : item.lab.trim(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _laboratorioId = value),
                    ),
                    _dropdownField(
                      label: 'Est. flujo',
                      value: _estseguValue,
                      width: 170,
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('Todos'),
                        ),
                        ...flowOptions.map((item) {
                          final rawValue = item.value.trim();
                          final itemText = rawValue.toUpperCase() == 'NULL'
                              ? (item.label.trim().isEmpty
                                    ? 'SIN FLUJO'
                                    : item.label.trim())
                              : '$rawValue ${item.label}'.trim();
                          return DropdownMenuItem<String>(
                            value: item.value,
                            child: Text(
                              itemText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }),
                      ],
                      onChanged: (value) =>
                          setState(() => _estseguValue = value),
                    ),
                    if (showAsign)
                      _dropdownField(
                        label: 'Asignado',
                        value: _asignValue,
                        width: 220,
                        items: asignadoItems,
                        onChanged: (value) =>
                            setState(() => _asignValue = value),
                      ),
                    _dateChip(
                      label: 'Desde',
                      value: _fecIni,
                      onPick: () => _pickDate(
                        initial: _fecIni,
                        onChange: (d) => setState(() => _fecIni = d),
                      ),
                      onClear: _fecIni == null
                          ? null
                          : () => setState(() => _fecIni = null),
                    ),
                    _dateChip(
                      label: 'Hasta',
                      value: _fecFin,
                      onPick: () => _pickDate(
                        initial: _fecFin,
                        onChange: (d) => setState(() => _fecFin = d),
                      ),
                      onClear: _fecFin == null
                          ? null
                          : () => setState(() => _fecFin = null),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _applyFilters(showAsign: showAsign),
                      icon: Icon(
                        Icons.search,
                        size: (_filterFontSize + 3).clamp(15.0, 20.0),
                      ),
                      style: ElevatedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.symmetric(
                          horizontal: (14 * _filterScale).clamp(10.0, 22.0),
                          vertical: (10 * _filterScale).clamp(8.0, 14.0),
                        ),
                        textStyle: TextStyle(
                          fontSize: _filterFontSize,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      label: const Text('Aplicar filtros'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _clearFilters,
                      icon: Icon(
                        Icons.clear_all,
                        size: (_filterFontSize + 3).clamp(15.0, 20.0),
                      ),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.symmetric(
                          horizontal: (14 * _filterScale).clamp(10.0, 22.0),
                          vertical: (10 * _filterScale).clamp(8.0, 14.0),
                        ),
                        textStyle: TextStyle(
                          fontSize: _filterFontSize,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      label: const Text('Limpiar filtros'),
                    ),
                  ],
                );
                final paginator = _buildPaginator(
                  panel,
                  asCard: false,
                  fontSize: _filterFontSize,
                );

                if (constraints.maxWidth < 1240) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      filtersWrap,
                      const SizedBox(height: 10),
                      Align(alignment: Alignment.centerRight, child: paginator),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: filtersWrap),
                    const SizedBox(width: 12),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: paginator,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBarTitle(OrdenTrabajoItem? selected) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _panelTitle(),
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        Text(
          _selectionStatusText(selected),
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  String _panelTitle() {
    switch (widget.panelMode) {
      case OrdenesTrabajoPanelMode.anulados:
        return 'Ordenes de Trabajo Anuladas';
      case OrdenesTrabajoPanelMode.entregadas:
        return 'Ordenes de Trabajo Entregadas';
      case OrdenesTrabajoPanelMode.operativo:
        return 'Ordenes de Trabajo';
    }
  }

  ButtonStyle _appBarActionButtonStyle() {
    return TextButton.styleFrom(
      backgroundColor: Colors.white,
      foregroundColor: Colors.teal.shade900,
      disabledBackgroundColor: Colors.white24,
      disabledForegroundColor: Colors.white70,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  void _tryHandleInitialAction(OrdenTrabajoPanelResponse? panel) {
    final initialAction = widget.initialAction;
    if (_initialActionHandled ||
        !_contextReady ||
        panel == null ||
        initialAction == null ||
        widget.panelMode != OrdenesTrabajoPanelMode.operativo) {
      return;
    }

    _initialActionHandled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (!_canLaunchInitialAction(initialAction, panel)) {
        _showError(
          'Tu usuario no tiene acceso a la opcion ${_initialActionLabel(initialAction)}.',
        );
        return;
      }

      switch (initialAction) {
        case OrdenesTrabajoInitialAction.enviar:
          await _showEnviarRelacionDialog();
          break;
        case OrdenesTrabajoInitialAction.asignar:
          await _showAsignarRelacionDialog();
          break;
        case OrdenesTrabajoInitialAction.regresarTienda:
          await _showRegresarTiendaRelacionDialog();
          break;
        case OrdenesTrabajoInitialAction.recibir:
          await _showRecibirRelacionDialog();
          break;
        case OrdenesTrabajoInitialAction.entregar:
          await _showEntregarRelacionDialog();
          break;
      }
    });
  }

  bool _canLaunchInitialAction(
    OrdenesTrabajoInitialAction action,
    OrdenTrabajoPanelResponse panel,
  ) {
    if (_isAdmin) return true;
    final allowedActions = panel.allowedActions;
    switch (action) {
      case OrdenesTrabajoInitialAction.enviar:
        return allowedActions.contains('ENVIAR');
      case OrdenesTrabajoInitialAction.asignar:
        return allowedActions.contains('ASIGNAR');
      case OrdenesTrabajoInitialAction.regresarTienda:
        return allowedActions.contains('REGRESAR_TIENDA');
      case OrdenesTrabajoInitialAction.recibir:
        return allowedActions.contains('SCAN_RECIBIR');
      case OrdenesTrabajoInitialAction.entregar:
        return allowedActions.contains('SCAN_ENTREGAR');
    }
  }

  String _initialActionLabel(OrdenesTrabajoInitialAction action) {
    switch (action) {
      case OrdenesTrabajoInitialAction.enviar:
        return 'Enviar a taller';
      case OrdenesTrabajoInitialAction.asignar:
        return 'Asignar a colaborador';
      case OrdenesTrabajoInitialAction.regresarTienda:
        return 'Recibir en tienda';
      case OrdenesTrabajoInitialAction.recibir:
        return 'Recibir en taller';
      case OrdenesTrabajoInitialAction.entregar:
        return 'Entregar a cliente';
    }
  }

  List<_OrdenTrabajoToolbarAction> _buildToolbarActions(
    OrdenTrabajoItem? selected,
    OrdenTrabajoPanelResponse? panel,
  ) {
    final selectedCount = _selectedIords.length;
    final hasSelection = selectedCount > 0;
    final hasSingleSelection = selectedCount == 1 && selected != null;
    final allowedActions = panel?.allowedActions ?? const <String>{};
    bool can(String action) => _isAdmin || allowedActions.contains(action);
    final actions = <_OrdenTrabajoToolbarAction>[];

    void addAction({
      required String action,
      required String label,
      required IconData icon,
      required bool requiresSelection,
      bool requiresSingleSelection = false,
      required VoidCallback onPressed,
    }) {
      if (!can(action)) return;
      final enabled =
          (!requiresSelection || hasSelection) &&
          (!requiresSingleSelection || hasSingleSelection);
      actions.add(
        _OrdenTrabajoToolbarAction(
          label: label,
          icon: icon,
          enabled: enabled,
          onPressed: onPressed,
        ),
      );
    }

    if (widget.panelMode == OrdenesTrabajoPanelMode.anulados) {
      actions.add(
        _OrdenTrabajoToolbarAction(
          label: 'VER DETALLE',
          icon: Icons.info_outline,
          enabled: hasSingleSelection,
          onPressed: () {
            if (!hasSingleSelection) {
              _showError('Selecciona una ORD anulada para ver detalle.');
              return;
            }
            _showDetail(selected.iord, panel);
          },
        ),
      );
      return actions;
    }

    if (widget.panelMode == OrdenesTrabajoPanelMode.entregadas) {
      actions.add(
        _OrdenTrabajoToolbarAction(
          label: 'VER DETALLE',
          icon: Icons.info_outline,
          enabled: hasSingleSelection,
          onPressed: () {
            if (!hasSingleSelection) {
              _showError('Selecciona una ORD entregada para ver detalle.');
              return;
            }
            _showDetail(selected.iord, panel);
          },
        ),
      );
      actions.add(
        _OrdenTrabajoToolbarAction(
          label: 'Garantia',
          icon: Icons.assignment_turned_in,
          enabled: hasSingleSelection,
          onPressed: () {
            if (!hasSingleSelection) {
              _showError(
                'Selecciona una ORD entregada para registrar garantia.',
              );
              return;
            }
            _doGarantia(selected.iord);
          },
        ),
      );
      return actions;
    }

    addAction(
      action: 'VER_DETALLE',
      label: 'VER DETALLE',
      icon: Icons.info_outline,
      requiresSelection: true,
      requiresSingleSelection: true,
      onPressed: () => _showDetail(selected!.iord, panel),
    );
    addAction(
      action: 'AUTORIZAR',
      label: 'AUTORIZAR',
      icon: Icons.verified,
      requiresSelection: true,
      onPressed: _doAutorizarSeleccion,
    );
    addAction(
      action: 'ANULAR',
      label: 'ANULAR',
      icon: Icons.cancel_outlined,
      requiresSelection: true,
      onPressed: _doAnularSeleccion,
    );
    addAction(
      action: 'ENVIAR',
      label: hasSelection ? 'ENVIAR A TALLER Sel.' : 'ENVIAR A TALLER',
      icon: Icons.outbound,
      requiresSelection: false,
      onPressed: _doEnviar,
    );
    addAction(
      action: 'ASIGNAR',
      label: hasSelection ? 'ASIGNAR A COLAB. Sel.' : 'ASIGNAR A COLABORADOR',
      icon: Icons.assignment_ind,
      requiresSelection: false,
      onPressed: _doAsignar,
    );
    addAction(
      action: 'TRABAJO_TERMINADO',
      label: hasSelection ? 'TRABAJO TERMINADO Sel.' : 'TRABAJO TERMINADO',
      icon: Icons.task_alt,
      requiresSelection: false,
      onPressed: _doTrabajoTerminado,
    );
    addAction(
      action: 'REGRESAR_INCIDENCIA',
      label: hasSelection ? 'INCIDENCIA Sel.' : 'Regresar incidencia',
      icon: Icons.report_problem_outlined,
      requiresSelection: false,
      onPressed: _doRegresarIncidencia,
    );
    addAction(
      action: 'REGRESAR_TIENDA',
      label: hasSelection ? 'RECIBIR EN TIENDA Sel.' : 'RECIBIR EN TIENDA',
      icon: Icons.storefront_outlined,
      requiresSelection: false,
      onPressed: _doRegresarTienda,
    );
    addAction(
      action: 'ASIGNAR_LABORATORIO',
      label: 'Asignar laboratorio',
      icon: Icons.science_outlined,
      requiresSelection: true,
      onPressed: _doAsignarLaboratorio,
    );
    addAction(
      action: 'SCAN_RECIBIR',
      label: hasSelection ? 'RECIBIR EN TALLER Sel.' : 'RECIBIR EN TALLER',
      icon: Icons.qr_code_scanner,
      requiresSelection: false,
      onPressed: _doScanRecibir,
    );
    addAction(
      action: 'SCAN_ENTREGAR',
      label: hasSelection ? 'ENTREGAR A CLIENTE Sel.' : 'ENTREGAR A CLIENTE',
      icon: Icons.qr_code,
      requiresSelection: false,
      onPressed: _doScanEntregar,
    );
    if ((_isAdmin || can('IMPRIMIR_ETIQUETA')) && panel != null) {
      actions.add(
        _OrdenTrabajoToolbarAction(
          label: 'Imprimir etiqueta',
          icon: Icons.print,
          enabled: hasSelection,
          onPressed: () => _printEtiquetasSeleccion(panel),
        ),
      );
    }

    return actions;
  }

  Future<void> _showOpcionesTrabajoDialog(
    OrdenTrabajoItem? selected,
    OrdenTrabajoPanelResponse? panel,
  ) async {
    final actions = _buildToolbarActions(selected, panel);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Opciones de Trabajo'),
        content: SizedBox(
          width: 760,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _selectionStatusText(selected),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              if (actions.isEmpty)
                const Text('Sin acciones disponibles para este panel o rol.')
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: actions
                      .map(
                        (action) => _actionButton(
                          label: action.label,
                          icon: action.icon,
                          enabled: action.enabled,
                          onPressed: action.enabled
                              ? () {
                                  Navigator.of(dialogContext).pop();
                                  action.onPressed();
                                }
                              : null,
                        ),
                      )
                      .toList(growable: false),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  String _selectionStatusText(OrdenTrabajoItem? selected) {
    final selectedCount = _selectedIords.length;
    final relatedCount = ref.watch(ordenesTrabajoEnviarRelacionProvider).length;
    if (selectedCount > 0) {
      if (selectedCount == 1) {
        return 'ORD seleccionada: ${selected?.iord ?? ''}';
      }
      return '$selectedCount ORDs seleccionadas';
    }
    if (relatedCount > 0) {
      return 'Sin selección en grilla. ORDs relacionadas: $relatedCount';
    }
    return 'Sin selección en grilla. Usa Enviar para digitar o escanear ORDs';
  }

  Widget _buildTable(OrdenTrabajoPanelResponse panel) {
    final currentFilter = ref.watch(ordenesTrabajoFilterProvider);
    if (_shouldDeferEntregadasResults(currentFilter)) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'El panel de entregadas no carga registros automáticamente. Aplica al menos un filtro para consultar.',
          ),
        ),
      );
    }
    if (panel.items.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('Sin resultados para los filtros actuales.'),
        ),
      );
    }

    final showAsign = _showAsignFilter(panel.roleCode);
    final allSelected =
        panel.items.isNotEmpty &&
        panel.items.every((row) => _selectedIords.contains(row.iord));
    final someSelected =
        !allSelected &&
        panel.items.any((row) => _selectedIords.contains(row.iord));
    final headingFontSize = (_tableFontSize + 0.3).clamp(11.0, 20.0);
    final autoWidths = _computeAutoColumnWidths(panel, showAsign: showAsign);
    double widthFor(String key) => _resolvedColumnWidth(key, autoWidths);
    final rowMaxLines = _estimateRowMaxLines(
      panel,
      showAsign: showAsign,
      widthFor: widthFor,
    );
    final dataRowHeight = _rowHeightForContent(rowMaxLines);
    final headingRowHeight = _scaledTableHeight(34 + (_tableFontSize * 0.8));

    final columns = <DataColumn>[
      DataColumn(
        label: SizedBox(
          width: 28,
          child: Checkbox(
            tristate: true,
            value: allSelected ? true : (someSelected ? null : false),
            onChanged: (_) => _toggleSelectAll(panel.items),
          ),
        ),
      ),
      _tableDataColumn('SUC', widthFor('SUC')),
      _tableDataColumn('TIPO', widthFor('TIPO')),
      _tableDataColumn('LABORATORIO', widthFor('LABORATORIO')),
      _tableDataColumn('IORD', widthFor('IORD')),
      _tableDataColumn('CLIENTE', widthFor('CLIENTE')),
      _tableDataColumn('ARTICULO', widthFor('ARTICULO')),
      _tableDataColumn('DESCRIPCION', widthFor('DESCRIPCION')),
      _tableDataColumn('CTD', widthFor('CTD'), textAlign: TextAlign.center),
      _tableDataColumn('FLUJO', widthFor('FLUJO')),
      if (showAsign) _tableDataColumn('ASIGNADO', widthFor('ASIGNADO')),
      _tableDataColumn('F_SOL', widthFor('F_SOL')),
      _tableDataColumn('F_ENT', widthFor('F_ENT')),
    ];

    return Card(
      elevation: 0,
      child: SelectionArea(
        child: SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              showCheckboxColumn: false,
              horizontalMargin: 2,
              checkboxHorizontalMargin: 2,
              columnSpacing: 0,
              headingRowHeight: headingRowHeight,
              dataRowMinHeight: dataRowHeight,
              dataRowMaxHeight: dataRowHeight,
              headingTextStyle: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: headingFontSize,
                color: Colors.black87,
              ),
              dataTextStyle: TextStyle(
                fontSize: _tableFontSize,
                color: Colors.black87,
              ),
              columns: columns,
              rows: panel.items
                  .map((row) {
                    final selected = _selectedIords.contains(row.iord);
                    final labDesc = _resolveLaboratorioDescripcion(
                      row.labor,
                      panel.laboratorios,
                    );
                    final cells = <DataCell>[
                      DataCell(
                        Checkbox(
                          value: selected,
                          onChanged: (checked) {
                            _toggleRowSelection(row.iord, checked ?? false);
                          },
                        ),
                      ),
                      DataCell(_tableCellText(row.suc, width: widthFor('SUC'))),
                      DataCell(
                        _tableCellText(row.tipo, width: widthFor('TIPO')),
                      ),
                      DataCell(
                        _tableCellText(
                          labDesc,
                          width: widthFor('LABORATORIO'),
                          maxLines: rowMaxLines,
                        ),
                      ),
                      DataCell(
                        _tableCellText(row.iord, width: widthFor('IORD')),
                      ),
                      DataCell(
                        _tableCellText(
                          '${row.clien} ${row.ncliente}'.trim(),
                          width: widthFor('CLIENTE'),
                          maxLines: rowMaxLines,
                        ),
                      ),
                      DataCell(
                        _tableCellText(row.art, width: widthFor('ARTICULO')),
                      ),
                      DataCell(
                        _tableCellText(
                          row.descArt,
                          width: widthFor('DESCRIPCION'),
                          maxLines: rowMaxLines,
                        ),
                      ),
                      DataCell(
                        _tableCellText(
                          _money(row.ctd),
                          width: widthFor('CTD'),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      DataCell(
                        _tableCellText(
                          _flowDescripcion(row.estsegu, row.estseguDesc),
                          width: widthFor('FLUJO'),
                          maxLines: rowMaxLines,
                        ),
                      ),
                      if (showAsign)
                        DataCell(
                          _tableCellText(
                            row.asign,
                            width: widthFor('ASIGNADO'),
                            maxLines: rowMaxLines,
                          ),
                        ),
                      DataCell(
                        _tableCellText(
                          _fmtDate(row.fcns),
                          width: widthFor('F_SOL'),
                        ),
                      ),
                      DataCell(
                        _tableCellText(
                          _fmtDate(row.fcnm),
                          width: widthFor('F_ENT'),
                        ),
                      ),
                    ];

                    return DataRow(
                      selected: selected,
                      onSelectChanged: (_) {
                        _toggleRowSelection(row.iord, !selected);
                      },
                      cells: cells,
                    );
                  })
                  .toList(growable: false),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaginator(
    OrdenTrabajoPanelResponse panel, {
    bool asCard = true,
    double? fontSize,
  }) {
    final totalPages = panel.pageSize <= 0
        ? 1
        : ((panel.total + panel.pageSize - 1) / panel.pageSize).ceil().clamp(
            1,
            999999,
          );
    final textSize = (fontSize ?? _filterFontSize).clamp(11.0, 18.0);
    final iconSize = (textSize + 6).clamp(16.0, 22.0);

    final content = LayoutBuilder(
      builder: (context, constraints) {
        final navButtons = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Pagina anterior',
              visualDensity: VisualDensity.compact,
              iconSize: iconSize,
              onPressed: panel.page > 1
                  ? () => _changePage(panel.page - 1)
                  : null,
              icon: const Icon(Icons.chevron_left),
            ),
            IconButton(
              tooltip: 'Pagina siguiente',
              visualDensity: VisualDensity.compact,
              iconSize: iconSize,
              onPressed: panel.page < totalPages
                  ? () => _changePage(panel.page + 1)
                  : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        );
        final summary = Text(
          'Total: ${panel.total} | Pagina ${panel.page} de $totalPages',
          style: TextStyle(fontSize: textSize, fontWeight: FontWeight.w600),
        );

        if (constraints.maxWidth < 680) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [summary, const SizedBox(height: 2), navButtons],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [summary, const SizedBox(width: 8), navButtons],
        );
      },
    );

    if (!asCard) return content;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: content,
      ),
    );
  }

  double get _filterScale {
    final scale = _filterFontSize / 13;
    if (scale < 0.85) return 0.85;
    if (scale > 1.55) return 1.55;
    return scale;
  }

  double get _tableScale {
    final scale = _tableFontSize / 13;
    if (scale < 0.85) return 0.85;
    if (scale > 1.6) return 1.6;
    return scale;
  }

  double _scaledTableHeight(double base) {
    final scaled = base * _tableScale;
    final min = base * 0.9;
    final max = base * 1.6;
    return scaled.clamp(min, max).toDouble();
  }

  double _resolvedColumnWidth(String key, Map<String, double> autoWidths) {
    final configured = _columnWidths[key];
    final fallback = autoWidths[key] ?? _defaultColumnWidths[key] ?? 90;
    final min = _columnMinWidth(key);
    final max = _columnMaxWidth(key);
    final width = configured == null
        ? fallback
        : configured * (_tableFontSize / _columnWidthsFontRef.clamp(8.0, 60.0));
    return width.clamp(min, max).toDouble();
  }

  List<String> _columnConfigKeys(bool showAsign) {
    final keys = <String>[
      'SUC',
      'TIPO',
      'LABORATORIO',
      'IORD',
      'CLIENTE',
      'ARTICULO',
      'DESCRIPCION',
      'CTD',
      'FLUJO',
      'F_SOL',
      'F_ENT',
    ];
    if (showAsign) {
      keys.insert(9, 'ASIGNADO');
    }
    return keys;
  }

  double _columnMinWidth(String key) {
    final compact = (40 + (_tableFontSize * 2.4)).clamp(42.0, 96.0).toDouble();
    switch (key) {
      case 'DESCRIPCION':
        return compact + 40;
      case 'CLIENTE':
      case 'LABORATORIO':
        return compact + 28;
      default:
        return compact;
    }
  }

  double _columnMaxWidth(String key) {
    switch (key) {
      case 'DESCRIPCION':
        return 460;
      case 'CLIENTE':
        return 360;
      case 'LABORATORIO':
        return 260;
      case 'FLUJO':
        return 240;
      default:
        return 220;
    }
  }

  Map<String, double> _computeAutoColumnWidths(
    OrdenTrabajoPanelResponse panel, {
    required bool showAsign,
  }) {
    final keys = _columnConfigKeys(showAsign);
    final widths = <String, double>{};
    final charPx = (_tableFontSize * 0.56) + 1.5;

    for (final key in keys) {
      var maxLen = (_columnTitles[key] ?? key).length;
      for (final row in panel.items) {
        final text = _columnValueText(panel, row, key);
        final len = text.trim().isEmpty ? 1 : text.length;
        if (len > maxLen) maxLen = len;
      }
      final raw = (maxLen * charPx) + 12;
      widths[key] = raw
          .clamp(_columnMinWidth(key), _columnMaxWidth(key))
          .toDouble();
    }

    return widths;
  }

  String _columnValueText(
    OrdenTrabajoPanelResponse panel,
    OrdenTrabajoItem row,
    String key,
  ) {
    switch (key) {
      case 'SUC':
        return row.suc;
      case 'TIPO':
        return row.tipo;
      case 'LABORATORIO':
        return _resolveLaboratorioDescripcion(row.labor, panel.laboratorios);
      case 'IORD':
        return row.iord;
      case 'CLIENTE':
        return '${row.clien} ${row.ncliente}'.trim();
      case 'ARTICULO':
        return row.art;
      case 'DESCRIPCION':
        return row.descArt;
      case 'CTD':
        return _money(row.ctd);
      case 'FLUJO':
        return _flowDescripcion(row.estsegu, row.estseguDesc);
      case 'ASIGNADO':
        return row.asign;
      case 'F_SOL':
        return _fmtDate(row.fcns);
      case 'F_ENT':
        return _fmtDate(row.fcnm);
      default:
        return '';
    }
  }

  int _estimateRowMaxLines(
    OrdenTrabajoPanelResponse panel, {
    required bool showAsign,
    required double Function(String key) widthFor,
  }) {
    if (panel.items.isEmpty) return 1;
    final sample = panel.items.length > 40
        ? panel.items.sublist(0, 40)
        : panel.items;
    var maxLines = 1;
    for (final row in sample) {
      final lines = <int>[
        _estimateCellLines(
          _columnValueText(panel, row, 'LABORATORIO'),
          widthFor('LABORATORIO'),
        ),
        _estimateCellLines(
          _columnValueText(panel, row, 'CLIENTE'),
          widthFor('CLIENTE'),
        ),
        _estimateCellLines(
          _columnValueText(panel, row, 'DESCRIPCION'),
          widthFor('DESCRIPCION'),
        ),
        _estimateCellLines(
          _columnValueText(panel, row, 'FLUJO'),
          widthFor('FLUJO'),
        ),
      ];
      if (showAsign) {
        lines.add(
          _estimateCellLines(
            _columnValueText(panel, row, 'ASIGNADO'),
            widthFor('ASIGNADO'),
          ),
        );
      }
      final rowLines = lines.fold<int>(
        1,
        (acc, item) => item > acc ? item : acc,
      );
      if (rowLines > maxLines) maxLines = rowLines;
      if (maxLines >= 3) break;
    }
    return maxLines.clamp(1, 3);
  }

  int _estimateCellLines(String text, double width) {
    final clean = text.trim();
    if (clean.isEmpty) return 1;
    final charPx = (_tableFontSize * 0.56) + 1.5;
    final usableWidth = (width - 8).clamp(charPx, 10000.0);
    final charsPerLine = (usableWidth / charPx).floor().clamp(1, 200);
    return (clean.length / charsPerLine).ceil().clamp(1, 3);
  }

  double _rowHeightForContent(int lines) {
    final normalized = lines.clamp(1, 3);
    final lineHeight = _tableFontSize * 1.35;
    final raw = 10 + (lineHeight * normalized);
    final min = _scaledTableHeight(34);
    final max = _scaledTableHeight(86);
    return raw.clamp(min, max).toDouble();
  }

  DataColumn _tableDataColumn(
    String key,
    double width, {
    TextAlign textAlign = TextAlign.left,
  }) {
    final label = _columnTitles[key] ?? key;
    return DataColumn(
      label: SizedBox(
        width: width,
        child: Text(
          label,
          overflow: TextOverflow.ellipsis,
          textAlign: textAlign,
        ),
      ),
    );
  }

  Widget _tableCellText(
    String text, {
    required double width,
    int maxLines = 1,
    TextAlign textAlign = TextAlign.left,
  }) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        softWrap: maxLines > 1,
        textAlign: textAlign,
      ),
    );
  }

  Future<void> _showViewConfigDialog(
    OrdenTrabajoPanelResponse panel,
    bool showAsign,
  ) async {
    final keys = _columnConfigKeys(showAsign);
    var draftFilterFont = _filterFontSize;
    var draftTableFont = _tableFontSize;
    final autoWidths = _computeAutoColumnWidths(panel, showAsign: showAsign);
    final draftWidths = <String, double>{
      for (final key in keys) key: _resolvedColumnWidth(key, autoWidths),
    };
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Configurar vista'),
          content: SizedBox(
            width: 720,
            height: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tamaño de fuente',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: draftFilterFont + 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Filtros (${draftFilterFont.toStringAsFixed(1)})',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: draftFilterFont,
                    ),
                  ),
                  Slider(
                    value: draftFilterFont,
                    min: 11,
                    max: 18,
                    divisions: 14,
                    label: draftFilterFont.toStringAsFixed(1),
                    onChanged: (value) {
                      setDialogState(() => draftFilterFont = value);
                    },
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Consulta (${draftTableFont.toStringAsFixed(1)})',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: draftFilterFont,
                    ),
                  ),
                  Slider(
                    value: draftTableFont,
                    min: 11,
                    max: 18,
                    divisions: 14,
                    label: draftTableFont.toStringAsFixed(1),
                    onChanged: (value) {
                      setDialogState(() => draftTableFont = value);
                    },
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  Text(
                    'Ancho de columnas',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: draftFilterFont + 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final key in keys)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 120,
                            child: Text(
                              _columnTitles[key] ?? key,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: draftFilterFont,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Slider(
                              value: draftWidths[key]!,
                              min: _columnMinWidth(key),
                              max: _columnMaxWidth(key),
                              divisions: 90,
                              label: draftWidths[key]!.round().toString(),
                              onChanged: (value) {
                                setDialogState(() => draftWidths[key] = value);
                              },
                            ),
                          ),
                          SizedBox(
                            width: 42,
                            child: Text(
                              draftWidths[key]!.round().toString(),
                              style: TextStyle(fontSize: draftFilterFont),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setDialogState(() {
                  draftFilterFont = 13;
                  draftTableFont = 13;
                  for (final key in keys) {
                    draftWidths[key] =
                        autoWidths[key] ?? _defaultColumnWidths[key] ?? 90;
                  }
                });
              },
              child: const Text('Restablecer'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cerrar'),
            ),
            ElevatedButton(
              onPressed: () {
                final fontRatio =
                    draftTableFont / _tableFontSize.clamp(8.0, 60.0);
                setState(() {
                  _filterFontSize = draftFilterFont;
                  _tableFontSize = draftTableFont;
                  _columnWidths.clear();
                  for (final key in keys) {
                    _columnWidths[key] = draftWidths[key]! * fontRatio;
                  }
                  _columnWidthsFontRef = draftTableFont;
                });
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Aplicar'),
            ),
          ],
        ),
      ),
    );
  }

  OrdenTrabajoItem? _findSelected(List<OrdenTrabajoItem> items) {
    for (final row in items) {
      if (_selectedIords.contains(row.iord)) return row;
    }
    return null;
  }

  void _toggleSelectAll(List<OrdenTrabajoItem> rows) {
    setState(() {
      final allSelected =
          rows.isNotEmpty &&
          rows.every((row) => _selectedIords.contains(row.iord));
      if (allSelected) {
        for (final row in rows) {
          _selectedIords.remove(row.iord);
        }
      } else {
        for (final row in rows) {
          _selectedIords.add(row.iord);
        }
      }
    });
  }

  void _toggleRowSelection(String iord, bool selected) {
    setState(() {
      if (selected) {
        _selectedIords.add(iord);
      } else {
        _selectedIords.remove(iord);
      }
    });
  }

  void _syncSelection(List<OrdenTrabajoItem> rows) {
    final visible = rows.map((row) => row.iord).toSet();
    _selectedIords.removeWhere((iord) => !visible.contains(iord));
  }

  static const List<String> _jobDisplayOrder = <String>['OD', 'OI', 'ADD'];

  int _jobSortWeight(String value) {
    final normalized = _normalizeJob(value);
    final index = _jobDisplayOrder.indexOf(normalized);
    return index >= 0 ? index : _jobDisplayOrder.length;
  }

  List<Map<String, String>> _sortEditableDetailRows(
    List<Map<String, String>> rows,
  ) {
    final knownRows = <String, Map<String, String>>{};
    final extraRows = <Map<String, String>>[];

    for (final row in rows) {
      final normalizedJob = _normalizeJob(row['job'] ?? '');
      if (_jobDisplayOrder.contains(normalizedJob) &&
          !knownRows.containsKey(normalizedJob)) {
        knownRows[normalizedJob] = row;
      } else {
        extraRows.add(row);
      }
    }

    final sorted = <Map<String, String>>[
      for (final job in _jobDisplayOrder)
        knownRows[job] ??
            <String, String>{
              'key': 'row-${job.toLowerCase()}',
              'job': job,
              'esf': '',
              'cil': '',
              'eje': '',
            },
    ];

    extraRows.sort((a, b) {
      final byJob = _jobSortWeight(
        a['job'] ?? '',
      ).compareTo(_jobSortWeight(b['job'] ?? ''));
      if (byJob != 0) return byJob;
      return (a['key'] ?? '').compareTo(b['key'] ?? '');
    });
    sorted.addAll(extraRows);
    return sorted;
  }

  List<TallerEtiquetaOrdLegacyDetail> _sortLegacyEtiquetaDetails(
    Iterable<TallerEtiquetaOrdLegacyDetail> details,
  ) {
    final sorted = details.toList(growable: false).toList();
    sorted.sort((a, b) {
      final byJob = _jobSortWeight(
        a.job ?? '',
      ).compareTo(_jobSortWeight(b.job ?? ''));
      if (byJob != 0) return byJob;
      return (a.job ?? '').compareTo(b.job ?? '');
    });
    return sorted;
  }

  String _resolveLaboratorioDescripcion(
    String laborValue,
    List<OrdenTrabajoLaboratorioOption> laboratorios,
  ) {
    final clean = laborValue.trim();
    if (clean.isEmpty) return '-';
    final laborId = _parseLaboratorioId(clean);
    if (laborId == null) return clean;
    for (final item in laboratorios) {
      if (item.id == laborId) {
        final lab = item.lab.trim();
        return lab.isEmpty ? laborId.toString() : lab;
      }
    }
    return laborId.toString();
  }

  List<OrdenTrabajoLaboratorioOption> _filterLaboratoriosByTipo(
    List<OrdenTrabajoLaboratorioOption> laboratorios,
    String? tipo,
    String? suc,
  ) {
    final tipoNorm = (tipo ?? '').trim().toUpperCase();
    final sucNorm = (suc ?? '').trim().toUpperCase();
    final filtered = laboratorios
        .where((item) {
          final matchesTipo =
              tipoNorm.isEmpty || item.tipoLab.trim().toUpperCase() == tipoNorm;
          final itemSuc = item.suc.trim().toUpperCase();
          final matchesSuc =
              sucNorm.isEmpty || itemSuc.isEmpty || itemSuc == sucNorm;
          return matchesTipo && matchesSuc;
        })
        .toList(growable: false);
    return _dedupeLaboratorios(filtered);
  }

  List<OrdenTrabajoLaboratorioOption> _laboratoriosDetallePorTipo(
    List<OrdenTrabajoLaboratorioOption> laboratorios,
    String tipo,
    String suc,
    String selectedLaborValue,
  ) {
    final byTipo = _filterLaboratoriosByTipo(laboratorios, tipo, suc).toList();
    final selectedId = _parseLaboratorioId(selectedLaborValue);
    if (selectedId == null) return byTipo;
    if (byTipo.any((item) => item.id == selectedId)) return byTipo;
    for (final item in laboratorios) {
      if (item.id == selectedId) {
        byTipo.add(item);
        break;
      }
    }
    return _dedupeLaboratorios(byTipo);
  }

  List<OrdenTrabajoLaboratorioOption> _dedupeLaboratorios(
    List<OrdenTrabajoLaboratorioOption> laboratorios,
  ) {
    final seen = <int>{};
    final out = <OrdenTrabajoLaboratorioOption>[];
    for (final item in laboratorios) {
      if (item.id <= 0 || !seen.add(item.id)) continue;
      out.add(item);
    }
    return out;
  }

  int? _parseLaboratorioId(String value) {
    final parsedInt = int.tryParse(value);
    if (parsedInt != null) return parsedInt;
    final parsedDouble = double.tryParse(value);
    if (parsedDouble == null || !parsedDouble.isFinite) return null;
    final truncated = parsedDouble.truncate();
    if ((parsedDouble - truncated).abs() > 0.000001) return null;
    return truncated;
  }

  bool _shouldDeferEntregadasResults(OrdenesTrabajoFilter filter) {
    if (widget.panelMode != OrdenesTrabajoPanelMode.entregadas) return false;
    return !_hasManualEntregadasFilters(filter);
  }

  bool _hasManualEntregadasFilters(OrdenesTrabajoFilter filter) {
    bool hasText(String? value) => (value ?? '').trim().isNotEmpty;
    return hasText(filter.iord) ||
        hasText(filter.idfol) ||
        hasText(filter.client) ||
        hasText(filter.art) ||
        hasText(filter.tipo) ||
        hasText(filter.labor) ||
        hasText(filter.estatus) ||
        hasText(filter.estsegu) ||
        filter.fecIni != null ||
        filter.fecFin != null ||
        hasText(filter.asign) ||
        hasText(filter.tipom) ||
        hasText(filter.motr) ||
        hasText(filter.search) ||
        (_isAdmin && hasText(filter.suc));
  }

  String _normalizeLaboratorioValue(String value) {
    final clean = value.trim();
    if (clean.isEmpty) return '';
    final laborId = _parseLaboratorioId(clean);
    return laborId?.toString() ?? clean;
  }

  String _flowDescripcion(String estsegu, String estseguDesc) {
    final code = estsegu.trim();
    final desc = estseguDesc.trim();
    if (code.isEmpty && desc.isEmpty) return 'SIN FLUJO';
    if (code.isEmpty) return desc;
    if (desc.isEmpty) return code;
    return '$code $desc';
  }

  List<Map<String, String>> _toEditableDetailRows(
    List<Map<String, dynamic>> details,
  ) {
    final rows = <Map<String, String>>[];
    var index = 0;
    for (final item in details) {
      rows.add({
        'key': 'row-$index',
        'iordp': _textOf(item['IORDP']),
        'job': _textOf(item['JOB']),
        'esf': _textOf(item['ESF']),
        'cil': _textOf(item['CIL']),
        'eje': _textOf(item['EJE']),
      });
      index++;
    }
    if (rows.isEmpty) {
      rows.addAll([
        {'key': 'row-od', 'job': 'OD', 'esf': '', 'cil': '', 'eje': ''},
        {'key': 'row-oi', 'job': 'OI', 'esf': '', 'cil': '', 'eje': ''},
        {'key': 'row-add', 'job': 'ADD', 'esf': '', 'cil': '', 'eje': ''},
      ]);
    }
    return _sortEditableDetailRows(rows);
  }

  String _normalizeJob(String value) => value.trim().toUpperCase();

  int? _parseIntLike(String value) {
    final clean = value.trim();
    if (clean.isEmpty) return null;
    final parsedInt = int.tryParse(clean);
    if (parsedInt != null) return parsedInt;
    final parsedDouble = double.tryParse(clean);
    if (parsedDouble == null || !parsedDouble.isFinite) return null;
    final truncated = parsedDouble.truncate();
    if ((parsedDouble - truncated).abs() > 0.000001) return null;
    return truncated;
  }

  bool _isFlowStatus(String value, double expected) {
    final parsed = double.tryParse(value.trim());
    if (parsed == null || !parsed.isFinite) return false;
    return (parsed - expected).abs() <= 0.0001;
  }

  String _textOf(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  DateTime? _toDate(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  Widget _filterField(
    TextEditingController ctrl,
    String label, {
    double width = 140,
    bool enabled = true,
  }) {
    final scaledWidth = (width * _filterScale).clamp(width * 0.9, width * 1.7);
    return SizedBox(
      width: scaledWidth.toDouble(),
      child: TextField(
        controller: ctrl,
        enabled: enabled,
        style: TextStyle(fontSize: _filterFontSize),
        decoration: InputDecoration(
          isDense: true,
          border: const OutlineInputBorder(),
          labelText: label,
          labelStyle: TextStyle(fontSize: _filterFontSize),
          floatingLabelStyle: TextStyle(
            fontSize: (_filterFontSize - 0.6).clamp(10.0, 18.0),
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: (10 * _filterScale).clamp(8.0, 16.0),
            vertical: (10 * _filterScale).clamp(8.0, 16.0),
          ),
        ),
      ),
    );
  }

  Widget _dropdownField({
    required String label,
    required String? value,
    required double width,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?>? onChanged,
  }) {
    final safeValue = _coerceDropdownValue(value, items);
    final scaledWidth = (width * _filterScale).clamp(width * 0.9, width * 1.7);
    return SizedBox(
      width: scaledWidth.toDouble(),
      child: DropdownButtonFormField<String>(
        key: ValueKey('$label-${safeValue ?? 'ALL'}'),
        initialValue: safeValue,
        isDense: true,
        isExpanded: true,
        items: items,
        onChanged: onChanged,
        style: TextStyle(fontSize: _filterFontSize, color: Colors.black87),
        decoration: InputDecoration(
          isDense: true,
          border: const OutlineInputBorder(),
          labelText: label,
          labelStyle: TextStyle(fontSize: _filterFontSize),
          floatingLabelStyle: TextStyle(
            fontSize: (_filterFontSize - 0.6).clamp(10.0, 18.0),
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: (10 * _filterScale).clamp(8.0, 16.0),
            vertical: (10 * _filterScale).clamp(8.0, 16.0),
          ),
        ),
      ),
    );
  }

  String? _coerceDropdownValue(
    String? value,
    List<DropdownMenuItem<String>> items,
  ) {
    if (value == null) return null;
    for (final item in items) {
      if (item.value == value) {
        return value;
      }
    }
    return null;
  }

  bool _showAsignFilter(String roleCodeRaw) {
    final role = roleCodeRaw.trim().toUpperCase();
    if (_isAdmin) return true;
    return role == 'JEF_TALLER' ||
        role == 'TALLER' ||
        role == 'ANALISTA_ORD' ||
        role == 'ANALISTA' ||
        role == 'ENC_MAQUILA' ||
        role == 'ENCARGADO_MAQUILA' ||
        role == 'ENC_BISEL' ||
        role == 'ENCARGADO_BISELADO';
  }

  bool _canEditOrdDetail(String roleCodeRaw) {
    final role = roleCodeRaw.trim().toUpperCase();
    if (_isAdmin) return true;
    return role == 'JEF_TALLER' ||
        role == 'TALLER' ||
        role == 'ANALISTA_ORD' ||
        role == 'ANALISTA';
  }

  bool _canManageOrdTipoAndPrint(String roleCodeRaw) {
    final role = roleCodeRaw.trim().toUpperCase();
    if (_isAdmin) return true;
    return role == 'JEF_TALLER' || role == 'ANALISTA_ORD' || role == 'ANALISTA';
  }

  Widget _dateChip({
    required String label,
    required DateTime? value,
    required VoidCallback onPick,
    VoidCallback? onClear,
  }) {
    final iconSize = (_filterFontSize + 2).clamp(14.0, 20.0);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: (8 * _filterScale).clamp(6.0, 14.0),
        vertical: (4 * _filterScale).clamp(3.0, 10.0),
      ),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ${_fmtDate(value)}',
            style: TextStyle(fontSize: _filterFontSize),
          ),
          const SizedBox(width: 4),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Seleccionar fecha',
            onPressed: onPick,
            icon: Icon(Icons.calendar_today, size: iconSize),
          ),
          if (onClear != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Limpiar fecha',
              onPressed: onClear,
              icon: Icon(Icons.clear, size: iconSize),
            ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required bool enabled,
    required VoidCallback? onPressed,
  }) {
    final iconSize = (_filterFontSize + 2).clamp(14.0, 20.0);
    return ElevatedButton.icon(
      onPressed: enabled ? onPressed : null,
      style: ElevatedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.symmetric(
          horizontal: (12 * _filterScale).clamp(8.0, 20.0),
          vertical: (8 * _filterScale).clamp(6.0, 14.0),
        ),
        textStyle: TextStyle(
          fontSize: _filterFontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
      icon: Icon(icon, size: iconSize),
      label: Text(label),
    );
  }

  Future<void> _pickDate({
    required DateTime? initial,
    required void Function(DateTime value) onChange,
  }) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null || !mounted) return;
    onChange(picked);
  }

  Future<void> _reload() async {
    ref.invalidate(ordenesTrabajoPanelProvider);
    await ref.read(ordenesTrabajoPanelProvider.future);
    if (!mounted) return;
    setState(() {
      // Mantener selección solamente del resultado visible tras recarga.
      _syncSelection(
        ref.read(ordenesTrabajoPanelProvider).valueOrNull?.items ??
            const <OrdenTrabajoItem>[],
      );
    });
  }

  void _applyFilters({required bool showAsign}) {
    final current = ref.read(ordenesTrabajoFilterProvider);
    ref.read(ordenesTrabajoFilterProvider.notifier).state = current.copyWith(
      iord: _iordCtrl.text,
      idfol: _idfolCtrl.text,
      client: _clientCtrl.text,
      art: null,
      tipo: _tipoValue,
      labor: _laboratorioId,
      estatus: null,
      estsegu: _estseguValue,
      fecIni: _fecIni,
      fecFin: _fecFin,
      asign: showAsign ? _asignValue : null,
      tipom: null,
      motr: null,
      suc: _selectedFilterSuc,
      search: null,
      page: 1,
    );
    setState(() => _selectedIords.clear());
  }

  void _clearFilters() {
    _iordCtrl.clear();
    _idfolCtrl.clear();
    _clientCtrl.clear();
    _sucCtrl.clear();
    setState(() {
      _asignValue = null;
      _tipoValue = null;
      _laboratorioId = null;
      _estseguValue = null;
      _fecIni = null;
      _fecFin = null;
      _selectedIords.clear();
    });

    ref.read(ordenesTrabajoFilterProvider.notifier).state =
        OrdenesTrabajoFilter(suc: null, panelMode: widget.panelMode);
  }

  String? get _selectedFilterSuc {
    final suc = _sucCtrl.text.trim().toUpperCase();
    return suc.isEmpty ? null : suc;
  }

  String? get _selectedSucursalFilterValue {
    return _selectedFilterSuc;
  }

  List<DropdownMenuItem<String>> _buildSucursalFilterItems(
    OrdenTrabajoPanelResponse panel,
  ) {
    final options = _visibleSucursalOptions(panel);
    final items = <DropdownMenuItem<String>>[
      const DropdownMenuItem<String>(value: null, child: Text('Todos')),
    ];
    items.addAll(
      options.map(
        (item) => DropdownMenuItem<String>(
          value: item.suc.trim().toUpperCase(),
          child: Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
    return items;
  }

  List<DropdownMenuItem<String>> _buildAsignadoFilterItems() {
    final selectedValue = (_asignValue ?? '').trim();
    final options = [..._asignadoOptions];
    if (selectedValue.isNotEmpty &&
        !options.any((item) => item.idopv.trim() == selectedValue)) {
      options.add(
        OrdenTrabajoColaboradorOption(
          idopv: selectedValue,
          label: selectedValue,
          nomb: '',
          apelp: '',
          apelm: '',
          suc: _selectedFilterSuc ?? '',
        ),
      );
    }
    return <DropdownMenuItem<String>>[
      const DropdownMenuItem<String>(value: null, child: Text('Todos')),
      ...options.map(
        (item) => DropdownMenuItem<String>(
          value: item.idopv.trim(),
          child: Text(
            item.label.trim().isEmpty ? item.idopv : item.label.trim(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    ];
  }

  List<OrdenTrabajoSucursalOption> _visibleSucursalOptions(
    OrdenTrabajoPanelResponse panel,
  ) {
    final currentSuc = (_selectedFilterSuc ?? '').trim().toUpperCase();
    final allowedSucs = panel.allowedSucs
        .map((item) => item.trim().toUpperCase())
        .where((item) => item.isNotEmpty)
        .toSet();
    final filtered = _isAdmin || allowedSucs.isEmpty
        ? _sucursalOptions
        : _sucursalOptions
              .where(
                (item) => allowedSucs.contains(item.suc.trim().toUpperCase()),
              )
              .toList(growable: false);
    if (filtered.isNotEmpty) return filtered;
    if (currentSuc.isEmpty) return const <OrdenTrabajoSucursalOption>[];
    return <OrdenTrabajoSucursalOption>[
      OrdenTrabajoSucursalOption(suc: currentSuc, label: currentSuc, desc: ''),
    ];
  }

  void _scheduleFilterCatalogSync(String? roleCodeRaw) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_sucursalOptions.isEmpty && !_loadingSucursalOptions) {
        unawaited(_loadSucursalOptions());
      }
      final normalizedRole = (roleCodeRaw ?? '').trim();
      if (normalizedRole.isEmpty) return;
      final canShowAsign = _showAsignFilter(normalizedRole);
      if (canShowAsign) {
        unawaited(_loadAsignadoOptionsForCurrentSuc());
      } else if (_asignadoOptions.isNotEmpty || _asignValue != null) {
        setState(() {
          _asignadoOptions = const <OrdenTrabajoColaboradorOption>[];
          _asignValue = null;
          _lastAsignadosSuc = null;
        });
      }
    });
  }

  Future<void> _loadSucursalOptions() async {
    if (_loadingSucursalOptions) return;
    _loadingSucursalOptions = true;
    try {
      final items = [
        ...await ref.read(ordenesTrabajoApiProvider).fetchSucursales(),
      ];
      if (!mounted) return;
      items.sort(
        (a, b) =>
            a.suc.trim().toUpperCase().compareTo(b.suc.trim().toUpperCase()),
      );
      setState(() {
        _sucursalOptions = items;
      });
    } catch (e) {
      if (!mounted) return;
      _showError(
        apiErrorMessage(e, fallback: 'No se pudieron cargar las sucursales.'),
      );
    } finally {
      _loadingSucursalOptions = false;
    }
  }

  Future<void> _loadAsignadoOptionsForCurrentSuc({bool force = false}) async {
    final suc = (_selectedFilterSuc ?? _userSuc).trim().toUpperCase();
    if (suc.isEmpty) {
      if (_asignadoOptions.isNotEmpty ||
          _asignValue != null ||
          _lastAsignadosSuc != null) {
        setState(() {
          _asignadoOptions = const <OrdenTrabajoColaboradorOption>[];
          _asignValue = null;
          _lastAsignadosSuc = null;
        });
      }
      return;
    }
    if (!force && !_loadingAsignadoOptions && _lastAsignadosSuc == suc) {
      return;
    }
    if (_loadingAsignadoOptions) return;

    _loadingAsignadoOptions = true;
    try {
      final items = await ref
          .read(ordenesTrabajoApiProvider)
          .fetchAsignarColaboradores(suc);
      if (!mounted) return;
      setState(() {
        _asignadoOptions = items;
        _lastAsignadosSuc = suc;
        if (_asignValue != null &&
            !_asignadoOptions.any(
              (item) => item.idopv.trim() == _asignValue!.trim(),
            )) {
          _asignValue = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      _showError(
        apiErrorMessage(e, fallback: 'No se pudieron cargar los asignados.'),
      );
    } finally {
      _loadingAsignadoOptions = false;
    }
  }

  void _changePage(int page) {
    final current = ref.read(ordenesTrabajoFilterProvider);
    ref.read(ordenesTrabajoFilterProvider.notifier).state = current.copyWith(
      page: page,
    );
    setState(() => _selectedIords.clear());
  }

  Future<void> _showDetail(
    String iord,
    OrdenTrabajoPanelResponse? panel,
  ) async {
    try {
      final detail = await ref
          .read(ordenesTrabajoApiProvider)
          .fetchDetail(iord);
      if (!mounted) return;
      final header = detail.header;
      final laboratorios =
          panel?.laboratorios ?? const <OrdenTrabajoLaboratorioOption>[];
      final jobRows = _toEditableDetailRows(detail.details);
      final ordId = _textOf(header['IORD'], fallback: iord);
      final idfol = _textOf(header['IDFOL']);
      final cliente = _textOf(header['CLIEN']);
      final razonSocial = _textOf(
        header['RAZONSOCIALRECEPTOR'],
        fallback: _textOf(header['NCLIENTE']),
      );
      final createdAt = _fmtDate(_toDate(header['FCNS']));
      final fEntrega = _fmtDate(_toDate(header['FCNM']));
      final articulo = _textOf(header['ART']);
      final descArticulo = _textOf(
        header['DESCART'],
        fallback: _textOf(header['DESCRT']),
      );
      final piezas = _textOf(header['CTD']);
      final flujoCode = _textOf(header['ESTSEGU']);
      final flujoDesc = _textOf(header['ESTSEGU_DESC']);
      final flujo = '$flujoCode $flujoDesc'.trim();
      final tipoOrd = _textOf(header['TIPO']);
      var selectedTipo = tipoOrd.trim().toUpperCase();
      if (selectedTipo != 'TALLADO' && selectedTipo != 'BISELADO') {
        selectedTipo = tipoOrd.trim();
      }
      final sucOrd = _textOf(header['SUC']);
      final tipom = _parseIntLike(
        _textOf(header['TIPOM'], fallback: _textOf(header['TPOM'])),
      );
      var selectedLab = _normalizeLaboratorioValue(_textOf(header['LABOR']));
      var comentarios = _textOf(header['COMAD']);
      final availableJobs = <String>{'OD', 'OI', 'ADD'};
      const detailGridFontSize = 18.0;
      const detailGridHeaderFontSize = 18.0;
      final canEditDetail =
          _isAdmin || _canEditOrdDetail(panel?.roleCode ?? '');
      final canManageTipoAndPrint = _canManageOrdTipoAndPrint(
        panel?.roleCode ?? '',
      );
      final isConsultaDetalle =
          widget.panelMode == OrdenesTrabajoPanelMode.anulados ||
          !canEditDetail;
      final allowedActions = panel?.allowedActions ?? const <String>{};
      bool can(String action) => _isAdmin || allowedActions.contains(action);
      final showCambioMaterialBtn =
          _isFlowStatus(flujoCode, 9.1) && tipom == 1 && can('CAMBIO_MATERIAL');
      final showMermaBtn =
          _isFlowStatus(flujoCode, 9.1) && tipom == 2 && can('MERMA');

      Future<bool> saveCurrentDetail({required bool showSuccessMessage}) async {
        try {
          final laborId = _parseLaboratorioId(selectedLab);
          await ref
              .read(ordenesTrabajoApiProvider)
              .saveDetail(
                ordId,
                labor: laborId,
                tipo: canManageTipoAndPrint ? selectedTipo : null,
                comentarios: comentarios,
                details: jobRows,
              );
          if (!mounted) return false;
          if (showSuccessMessage) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Cambios de ORD guardados.')),
            );
          }
          await _reload();
          return true;
        } catch (e) {
          if (!mounted) return false;
          _showError(
            apiErrorMessage(e, fallback: 'No se pudo guardar detalle ORD'),
          );
          return false;
        }
      }

      await showDialog<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) {
            final laboratoriosByTipo = _laboratoriosDetallePorTipo(
              laboratorios,
              selectedTipo,
              sucOrd,
              selectedLab,
            );
            final editableLaboratorios = laboratoriosByTipo.isNotEmpty
                ? laboratoriosByTipo
                : laboratorios;
            final selectedLabDropdownValue =
                editableLaboratorios.any(
                  (lab) => lab.id.toString() == selectedLab,
                )
                ? selectedLab
                : null;
            final laboratorioLabel = () {
              if (selectedLab.isEmpty) return '';
              final selectedLabId = _parseLaboratorioId(selectedLab);
              final options = editableLaboratorios;
              if (selectedLabId != null) {
                for (final lab in options) {
                  if (lab.id == selectedLabId) {
                    return lab.lab.trim().isEmpty
                        ? lab.id.toString()
                        : lab.lab.trim();
                  }
                }
                for (final lab in laboratorios) {
                  if (lab.id == selectedLabId) {
                    return lab.lab.trim().isEmpty
                        ? lab.id.toString()
                        : lab.lab.trim();
                  }
                }
                return selectedLabId.toString();
              }
              return selectedLab;
            }();
            final selectedTipoDropdownValue =
                selectedTipo == 'TALLADO' || selectedTipo == 'BISELADO'
                ? selectedTipo
                : null;

            return AlertDialog(
              title: const Text('DETALLE DE ORDEN DE TRABAJO'),
              content: SizedBox(
                width: 980,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'ID ORD: $ordId',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            'Fch creación: $createdAt',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 12,
                        runSpacing: 10,
                        children: [
                          if (canManageTipoAndPrint)
                            SizedBox(
                              width: 180,
                              child: isConsultaDetalle
                                  ? TextFormField(
                                      initialValue: selectedTipo,
                                      readOnly: true,
                                      decoration: const InputDecoration(
                                        labelText: 'Tipo',
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                    )
                                  : DropdownButtonFormField<String>(
                                      key: ValueKey(
                                        'detalle-tipo-${ordId.trim()}-$selectedTipo',
                                      ),
                                      initialValue: selectedTipoDropdownValue,
                                      isExpanded: true,
                                      decoration: const InputDecoration(
                                        labelText: 'Tipo',
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                      items: const [
                                        DropdownMenuItem<String>(
                                          value: 'TALLADO',
                                          child: Text('TALLADO'),
                                        ),
                                        DropdownMenuItem<String>(
                                          value: 'BISELADO',
                                          child: Text('BISELADO'),
                                        ),
                                      ],
                                      onChanged: (value) {
                                        setDialogState(() {
                                          selectedTipo = value ?? selectedTipo;
                                          final compatibles =
                                              _laboratoriosDetallePorTipo(
                                                laboratorios,
                                                selectedTipo,
                                                sucOrd,
                                                selectedLab,
                                              );
                                          if (compatibles.isNotEmpty &&
                                              !compatibles.any(
                                                (lab) =>
                                                    lab.id.toString() ==
                                                    selectedLab,
                                              )) {
                                            selectedLab = '';
                                          }
                                        });
                                      },
                                    ),
                            ),
                          SizedBox(
                            width: 320,
                            child:
                                canEditDetail && editableLaboratorios.isNotEmpty
                                ? DropdownButtonFormField<String>(
                                    key: ValueKey(
                                      'detalle-labor-${ordId.trim()}-$selectedTipo-$selectedLab',
                                    ),
                                    initialValue: selectedLabDropdownValue,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Laboratorio',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    items: editableLaboratorios
                                        .map(
                                          (lab) => DropdownMenuItem<String>(
                                            value: lab.id.toString(),
                                            child: Text(
                                              lab.lab.trim().isEmpty
                                                  ? lab.id.toString()
                                                  : lab.lab.trim(),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        )
                                        .toList(growable: false),
                                    onChanged: (value) {
                                      setDialogState(() {
                                        selectedLab = value ?? '';
                                      });
                                    },
                                  )
                                : TextFormField(
                                    initialValue: laboratorioLabel,
                                    readOnly: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Laboratorio',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                  ),
                          ),
                          SizedBox(
                            width: 220,
                            child: TextFormField(
                              initialValue: idfol,
                              readOnly: true,
                              decoration: const InputDecoration(
                                labelText: 'IDFOL',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 180,
                            child: TextFormField(
                              initialValue: cliente,
                              readOnly: true,
                              decoration: const InputDecoration(
                                labelText: 'Cliente',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 360,
                            child: TextFormField(
                              initialValue: razonSocial,
                              readOnly: true,
                              decoration: const InputDecoration(
                                labelText: 'Razon social receptor',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 210,
                            child: TextFormField(
                              initialValue: articulo,
                              readOnly: true,
                              decoration: const InputDecoration(
                                labelText: 'Articulo',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 140,
                            child: TextFormField(
                              initialValue: piezas,
                              readOnly: true,
                              decoration: const InputDecoration(
                                labelText: 'Piezas',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 240,
                            child: TextFormField(
                              initialValue: flujo,
                              readOnly: true,
                              decoration: const InputDecoration(
                                labelText: 'Estado flujo',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 360,
                            child: TextFormField(
                              initialValue: descArticulo,
                              readOnly: true,
                              decoration: const InputDecoration(
                                labelText: 'Descripción artículo',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 200,
                            child: TextFormField(
                              initialValue: fEntrega,
                              readOnly: true,
                              decoration: const InputDecoration(
                                labelText: 'Fecha entrega',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        key: ValueKey(
                          'detalle-comentarios-${comentarios.length}',
                        ),
                        initialValue: comentarios,
                        minLines: 2,
                        maxLines: 3,
                        readOnly: isConsultaDetalle,
                        decoration: const InputDecoration(
                          labelText: 'Comentarios',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: isConsultaDetalle
                            ? null
                            : (value) => comentarios = value,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Detalle de graduación',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: detailGridHeaderFontSize,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Table(
                        border: TableBorder.all(color: Colors.grey.shade400),
                        columnWidths: const {
                          0: FixedColumnWidth(90),
                          1: FixedColumnWidth(90),
                          2: FixedColumnWidth(90),
                          3: FixedColumnWidth(90),
                        },
                        children: [
                          const TableRow(
                            decoration: BoxDecoration(color: Color(0xFFE9EEF6)),
                            children: [
                              Padding(
                                padding: EdgeInsets.all(6),
                                child: Text(
                                  'JOB',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: detailGridHeaderFontSize,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.all(6),
                                child: Text(
                                  'ESF',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: detailGridHeaderFontSize,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.all(6),
                                child: Text(
                                  'CIL',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: detailGridHeaderFontSize,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.all(6),
                                child: Text(
                                  'EJE',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: detailGridHeaderFontSize,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                          ...jobRows.map(
                            (line) => TableRow(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Focus(
                                    canRequestFocus: false,
                                    skipTraversal: true,
                                    descendantsAreFocusable: false,
                                    child: IgnorePointer(
                                      child: TextFormField(
                                        key: ValueKey(
                                          'job-${line['key']}-${line['job']}',
                                        ),
                                        initialValue: line['job'],
                                        textAlign: TextAlign.center,
                                        readOnly: true,
                                        style: const TextStyle(
                                          fontSize: detailGridFontSize,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: TextFormField(
                                    key: ValueKey(
                                      'esf-${line['key']}-${line['esf']}',
                                    ),
                                    initialValue: line['esf'],
                                    textAlign: TextAlign.center,
                                    readOnly: !canEditDetail,
                                    style: const TextStyle(
                                      fontSize: detailGridFontSize,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: canEditDetail
                                        ? (value) => line['esf'] = value
                                        : null,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: TextFormField(
                                    key: ValueKey(
                                      'cil-${line['key']}-${line['cil']}',
                                    ),
                                    initialValue: line['cil'],
                                    textAlign: TextAlign.center,
                                    readOnly: !canEditDetail,
                                    style: const TextStyle(
                                      fontSize: detailGridFontSize,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: canEditDetail
                                        ? (value) => line['cil'] = value
                                        : null,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: TextFormField(
                                    key: ValueKey(
                                      'eje-${line['key']}-${line['eje']}',
                                    ),
                                    initialValue: line['eje'],
                                    textAlign: TextAlign.center,
                                    readOnly: !canEditDetail,
                                    style: const TextStyle(
                                      fontSize: detailGridFontSize,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    textInputAction: TextInputAction.done,
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: canEditDetail
                                        ? (value) => line['eje'] = value
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (jobRows
                              .where(
                                (line) => availableJobs.contains(
                                  _normalizeJob(line['job'] ?? ''),
                                ),
                              )
                              .isEmpty)
                            const TableRow(
                              children: [
                                Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Text('OD'),
                                ),
                                Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Text(''),
                                ),
                                Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Text(''),
                                ),
                                Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Text(''),
                                ),
                              ],
                            ),
                        ],
                      ),
                      if (showCambioMaterialBtn || showMermaBtn) ...[
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            if (showCambioMaterialBtn)
                              OutlinedButton.icon(
                                onPressed: () async {
                                  Navigator.of(ctx).pop();
                                  await _doCambioMaterial(ordId);
                                },
                                icon: const Icon(Icons.swap_horiz),
                                label: const Text('Cambio material'),
                              ),
                            if (showMermaBtn)
                              OutlinedButton.icon(
                                onPressed: () async {
                                  Navigator.of(ctx).pop();
                                  await _doMerma(ordId);
                                },
                                icon: const Icon(Icons.warning_amber),
                                label: const Text('Merma'),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                if (canManageTipoAndPrint)
                  OutlinedButton.icon(
                    onPressed: () async {
                      final canPrint =
                          isConsultaDetalle ||
                          await saveCurrentDetail(showSuccessMessage: false);
                      if (!canPrint || !mounted || !ctx.mounted) return;
                      Navigator.of(ctx).pop();
                      await _printEtiquetasPorIords([ordId], panel: panel);
                    },
                    icon: const Icon(Icons.print),
                    label: const Text('Imprimir etiqueta'),
                  ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cerrar'),
                ),
                if (!isConsultaDetalle)
                  ElevatedButton(
                    onPressed: () async {
                      final saved = await saveCurrentDetail(
                        showSuccessMessage: true,
                      );
                      if (!saved || !mounted || !ctx.mounted) return;
                      Navigator.of(ctx).pop();
                    },
                    child: const Text('Guardar cambios'),
                  ),
              ],
            );
          },
        ),
      );
    } catch (e) {
      _showError(apiErrorMessage(e, fallback: 'No se pudo cargar detalle ORD'));
    }
  }

  Future<void> _doAutorizarSeleccion() async {
    final iords = _selectedIords.toList(growable: false);
    if (iords.isEmpty) return;
    final api = ref.read(ordenesTrabajoApiProvider);
    var success = 0;
    final errors = <String>[];
    for (final iord in iords) {
      try {
        await api.autorizar(iord);
        success++;
      } catch (e) {
        errors.add('$iord: ${apiErrorMessage(e, fallback: 'Error')}');
      }
    }
    if (!mounted) return;
    if (success > 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ORDs autorizadas: $success')));
    }
    if (errors.isNotEmpty) {
      _showError(
        'No se autorizaron ${errors.length} ORDs. Revisa permisos/estado.',
      );
    }
    await _reload();
  }

  Future<void> _doAnularSeleccion() async {
    final iords = _selectedIords.toList(growable: false);
    if (iords.isEmpty) {
      _showError('Selecciona una o más ORDs para anular.');
      return;
    }
    final confirm = await _confirmAnular(iords.length);
    if (confirm != true) return;

    await _executeAction(
      () => ref.read(ordenesTrabajoApiProvider).anularLote(iords),
    );
  }

  Future<void> _printEtiquetasSeleccion(OrdenTrabajoPanelResponse panel) async {
    final selectedIords = panel.items
        .where((row) => _selectedIords.contains(row.iord))
        .map((row) => row.iord)
        .toList(growable: false);
    if (selectedIords.isEmpty) {
      _showError('Selecciona al menos una ORD para imprimir etiquetas.');
      return;
    }
    await _printEtiquetasPorIords(selectedIords, panel: panel);
  }

  Future<void> _printEtiquetasPorIords(
    List<String> iords, {
    OrdenTrabajoPanelResponse? panel,
  }) async {
    final confirm = await _confirmImprimirEtiquetas(iords.length);
    if (confirm != true) return;

    final selectedRowsByIord = <String, OrdenTrabajoItem>{
      for (final row in panel?.items ?? const <OrdenTrabajoItem>[])
        row.iord: row,
    };
    final api = ref.read(ordenesTrabajoApiProvider);
    final ords = <TallerEtiquetaOrdLegacy>[];
    for (final iord in iords) {
      final row = selectedRowsByIord[iord];
      try {
        final detail = await api.fetchDetail(iord);
        final header = detail.header;
        final details = _sortLegacyEtiquetaDetails(
          detail.details.map(
            (item) => TallerEtiquetaOrdLegacyDetail(
              job: _textOf(item['JOB']),
              esf: _textOf(item['ESF']),
              cil: _textOf(item['CIL']),
              eje: _textOf(item['EJE']),
            ),
          ),
        );
        ords.add(
          TallerEtiquetaOrdLegacy(
            ord: iord,
            description: row?.descArt ?? _textOf(header['DESCART']),
            tipo: row?.tipo ?? _textOf(header['TIPO']),
            clientNumber: _textOf(header['CLIEN']),
            clientName: _textOf(
              header['RAZONSOCIALRECEPTOR'],
              fallback: _textOf(header['NCLIENTE']),
            ),
            deliveryDate: _textOf(
              header['FCNTE'],
              fallback: _textOf(
                header['FCNEN'],
                fallback: _fmtDate(_toDate(header['FCNM'])),
              ),
            ),
            deliveryTime: _textOf(
              header['HR_ENT'],
              fallback: _textOf(header['HREN'], fallback: '-'),
            ),
            comment: _textOf(header['COMAD']),
            details: details,
          ),
        );
      } catch (_) {
        ords.add(
          TallerEtiquetaOrdLegacy(
            ord: iord,
            description: row?.descArt,
            tipo: row?.tipo,
          ),
        );
      }
    }

    if (ords.isEmpty) {
      _showError('No se pudo construir etiquetas para las ORDs seleccionadas.');
      return;
    }

    final doc = _buildEtiquetasLegacyPdf(ords);
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    await Printing.layoutPdf(
      name: 'etiquetas_ords_$y$m$d-$hh$mm.pdf',
      onLayout: (_) => doc.save(),
    );
  }

  Future<bool?> _confirmImprimirEtiquetas(int total) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Imprimir etiquetas'),
        content: Text(
          'Se generará${total == 1 ? '' : 'n'} etiqueta${total == 1 ? '' : 's'} para $total ORD${total == 1 ? '' : 's'}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.print),
            label: const Text('Imprimir etiqueta'),
          ),
        ],
      ),
    );
  }

  pw.Document _buildEtiquetasLegacyPdf(List<TallerEtiquetaOrdLegacy> ords) {
    final doc = pw.Document();
    final pageFormat = PdfPageFormat(
      _legacyEtiquetaWidthMm * PdfPageFormat.mm,
      _legacyEtiquetaHeightMm * PdfPageFormat.mm,
      marginAll: 0,
    );
    for (final ord in ords) {
      doc.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: pw.EdgeInsets.all(0.8 * PdfPageFormat.mm),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: buildTicketOrdsLegacySection(
              ords: [ord],
              widthMm: _legacyEtiquetaWidthMm,
              baseFontSize: 6.6,
              smallFontSize: 4.8,
              showSectionTitle: false,
            ),
          ),
        ),
      );
    }
    return doc;
  }

  Future<void> _doEnviar() async {
    final selectedIords = _selectedIords.toList(growable: false);
    if (selectedIords.isNotEmpty) {
      await _doEnviarSeleccionados(selectedIords);
      return;
    }
    await _showEnviarRelacionDialog();
  }

  Future<void> _doAsignar() async {
    final selectedIords = _selectedIords.toList(growable: false);
    if (selectedIords.isNotEmpty) {
      await _doAsignarSeleccionados(selectedIords);
      return;
    }
    await _showAsignarRelacionDialog();
  }

  Future<void> _doTrabajoTerminado() async {
    final selectedIords = _selectedIords.toList(growable: false);
    if (selectedIords.isNotEmpty) {
      await _doTrabajoTerminadoSeleccionados(selectedIords);
      return;
    }
    await _showTrabajoTerminadoRelacionDialog();
  }

  Future<void> _doRegresarIncidencia() async {
    final selectedIords = _selectedIords.toList(growable: false);
    if (selectedIords.isNotEmpty) {
      await _doRegresarIncidenciaSeleccionados(selectedIords);
      return;
    }
    await _showRegresarIncidenciaRelacionDialog();
  }

  Future<void> _doRegresarTienda() async {
    final selectedIords = _selectedIords.toList(growable: false);
    if (selectedIords.isNotEmpty) {
      await _doRegresarTiendaSeleccionados(selectedIords);
      return;
    }
    await _showRegresarTiendaRelacionDialog();
  }

  Future<void> _doAsignarLaboratorio() async {
    final panel = ref.read(ordenesTrabajoPanelProvider).valueOrNull;
    if (panel == null) {
      _showError(
        'No hay datos del panel disponibles para asignar laboratorio.',
      );
      return;
    }
    final selectedIords = _selectedIords.toList(growable: false);
    if (selectedIords.isEmpty) {
      _showError('Selecciona una o más ORDs para asignar laboratorio.');
      return;
    }
    final selectedRows = panel.items
        .where((row) => _selectedIords.contains(row.iord))
        .toList(growable: false);
    if (selectedRows.isEmpty) {
      _showError('No se encontraron ORDs seleccionadas en la grilla actual.');
      return;
    }

    final sucs = selectedRows
        .map((row) => row.suc.trim().toUpperCase())
        .where((item) => item.isNotEmpty)
        .toSet();
    if (sucs.length > 1) {
      _showError(
        'Para asignación masiva de laboratorio, selecciona ORDs de una sola sucursal.',
      );
      return;
    }
    final suc = sucs.isEmpty ? '' : sucs.first;
    final laboratorios = panel.laboratorios
        .where((item) => item.id > 0)
        .where(
          (item) =>
              suc.isEmpty ||
              item.suc.trim().isEmpty ||
              item.suc.trim().toUpperCase() == suc,
        )
        .toList(growable: false);
    if (laboratorios.isEmpty) {
      _showError(
        'No hay laboratorios disponibles para la sucursal seleccionada.',
      );
      return;
    }

    final selectedLabor = await _selectLaboratorioDialog(laboratorios);
    if (selectedLabor == null) return;

    final confirm = await _confirmAsignarLaboratorio(
      selectedIords.length,
      selectedLabor.lab,
    );
    if (confirm != true) return;

    await _executeAction(
      () => ref
          .read(ordenesTrabajoApiProvider)
          .asignarLaboratorioLote(selectedIords, labor: selectedLabor.id),
    );
  }

  Future<void> _doEnviarSeleccionados(List<String> iords) async {
    if (iords.isEmpty) return;
    final confirm = await _confirmEnviarAmaqBisel(iords.length);
    if (confirm != true) return;

    await _executeAction(
      () => ref.read(ordenesTrabajoApiProvider).enviarLote(iords),
    );
  }

  Future<void> _doAsignarSeleccionados(List<String> iords) async {
    if (iords.isEmpty) return;
    final panel = ref.read(ordenesTrabajoPanelProvider).valueOrNull;
    if (panel == null) {
      _showError('No hay datos del panel disponibles para asignar.');
      return;
    }
    final selectedRows = panel.items
        .where((row) => _selectedIords.contains(row.iord))
        .toList(growable: false);
    if (selectedRows.isEmpty) {
      _showError(
        'No se identificaron ORDs seleccionadas para asignar colaborador.',
      );
      return;
    }

    final colaborador = await _selectColaboradorDialog();
    if (colaborador == null) return;
    final confirm = await _confirmAsignarAColaborador(
      iords.length,
      colaborador.label,
    );
    if (confirm != true) return;

    await _executeAction(
      () => ref
          .read(ordenesTrabajoApiProvider)
          .asignarLote(iords, idopv: colaborador.idopv),
    );
  }

  Future<bool?> _confirmEnviarAmaqBisel(int total) {
    return _confirmCambioEstatus(
      title: 'Confirmar envío a taller',
      targetStatus: '5 (ENTREGADA A MAQ O BISEL)',
      total: total,
    );
  }

  Future<bool?> _confirmAnular(int total) {
    return _confirmCambioEstatus(
      title: 'Confirmar anulación de ORDs',
      targetStatus: '4 (ANULADA)',
      total: total,
    );
  }

  Future<bool?> _confirmRecibirATaller(int total) {
    return _confirmCambioEstatus(
      title: 'Confirmar recepción en taller',
      targetStatus: '7 (RECIBIDA A TALLER)',
      total: total,
    );
  }

  Future<bool?> _confirmEntregarCliente(int total) {
    return _confirmCambioEstatus(
      title: 'Confirmar entrega de ORDs',
      targetStatus: '11 (ENTREGADA A CLIENTE)',
      total: total,
    );
  }

  Future<bool?> _confirmAsignarAColaborador(
    int total,
    String colaboradorLabel,
  ) {
    return _confirmCambioEstatus(
      title: 'Confirmar asignación a colaborador',
      targetStatus: '8 (ASIGNADA)',
      total: total,
      extraMessage: 'Colaborador: $colaboradorLabel',
    );
  }

  Future<bool?> _confirmTrabajoTerminado(int total) {
    return _confirmCambioEstatus(
      title: 'Confirmar trabajo terminado',
      targetStatus: '9 (TRABAJO TERMINADO)',
      total: total,
    );
  }

  Future<bool?> _confirmRegresarIncidencia(int total, {String? motivoLabel}) {
    return _confirmCambioEstatus(
      title: 'Confirmar regreso por incidencia',
      targetStatus: '9.1 (REGRESAR POR INCIDENCIA)',
      total: total,
      extraMessage: (motivoLabel ?? '').trim().isEmpty
          ? null
          : 'Motivo: ${motivoLabel!.trim()}',
    );
  }

  Future<bool?> _confirmRegresarTienda(int total) {
    return _confirmCambioEstatus(
      title: 'Confirmar recepción en tienda',
      targetStatus: '10 (REGRESADO A TIENDA)',
      total: total,
    );
  }

  Future<bool?> _confirmAsignarLaboratorio(int total, String laboratorioLabel) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar asignación de laboratorio'),
        content: Text(
          'Se asignará el laboratorio "$laboratorioLabel" a $total ORD${total == 1 ? '' : 's'}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmCambioEstatus({
    required String title,
    required String targetStatus,
    required int total,
    String? extraMessage,
  }) {
    final suffix = total == 1 ? '' : 's';
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(
          [
            'Se cambiará ESTSEGU a $targetStatus para $total ORD$suffix.',
            if ((extraMessage ?? '').trim().isNotEmpty) extraMessage!.trim(),
            '¿Deseas continuar?',
          ].join('\n'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  Future<void> _doRecibirSeleccionados(List<String> iords) async {
    if (iords.isEmpty) return;
    final confirm = await _confirmRecibirATaller(iords.length);
    if (confirm != true) return;

    await _executeAction(
      () => ref.read(ordenesTrabajoApiProvider).recibirLote(iords),
    );
  }

  Future<void> _doEntregarSeleccionados(List<String> iords) async {
    if (iords.isEmpty) return;
    final confirm = await _confirmEntregarCliente(iords.length);
    if (confirm != true) return;

    await _executeAction(
      () => ref.read(ordenesTrabajoApiProvider).entregarLote(iords),
    );
  }

  Future<void> _doTrabajoTerminadoSeleccionados(List<String> iords) async {
    if (iords.isEmpty) return;
    final confirm = await _confirmTrabajoTerminado(iords.length);
    if (confirm != true) return;
    await _executeAction(
      () => ref.read(ordenesTrabajoApiProvider).trabajoTerminadoLote(iords),
    );
  }

  Future<void> _doRegresarIncidenciaSeleccionados(List<String> iords) async {
    if (iords.isEmpty) return;
    final motivo = await _selectIncidenciaOptionDialog();
    if (motivo == null) return;
    final confirm = await _confirmRegresarIncidencia(
      iords.length,
      motivoLabel: motivo.label,
    );
    if (confirm != true) return;
    await _executeAction(
      () => ref
          .read(ordenesTrabajoApiProvider)
          .regresarIncidenciaLote(iords, tipom: motivo.id),
    );
  }

  Future<void> _doRegresarTiendaSeleccionados(List<String> iords) async {
    if (iords.isEmpty) return;
    final confirm = await _confirmRegresarTienda(iords.length);
    if (confirm != true) return;
    await _executeAction(
      () => ref.read(ordenesTrabajoApiProvider).regresarTiendaLote(iords),
    );
  }

  Future<void> _showEnviarRelacionDialog() {
    return _showRelacionDialog(
      _RelacionDialogConfig(
        title: 'ORDs: Enviar a taller',
        helperText:
            'Captura o escanea una ORD para validarla en estatus 3 (NUEVA AUTORIZADA) y relacionarla en appstate.',
        submitLabel: 'Enviar a taller',
        submitIcon: Icons.outbound,
        emptySubmitError: 'No hay ORDs relacionadas para enviar.',
        validateFallbackError:
            'No se pudo validar la ORD. Debe estar en estatus 3.',
        executeFallbackError: 'No se pudo enviar las ORDs.',
        relacionProvider: ordenesTrabajoEnviarRelacionProvider,
        validateOrd: (code) =>
            ref.read(ordenesTrabajoApiProvider).validarOrdEnviar(code),
        executeLote: (iords) =>
            ref.read(ordenesTrabajoApiProvider).enviarLote(iords),
        confirmAction: _confirmEnviarAmaqBisel,
      ),
    );
  }

  Future<void> _showRecibirRelacionDialog() {
    return _showRelacionDialog(
      _RelacionDialogConfig(
        title: 'ORDs: Recibir en taller',
        helperText:
            'Captura o escanea una ORD para validarla en estatus 5 (ENTREGADA A MAQ O BISEL) y relacionarla en appstate.\n\n$_recibirRolHint',
        submitLabel: 'Recibir en taller',
        submitIcon: Icons.move_to_inbox,
        emptySubmitError: 'No hay ORDs relacionadas para recibir en taller.',
        validateFallbackError:
            'No se pudo validar la ORD. Debe estar en estatus 5.',
        executeFallbackError: 'No se pudo recibir las ORDs en taller.',
        relacionProvider: ordenesTrabajoRecibirRelacionProvider,
        validateOrd: (code) =>
            ref.read(ordenesTrabajoApiProvider).validarOrdRecibir(code),
        executeLote: (iords) =>
            ref.read(ordenesTrabajoApiProvider).recibirLote(iords),
        confirmAction: _confirmRecibirATaller,
      ),
    );
  }

  Future<void> _showEntregarRelacionDialog() {
    return _showRelacionDialog(
      _RelacionDialogConfig(
        title: 'ORDs: Entregar a cliente',
        helperText:
            'Captura o escanea una ORD para validarla en estatus 10 (REGRESADO A TIENDA) y relacionarla en appstate.',
        submitLabel: 'Entregar a cliente',
        submitIcon: Icons.handshake,
        emptySubmitError: 'No hay ORDs relacionadas para entregar a cliente.',
        validateFallbackError:
            'No se pudo validar la ORD. Debe estar en estatus 10.',
        executeFallbackError: 'No se pudo entregar las ORDs a cliente.',
        relacionProvider: ordenesTrabajoEntregarRelacionProvider,
        validateOrd: (code) =>
            ref.read(ordenesTrabajoApiProvider).validarOrdEntregar(code),
        executeLote: (iords) =>
            ref.read(ordenesTrabajoApiProvider).entregarLote(iords),
        confirmAction: _confirmEntregarCliente,
      ),
    );
  }

  Future<void> _showTrabajoTerminadoRelacionDialog() {
    return _showRelacionDialog(
      _RelacionDialogConfig(
        title: 'ORDs: Trabajo terminado',
        helperText:
            'Captura o escanea una ORD para validarla en estatus 8 (ASIGNADA) y relacionarla en appstate.',
        submitLabel: 'Trabajo terminado',
        submitIcon: Icons.task_alt,
        emptySubmitError: 'No hay ORDs relacionadas para trabajo terminado.',
        validateFallbackError:
            'No se pudo validar la ORD. Debe estar en estatus 8.',
        executeFallbackError: 'No se pudo marcar trabajo terminado.',
        relacionProvider: ordenesTrabajoTrabajoTerminadoRelacionProvider,
        validateOrd: (code) => ref
            .read(ordenesTrabajoApiProvider)
            .validarOrdTrabajoTerminado(code),
        executeLote: (iords) =>
            ref.read(ordenesTrabajoApiProvider).trabajoTerminadoLote(iords),
        confirmAction: _confirmTrabajoTerminado,
      ),
    );
  }

  Future<void> _showRegresarIncidenciaRelacionDialog() {
    return _showRelacionDialogIncidencia();
  }

  Future<void> _showRegresarTiendaRelacionDialog() {
    return _showRelacionDialog(
      _RelacionDialogConfig(
        title: 'ORDs: Recibir en tienda',
        helperText:
            'Captura o escanea una ORD para validarla en estatus 9 (TRABAJO TERMINADO) y relacionarla en appstate para recibirla en tienda.',
        submitLabel: 'Recibir en tienda',
        submitIcon: Icons.storefront_outlined,
        emptySubmitError: 'No hay ORDs relacionadas para recibir en tienda.',
        validateFallbackError:
            'No se pudo validar la ORD. Debe estar en estatus 9.',
        executeFallbackError: 'No se pudo recibir las ORDs en tienda.',
        relacionProvider: ordenesTrabajoRegresarTiendaRelacionProvider,
        validateOrd: (code) =>
            ref.read(ordenesTrabajoApiProvider).validarOrdRegresarTienda(code),
        executeLote: (iords) =>
            ref.read(ordenesTrabajoApiProvider).regresarTiendaLote(iords),
        confirmAction: _confirmRegresarTienda,
      ),
    );
  }

  Future<void> _showAsignarRelacionDialog() async {
    _ordEnviarCtrl.clear();
    var processing = false;
    var loadingCollaborators = false;
    String? colaboradorId;
    List<OrdenTrabajoColaboradorOption> colaboradores =
        const <OrdenTrabajoColaboradorOption>[];
    final colaboradorSuc = _userSuc.trim().toUpperCase();

    if (colaboradorSuc.isEmpty) {
      _showError(
        'No se pudo determinar la sucursal base del usuario para asignar colaborador.',
      );
      return;
    }

    Future<void> loadCollaborators({
      required BuildContext dialogContext,
      required StateSetter setDialogState,
    }) async {
      if (loadingCollaborators) return;
      setDialogState(() => loadingCollaborators = true);
      try {
        final items = await ref
            .read(ordenesTrabajoApiProvider)
            .fetchAsignarColaboradores(colaboradorSuc);
        if (!dialogContext.mounted) return;
        setDialogState(() {
          colaboradores = items;
          if (!colaboradores.any((item) => item.idopv == colaboradorId)) {
            colaboradorId = colaboradores.isEmpty
                ? null
                : colaboradores.first.idopv;
          }
        });
      } catch (e) {
        _showError(
          apiErrorMessage(e, fallback: 'No se pudo cargar colaboradores.'),
        );
      } finally {
        if (dialogContext.mounted) {
          setDialogState(() => loadingCollaborators = false);
        }
      }
    }

    Future<void> addOrd({
      required BuildContext dialogContext,
      required WidgetRef dialogRef,
      required StateSetter setDialogState,
      String? codeOverride,
    }) async {
      final code = (codeOverride ?? _ordEnviarCtrl.text).trim();
      if (code.isEmpty) {
        _showError('Digita o escanea una ORD para continuar.');
        return;
      }
      if (processing) return;
      setDialogState(() => processing = true);
      try {
        final item = await ref
            .read(ordenesTrabajoApiProvider)
            .validarOrdAsignar(code);
        final current = dialogRef.read(ordenesTrabajoAsignarRelacionProvider);
        final exists = current.any(
          (row) =>
              row.iord.trim().toUpperCase() == item.iord.trim().toUpperCase(),
        );
        if (exists) {
          _showError('La ORD ${item.iord} ya está relacionada.');
          return;
        }
        dialogRef.read(ordenesTrabajoAsignarRelacionProvider.notifier).state = [
          ...current,
          item,
        ];
        _ordEnviarCtrl.clear();
      } catch (e) {
        _showError(
          apiErrorMessage(
            e,
            fallback:
                'No se pudo validar la ORD. Debe estar en estatus 7 (RECIBIDA A TALLER).',
          ),
        );
      } finally {
        if (dialogContext.mounted) {
          setDialogState(() => processing = false);
        }
      }
    }

    Future<void> executeAsignar({
      required BuildContext dialogContext,
      required WidgetRef dialogRef,
      required StateSetter setDialogState,
    }) async {
      if (processing) return;
      final relaciones = dialogRef.read(ordenesTrabajoAsignarRelacionProvider);
      if (relaciones.isEmpty) {
        _showError('No hay ORDs relacionadas para asignar.');
        return;
      }
      if ((colaboradorId ?? '').trim().isEmpty) {
        _showError('Selecciona un colaborador para continuar.');
        return;
      }
      final selectedColab = colaboradores.where(
        (item) => item.idopv == colaboradorId,
      );
      final colabLabel = selectedColab.isEmpty
          ? colaboradorId!.trim()
          : selectedColab.first.label;
      final confirm = await _confirmAsignarAColaborador(
        relaciones.length,
        colabLabel,
      );
      if (confirm != true) return;

      setDialogState(() => processing = true);
      try {
        final result = await ref
            .read(ordenesTrabajoApiProvider)
            .asignarLote(
              relaciones.map((item) => item.iord).toList(growable: false),
              idopv: colaboradorId!,
            );
        dialogRef.read(ordenesTrabajoAsignarRelacionProvider.notifier).state =
            const <OrdenTrabajoEnviarRelacionItem>[];
        if (dialogContext.mounted) {
          Navigator.of(dialogContext).pop();
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.message.isEmpty
                  ? 'ORDs asignadas correctamente.'
                  : result.message,
            ),
          ),
        );
        await _reload();
      } catch (e) {
        _showError(
          apiErrorMessage(e, fallback: 'No se pudo asignar las ORDs.'),
        );
      } finally {
        if (dialogContext.mounted) {
          setDialogState(() => processing = false);
        }
      }
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Consumer(
          builder: (dialogContext, dialogRef, _) {
            if (!loadingCollaborators && colaboradores.isEmpty) {
              unawaited(
                loadCollaborators(
                  dialogContext: dialogContext,
                  setDialogState: setDialogState,
                ),
              );
            }
            final relaciones = dialogRef.watch(
              ordenesTrabajoAsignarRelacionProvider,
            );
            return AlertDialog(
              title: const Text('Asignar ORDs a colaborador'),
              content: SizedBox(
                width: 1050,
                height: 500,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Captura o escanea una ORD para validarla en estatus 7 (RECIBIDA A TALLER) y asignar colaborador.',
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Colaboradores disponibles para la sucursal $colaboradorSuc.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _ordEnviarCtrl,
                            autofocus: true,
                            enabled: !processing,
                            textInputAction: TextInputAction.done,
                            decoration: const InputDecoration(
                              labelText: 'ORD',
                              border: OutlineInputBorder(),
                            ),
                            onSubmitted: (_) => addOrd(
                              dialogContext: dialogContext,
                              dialogRef: dialogRef,
                              setDialogState: setDialogState,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: processing
                              ? null
                              : () async {
                                  final scanned =
                                      await _captureCodeWithCamera();
                                  if (!dialogContext.mounted) return;
                                  if (scanned == null ||
                                      scanned.trim().isEmpty) {
                                    return;
                                  }
                                  await addOrd(
                                    dialogContext: dialogContext,
                                    dialogRef: dialogRef,
                                    setDialogState: setDialogState,
                                    codeOverride: scanned,
                                  );
                                },
                          icon: const Icon(Icons.qr_code_scanner),
                          label: const Text('Escanear'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      key: ValueKey('asignar-colab-${colaboradorId ?? 'NONE'}'),
                      initialValue: colaboradorId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Colaborador a asignar ($colaboradorSuc)',
                        border: const OutlineInputBorder(),
                      ),
                      items: colaboradores
                          .map(
                            (item) => DropdownMenuItem<String>(
                              value: item.idopv,
                              child: Text(
                                '${item.idopv} - ${item.label}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: processing || loadingCollaborators
                          ? null
                          : (value) =>
                                setDialogState(() => colaboradorId = value),
                    ),
                    if (loadingCollaborators) ...[
                      const SizedBox(height: 8),
                      const LinearProgressIndicator(),
                    ],
                    const SizedBox(height: 12),
                    const Text(
                      'ORDs relacionadas (no editables)',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: relaciones.isEmpty
                          ? const Center(child: Text('Sin ORDs relacionadas.'))
                          : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SingleChildScrollView(
                                child: DataTable(
                                  columns: const [
                                    DataColumn(label: Text('ORD')),
                                    DataColumn(label: Text('Cliente')),
                                    DataColumn(label: Text('Nombre cliente')),
                                    DataColumn(label: Text('Articulo')),
                                    DataColumn(label: Text('Descripcion')),
                                    DataColumn(label: Text('Cantidad')),
                                    DataColumn(label: Text('Acciones')),
                                  ],
                                  rows: relaciones
                                      .map(
                                        (row) => DataRow(
                                          cells: [
                                            DataCell(Text(row.iord)),
                                            DataCell(Text(row.clien)),
                                            DataCell(
                                              SizedBox(
                                                width: 220,
                                                child: Text(row.ncliente),
                                              ),
                                            ),
                                            DataCell(Text(row.art)),
                                            DataCell(
                                              SizedBox(
                                                width: 280,
                                                child: Text(row.descArt),
                                              ),
                                            ),
                                            DataCell(Text(_money(row.ctd))),
                                            DataCell(
                                              IconButton(
                                                tooltip: 'Eliminar ORD',
                                                onPressed: processing
                                                    ? null
                                                    : () {
                                                        final remaining = relaciones
                                                            .where(
                                                              (item) =>
                                                                  item.iord
                                                                      .trim()
                                                                      .toUpperCase() !=
                                                                  row.iord
                                                                      .trim()
                                                                      .toUpperCase(),
                                                            )
                                                            .toList(
                                                              growable: false,
                                                            );
                                                        dialogRef
                                                                .read(
                                                                  ordenesTrabajoAsignarRelacionProvider
                                                                      .notifier,
                                                                )
                                                                .state =
                                                            remaining;
                                                      },
                                                icon: const Icon(
                                                  Icons.delete_outline,
                                                  color: Colors.redAccent,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                      .toList(growable: false),
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: processing
                      ? null
                      : () {
                          _ordEnviarCtrl.clear();
                          dialogRef
                                  .read(
                                    ordenesTrabajoAsignarRelacionProvider
                                        .notifier,
                                  )
                                  .state =
                              const <OrdenTrabajoEnviarRelacionItem>[];
                          Navigator.of(dialogContext).pop();
                        },
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: processing
                      ? null
                      : () {
                          _ordEnviarCtrl.clear();
                          Navigator.of(dialogContext).pop();
                        },
                  child: const Text('Cerrar'),
                ),
                ElevatedButton.icon(
                  onPressed: processing || relaciones.isEmpty
                      ? null
                      : () => executeAsignar(
                          dialogContext: dialogContext,
                          dialogRef: dialogRef,
                          setDialogState: setDialogState,
                        ),
                  icon: const Icon(Icons.assignment_ind),
                  label: const Text('Asignar'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _showRelacionDialog(_RelacionDialogConfig config) async {
    _ordEnviarCtrl.clear();
    var processing = false;

    Future<void> addOrd({
      required BuildContext dialogContext,
      required WidgetRef dialogRef,
      required StateSetter setDialogState,
      String? codeOverride,
    }) async {
      final code = (codeOverride ?? _ordEnviarCtrl.text).trim();
      if (code.isEmpty) {
        _showError('Digita o escanea una ORD para continuar.');
        return;
      }
      if (processing) return;
      setDialogState(() => processing = true);
      try {
        final item = await config.validateOrd(code);
        final current = dialogRef.read(config.relacionProvider);
        final exists = current.any(
          (row) =>
              row.iord.trim().toUpperCase() == item.iord.trim().toUpperCase(),
        );
        if (exists) {
          _showError('La ORD ${item.iord} ya está relacionada.');
          return;
        }
        dialogRef.read(config.relacionProvider.notifier).state = [
          ...current,
          item,
        ];
        _ordEnviarCtrl.clear();
      } catch (e) {
        _showError(apiErrorMessage(e, fallback: config.validateFallbackError));
      } finally {
        if (dialogContext.mounted) {
          setDialogState(() => processing = false);
        }
      }
    }

    Future<void> ejecutarRelacionadas({
      required BuildContext dialogContext,
      required WidgetRef dialogRef,
      required StateSetter setDialogState,
    }) async {
      if (processing) return;
      final relaciones = dialogRef.read(config.relacionProvider);
      if (relaciones.isEmpty) {
        _showError(config.emptySubmitError);
        return;
      }
      final confirm = await config.confirmAction(relaciones.length);
      if (confirm != true) return;

      setDialogState(() => processing = true);
      try {
        final result = await config.executeLote(
          relaciones.map((item) => item.iord).toList(growable: false),
        );
        dialogRef.read(config.relacionProvider.notifier).state =
            const <OrdenTrabajoEnviarRelacionItem>[];
        if (dialogContext.mounted) {
          Navigator.of(dialogContext).pop();
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.message.isEmpty
                  ? 'ORDs procesadas correctamente.'
                  : result.message,
            ),
          ),
        );
        await _reload();
      } catch (e) {
        _showError(apiErrorMessage(e, fallback: config.executeFallbackError));
      } finally {
        if (dialogContext.mounted) {
          setDialogState(() => processing = false);
        }
      }
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Consumer(
          builder: (dialogContext, dialogRef, _) {
            final relaciones = dialogRef.watch(config.relacionProvider);
            return AlertDialog(
              title: Text(config.title),
              content: SizedBox(
                width: 1050,
                height: 460,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(config.helperText),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _ordEnviarCtrl,
                            autofocus: true,
                            enabled: !processing,
                            textInputAction: TextInputAction.done,
                            decoration: const InputDecoration(
                              labelText: 'ORD',
                              border: OutlineInputBorder(),
                            ),
                            onSubmitted: (_) => addOrd(
                              dialogContext: dialogContext,
                              dialogRef: dialogRef,
                              setDialogState: setDialogState,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: processing
                              ? null
                              : () async {
                                  final scanned =
                                      await _captureCodeWithCamera();
                                  if (!dialogContext.mounted) return;
                                  if (scanned == null ||
                                      scanned.trim().isEmpty) {
                                    return;
                                  }
                                  await addOrd(
                                    dialogContext: dialogContext,
                                    dialogRef: dialogRef,
                                    setDialogState: setDialogState,
                                    codeOverride: scanned,
                                  );
                                },
                          icon: const Icon(Icons.qr_code_scanner),
                          label: const Text('Escanear'),
                        ),
                      ],
                    ),
                    if (processing) ...[
                      const SizedBox(height: 10),
                      const LinearProgressIndicator(),
                    ],
                    const SizedBox(height: 12),
                    const Text(
                      'ORDs relacionadas (no editables)',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: relaciones.isEmpty
                          ? const Center(child: Text('Sin ORDs relacionadas.'))
                          : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SingleChildScrollView(
                                child: DataTable(
                                  columns: const [
                                    DataColumn(label: Text('ORD')),
                                    DataColumn(label: Text('Cliente')),
                                    DataColumn(label: Text('Nombre cliente')),
                                    DataColumn(label: Text('Articulo')),
                                    DataColumn(label: Text('Descripcion')),
                                    DataColumn(label: Text('Cantidad')),
                                    DataColumn(label: Text('Acciones')),
                                  ],
                                  rows: relaciones
                                      .map(
                                        (row) => DataRow(
                                          cells: [
                                            DataCell(Text(row.iord)),
                                            DataCell(Text(row.clien)),
                                            DataCell(
                                              SizedBox(
                                                width: 220,
                                                child: Text(row.ncliente),
                                              ),
                                            ),
                                            DataCell(Text(row.art)),
                                            DataCell(
                                              SizedBox(
                                                width: 280,
                                                child: Text(row.descArt),
                                              ),
                                            ),
                                            DataCell(Text(_money(row.ctd))),
                                            DataCell(
                                              IconButton(
                                                tooltip: 'Eliminar ORD',
                                                onPressed: processing
                                                    ? null
                                                    : () {
                                                        dialogRef
                                                            .read(
                                                              config
                                                                  .relacionProvider
                                                                  .notifier,
                                                            )
                                                            .state = relaciones
                                                            .where(
                                                              (item) =>
                                                                  item.iord
                                                                      .trim()
                                                                      .toUpperCase() !=
                                                                  row.iord
                                                                      .trim()
                                                                      .toUpperCase(),
                                                            )
                                                            .toList(
                                                              growable: false,
                                                            );
                                                      },
                                                icon: const Icon(
                                                  Icons.delete_outline,
                                                  color: Colors.redAccent,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                      .toList(growable: false),
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: processing
                      ? null
                      : () {
                          _ordEnviarCtrl.clear();
                          dialogRef
                                  .read(config.relacionProvider.notifier)
                                  .state =
                              const <OrdenTrabajoEnviarRelacionItem>[];
                          Navigator.of(dialogContext).pop();
                        },
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: processing
                      ? null
                      : () {
                          _ordEnviarCtrl.clear();
                          Navigator.of(dialogContext).pop();
                        },
                  child: const Text('Cerrar'),
                ),
                ElevatedButton.icon(
                  onPressed: processing || relaciones.isEmpty
                      ? null
                      : () => ejecutarRelacionadas(
                          dialogContext: dialogContext,
                          dialogRef: dialogRef,
                          setDialogState: setDialogState,
                        ),
                  icon: Icon(config.submitIcon),
                  label: Text(config.submitLabel),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _showRelacionDialogIncidencia() async {
    _ordEnviarCtrl.clear();
    var processing = false;

    Future<void> addOrd({
      required BuildContext dialogContext,
      required WidgetRef dialogRef,
      required StateSetter setDialogState,
      String? codeOverride,
    }) async {
      final code = (codeOverride ?? _ordEnviarCtrl.text).trim();
      if (code.isEmpty) {
        _showError('Digita o escanea una ORD para continuar.');
        return;
      }
      if (processing) return;
      setDialogState(() => processing = true);
      try {
        final item = await ref
            .read(ordenesTrabajoApiProvider)
            .validarOrdRegresarIncidencia(code);
        final current = dialogRef.read(
          ordenesTrabajoIncidenciaRelacionProvider,
        );
        final exists = current.any(
          (row) =>
              row.iord.trim().toUpperCase() == item.iord.trim().toUpperCase(),
        );
        if (exists) {
          _showError('La ORD ${item.iord} ya está relacionada.');
          return;
        }
        dialogRef
            .read(ordenesTrabajoIncidenciaRelacionProvider.notifier)
            .state = [
          ...current,
          item,
        ];
        _ordEnviarCtrl.clear();
      } catch (e) {
        _showError(
          apiErrorMessage(
            e,
            fallback: 'No se pudo validar la ORD. Debe estar en estatus 9.',
          ),
        );
      } finally {
        if (dialogContext.mounted) {
          setDialogState(() => processing = false);
        }
      }
    }

    Future<void> ejecutarRelacionadas({
      required BuildContext dialogContext,
      required WidgetRef dialogRef,
      required StateSetter setDialogState,
    }) async {
      if (processing) return;
      final relaciones = dialogRef.read(
        ordenesTrabajoIncidenciaRelacionProvider,
      );
      if (relaciones.isEmpty) {
        _showError('No hay ORDs relacionadas para regresar por incidencia.');
        return;
      }

      final motivo = await _selectIncidenciaOptionDialog();
      if (motivo == null) return;
      final confirm = await _confirmRegresarIncidencia(
        relaciones.length,
        motivoLabel: motivo.label,
      );
      if (confirm != true) return;

      setDialogState(() => processing = true);
      try {
        final result = await ref
            .read(ordenesTrabajoApiProvider)
            .regresarIncidenciaLote(
              relaciones.map((item) => item.iord).toList(growable: false),
              tipom: motivo.id,
            );
        dialogRef
                .read(ordenesTrabajoIncidenciaRelacionProvider.notifier)
                .state =
            const <OrdenTrabajoEnviarRelacionItem>[];
        if (dialogContext.mounted) {
          Navigator.of(dialogContext).pop();
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.message.isEmpty
                  ? 'ORDs procesadas correctamente.'
                  : result.message,
            ),
          ),
        );
        await _reload();
      } catch (e) {
        _showError(
          apiErrorMessage(e, fallback: 'No se pudo regresar por incidencia.'),
        );
      } finally {
        if (dialogContext.mounted) {
          setDialogState(() => processing = false);
        }
      }
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Consumer(
          builder: (dialogContext, dialogRef, _) {
            final relaciones = dialogRef.watch(
              ordenesTrabajoIncidenciaRelacionProvider,
            );
            return AlertDialog(
              title: const Text('ORDs: Regresar por incidencia'),
              content: SizedBox(
                width: 1050,
                height: 460,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Captura o escanea una ORD para validarla en estatus 9 (TRABAJO TERMINADO) y relacionarla en appstate.',
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _ordEnviarCtrl,
                            autofocus: true,
                            enabled: !processing,
                            textInputAction: TextInputAction.done,
                            decoration: const InputDecoration(
                              labelText: 'ORD',
                              border: OutlineInputBorder(),
                            ),
                            onSubmitted: (_) => addOrd(
                              dialogContext: dialogContext,
                              dialogRef: dialogRef,
                              setDialogState: setDialogState,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: processing
                              ? null
                              : () async {
                                  final scanned =
                                      await _captureCodeWithCamera();
                                  if (!dialogContext.mounted) return;
                                  if (scanned == null ||
                                      scanned.trim().isEmpty) {
                                    return;
                                  }
                                  await addOrd(
                                    dialogContext: dialogContext,
                                    dialogRef: dialogRef,
                                    setDialogState: setDialogState,
                                    codeOverride: scanned,
                                  );
                                },
                          icon: const Icon(Icons.qr_code_scanner),
                          label: const Text('Escanear'),
                        ),
                      ],
                    ),
                    if (processing) ...[
                      const SizedBox(height: 10),
                      const LinearProgressIndicator(),
                    ],
                    const SizedBox(height: 12),
                    const Text(
                      'ORDs relacionadas (no editables)',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: relaciones.isEmpty
                          ? const Center(child: Text('Sin ORDs relacionadas.'))
                          : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SingleChildScrollView(
                                child: DataTable(
                                  columns: const [
                                    DataColumn(label: Text('ORD')),
                                    DataColumn(label: Text('Cliente')),
                                    DataColumn(label: Text('Nombre cliente')),
                                    DataColumn(label: Text('Articulo')),
                                    DataColumn(label: Text('Descripcion')),
                                    DataColumn(label: Text('Cantidad')),
                                    DataColumn(label: Text('Acciones')),
                                  ],
                                  rows: relaciones
                                      .map(
                                        (row) => DataRow(
                                          cells: [
                                            DataCell(Text(row.iord)),
                                            DataCell(Text(row.clien)),
                                            DataCell(
                                              SizedBox(
                                                width: 220,
                                                child: Text(row.ncliente),
                                              ),
                                            ),
                                            DataCell(Text(row.art)),
                                            DataCell(
                                              SizedBox(
                                                width: 280,
                                                child: Text(row.descArt),
                                              ),
                                            ),
                                            DataCell(Text(_money(row.ctd))),
                                            DataCell(
                                              IconButton(
                                                tooltip: 'Eliminar ORD',
                                                onPressed: processing
                                                    ? null
                                                    : () {
                                                        dialogRef
                                                            .read(
                                                              ordenesTrabajoIncidenciaRelacionProvider
                                                                  .notifier,
                                                            )
                                                            .state = relaciones
                                                            .where(
                                                              (item) =>
                                                                  item.iord
                                                                      .trim()
                                                                      .toUpperCase() !=
                                                                  row.iord
                                                                      .trim()
                                                                      .toUpperCase(),
                                                            )
                                                            .toList(
                                                              growable: false,
                                                            );
                                                      },
                                                icon: const Icon(
                                                  Icons.delete_outline,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                      .toList(growable: false),
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: processing
                      ? null
                      : () {
                          dialogRef
                                  .read(
                                    ordenesTrabajoIncidenciaRelacionProvider
                                        .notifier,
                                  )
                                  .state =
                              const <OrdenTrabajoEnviarRelacionItem>[];
                          _ordEnviarCtrl.clear();
                          Navigator.of(dialogContext).pop();
                        },
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: processing
                      ? null
                      : () {
                          _ordEnviarCtrl.clear();
                          Navigator.of(dialogContext).pop();
                        },
                  child: const Text('Cerrar'),
                ),
                ElevatedButton.icon(
                  onPressed: processing || relaciones.isEmpty
                      ? null
                      : () => ejecutarRelacionadas(
                          dialogContext: dialogContext,
                          dialogRef: dialogRef,
                          setDialogState: setDialogState,
                        ),
                  icon: const Icon(Icons.report_problem_outlined),
                  label: const Text('Regresar incidencia'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _doGarantia(String iord) async {
    try {
      final detail = await ref
          .read(ordenesTrabajoApiProvider)
          .fetchDetail(iord);
      final flujoCode = _textOf(detail.header['ESTSEGU']);
      if (!_isFlowStatus(flujoCode, 11)) {
        _showError(
          'La ORD $iord debe estar en flujo 11 (ENTREGADA A CLIENTE) para registrar garantia.',
        );
        return;
      }
    } catch (e) {
      _showError(
        apiErrorMessage(
          e,
          fallback: 'No se pudo validar el flujo actual de la ORD',
        ),
      );
      return;
    }

    final motivoCtrl = TextEditingController();
    final ok = await _showSimpleForm(
      title: 'Registrar garantia',
      childrenBuilder: (_) => [
        TextField(
          controller: motivoCtrl,
          minLines: 2,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Motivo (requerido)',
            border: OutlineInputBorder(),
          ),
        ),
      ],
      validate: () {
        if (motivoCtrl.text.trim().length < 3) {
          _showError('Captura un motivo valido.');
          return false;
        }
        return true;
      },
    );
    if (ok != true) return;
    final confirm = await _confirmCambioEstatus(
      title: 'Confirmar garantia',
      targetStatus: '12 (GARANTIA)',
      total: 1,
      extraMessage:
          'Se cambiará la ORD $iord a estado 12 (GARANTIA). ¿Deseas continuar?',
    );
    if (confirm != true) return;

    await _executeAction(
      () => ref
          .read(ordenesTrabajoApiProvider)
          .garantia(iord, motivo: motivoCtrl.text),
    );
  }

  Future<void> _doCambioMaterial(String iord) async {
    final artCtrl = TextEditingController();
    final motivoCtrl = TextEditingController();
    final laborCtrl = TextEditingController();
    final docCtrl = TextEditingController();

    final ok = await _showSimpleForm(
      title: 'Cambio de material',
      childrenBuilder: (_) => [
        TextField(
          controller: artCtrl,
          decoration: const InputDecoration(
            labelText: 'Articulo nuevo',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: motivoCtrl,
          decoration: const InputDecoration(
            labelText: 'Motivo',
            border: OutlineInputBorder(),
          ),
          minLines: 2,
          maxLines: 3,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: laborCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Labor (opcional)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: docCtrl,
          decoration: const InputDecoration(
            labelText: 'DOCDIF (opcional)',
            border: OutlineInputBorder(),
          ),
        ),
      ],
      validate: () {
        if (artCtrl.text.trim().isEmpty || motivoCtrl.text.trim().length < 3) {
          _showError('Articulo nuevo y motivo son obligatorios.');
          return false;
        }
        return true;
      },
    );
    if (ok != true) return;

    final labor = double.tryParse(laborCtrl.text.trim());
    await _executeAction(
      () => ref
          .read(ordenesTrabajoApiProvider)
          .cambioMaterial(
            iord,
            artNuevo: artCtrl.text,
            motivo: motivoCtrl.text,
            labor: labor,
            docDif: docCtrl.text,
          ),
    );
  }

  Future<void> _doMerma(String iord) async {
    final cantidadCtrl = TextEditingController();
    final motivoCtrl = TextEditingController();
    bool crearNuevaOrd = true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('Procesar merma'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: cantidadCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Cantidad merma',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: motivoCtrl,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Motivo',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: crearNuevaOrd,
                    onChanged: (v) =>
                        setStateDialog(() => crearNuevaOrd = v ?? true),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Crear nueva ORD derivada'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final qty = double.tryParse(cantidadCtrl.text.trim());
                if (qty == null ||
                    qty <= 0 ||
                    motivoCtrl.text.trim().length < 3) {
                  _showError('Cantidad y motivo valido son obligatorios.');
                  return;
                }
                Navigator.of(ctx).pop(true);
              },
              child: const Text('Aplicar'),
            ),
          ],
        ),
      ),
    );

    if (ok != true) return;

    final qty = double.parse(cantidadCtrl.text.trim());
    await _executeAction(
      () => ref
          .read(ordenesTrabajoApiProvider)
          .merma(
            iord,
            cantidadMerma: qty,
            motivo: motivoCtrl.text,
            crearNuevaOrd: crearNuevaOrd,
          ),
    );
  }

  Future<void> _doScanRecibir() async {
    final selectedIords = _selectedIords.toList(growable: false);
    if (selectedIords.isNotEmpty) {
      await _doRecibirSeleccionados(selectedIords);
      return;
    }
    await _showRecibirRelacionDialog();
  }

  Future<void> _doScanEntregar() async {
    final selectedIords = _selectedIords.toList(growable: false);
    if (selectedIords.isNotEmpty) {
      await _doEntregarSeleccionados(selectedIords);
      return;
    }
    await _showEntregarRelacionDialog();
  }

  Future<OrdenTrabajoColaboradorOption?> _selectColaboradorDialog() async {
    final suc = _userSuc.trim().toUpperCase();
    if (suc.isEmpty) {
      _showError(
        'No se pudo determinar la sucursal base del usuario para asignar colaborador.',
      );
      return null;
    }
    try {
      final colaboradores = await ref
          .read(ordenesTrabajoApiProvider)
          .fetchAsignarColaboradores(suc);
      if (!mounted) return null;
      if (colaboradores.isEmpty) {
        _showError('No hay colaboradores disponibles para la sucursal $suc.');
        return null;
      }

      var selectedId = colaboradores.first.idopv;
      return showDialog<OrdenTrabajoColaboradorOption>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setStateDialog) => AlertDialog(
            title: const Text('Seleccionar colaborador'),
            content: SizedBox(
              width: 460,
              child: DropdownButtonFormField<String>(
                key: ValueKey('select-colab-$selectedId'),
                initialValue: selectedId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Colaborador',
                  border: OutlineInputBorder(),
                ),
                items: colaboradores
                    .map(
                      (item) => DropdownMenuItem<String>(
                        value: item.idopv,
                        child: Text(
                          '${item.idopv} - ${item.label}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value == null || value.trim().isEmpty) return;
                  setStateDialog(() => selectedId = value);
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  final selected = colaboradores.firstWhere(
                    (item) => item.idopv == selectedId,
                    orElse: () => colaboradores.first,
                  );
                  Navigator.of(ctx).pop(selected);
                },
                child: const Text('Aceptar'),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return null;
      _showError(
        apiErrorMessage(e, fallback: 'No se pudo cargar colaboradores.'),
      );
      return null;
    }
  }

  Future<OrdenTrabajoLaboratorioOption?> _selectLaboratorioDialog(
    List<OrdenTrabajoLaboratorioOption> laboratorios,
  ) {
    if (laboratorios.isEmpty) return Future.value(null);
    final unique = <int, OrdenTrabajoLaboratorioOption>{};
    for (final lab in laboratorios) {
      if (lab.id <= 0) continue;
      unique.putIfAbsent(lab.id, () => lab);
    }
    final options = unique.values.toList(growable: false)
      ..sort(
        (a, b) =>
            a.lab.trim().toUpperCase().compareTo(b.lab.trim().toUpperCase()),
      );
    if (options.isEmpty) return Future.value(null);

    var selectedId = options.first.id;
    return showDialog<OrdenTrabajoLaboratorioOption>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('Seleccionar laboratorio'),
          content: SizedBox(
            width: 460,
            child: DropdownButtonFormField<int>(
              key: ValueKey('select-labor-$selectedId'),
              initialValue: selectedId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Laboratorio',
                border: OutlineInputBorder(),
              ),
              items: options
                  .map(
                    (item) => DropdownMenuItem<int>(
                      value: item.id,
                      child: Text(
                        '${item.id} - ${item.lab}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value == null) return;
                setStateDialog(() => selectedId = value);
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final selected = options.firstWhere(
                  (item) => item.id == selectedId,
                  orElse: () => options.first,
                );
                Navigator.of(ctx).pop(selected);
              },
              child: const Text('Aceptar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<OrdenTrabajoIncidenciaOption?> _selectIncidenciaOptionDialog() async {
    final panel = ref.read(ordenesTrabajoPanelProvider).valueOrNull;
    final options =
        (panel?.incidenciaOptions ?? const <OrdenTrabajoIncidenciaOption>[])
            .where((item) => item.id > 0 && item.label.trim().isNotEmpty)
            .toList(growable: false);
    if (options.isEmpty) {
      _showError('No hay motivos de incidencia configurados en DAT_ORD_TMOV.');
      return null;
    }

    var selectedId = options.first.id;
    return showDialog<OrdenTrabajoIncidenciaOption>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('Seleccionar motivo de incidencia'),
          content: SizedBox(
            width: 460,
            child: DropdownButtonFormField<int>(
              key: ValueKey('select-incidencia-$selectedId'),
              initialValue: selectedId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Motivo',
                border: OutlineInputBorder(),
              ),
              items: options
                  .map(
                    (item) => DropdownMenuItem<int>(
                      value: item.id,
                      child: Text(
                        '${item.id} - ${item.label}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value == null) return;
                setStateDialog(() => selectedId = value);
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final selected = options.firstWhere(
                  (item) => item.id == selectedId,
                  orElse: () => options.first,
                );
                Navigator.of(ctx).pop(selected);
              },
              child: const Text('Aceptar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _captureCodeWithCamera() async {
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        var locked = false;
        return AlertDialog(
          title: const Text('Escanear por camara'),
          content: SizedBox(
            width: 420,
            height: 420,
            child: MobileScanner(
              controller: MobileScannerController(
                detectionSpeed: DetectionSpeed.noDuplicates,
              ),
              onDetect: (capture) {
                if (locked) return;
                final barcode = capture.barcodes.isNotEmpty
                    ? capture.barcodes.first
                    : null;
                final code = barcode?.rawValue?.trim() ?? '';
                if (code.isEmpty) return;
                locked = true;
                Navigator.of(ctx).pop(code);
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    );
  }

  Future<bool?> _showSimpleForm({
    required String title,
    required List<Widget> Function(BuildContext ctx) childrenBuilder,
    bool Function()? validate,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: childrenBuilder(ctx),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (validate != null && validate() == false) return;
              Navigator.of(ctx).pop(true);
            },
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
  }

  Future<void> _executeAction(
    Future<OrdenTrabajoActionResult> Function() call,
  ) async {
    try {
      final result = await call();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.message.isEmpty ? 'Accion aplicada' : result.message,
          ),
        ),
      );
      await _reload();
      if (!mounted) return;
    } catch (e) {
      if (!mounted) return;
      _showError(apiErrorMessage(e, fallback: 'No se pudo ejecutar la accion'));
    }
  }

  Future<void> _loadUserContext() async {
    final storage = ref.read(storageProvider);
    final token = await storage.getAccessToken();
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      setState(() => _contextReady = true);
      return;
    }

    final payload = _decodeJwt(token);
    final roleId = _asInt(payload['roleId']) ?? 0;
    final username = (payload['username'] ?? '')
        .toString()
        .trim()
        .toUpperCase();
    final suc = (payload['suc'] ?? '').toString().trim();
    final isAdmin = roleId == 1 || username == 'ADMIN';

    if (!mounted) return;
    setState(() {
      _isAdmin = isAdmin;
      _userSuc = suc.toUpperCase();
      _sucCtrl.clear();
      _contextReady = true;
    });
    unawaited(_loadSucursalOptions());

    ref
        .read(ordenesTrabajoFilterProvider.notifier)
        .state = OrdenesTrabajoFilter(
      suc: null,
      panelMode: widget.panelMode,
      page: 1,
      pageSize: 25,
    );
  }

  Map<String, dynamic> _decodeJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return {};
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      return Map<String, dynamic>.from(json.decode(payload) as Map);
    } catch (_) {
      return {};
    }
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _fmtDate(DateTime? date) {
    if (date == null) return '-';
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _money(num value) {
    return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(2);
  }
}

class _RelacionDialogConfig {
  const _RelacionDialogConfig({
    required this.title,
    required this.helperText,
    required this.submitLabel,
    required this.submitIcon,
    required this.emptySubmitError,
    required this.validateFallbackError,
    required this.executeFallbackError,
    required this.relacionProvider,
    required this.validateOrd,
    required this.executeLote,
    required this.confirmAction,
  });

  final String title;
  final String helperText;
  final String submitLabel;
  final IconData submitIcon;
  final String emptySubmitError;
  final String validateFallbackError;
  final String executeFallbackError;
  final StateProvider<List<OrdenTrabajoEnviarRelacionItem>> relacionProvider;
  final Future<OrdenTrabajoEnviarRelacionItem> Function(String code)
  validateOrd;
  final Future<OrdenTrabajoActionResult> Function(List<String> iords)
  executeLote;
  final Future<bool?> Function(int total) confirmAction;
}

class _OrdenTrabajoToolbarAction {
  const _OrdenTrabajoToolbarAction({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;
}
