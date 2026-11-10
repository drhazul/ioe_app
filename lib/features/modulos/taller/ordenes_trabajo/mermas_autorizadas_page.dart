import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ioe_app/core/excel_exporter.dart';

import 'ordenes_trabajo_models.dart';
import 'ordenes_trabajo_providers.dart';

class MermasAutorizadasPage extends ConsumerStatefulWidget {
  const MermasAutorizadasPage({super.key});

  @override
  ConsumerState<MermasAutorizadasPage> createState() =>
      _MermasAutorizadasPageState();
}

class _MermasAutorizadasPageState extends ConsumerState<MermasAutorizadasPage> {
  static const int _pageSize = 25;
  final _autorizacionCtrl = TextEditingController();
  final _originalCtrl = TextEditingController();
  final _iordCtrl = TextEditingController();
  final _folioCtrl = TextEditingController();
  final _clienteCtrl = TextEditingController();
  final _tableHorizontalScrollCtrl = ScrollController();
  List<OrdenTrabajoSucursalOption> _sucursales = const [];
  List<Map<String, dynamic>> _tipos = const [];
  List<Map<String, dynamic>> _laboratorios = const [];
  List<Map<String, dynamic>> _asignados = const [];
  String? _sucursal;
  String? _tipo;
  String? _labor;
  String? _asign;
  String? _filterOptionsSuc;
  bool _filterOptionsLoaded = false;
  final Set<String> _filterOptionsRequestsInFlight = <String>{};
  DateTime? _desde;
  DateTime? _hasta;
  List<Map<String, dynamic>> _items = const [];
  int _page = 1;
  int _total = 0;
  String? _selectedIord;
  bool _loading = false;
  bool _exporting = false;
  String? _error;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _loadSucursales();
  }

  @override
  void dispose() {
    _autorizacionCtrl.dispose();
    _originalCtrl.dispose();
    _iordCtrl.dispose();
    _folioCtrl.dispose();
    _clienteCtrl.dispose();
    _tableHorizontalScrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSucursales() async {
    try {
      final items = await ref.read(ordenesTrabajoApiProvider).fetchSucursales();
      items.sort((a, b) => a.suc.toUpperCase().compareTo(b.suc.toUpperCase()));
      if (mounted) setState(() => _sucursales = items);
    } catch (_) {
      // El listado sigue disponible aunque falle la carga de opciones.
    }
  }

  Future<void> _load({int? page}) async {
    setState(() {
      _loading = true;
      _error = null;
      if (page != null) _page = page;
    });
    try {
      final result = await ref
          .read(ordenesTrabajoApiProvider)
          .fetchMermasAutorizadas(
            suc: _sucursal,
            iordAutorizacion: _autorizacionCtrl.text,
            iordOriginal: _originalCtrl.text,
            iord: _iordCtrl.text,
            idfol: _folioCtrl.text,
            client: _clienteCtrl.text,
            tipo: _tipo,
            labor: _labor,
            asign: _asign,
            fecIni: _apiDate(_desde),
            fecFin: _apiDate(_hasta),
            page: _page,
            pageSize: _pageSize,
          );
      if (!mounted) return;
      final rows = (result['items'] as List? ?? const [])
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
      setState(() {
        _items = rows;
        _total = int.tryParse('${result['total'] ?? 0}') ?? 0;
        if (_selectedIord != null &&
            !rows.any((row) => _orderKey(row) == _selectedIord)) {
          _selectedIord = null;
        }
        _loading = false;
      });
      _refreshFilterOptions(_sucursal);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _items = const [];
        _total = 0;
        _selectedIord = null;
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _exportExcel() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final bytes = await ref
          .read(ordenesTrabajoApiProvider)
          .exportMermasAutorizadas(
            suc: _sucursal,
            iordAutorizacion: _autorizacionCtrl.text,
            iordOriginal: _originalCtrl.text,
            iord: _iordCtrl.text,
            idfol: _folioCtrl.text,
            client: _clienteCtrl.text,
            tipo: _tipo,
            labor: _labor,
            asign: _asign,
            fecIni: _apiDate(_desde),
            fecFin: _apiDate(_hasta),
          );
      final now = DateTime.now();
      final date =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final saved = await getExcelExporter().save(
        bytes,
        'mermas_autorizadas_taller_$date.xlsx',
      );
      if (mounted) {
        _message(saved ? 'Excel descargado.' : 'Descarga cancelada.');
      }
    } catch (error) {
      if (mounted) _message('No se pudo descargar el Excel: $error');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _loadFilterOptions(String? suc) async {
    final requestKey = (suc ?? '').trim().toUpperCase();
    if (!_filterOptionsRequestsInFlight.add(requestKey)) return;
    try {
      final result = await ref
          .read(ordenesTrabajoApiProvider)
          .fetchMermasAutorizadasFilterOptions(suc: suc);
      if (!mounted || _sucursal != suc) return;
      final options = Map<String, dynamic>.from(
        (result['filterOptions'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
      setState(() {
        _tipos = _readOptions(options['tipos']);
        _laboratorios = _readOptions(options['laboratorios']);
        _asignados = _readOptions(options['asignados']);
        _filterOptionsLoaded = true;
      });
    } catch (_) {
      // Se conserva la consulta aunque los catálogos opcionales no carguen.
    } finally {
      _filterOptionsRequestsInFlight.remove(requestKey);
    }
  }

  void _refreshFilterOptions(String? suc) {
    if (_filterOptionsLoaded && _filterOptionsSuc == suc) return;
    _filterOptionsSuc = suc;
    _filterOptionsLoaded = false;
    unawaited(_loadFilterOptions(suc));
  }

  void _applyFilters() {
    setState(() => _hasSearched = true);
    _load(page: 1);
  }

  void _clearFilters() {
    setState(() {
      _sucursal = null;
      _tipo = null;
      _labor = null;
      _asign = null;
      _selectedIord = null;
      _desde = null;
      _hasta = null;
      _tipos = const [];
      _laboratorios = const [];
      _asignados = const [];
      _filterOptionsSuc = null;
      _filterOptionsLoaded = false;
      _autorizacionCtrl.clear();
      _originalCtrl.clear();
      _iordCtrl.clear();
      _folioCtrl.clear();
      _clienteCtrl.clear();
      _items = const [];
      _total = 0;
      _hasSearched = false;
    });
  }

  void _message(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showDetail() {
    final selectedKey = _selectedIord;
    if (selectedKey == null) return;
    final row = _items.cast<Map<String, dynamic>?>().firstWhere(
      (item) => item != null && _orderKey(item) == selectedKey,
      orElse: () => null,
    );
    if (row == null) return;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Detalle de orden'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _detailSection('Orden', [
                  ('Sucursal', _value(row, 'SUC')),
                  ('IORD original', _value(row, 'IORD')),
                  ('IORD autorización', _value(row, 'IORD_NUEVA')),
                  ('Folio', _value(row, 'IDFOL')),
                  ('OPV', _value(row, 'OPV')),
                  ('Flujo', _value(row, 'FLUJO')),
                ]),
                const SizedBox(height: 12),
                _detailSection('Artículo original y merma', [
                  ('Artículo', _value(row, 'ART')),
                  ('Descripción', _value(row, 'DESCART')),
                  ('Cantidad original', _value(row, 'CTD')),
                  ('Cantidad merma', _value(row, 'CTD_C_M')),
                  ('Motivo de Merma', _value(row, 'MOTIVO_MERMA')),
                  (
                    'Motivo Cambio de Material',
                    _value(row, 'MOTIVO_CAMBIO_MATERIAL'),
                  ),
                ]),
                const SizedBox(height: 12),
                _detailSection('Artículo de autorización', [
                  ('Artículo nuevo', _value(row, 'ART_NUEVA')),
                  ('Descripción', _value(row, 'DESCART_NUEVA')),
                  ('Cantidad nueva', _value(row, 'CTD_NUEVA')),
                  ('Autorizó', _value(row, 'USR_AUT_CYM')),
                  ('Fecha de autorización', _date(row['FCN_AUT_CYM'])),
                ]),
              ],
            ),
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

  Widget _detailSection(String title, List<(String, String)> fields) => Card(
    margin: EdgeInsets.zero,
    elevation: 0,
    color: const Color(0xFFF5F7FA),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: const BorderSide(color: Color(0xFFE1E7EF)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF182A43),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          for (final field in fields) _detailRow(field.$1, field.$2),
        ],
      ),
    ),
  );

  Widget _detailRow(String label, String rawValue) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 170,
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFF637188), fontSize: 12),
          ),
        ),
        Expanded(
          child: Text(
            rawValue.isEmpty ? '—' : rawValue,
            style: const TextStyle(
              color: Color(0xFF26364C),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final pages = (_total / _pageSize).ceil().clamp(1, 999999);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Regresar',
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Mermas autorizadas de Taller'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: TextButton.icon(
              onPressed: _selectedIord == null ? null : _showDetail,
              style: TextButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF071428),
                disabledBackgroundColor: Colors.white24,
                disabledForegroundColor: Colors.white60,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('Ver detalle'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: TextButton.icon(
              onPressed: _loading || _exporting || !_hasSearched || _total == 0
                  ? null
                  : _exportExcel,
              style: TextButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF071428),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: _exporting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_outlined),
              label: const Text('Descargar Excel'),
            ),
          ),
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _loading
                ? null
                : _hasSearched
                ? () => _load()
                : () => _refreshFilterOptions(_sucursal),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Container(
        color: const Color(0xFFF1F5F9),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Filtros del panel',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: 180,
                          child: DropdownButtonFormField<String?>(
                            initialValue: _sucursal,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Sucursal',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('Todas'),
                              ),
                              ..._sucursales.map(
                                (s) => DropdownMenuItem<String?>(
                                  value: s.suc,
                                  child: Text(
                                    s.label,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _sucursal = value;
                                _tipo = null;
                                _labor = null;
                                _asign = null;
                                _tipos = const [];
                                _laboratorios = const [];
                                _asignados = const [];
                                _filterOptionsLoaded = false;
                              });
                            },
                          ),
                        ),
                        _filterField(
                          _autorizacionCtrl,
                          'IORD autorización',
                          200,
                        ),
                        _filterField(_originalCtrl, 'IORD original', 200),
                        _filterField(_iordCtrl, 'IORD', 180),
                        _filterField(_folioCtrl, 'IDFOL', 200),
                        _filterField(_clienteCtrl, 'Cliente', 220),
                        _filterDropdown(
                          'Tipo',
                          _tipo,
                          _tipos,
                          (value) => setState(() => _tipo = value),
                        ),
                        _filterDropdown(
                          'Laboratorio',
                          _labor,
                          _laboratorios,
                          (value) => setState(() => _labor = value),
                        ),
                        _filterDropdown(
                          'Asignado',
                          _asign,
                          _asignados,
                          (value) => setState(() => _asign = value),
                        ),
                        _dateField(
                          'Desde',
                          _desde,
                          (value) => setState(() => _desde = value),
                        ),
                        _dateField(
                          'Hasta',
                          _hasta,
                          (value) => setState(() => _hasta = value),
                        ),
                        FilledButton.icon(
                          onPressed: _loading ? null : _applyFilters,
                          icon: const Icon(Icons.search),
                          label: const Text('Aplicar filtros'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _loading ? null : _clearFilters,
                          icon: const Icon(Icons.filter_alt_off_outlined),
                          label: const Text('Limpiar filtros'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _buildPagination(pages),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (_error != null)
              MaterialBanner(
                content: Text(_error!),
                actions: [
                  TextButton(
                    onPressed: () => _load(),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            if (_loading) const LinearProgressIndicator(),
            Expanded(
              child: _items.isEmpty && !_loading
                  ? Center(
                      child: Text(
                        _error == null
                            ? _hasSearched
                                  ? 'No se encontraron mermas autorizadas.'
                                  : 'Pulsa Aplicar filtros para consultar las órdenes.'
                            : 'No se pudo consultar el listado.',
                      ),
                    )
                  : Card(
                      child: SingleChildScrollView(
                        child: Scrollbar(
                          controller: _tableHorizontalScrollCtrl,
                          thumbVisibility: true,
                          interactive: true,
                          scrollbarOrientation: ScrollbarOrientation.bottom,
                          child: SingleChildScrollView(
                            controller: _tableHorizontalScrollCtrl,
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: _resultColumns,
                              rows: _items
                                  .map((row) {
                                    final orderKey = _orderKey(row);
                                    final selected = orderKey == _selectedIord;
                                    return DataRow(
                                      selected: selected,
                                      onSelectChanged: (value) => setState(
                                        () => _selectedIord = value == true
                                            ? orderKey
                                            : null,
                                      ),
                                      cells: [
                                        DataCell(
                                          _tableText(_value(row, 'SUC')),
                                        ),
                                        DataCell(
                                          _tableText(_value(row, 'TIPO')),
                                        ),
                                        DataCell(
                                          _tableText(_value(row, 'MOVIMIENTO')),
                                        ),
                                        DataCell(
                                          _tableText(_value(row, 'OPV')),
                                        ),
                                        DataCell(
                                          _tableText(
                                            _value(row, 'LABORATORIO_DESC'),
                                          ),
                                        ),
                                        DataCell(
                                          _tableText(_value(row, 'IORD')),
                                        ),
                                        DataCell(
                                          _tableText(
                                            '${_value(row, 'CLIEN')} ${_value(row, 'NCLIENTE')}'
                                                .trim(),
                                          ),
                                        ),
                                        DataCell(
                                          _tableText(_value(row, 'ART')),
                                        ),
                                        DataCell(
                                          _tableText(_value(row, 'DESCART')),
                                        ),
                                        DataCell(
                                          _tableText(_value(row, 'CTD_C_M')),
                                        ),
                                        DataCell(
                                          _tableText(_value(row, 'FLUJO')),
                                        ),
                                        DataCell(
                                          _tableText(
                                            _value(row, 'RESPONSABLE_MERMA'),
                                          ),
                                        ),
                                        DataCell(
                                          _tableText(
                                            _value(row, 'MOTIVO_MERMA'),
                                          ),
                                        ),
                                        DataCell(
                                          _tableText(
                                            _value(
                                              row,
                                              'MOTIVO_CAMBIO_MATERIAL',
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          _tableText(_value(row, 'IORD_NUEVA')),
                                        ),
                                        DataCell(
                                          _tableText(_value(row, 'IDFOL')),
                                        ),
                                        DataCell(
                                          _tableText(_value(row, 'ART_NUEVA')),
                                        ),
                                        DataCell(
                                          _tableText(
                                            _value(row, 'DESCART_NUEVA'),
                                          ),
                                        ),
                                        DataCell(
                                          _tableText(_date(row['FCN_AUT_CYM'])),
                                        ),
                                        DataCell(
                                          _tableText(
                                            _value(row, 'PRECIO_COBRADO'),
                                          ),
                                        ),
                                        DataCell(
                                          _tableText(
                                            _value(row, 'COSTO_ARTICULO'),
                                          ),
                                        ),
                                        DataCell(
                                          _tableText(
                                            _value(row, 'COSTO_SERVICIO'),
                                          ),
                                        ),
                                        DataCell(
                                          _tableText(
                                            _value(row, 'USR_AUT_CYM'),
                                          ),
                                        ),
                                      ],
                                    );
                                  })
                                  .toList(growable: false),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<DataColumn> get _resultColumns {
    const labels = [
      'SUC',
      'Tipo',
      'Movimiento',
      'OPV',
      'Laboratorio',
      'IORD',
      'Cliente',
      'Artículo',
      'Descripción',
      'CTD',
      'Flujo',
      'Asignado',
      'Motivo de Merma',
      'Motivo Cambio de Material',
      'IORD autorización',
      'Folio',
      'Artículo nuevo',
      'Descripción nueva',
      'F. autorización',
      'Precio cobrado',
      'Costo del artículo',
      'Costo del servicio',
      'Autorizó',
    ];
    return List<DataColumn>.generate(
      labels.length,
      (index) => DataColumn(label: Text(labels[index])),
      growable: false,
    );
  }

  Widget _filterField(
    TextEditingController controller,
    String label,
    double width,
  ) => SizedBox(
    width: width,
    child: TextField(
      controller: controller,
      onSubmitted: (_) => _applyFilters(),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
    ),
  );

  Widget _filterDropdown(
    String label,
    String? value,
    List<Map<String, dynamic>> options,
    ValueChanged<String?> onChanged,
  ) => SizedBox(
    width: 190,
    child: DropdownButtonFormField<String?>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('Todos')),
        ...options.map(
          (option) => DropdownMenuItem<String?>(
            value: option['value']?.toString(),
            child: Text(
              option['label']?.toString() ?? '',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
      onChanged: onChanged,
    ),
  );

  List<Map<String, dynamic>> _readOptions(dynamic rawOptions) =>
      (rawOptions as List? ?? const [])
          .whereType<Map>()
          .map((raw) {
            final option = Map<String, dynamic>.from(raw);
            return {
              'value': option['value'] ?? option['id'],
              'label': option['label'] ?? option['lab'] ?? option['name'],
            };
          })
          .where((option) => (option['value'] ?? '').toString().isNotEmpty)
          .toList();

  Widget _dateField(
    String label,
    DateTime? value,
    ValueChanged<DateTime?> onChanged,
  ) {
    final text = value == null ? '' : _apiDate(value);
    return SizedBox(
      width: 150,
      child: InkWell(
        onTap: () async {
          final now = DateTime.now();
          final picked = await showDatePicker(
            context: context,
            initialDate: value ?? now,
            firstDate: DateTime(now.year - 10),
            lastDate: DateTime(now.year + 10),
          );
          if (picked != null) onChanged(picked);
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            isDense: true,
            border: const OutlineInputBorder(),
            suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
          ),
          child: Text(text.isEmpty ? 'Seleccionar' : text),
        ),
      ),
    );
  }

  Widget _buildPagination(int pages) => Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      Text('Total: $_total  |  Página $_page de $pages'),
      IconButton(
        tooltip: 'Anterior',
        onPressed: _loading || _page <= 1 ? null : () => _load(page: _page - 1),
        icon: const Icon(Icons.chevron_left),
      ),
      IconButton(
        tooltip: 'Siguiente',
        onPressed: _loading || _page >= pages
            ? null
            : () => _load(page: _page + 1),
        icon: const Icon(Icons.chevron_right),
      ),
    ],
  );

  String _apiDate(DateTime? value) {
    if (value == null) return '';
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

  String _value(Map<String, dynamic> row, String key) =>
      (row[key] ?? '').toString().trim();

  String _orderKey(Map<String, dynamic> row) =>
      '${_value(row, 'SUC')}|${_value(row, 'IORD')}';

  Widget _tableText(String text) => Text(
    text.isEmpty ? '—' : text,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
  );

  String _date(dynamic value) {
    if (value == null) return '';
    final date = DateTime.tryParse(value.toString());
    if (date == null) return value.toString();
    final local = date.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}
