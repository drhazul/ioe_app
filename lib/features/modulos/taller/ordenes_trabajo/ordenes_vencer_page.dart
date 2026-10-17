import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ioe_app/core/app_theme.dart';
import 'package:ioe_app/core/excel_exporter.dart';

import 'ordenes_trabajo_models.dart';
import 'ordenes_trabajo_providers.dart';

/// Pantalla independiente para DAT_JAO_ORDENES_VENCER.
class OrdenesVencerPage extends ConsumerStatefulWidget {
  const OrdenesVencerPage({super.key});

  @override
  ConsumerState<OrdenesVencerPage> createState() => _OrdenesVencerPageState();
}

class _OrdenesVencerPageState extends ConsumerState<OrdenesVencerPage> {
  final _iord = TextEditingController();
  final _idfol = TextEditingController();
  final _client = TextEditingController();
  final _tipo = TextEditingController();
  final _asign = TextEditingController();
  String? _suc;
  String? _labor;
  String? _flow;
  String? _vencimiento;
  bool _isEncargadoMaquila = false;
  bool _isEncargadoBisel = false;
  List<OrdenTrabajoColaboradorOption> _roleAssignedOptions =
      const <OrdenTrabajoColaboradorOption>[];
  List<OrdenTrabajoSucursalOption> _sucursalOptions =
      const <OrdenTrabajoSucursalOption>[];
  DateTime? _from;
  DateTime? _to;
  final Set<String> _selectedIords = <String>{};
  bool _exportingExcel = false;
  Timer? _clock;
  final Set<String> _visibleColumns = {
    'SUC',
    'Tipo',
    'OPV',
    'Laboratorio',
    'IORD',
    'Cliente',
    'Artículo',
    'Descripción',
    'CTD',
    'Flujo',
    'Asignado',
    'F. sol',
    'F. ent',
  };

  OrdenesTrabajoFilter get _filter =>
      ref.read(ordenesTrabajoVencerFilterProvider);

  @override
  void initState() {
    super.initState();
    final filter = ref.read(ordenesTrabajoVencerFilterProvider);
    _restore(filter);
    unawaited(_loadSucursales());
    unawaited(_initializeRoleSpecificFilters());
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if (_vencimiento != null) {
        ref.invalidate(ordenesTrabajoVencerPanelProvider);
      }
    });
  }

  Future<void> _loadSucursales() async {
    try {
      final options = await ref
          .read(ordenesTrabajoApiProvider)
          .fetchSucursales();
      if (!mounted) return;
      setState(() => _sucursalOptions = options);
    } catch (error) {
      if (mounted) {
        _message('No se pudieron cargar los nombres de sucursal: $error');
      }
    }
  }

  Future<void> _initializeRoleSpecificFilters() async {
    try {
      final panel = await ref.read(ordenesTrabajoVencerPanelProvider.future);
      final roleTipo = _roleTipoForRole(panel.roleCode);
      if (!mounted || roleTipo == null) return;

      setState(() {
        _isEncargadoMaquila = _isMaquilaRole(panel.roleCode);
        _isEncargadoBisel = _isBiselRole(panel.roleCode);
      });
      _tipo.text = roleTipo;
      final filter = ref.read(ordenesTrabajoVencerFilterProvider);
      if (filter.tipo?.trim().toUpperCase() != roleTipo) {
        ref.read(ordenesTrabajoVencerFilterProvider.notifier).state = filter
            .copyWith(tipo: roleTipo, page: 1);
        ref.invalidate(ordenesTrabajoVencerPanelProvider);
      }

      final sucs = panel.allowedSucs
          .map((suc) => suc.trim().toUpperCase())
          .where((suc) => suc.isNotEmpty)
          .toSet();
      final optionsById = <String, OrdenTrabajoColaboradorOption>{};
      final api = ref.read(ordenesTrabajoApiProvider);
      for (final suc in sucs) {
        final options = await api.fetchAsignarColaboradores(suc);
        for (final option in options) {
          final id = option.idopv.trim();
          final searchableLabel = '${option.label} $id'.toUpperCase();
          if (id.isNotEmpty &&
              (!_isEncargadoMaquila || !searchableLabel.contains('PRUEBA'))) {
            optionsById.putIfAbsent(id, () => option);
          }
        }
      }
      if (!mounted) return;
      final options = optionsById.values.toList()
        ..sort((a, b) => a.label.toUpperCase().compareTo(b.label.toUpperCase()));
      final selectedAssigned = _asign.text.trim();
      if (selectedAssigned.isNotEmpty &&
          !options.any((option) => option.idopv.trim() == selectedAssigned)) {
        _asign.clear();
        final currentFilter = ref.read(ordenesTrabajoVencerFilterProvider);
        if (currentFilter.asign?.trim() == selectedAssigned) {
          ref.read(ordenesTrabajoVencerFilterProvider.notifier).state =
              currentFilter.copyWith(asign: '', page: 1);
          ref.invalidate(ordenesTrabajoVencerPanelProvider);
        }
      }
      setState(() => _roleAssignedOptions = options);
    } catch (error) {
      if (mounted) {
        _message('No se pudieron cargar los colaboradores asignados: $error');
      }
    }
  }

  bool _isMaquilaRole(String roleCode) =>
      const {'ENC_MAQUILA', 'ENCARGADO_MAQUILA'}.contains(
        roleCode.trim().toUpperCase(),
      );

  bool _isBiselRole(String roleCode) =>
      const {'ENC_BISEL', 'ENCARGADO_BISELADO'}.contains(
        roleCode.trim().toUpperCase(),
      );

  String? _roleTipoForRole(String roleCode) {
    if (_isMaquilaRole(roleCode)) return 'TALLADO';
    if (_isBiselRole(roleCode)) return 'BISELADO';
    return null;
  }

  String? get _roleTipo =>
      _isEncargadoMaquila ? 'TALLADO' : (_isEncargadoBisel ? 'BISELADO' : null);

  void _restore(OrdenesTrabajoFilter filter) {
    _iord.text = filter.iord ?? '';
    _idfol.text = filter.idfol ?? '';
    _client.text = filter.client ?? '';
    _tipo.text = filter.tipo ?? '';
    _asign.text = filter.asign ?? '';
    _suc = filter.suc;
    _labor = filter.labor;
    _flow = filter.estsegu;
    _vencimiento = filter.vencimiento;
    _from = filter.fecIni;
    _to = filter.fecFin;
  }

  @override
  void dispose() {
    _clock?.cancel();
    _iord.dispose();
    _idfol.dispose();
    _client.dispose();
    _tipo.dispose();
    _asign.dispose();
    super.dispose();
  }

  void _apply({int page = 1}) {
    ref.read(ordenesTrabajoVencerFilterProvider.notifier).state = _filter
        .copyWith(
          iord: _iord.text,
          idfol: _idfol.text,
          client: _client.text,
          tipo: _roleTipo ?? _tipo.text,
          asign: _asign.text,
          suc: _suc,
          labor: _labor,
          estsegu: _flow,
          vencimiento: _vencimiento,
          fecIni: _from,
          fecFin: _to,
          page: page,
          reportMode: false,
          ordenesVencerMode: true,
        );
    setState(_selectedIords.clear);
  }

  void _clear() {
    final clearFilter = OrdenesTrabajoFilter(
      panelMode: OrdenesTrabajoPanelMode.estado,
      ordenesVencerMode: true,
      tipo: _roleTipo,
    );
    _restore(clearFilter);
    ref
        .read(ordenesTrabajoVencerFilterProvider.notifier)
        .state = clearFilter;
    setState(_selectedIords.clear);
  }

  Future<void> _pickDate({required bool start}) async {
    final initial = (start ? _from : _to) ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null) return;
    setState(() {
      if (start) {
        _from = date;
      } else {
        _to = date;
      }
    });
  }

  Future<void> _showDetail(OrdenTrabajoItem item) async {
    try {
      final detail = await ref
          .read(ordenesTrabajoApiProvider)
          .fetchDetail(item.iord);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Detalle de orden ${item.iord}'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: SelectableText(
                '${detail.header}\n\n${detail.details.join('\n')}',
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) _message('No se pudo cargar el detalle: $error');
    }
  }

  Future<void> _exportExcel() async {
    if (_exportingExcel) return;
    setState(() => _exportingExcel = true);
    try {
      // El endpoint de exportación aplica los filtros y solicita todas las
      // coincidencias, sin limitar el archivo a la página visible.
      final filter = _filter.copyWith(page: 1, ordenesVencerMode: true);
      final bytes = await ref
          .read(ordenesTrabajoApiProvider)
          .exportExcel(filter);
      final now = DateTime.now();
      final date =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final saved = await getExcelExporter().save(
        bytes,
        'ordenes_a_vencer_$date.xlsx',
      );
      if (!mounted) return;
      _message(
        saved
            ? 'Excel descargado con todos los resultados de los filtros aplicados.'
            : 'Descarga cancelada.',
      );
    } catch (error) {
      if (mounted) _message('No se pudo descargar el Excel: $error');
    } finally {
      if (mounted) setState(() => _exportingExcel = false);
    }
  }

  Future<void> _configureView() async {
    const options = [
      'IORD',
      'SUC',
      'Tipo',
      'OPV',
      'Laboratorio',
      'Cliente',
      'Artículo',
      'Descripción',
      'CTD',
      'Flujo',
      'Asignado',
      'F. sol',
      'F. ent',
    ];
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Configuración de vista'),
          content: SizedBox(
            width: 360,
            child: ListView(
              shrinkWrap: true,
              children: options
                  .map(
                    (label) => CheckboxListTile(
                      dense: true,
                      title: Text(label),
                      value: _visibleColumns.contains(label),
                      onChanged: (show) {
                        setDialogState(() {
                          if (show == true) {
                            _visibleColumns.add(label);
                          } else if (_visibleColumns.length > 1) {
                            _visibleColumns.remove(label);
                          }
                        });
                        setState(() {});
                      },
                    ),
                  )
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      ),
    );
  }

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  String _date(DateTime? date) => date == null
      ? '—'
      : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  bool _late(OrdenTrabajoItem item) {
    final classification = item.vencimientoColor;
    if (classification != null) return classification == 'retrasadas';
    return item.fcnm != null &&
        item.fcnm!.isBefore(DateTime.now()) &&
        item.estsegu != '4' &&
        item.estsegu != '11';
  }

  bool _soon(OrdenTrabajoItem item) {
    final classification = item.vencimientoColor;
    if (classification != null) return classification == 'por_vencer';
    final due = item.fcnm;
    if (due == null || item.estsegu == '4' || item.estsegu == '11') {
      return false;
    }
    final remaining = due.difference(DateTime.now());
    return remaining > Duration.zero &&
        remaining <= const Duration(minutes: 30);
  }

  @override
  Widget build(BuildContext context) {
    final panel = ref.watch(ordenesTrabajoVencerPanelProvider);
    final roleCode = panel.valueOrNull?.roleCode;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        toolbarHeight: kToolbarHeight,
        leading: IconButton(
          tooltip: 'Regresar',
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.arrow_back),
        ),
        titleSpacing: 8,
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Órdenes a Vencer',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              _selectedIords.isEmpty
                  ? 'Sin selección en grilla.'
                  : '${_selectedIords.length} ORD${_selectedIords.length == 1 ? '' : 's'} seleccionada${_selectedIords.length == 1 ? '' : 's'}',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: TextButton.icon(
              onPressed: _selectedIords.length != 1
                  ? null
                  : () {
                      final selectedIord = _selectedIords.single;
                      final current = panel.valueOrNull?.items
                          .where((item) => item.iord == selectedIord)
                          .firstOrNull;
                      if (current != null) _showDetail(current);
                    },
              style: _appBarActionButtonStyle(),
              icon: const Icon(Icons.info_outline),
              label: const Text('Ver detalle'),
            ),
          ),
          if (roleCode != null && !_hideDelayAndExcelForRole(roleCode))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: TextButton.icon(
                onPressed: _exportingExcel ? null : _exportExcel,
                style: _appBarActionButtonStyle(),
                icon: _exportingExcel
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_outlined),
                label: const Text('Descargar Excel'),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: TextButton.icon(
              onPressed: _configureView,
              style: _appBarActionButtonStyle(),
              icon: const Icon(Icons.tune),
              label: const Text('Configuración de Vista'),
            ),
          ),
          IconButton(
            tooltip: 'Refrescar',
            onPressed: () => ref.invalidate(ordenesTrabajoVencerPanelProvider),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.navy,
            ),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.canvas, AppColors.canvasAlt],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: panel.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('No se pudieron cargar las órdenes: $error'),
            ),
          ),
          data: (data) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _filters(data),
                const SizedBox(height: 6),
                Align(alignment: Alignment.centerLeft, child: _legend()),
                const SizedBox(height: 8),
                Expanded(child: _results(data)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _filters(OrdenTrabajoPanelResponse data) {
    final allowedSucs = data.allowedSucs
        .map((value) => value.trim().toUpperCase())
        .where((value) => value.isNotEmpty)
        .toSet();
    final availableSucursales = _sucursalOptions
        .where(
          (item) =>
              allowedSucs.isEmpty ||
              allowedSucs.contains(item.suc.trim().toUpperCase()),
        )
        .toList(growable: false);
    final fallbackSucs =
        (allowedSucs.isNotEmpty
                ? allowedSucs
                : data.items
                      .map((item) => item.suc.trim().toUpperCase())
                      .toSet())
            .toList()
          ..sort();
    final sucursales = availableSucursales.isNotEmpty
        ? availableSucursales
        : fallbackSucs
              .map(
                (suc) =>
                    OrdenTrabajoSucursalOption(suc: suc, label: suc, desc: ''),
              )
              .toList(growable: false);
    final flowItems = data.flowStatusOptions
        .where((item) => item.value.isNotEmpty)
        .map((item) {
          final code = item.value.trim();
          final label = code.toUpperCase() == 'NULL'
              ? (item.label.trim().isEmpty ? 'SIN FLUJO' : item.label.trim())
              : '$code ${item.label}'.trim();
          return DropdownMenuItem<String>(
            value: item.value,
            child: Text(label),
          );
        })
        .toList(growable: false);
    final assignedItems =
        data.items
            .map((item) => item.asign.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final filters = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _dropdownField(
          label: 'Sucursal',
          value: _suc,
          width: 180,
          items: [
            const DropdownMenuItem<String>(value: null, child: Text('Todos')),
            ...sucursales.map(
              (item) => DropdownMenuItem<String>(
                value: item.suc,
                child: Text(item.label, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
          onChanged: (value) => setState(() => _suc = value),
        ),
        _text('IORD', _iord, width: 150),
        _text('IDFOL', _idfol, width: 150),
        _text('Cliente', _client, width: 150),
        _dropdownField(
          label: 'Tipo',
          value: _roleTipo ?? (_tipo.text.isEmpty ? null : _tipo.text),
          width: 140,
          items: _roleTipo != null
              ? [
                  DropdownMenuItem<String>(
                    value: _roleTipo,
                    child: Text(_roleTipo!),
                  ),
                ]
              : const [
                  DropdownMenuItem<String>(value: null, child: Text('Todos')),
                  DropdownMenuItem<String>(
                    value: 'TALLADO',
                    child: Text('TALLADO'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'BISELADO',
                    child: Text('BISELADO'),
                  ),
                ],
          onChanged: (value) => setState(
            () => _tipo.text =
                _roleTipo ?? (value ?? ''),
          ),
        ),
        _dropdownField(
          label: 'Laboratorio',
          value: _labor,
          width: 220,
          items: [
            const DropdownMenuItem<String>(value: null, child: Text('Todos')),
            ...data.laboratorios.map(
              (item) => DropdownMenuItem<String>(
                value: item.id.toString(),
                child: Text(item.lab, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
          onChanged: (value) => setState(() => _labor = value),
        ),
        _dropdownField(
          label: 'Est. flujo',
          value: _flow,
          width: 170,
          items: [
            const DropdownMenuItem<String>(value: null, child: Text('Todos')),
            ...flowItems,
          ],
          onChanged: (value) => setState(() => _flow = value),
        ),
        _dropdownField(
          label: 'Otros',
          value: _vencimiento,
          width: 210,
          items: const [
            DropdownMenuItem<String>(value: null, child: Text('Todos')),
            DropdownMenuItem<String>(
              value: 'por_vencer',
              child: Text('Órdenes por vencer'),
            ),
            DropdownMenuItem<String>(
              value: 'retrasadas',
              child: Text('Órdenes retrasadas'),
            ),
          ],
          onChanged: (value) => setState(() => _vencimiento = value),
        ),
        _dropdownField(
          label: 'Asignado',
          value: _asign.text.isEmpty ? null : _asign.text,
          width: 220,
          items: [
            const DropdownMenuItem<String>(value: null, child: Text('Todos')),
            if (_roleTipo != null)
              ..._roleAssignedOptions.map(
                (option) => DropdownMenuItem<String>(
                  value: option.idopv.trim(),
                  child: Text(
                    option.label,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
            else
              ...assignedItems.map(
                (value) =>
                    DropdownMenuItem<String>(value: value, child: Text(value)),
              ),
          ],
          onChanged: (value) => setState(() => _asign.text = value ?? ''),
        ),
        _dateChip('Desde', _from, () => _pickDate(start: true)),
        _dateChip('Hasta', _to, () => _pickDate(start: false)),
        ElevatedButton.icon(
          onPressed: () => _apply(),
          icon: const Icon(Icons.search, size: 18),
          style: ElevatedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          label: const Text('Aplicar filtros'),
        ),
        OutlinedButton.icon(
          onPressed: _clear,
          icon: const Icon(Icons.clear_all, size: 18),
          style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          label: const Text('Limpiar filtros'),
        ),
      ],
    );
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filtros del panel',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 1240) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      filters,
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: _paginator(data),
                      ),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: filters),
                    const SizedBox(width: 12),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: _paginator(data),
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

  Widget _text(
    String label,
    TextEditingController controller, {
    double width = 150,
    ValueChanged<String>? onChanged,
  }) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 11,
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
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        isDense: true,
        items: items,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 11,
          ),
        ),
      ),
    );
  }

  Widget _dateChip(String label, DateTime? value, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.calendar_today_outlined, size: 16),
      label: Text('$label: ${_date(value)}'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.navy,
        side: BorderSide(color: Colors.blueGrey.shade200),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _paginator(OrdenTrabajoPanelResponse data) {
    final pages = data.pageSize <= 0
        ? 1
        : ((data.total + data.pageSize - 1) / data.pageSize).ceil().clamp(
            1,
            999999,
          );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Total: ${data.total} | Página ${data.page} de $pages',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        IconButton(
          tooltip: 'Página anterior',
          visualDensity: VisualDensity.compact,
          onPressed: data.page > 1 ? () => _apply(page: data.page - 1) : null,
          icon: const Icon(Icons.chevron_left),
        ),
        IconButton(
          tooltip: 'Página siguiente',
          visualDensity: VisualDensity.compact,
          onPressed: data.page < pages
              ? () => _apply(page: data.page + 1)
              : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Widget _legend() {
    Widget item(Color color, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            border: Border.all(color: color.withValues(alpha: 0.8)),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 7),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 6,
        children: [
          item(
            const Color(0xFFFFF0C2),
            'Por vencer: fecha y hora prevista dentro de los próximos 30 minutos',
          ),
          item(
            const Color(0xFFFFD9D9),
            'Retrasada: hora prevista vencida (excluye anuladas y entregadas)',
          ),
        ],
      ),
    );
  }

  ButtonStyle _appBarActionButtonStyle() => TextButton.styleFrom(
    backgroundColor: Colors.white,
    foregroundColor: AppColors.navy,
    disabledBackgroundColor: const Color(0xFF4A5565),
    disabledForegroundColor: Colors.white70,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  );

  Widget _results(OrdenTrabajoPanelResponse data) {
    if (data.items.isEmpty) {
      return const Center(
        child: Text('Sin resultados para los filtros actuales.'),
      );
    }
    final allSelected = data.items.every(
      (item) => _selectedIords.contains(item.iord),
    );
    final someSelected =
        !allSelected &&
        data.items.any((item) => _selectedIords.contains(item.iord));
    final resultColumns = _visibleColumns.toList();
    if (!_hideDelayAndExcelForRole(data.roleCode)) {
      final deliveryDateIndex = resultColumns.indexOf('F. ent');
      resultColumns.insert(
        deliveryDateIndex < 0 ? resultColumns.length : deliveryDateIndex + 1,
        'Tiempo de retraso',
      );
    }
    final columns = <DataColumn>[
      DataColumn(
        label: SizedBox(
          width: 28,
          child: Checkbox(
            tristate: true,
            value: allSelected ? true : (someSelected ? null : false),
            onChanged: (_) => setState(() {
              if (allSelected) {
                _selectedIords.removeAll(data.items.map((item) => item.iord));
              } else {
                _selectedIords.addAll(data.items.map((item) => item.iord));
              }
            }),
          ),
        ),
      ),
      ...resultColumns.map(
        (label) => DataColumn(
          label: SizedBox(
            width: _columnWidth(label),
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ),
      ),
    ];
    return Card(
      elevation: 0,
      color: Colors.transparent,
      margin: const EdgeInsets.fromLTRB(4, 4, 4, 12),
      clipBehavior: Clip.antiAlias,
      child: SelectionArea(
        child: SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              showCheckboxColumn: false,
              horizontalMargin: 2,
              checkboxHorizontalMargin: 2,
              columnSpacing: 8,
              headingRowHeight: 44,
              dataRowMinHeight: 44,
              dataRowMaxHeight: 44,
              dividerThickness: 1,
              headingRowColor: const WidgetStatePropertyAll(Color(0xFFE8EEF4)),
              dataRowColor: const WidgetStatePropertyAll(Color(0xFFF4F7FA)),
              headingTextStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: Colors.black87,
              ),
              dataTextStyle: const TextStyle(
                fontSize: 12,
                color: Colors.black87,
              ),
              border: TableBorder(
                horizontalInside: BorderSide(color: Color(0xFFD5DFE8)),
              ),
              columns: columns,
              rows: data.items.map((item) {
                final color = _late(item)
                    ? const Color(0xFFFFD9D9)
                    : _soon(item)
                    ? const Color(0xFFFFF0C2)
                    : null;
                return DataRow(
                  selected: _selectedIords.contains(item.iord),
                  color: color == null ? null : WidgetStatePropertyAll(color),
                  cells: [
                    DataCell(
                      SizedBox(
                        width: 28,
                        child: Checkbox(
                          value: _selectedIords.contains(item.iord),
                          onChanged: (selected) => setState(() {
                            if (selected == true) {
                              _selectedIords.add(item.iord);
                            } else {
                              _selectedIords.remove(item.iord);
                            }
                          }),
                        ),
                      ),
                    ),
                    ...resultColumns.map(
                      (label) => DataCell(
                        SizedBox(
                          width: _columnWidth(label),
                          child: Text(
                            _cellValue(item, label),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
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
    );
  }

  bool _hideDelayAndExcelForRole(String roleCode) =>
      const {
        'ANALISTA_ORD',
        'ENC_MAQUILA',
        'ENCARGADO_MAQUILA',
        'ENC_BISEL',
        'ENCARGADO_BISELADO',
      }.contains(roleCode.trim().toUpperCase());

  double _columnWidth(String label) {
    switch (label) {
      case 'SUC':
        return 56;
      case 'Tipo':
        return 90;
      case 'OPV':
        return 220;
      case 'Laboratorio':
        return 165;
      case 'IORD':
        return 125;
      case 'Cliente':
        return 320;
      case 'Artículo':
        return 90;
      case 'Descripción':
        return 330;
      case 'CTD':
        return 56;
      case 'Flujo':
        return 190;
      case 'Asignado':
        return 190;
      case 'F. sol':
        return 105;
      case 'F. ent':
        return 145;
      case 'Tiempo de retraso':
        return 140;
      default:
        return 120;
    }
  }

  String _cellValue(OrdenTrabajoItem item, String label) {
    switch (label) {
      case 'IORD':
        return item.iord;
      case 'SUC':
        return item.suc;
      case 'Tipo':
        return item.tipo;
      case 'OPV':
        return item.opv;
      case 'Laboratorio':
        return item.labor;
      case 'Cliente':
        return '${item.clien} ${item.ncliente}'.trim();
      case 'Artículo':
        return item.art;
      case 'Descripción':
        return item.descArt;
      case 'CTD':
        return item.ctd.toString();
      case 'Flujo':
        return item.flujoHistorial;
      case 'Asignado':
        return item.asign;
      case 'F. sol':
        return _date(item.fcns);
      case 'F. ent':
        return item.fcnm == null
            ? '—'
            : '${_date(item.fcnm)} ${item.fcnm!.hour.toString().padLeft(2, '0')}:${item.fcnm!.minute.toString().padLeft(2, '0')}';
      case 'Tiempo de retraso':
        return _formatLateDuration(item.minutosRetraso);
      default:
        return '';
    }
  }

  String _formatLateDuration(int? totalMinutes) {
    if (totalMinutes == null || totalMinutes < 0) return '—';
    final days = totalMinutes ~/ 1440;
    final hours = (totalMinutes % 1440) ~/ 60;
    final minutes = totalMinutes % 60;
    return [
      if (days > 0) '$days ${days == 1 ? 'día' : 'días'}',
      if (hours > 0) '$hours h',
      if (minutes > 0 || (days == 0 && hours == 0)) '$minutes min',
    ].join(' ');
  }
}
