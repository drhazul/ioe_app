import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../masterdata/deptos/deptos_models.dart';
import '../../../masterdata/deptos/deptos_providers.dart';
import '../../../masterdata/puestos/puestos_models.dart';
import '../../../masterdata/puestos/puestos_providers.dart';

import 'colaboradores_service.dart';
import 'excel_export_util.dart';
import 'nomina_service.dart';
import 'pdf_export_util.dart';
import 'reloj_checador_app_models.dart';
import 'reloj_checador_app_providers.dart';

class RelojChecadorReporteTab extends ConsumerStatefulWidget {
  const RelojChecadorReporteTab({super.key});

  @override
  ConsumerState<RelojChecadorReporteTab> createState() =>
      _RelojChecadorReporteTabState();
}

class _RelojChecadorReporteTabState
    extends ConsumerState<RelojChecadorReporteTab>
    with AutomaticKeepAliveClientMixin {
  late final TextEditingController _idSearchCtrl;
  final _colabService = const ColaboradoresService();
  final _nominaService = NominaService();
  final _pdfUtil = PdfExportUtil();
  final _excelUtil = ExcelExportUtil();

  bool _exportingPdf = false;
  bool _exportingExcel = false;

  List<SucursalOptionModel> _cachedSucursales = const [];
  List<ColaboradorGestionModel> _cachedColaboradores = const [];
  List<DeptoModel> _cachedDeptos = const [];
  List<PuestoModel> _cachedPuestos = const [];
  List<AsistenciaReporteRow> _cachedRows = const [];
  List<SolicitudIncidenciaModel> _cachedSolicitudes = const [];

  @override
  void initState() {
    super.initState();
    _idSearchCtrl = TextEditingController(
      text: ref.read(reporteIdEmpleadoProvider),
    );
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _idSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickRange(DateTimeRange current) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      initialDateRange: current,
      helpText: 'Rango pre-nómina',
    );
    if (picked == null) return;

    ref.read(reporteRangeProvider.notifier).state = DateTimeRange(
      start: DateTime(picked.start.year, picked.start.month, picked.start.day),
      end: DateTime(picked.end.year, picked.end.month, picked.end.day),
    );
    _refreshReport();
  }

  void _applyPreset(_RangePreset preset, DateTime now) {
    DateTime start;
    DateTime end;

    switch (preset) {
      case _RangePreset.hoy:
        start = DateTime(now.year, now.month, now.day);
        end = start;
        break;
      case _RangePreset.semana:
        start = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: now.weekday - DateTime.monday));
        end = start.add(const Duration(days: 6));
        break;
      case _RangePreset.mes:
        start = DateTime(now.year, now.month, 1);
        end = DateTime(now.year, now.month + 1, 0);
        break;
    }

    ref.read(reporteRangeProvider.notifier).state = DateTimeRange(
      start: start,
      end: end,
    );
    _refreshReport();
  }

  void _refreshReport() {
    ref.invalidate(asistenciaReporteProvider);
    ref.invalidate(reporteSolicitudesProvider);
  }

  int safeInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }

  double safeDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  NominaComputedData _computeNomina({
    required List<AsistenciaReporteRow> rows,
    required List<ColaboradorGestionModel> colaboradores,
    required List<SolicitudIncidenciaModel> solicitudes,
  }) {
    return _nominaService.compute(
      asistencias: rows,
      colaboradores: colaboradores,
      incidencias: solicitudes,
    );
  }

  Future<void> _exportPdf(
    NominaComputedData computed,
    DateTimeRange range,
  ) async {
    if (_exportingPdf || _exportingExcel) return;

    if (computed.issues.isNotEmpty) {
      _showIntegrityIssues(computed.issues);
      return;
    }

    setState(() => _exportingPdf = true);
    try {
      final bytes = await _pdfUtil.buildPreNominaPdf(
        rows: computed.rows,
        kpi: computed.kpi,
        start: range.start,
        end: range.end,
      );
      final file = await _writeTemp(
        bytes,
        'pre_nomina_${_d(range.start)}_${_d(range.end)}.pdf',
      );
      await _shareFile(file, subject: 'Pre-Nomina PDF');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error exportando PDF: $e')));
    } finally {
      if (mounted) setState(() => _exportingPdf = false);
    }
  }

  Future<void> _exportExcel(
    NominaComputedData computed,
    DateTimeRange range,
  ) async {
    if (_exportingPdf || _exportingExcel) return;

    if (computed.issues.isNotEmpty) {
      _showIntegrityIssues(computed.issues);
      return;
    }

    setState(() => _exportingExcel = true);
    try {
      final bytes = _excelUtil.buildPreNominaExcel(
        rows: computed.rows,
        kpi: computed.kpi,
        start: range.start,
        end: range.end,
      );
      final file = await _writeTemp(
        bytes,
        'pre_nomina_${_d(range.start)}_${_d(range.end)}.xlsx',
      );
      await _shareFile(file, subject: 'Pre-Nomina Excel');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error exportando Excel: $e')));
    } finally {
      if (mounted) setState(() => _exportingExcel = false);
    }
  }

  Future<File> _writeTemp(List<int> bytes, String filename) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> _shareFile(File file, {required String subject}) async {
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], subject: subject, text: subject),
    );
  }

  void _showIntegrityIssues(List<NominaValidationIssue> issues) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Inconsistencias detectadas'),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Exportación bloqueada. Corrige antes de cálculo final.',
                ),
                const SizedBox(height: 10),
                for (final issue in issues.take(50))
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(issue.nombre),
                    subtitle: Text(
                      '${issue.code} · ${issue.message}\nWorkday: ${issue.workdayId}',
                    ),
                    trailing: const Icon(Icons.edit_note),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final range = ref.watch(reporteRangeProvider);
    final sucursalId = ref.watch(reporteSucursalIdProvider);
    final departamentoId = ref.watch(reporteDepartamentoIdProvider);
    final cargoId = ref.watch(reporteCargoIdProvider);
    final expedienteEstatus = ref.watch(reporteExpedienteEstatusProvider);

    final sucursalesAsync = ref.watch(sucursalesCatalogProvider);
    final deptosAsync = ref.watch(deptosListProvider);
    final puestosAsync = ref.watch(puestosListProvider);
    final colaboradoresAsync = ref.watch(colaboradoresLiveProvider);
    final reporteAsync = ref.watch(asistenciaReporteProvider);
    final solicitudesAsync = ref.watch(reporteSolicitudesProvider);
    if ((sucursalesAsync.valueOrNull == null ||
            colaboradoresAsync.valueOrNull == null ||
            reporteAsync.valueOrNull == null) &&
        (sucursalesAsync.isLoading ||
            colaboradoresAsync.isLoading ||
            reporteAsync.isLoading)) {
      return const Center(child: CircularProgressIndicator());
    }

    final now = DateTime.now();

    final sucData = sucursalesAsync.valueOrNull;
    if (sucData != null && sucData.isNotEmpty) {
      _cachedSucursales = sucData;
    }

    final colabData = colaboradoresAsync.valueOrNull;
    if (colabData != null && colabData.isNotEmpty) {
      _cachedColaboradores = colabData;
    }
    final deptosData = deptosAsync.valueOrNull;
    if (deptosData != null && deptosData.isNotEmpty) {
      _cachedDeptos = deptosData;
    }
    final puestosData = puestosAsync.valueOrNull;
    if (puestosData != null && puestosData.isNotEmpty) {
      _cachedPuestos = puestosData;
    }

    final reportData = reporteAsync.valueOrNull;
    if (reportData != null) {
      _cachedRows = reportData;
    }

    final solicitudesData = solicitudesAsync.valueOrNull;
    if (solicitudesData != null) {
      _cachedSolicitudes = solicitudesData;
    }

    final sucursales = _colabService.resolveSucursales(
      _cachedSucursales,
      _cachedColaboradores,
    );

    final departamentos =
        _cachedDeptos.where((d) => d.activo).toList(growable: false)..sort(
          (a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()),
        );

    final cargos =
        _cachedPuestos
            .where((p) => p.activo)
            .where((p) => departamentoId == null || p.idDepto == departamentoId)
            .toList(growable: false)
          ..sort(
            (a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()),
          );

    final filteredRows = _filteredRows(
      rows: _cachedRows,
      colaboradores: _cachedColaboradores,
      deptos: _cachedDeptos,
      puestos: _cachedPuestos,
      sucursalId: sucursalId,
      departamentoId: departamentoId,
      cargoId: cargoId,
      idSearch: ref.watch(reporteIdEmpleadoProvider),
      expedienteEstatus: expedienteEstatus,
    );

    final computed = _computeNomina(
      rows: filteredRows,
      colaboradores: _cachedColaboradores,
      solicitudes: _cachedSolicitudes,
    );

    final puntualCount = computed.rows.where((r) {
      final status = r.estatusFinal.trim().toUpperCase();
      return status == 'OK' || status == 'PUNTUAL' || status == 'NORMAL';
    }).length;
    final noPuntualCount = computed.rows.length - puntualCount;
    final chartTotal = (puntualCount + noPuntualCount).toDouble();
    final punctualPct = chartTotal == 0 ? 0 : (puntualCount / chartTotal);
    final absentPct = chartTotal == 0 ? 0 : (noPuntualCount / chartTotal);

    return Container(
      color: const Color(0xFFF8F9FA),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTopBar(
            now: now,
            range: range,
            sucursales: sucursales,
            sucursalId: sucursalId,
            departamentos: departamentos,
            cargos: cargos,
            departamentoId: departamentoId,
            cargoId: cargoId,
            expedienteEstatus: expedienteEstatus,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 1280;
                  final chartCard = Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFD4D8DF)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x12000000),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Puntualidad vs Ausentismo',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        LayoutBuilder(
                          builder: (context, chartConstraints) {
                            final size = chartConstraints.maxWidth.clamp(
                              180.0,
                              320.0,
                            );
                            final radius = (size * 0.28).clamp(44.0, 70.0);
                            final center = (size * 0.16).clamp(22.0, 42.0);
                            return Center(
                              child: SizedBox(
                                width: size,
                                height: size,
                                child: PieChart(
                                  PieChartData(
                                    sectionsSpace: 2,
                                    centerSpaceRadius: center,
                                    sections: [
                                      PieChartSectionData(
                                        value: puntualCount.toDouble(),
                                        color: const Color(0xFF2E7D32),
                                        title:
                                            '${(punctualPct * 100).toStringAsFixed(0)}%',
                                        radius: radius,
                                      ),
                                      PieChartSectionData(
                                        value: noPuntualCount.toDouble(),
                                        color: const Color(0xFFC62828),
                                        title:
                                            '${(absentPct * 100).toStringAsFixed(0)}%',
                                        radius: radius,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  );

                  final tableCard = Container(
                    height: 320,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFD4D8DF)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x12000000),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: _buildTable(
                      computed.rows,
                      reporteAsync,
                      solicitudesAsync,
                    ),
                  );

                  final issueBox = computed.issues.isNotEmpty
                      ? Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFFCC80)),
                          ),
                          child: ListTile(
                            leading: const Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.deepOrange,
                            ),
                            title: Text(
                              'Inconsistencias: ${computed.issues.length}',
                            ),
                            subtitle: const Text(
                              'Exportación bloqueada hasta corregir huérfanos/duplicados.',
                            ),
                            trailing: TextButton.icon(
                              onPressed: () =>
                                  _showIntegrityIssues(computed.issues),
                              icon: const Icon(Icons.open_in_new),
                              label: const Text('Revisar'),
                            ),
                          ),
                        )
                      : const SizedBox.shrink();

                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildKpiCards(computed.kpi, vertical: false),
                        const SizedBox(height: 12),
                        chartCard,
                        const SizedBox(height: 12),
                        tableCard,
                        if (computed.issues.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          issueBox,
                        ],
                      ],
                    );
                  }

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: constraints.maxWidth,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 255,
                            child: _buildKpiCards(computed.kpi, vertical: true),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(flex: 4, child: chartCard),
                                    const SizedBox(width: 12),
                                    Expanded(flex: 6, child: tableCard),
                                  ],
                                ),
                                if (computed.issues.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  issueBox,
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar({
    required DateTime now,
    required DateTimeRange range,
    required List<SucursalOptionModel> sucursales,
    required int? sucursalId,
    required List<DeptoModel> departamentos,
    required List<PuestoModel> cargos,
    required int? departamentoId,
    required int? cargoId,
    required String? expedienteEstatus,
  }) {
    const compactDecoration = InputDecoration(
      border: OutlineInputBorder(),
      isDense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    );
    String sucursalLabel(SucursalOptionModel s) => '${s.codigo} - ${s.nombre}';

    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.start,
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SegmentedButton<_RangePreset>(
                  segments: const [
                    ButtonSegment(value: _RangePreset.hoy, label: Text('Hoy')),
                    ButtonSegment(
                      value: _RangePreset.semana,
                      label: Text('Semana'),
                    ),
                    ButtonSegment(value: _RangePreset.mes, label: Text('Mes')),
                  ],
                  selected: const <_RangePreset>{_RangePreset.mes},
                  onSelectionChanged: (set) {
                    final selected = set.isEmpty ? _RangePreset.mes : set.first;
                    _applyPreset(selected, now);
                  },
                ),
                SizedBox(
                  width: 200,
                  child: OutlinedButton.icon(
                    onPressed: () => _pickRange(range),
                    icon: const Icon(Icons.date_range, size: 18),
                    label: Text('${_d(range.start)} a ${_d(range.end)}'),
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<int?>(
                    initialValue: sucursalId,
                    decoration: compactDecoration.copyWith(
                      labelText: 'Sucursal',
                    ),
                    icon: const Icon(Icons.arrow_drop_down, size: 18),
                    isDense: true,
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Todas'),
                      ),
                      ...sucursales.map(
                        (s) => DropdownMenuItem<int?>(
                          value: s.id,
                          child: Text(
                            sucursalLabel(s),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    selectedItemBuilder: (context) => [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Todas',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ...sucursales.map(
                        (s) => Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            sucursalLabel(s),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      ref.read(reporteSucursalIdProvider.notifier).state =
                          value;
                      ref.read(reporteDepartamentoIdProvider.notifier).state =
                          null;
                      ref.read(reporteDepartamentoProvider.notifier).state =
                          null;
                      ref.read(reporteCargoIdProvider.notifier).state = null;
                      ref.read(reporteCargoProvider.notifier).state = null;
                      _refreshReport();
                    },
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<int?>(
                    initialValue: departamentoId,
                    decoration: compactDecoration.copyWith(
                      labelText: 'Departamento',
                    ),
                    icon: const Icon(Icons.arrow_drop_down, size: 18),
                    isDense: true,
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Todos'),
                      ),
                      ...departamentos.map(
                        (d) => DropdownMenuItem<int?>(
                          value: d.id,
                          child: Text(
                            d.nombre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    selectedItemBuilder: (context) => [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Todos',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ...departamentos.map(
                        (d) => Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            d.nombre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      DeptoModel? selected;
                      for (final item in departamentos) {
                        if (item.id == value) {
                          selected = item;
                          break;
                        }
                      }
                      ref.read(reporteDepartamentoIdProvider.notifier).state =
                          value;
                      ref.read(reporteDepartamentoProvider.notifier).state =
                          selected?.nombre;
                      ref.read(reporteCargoIdProvider.notifier).state = null;
                      ref.read(reporteCargoProvider.notifier).state = null;
                      _refreshReport();
                    },
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<int?>(
                    initialValue: cargoId,
                    decoration: compactDecoration.copyWith(labelText: 'Cargo'),
                    icon: const Icon(Icons.arrow_drop_down, size: 18),
                    isDense: true,
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Todos'),
                      ),
                      ...cargos.map(
                        (item) => DropdownMenuItem<int?>(
                          value: item.id,
                          child: Text(
                            item.nombre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    selectedItemBuilder: (context) => [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Todos',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ...cargos.map(
                        (item) => Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            item.nombre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      PuestoModel? selected;
                      for (final item in cargos) {
                        if (item.id == value) {
                          selected = item;
                          break;
                        }
                      }
                      ref.read(reporteCargoIdProvider.notifier).state = value;
                      ref.read(reporteCargoProvider.notifier).state =
                          selected?.nombre;
                      _refreshReport();
                    },
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<String?>(
                    initialValue: expedienteEstatus,
                    decoration: compactDecoration.copyWith(
                      labelText: 'Estatus Expediente',
                    ),
                    icon: const Icon(Icons.arrow_drop_down, size: 18),
                    isDense: true,
                    items: const [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Todos'),
                      ),
                      DropdownMenuItem<String?>(
                        value: 'INCOMPLETO',
                        child: Text('Incompleto'),
                      ),
                      DropdownMenuItem<String?>(
                        value: 'PARCIAL',
                        child: Text('Parcial'),
                      ),
                      DropdownMenuItem<String?>(
                        value: 'COMPLETO',
                        child: Text('Completo'),
                      ),
                    ],
                    onChanged: (value) {
                      ref
                              .read(reporteExpedienteEstatusProvider.notifier)
                              .state =
                          value;
                      _refreshReport();
                    },
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 155),
                  child: TextField(
                    controller: _idSearchCtrl,
                    decoration: compactDecoration.copyWith(
                      labelText: 'ID',
                      prefixIcon: const Icon(Icons.badge_outlined, size: 18),
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: 30,
                        minHeight: 30,
                      ),
                    ),
                    onSubmitted: (value) {
                      ref.read(reporteIdEmpleadoProvider.notifier).state = value
                          .trim();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.start,
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    ref.read(reporteIdEmpleadoProvider.notifier).state =
                        _idSearchCtrl.text.trim();
                    _refreshReport();
                  },
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text('Aplicar'),
                ),
                ElevatedButton.icon(
                  onPressed: _exportingPdf
                      ? null
                      : () => _exportPdf(
                          _computeNomina(
                            rows: _filteredRows(
                              rows: _cachedRows,
                              colaboradores: _cachedColaboradores,
                              deptos: _cachedDeptos,
                              puestos: _cachedPuestos,
                              sucursalId: ref.read(reporteSucursalIdProvider),
                              departamentoId: ref.read(
                                reporteDepartamentoIdProvider,
                              ),
                              cargoId: ref.read(reporteCargoIdProvider),
                              idSearch: ref.read(reporteIdEmpleadoProvider),
                              expedienteEstatus: ref.read(
                                reporteExpedienteEstatusProvider,
                              ),
                            ),
                            colaboradores: _cachedColaboradores,
                            solicitudes: _cachedSolicitudes,
                          ),
                          range,
                        ),
                  icon: _exportingPdf
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.picture_as_pdf, size: 18),
                  label: const Text('PDF'),
                ),
                ElevatedButton.icon(
                  onPressed: _exportingExcel
                      ? null
                      : () => _exportExcel(
                          _computeNomina(
                            rows: _filteredRows(
                              rows: _cachedRows,
                              colaboradores: _cachedColaboradores,
                              deptos: _cachedDeptos,
                              puestos: _cachedPuestos,
                              sucursalId: ref.read(reporteSucursalIdProvider),
                              departamentoId: ref.read(
                                reporteDepartamentoIdProvider,
                              ),
                              cargoId: ref.read(reporteCargoIdProvider),
                              idSearch: ref.read(reporteIdEmpleadoProvider),
                              expedienteEstatus: ref.read(
                                reporteExpedienteEstatusProvider,
                              ),
                            ),
                            colaboradores: _cachedColaboradores,
                            solicitudes: _cachedSolicitudes,
                          ),
                          range,
                        ),
                  icon: _exportingExcel
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.grid_on, size: 18),
                  label: const Text('Excel'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCards(NominaKpi kpi, {required bool vertical}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final compact = width < 760;
        final cardWidth = vertical
            ? width
            : compact
            ? width
            : (width - 20) / 2;
        final cards = <Widget>[
          _kpiCard(
            'Dias Vacaciones',
            '${safeInt(kpi.diasVacaciones)}',
            const Color(0xFF2E7D32),
            width: cardWidth.clamp(220, 360).toDouble(),
          ),
          _kpiCard(
            'Costo Est. Horas Extra',
            r'$ ' + safeDouble(kpi.costoHorasExtra).toStringAsFixed(2),
            const Color(0xFFF9A825),
            width: cardWidth.clamp(220, 360).toDouble(),
          ),
          _kpiCard(
            'Retardos (min)',
            '${safeInt(kpi.totalRetardosMin)}',
            const Color(0xFFC62828),
            width: cardWidth.clamp(220, 360).toDouble(),
          ),
        ];
        return Wrap(spacing: 10, runSpacing: 10, children: cards);
      },
    );
  }

  Widget _kpiCard(String title, String value, Color color, {double? width}) {
    return Container(
      width: width ?? 230,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD4D8DF)),
      ),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 56,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(
    List<NominaJoinedRow> rows,
    AsyncValue<List<AsistenciaReporteRow>> reporteAsync,
    AsyncValue<List<SolicitudIncidenciaModel>> solicitudesAsync,
  ) {
    final loading = reporteAsync.isLoading && _cachedRows.isEmpty;
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (reporteAsync.hasError && _cachedRows.isEmpty) {
      return Center(child: Text('Error reporte: ${reporteAsync.error}'));
    }

    if (solicitudesAsync.hasError && _cachedSolicitudes.isEmpty) {
      return Center(
        child: Text('Error incidencias: ${solicitudesAsync.error}'),
      );
    }

    if (rows.isEmpty) {
      return const Center(child: Text('Sin datos disponibles'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 22,
          headingRowColor: WidgetStateProperty.all(const Color(0xFF606973)),
          columns: const [
            DataColumn(
              label: Text('Fecha', style: TextStyle(color: Colors.white)),
            ),
            DataColumn(
              label: Text('ID', style: TextStyle(color: Colors.white)),
            ),
            DataColumn(
              label: Text('Nombre', style: TextStyle(color: Colors.white)),
            ),
            DataColumn(
              label: Text('RFC', style: TextStyle(color: Colors.white)),
            ),
            DataColumn(
              label: Text('CURP', style: TextStyle(color: Colors.white)),
            ),
            DataColumn(
              label: Text('Depto', style: TextStyle(color: Colors.white)),
            ),
            DataColumn(
              label: Text('Entrada', style: TextStyle(color: Colors.white)),
            ),
            DataColumn(
              label: Text('Salida', style: TextStyle(color: Colors.white)),
            ),
            DataColumn(
              label: Text('Estatus', style: TextStyle(color: Colors.white)),
            ),
            DataColumn(
              label: Text('Hrs Extra', style: TextStyle(color: Colors.white)),
            ),
          ],
          rows: rows.map((row) {
            final blocked = row.bloqueadoPorIncidencia;
            final status = row.estatusFinal.trim().toUpperCase();
            return DataRow(
              color: status == 'FALTA'
                  ? WidgetStateProperty.all(const Color(0xFFFFEBEE))
                  : status == 'JUSTIFICADO'
                  ? WidgetStateProperty.all(const Color(0xFFE1F5FE))
                  : blocked
                  ? WidgetStateProperty.all(const Color(0xFFEEEEEE))
                  : null,
              cells: [
                DataCell(Text(row.reporte.fecha)),
                DataCell(Text(row.colaborador?.idEmpleado ?? row.reporte.pin)),
                DataCell(
                  Text(row.colaborador?.nombreCompleto ?? row.reporte.nombre),
                ),
                DataCell(
                  Text(
                    ((row.reporte.rfc ?? '-').toString()).trim().isEmpty
                        ? '-'
                        : (row.reporte.rfc ?? '-').toString(),
                  ),
                ),
                DataCell(
                  Text(
                    ((row.reporte.curp ?? '-').toString()).trim().isEmpty
                        ? '-'
                        : (row.reporte.curp ?? '-').toString(),
                  ),
                ),
                DataCell(Text(row.colaborador?.departamento ?? '-')),
                DataCell(Text(row.reporte.entrada ?? '-')),
                DataCell(Text(row.reporte.salida ?? '-')),
                DataCell(
                  Text(
                    status,
                    style: TextStyle(
                      color: _statusColor(status),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    'D ${safeDouble(row.horasDobles).toStringAsFixed(2)} / T ${safeDouble(row.horasTriples).toStringAsFixed(2)}',
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  List<AsistenciaReporteRow> _filteredRows({
    required List<AsistenciaReporteRow> rows,
    required List<ColaboradorGestionModel> colaboradores,
    required List<DeptoModel> deptos,
    required List<PuestoModel> puestos,
    required int? sucursalId,
    required int? departamentoId,
    required int? cargoId,
    required String idSearch,
    required String? expedienteEstatus,
  }) {
    final colabById = <int, ColaboradorGestionModel>{
      for (final c in colaboradores) c.id: c,
    };
    final deptoIdByName = <String, int>{
      for (final d in deptos) d.nombre.trim().toUpperCase(): d.id,
    };
    final cargoIdByName = <String, int>{
      for (final p in puestos) p.nombre.trim().toUpperCase(): p.id,
    };
    final term = idSearch.trim().toUpperCase();

    return rows.where((r) {
      final c = colabById[r.colaboradorId];
      if (sucursalId != null && r.sucursalId != sucursalId) return false;
      if (departamentoId != null) {
        final deptoName = (c?.departamento ?? '').trim().toUpperCase();
        final mappedDeptoId = deptoIdByName[deptoName];
        if (mappedDeptoId != departamentoId) return false;
      }
      if (cargoId != null) {
        final cargoName = (c?.cargo ?? '').trim().toUpperCase();
        final mappedCargoId = cargoIdByName[cargoName];
        if (mappedCargoId != cargoId) return false;
      }
      final exp = (expedienteEstatus ?? '').trim().toUpperCase();
      if (exp.isNotEmpty && c != null && _expedienteStatus(c) != exp) {
        return false;
      }
      if (term.isEmpty) return true;
      final id = (c?.idEmpleado ?? '').toUpperCase();
      final pin = r.pin.toUpperCase();
      final name = (c?.nombreCompleto ?? r.nombre).toUpperCase();
      return id.contains(term) || pin.contains(term) || name.contains(term);
    }).toList();
  }
}

enum _RangePreset { hoy, semana, mes }

Color _statusColor(String status) {
  final normalized = status.trim().toUpperCase();
  if (normalized == 'RETARDO') return const Color(0xFFE65100);
  if (normalized == 'FALTA') return const Color(0xFFC62828);
  if (normalized == 'JUSTIFICADO') return const Color(0xFF0288D1);
  if (normalized == 'SALIDA_TEMPRANA') return const Color(0xFF6A1B9A);
  if (normalized == 'ERROR_MARCAJE') return const Color(0xFFD32F2F);
  if (normalized.contains('VACACION') || normalized.contains('PERMISO')) {
    return const Color(0xFF455A64);
  }
  return const Color(0xFF2E7D32);
}

String _expedienteStatus(ColaboradorGestionModel c) {
  final basicReady =
      c.nombre.trim().isNotEmpty &&
      c.apellido.trim().isNotEmpty &&
      c.sucursalId > 0 &&
      (c.horarioId ?? 0) > 0;
  if (!basicReady) return 'INCOMPLETO';
  final docsReady = c.documentacionCompleta;
  final biometricsReady = c.hasFace && c.hasFingerprint;
  return (docsReady && biometricsReady) ? 'COMPLETO' : 'PARCIAL';
}

String _d(DateTime value) {
  final y = value.year.toString().padLeft(4, '0');
  final m = value.month.toString().padLeft(2, '0');
  final d = value.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
