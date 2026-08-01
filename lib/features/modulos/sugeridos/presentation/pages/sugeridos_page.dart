import 'dart:typed_data';

import 'package:excel/excel.dart' as xls;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../reloj_checador/consultas/download_helper.dart';
import '../../../punto_venta/cotizaciones/detalle_cot/jrq_models.dart';
import '../../domain/sugeridos_models.dart';
import '../../providers/sugeridos_provider.dart';
import '../widgets/orden_compra_detalle_dialog.dart';

class SugeridosPage extends ConsumerStatefulWidget {
  const SugeridosPage({super.key, this.initialSuc = '', this.initialProv});

  final String initialSuc;
  final int? initialProv;

  @override
  ConsumerState<SugeridosPage> createState() => _SugeridosPageState();
}

class _SugeridosPageState extends ConsumerState<SugeridosPage> {
  List<double> _depa = const [];
  List<double> _subd = const [];
  List<double> _clas = const [];
  List<double> _scla = const [];
  List<double> _scla2 = const [];
  String _suc = '';
  int? _prov;
  int _calculoPage = 1;
  static const int _calculoLimit = 100;
  static const int _selectAllBatchLimit = 500;
  bool _calculoAplicado = false;
  bool _selectingAll = false;
  final Set<String> _selectedArts = {};
  final Map<String, SugeridoCalculoModel> _selectedItems = {};

  @override
  void initState() {
    super.initState();
    _suc = widget.initialSuc.trim().toUpperCase();
    final initialProv = widget.initialProv;
    if (initialProv != null && initialProv > 0) {
      _prov = initialProv;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sucsAsync = ref.watch(sugeridosSucursalesProvider);
    final proveedoresAsync = ref.watch(sugeridosProveedoresProvider);
    final depaAsync = ref.watch(sugeridosJrqDepaProvider);
    final subdAsync = ref.watch(
      sugeridosJrqSubdProvider(sugeridosNumberKey(_depa)),
    );
    final clasAsync = ref.watch(
      sugeridosJrqClasProvider(sugeridosNumberKey(_subd)),
    );
    final sclaAsync = ref.watch(
      sugeridosJrqSclaProvider(sugeridosNumberKey(_clas)),
    );
    final scla2Async = ref.watch(
      sugeridosJrqScla2Provider(sugeridosNumberKey(_scla)),
    );
    final calculoFilters = _suc.isEmpty
        ? null
        : SugeridosCalculoFilters(
            suc: _suc,
            prov: _prov,
            depa: _depa,
            subd: _subd,
            clas: _clas,
            scla: _scla,
            scla2: _scla2,
            page: _calculoPage,
            limit: _calculoLimit,
          );
    final calculoAsync = _calculoAplicado && calculoFilters != null
        ? ref.watch(sugeridosCalculoProvider(calculoFilters))
        : null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Planeacion y sugeridos de compra'),
        actions: [
          IconButton(
            tooltip: 'Refrescar',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (calculoFilters != null) {
                ref.invalidate(sugeridosCalculoProvider(calculoFilters));
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: _FiltersPanel(
              suc: _suc,
              prov: _prov,
              depa: _depa,
              subd: _subd,
              clas: _clas,
              scla: _scla,
              scla2: _scla2,
              sucsAsync: sucsAsync,
              proveedoresAsync: proveedoresAsync,
              depaAsync: depaAsync,
              subdAsync: subdAsync,
              clasAsync: clasAsync,
              sclaAsync: sclaAsync,
              scla2Async: scla2Async,
              onSucChanged: (value) => setState(() => _suc = value ?? ''),
              onProvChanged: (value) => setState(() => _prov = value),
              onDepaChanged: (value) {
                setState(() {
                  _depa = value;
                  _subd = const [];
                  _clas = const [];
                  _scla = const [];
                  _scla2 = const [];
                });
              },
              onSubdChanged: (value) {
                setState(() {
                  _subd = value;
                  _clas = const [];
                  _scla = const [];
                  _scla2 = const [];
                });
              },
              onClasChanged: (value) {
                setState(() {
                  _clas = value;
                  _scla = const [];
                  _scla2 = const [];
                });
              },
              onSclaChanged: (value) {
                setState(() {
                  _scla = value;
                  _scla2 = const [];
                });
              },
              onScla2Changed: (value) => setState(() => _scla2 = value),
              onApplyCalculo: _applyCalculo,
              onClear: _clearFilters,
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: calculoAsync == null
                ? const Center(
                    child: Text('Seleccione filtros y presione Calcular.'),
                  )
                : ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      calculoAsync.when(
                        data: (result) => _CalculoSection(
                          items: result.items,
                          totalItems: result.total,
                          page: result.page,
                          limit: result.limit,
                          selectedArts: _selectedArts,
                          onToggle: (item, selected) {
                            setState(() {
                              if (selected) {
                                _selectedArts.add(item.art);
                                _selectedItems[item.art] = item;
                              } else {
                                _selectedArts.remove(item.art);
                                _selectedItems.remove(item.art);
                              }
                            });
                          },
                          selectingAll: _selectingAll,
                          onSelectAll: () => _selectAllCalculo(calculoFilters),
                          onExport: () => _exportCalculo(calculoFilters),
                          onClear: () => setState(() {
                            _selectedArts.clear();
                            _selectedItems.clear();
                          }),
                          onCreate: () =>
                              _createOrden(_selectedItems.values.toList()),
                          onPageChanged: _changeCalculoPage,
                        ),
                        loading: () =>
                            const _LoadingBand(text: 'Calculando sugerido...'),
                        error: (e, _) =>
                            _ErrorBand(message: 'No se pudo calcular: $e'),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  void _applyCalculo() {
    if (_suc.trim().isEmpty) {
      _snack('Selecciona una sucursal para calcular sugeridos.');
      return;
    }
    if (_prov == null || _prov! <= 0) {
      _snack('Selecciona un proveedor para calcular sugeridos.');
      return;
    }
    setState(() {
      _calculoPage = 1;
      _selectedArts.clear();
      _selectedItems.clear();
      _calculoAplicado = true;
    });
  }

  void _clearFilters() {
    setState(() {
      _suc = '';
      _prov = null;
      _depa = const [];
      _subd = const [];
      _clas = const [];
      _scla = const [];
      _scla2 = const [];
      _calculoPage = 1;
      _calculoAplicado = false;
      _selectedArts.clear();
      _selectedItems.clear();
    });
  }

  void _changeCalculoPage(int page) {
    if (page < 1 || page == _calculoPage) return;
    setState(() {
      _calculoPage = page;
    });
  }

  Future<void> _selectAllCalculo(SugeridosCalculoFilters? filters) async {
    if (filters == null || _selectingAll) return;
    setState(() => _selectingAll = true);
    try {
      var page = 1;
      var total = 0;
      var loaded = 0;
      final selectedItems = <String, SugeridoCalculoModel>{};

      do {
        final result = await ref
            .read(sugeridosApiProvider)
            .calcular(
              suc: filters.suc,
              prov: filters.prov,
              depa: filters.depa,
              subd: filters.subd,
              clas: filters.clas,
              scla: filters.scla,
              scla2: filters.scla2,
              dias: filters.dias,
              page: page,
              limit: _selectAllBatchLimit,
            );
        total = result.total;
        loaded += result.items.length;
        for (final item in result.items) {
          selectedItems[item.art] = item;
        }
        page += 1;
        if (result.items.isEmpty) break;
      } while (loaded < total);

      if (!mounted) return;
      setState(() {
        _selectedArts
          ..clear()
          ..addAll(selectedItems.keys);
        _selectedItems
          ..clear()
          ..addAll(selectedItems);
      });
      _snack('Seleccionados ${selectedItems.length} articulos.');
    } catch (e) {
      if (mounted) _snack('No se pudo seleccionar todo: $e');
    } finally {
      if (mounted) setState(() => _selectingAll = false);
    }
  }

  Future<void> _exportCalculo(SugeridosCalculoFilters? filters) async {
    if (filters == null) return;
    try {
      var page = 1;
      var total = 0;
      var loaded = 0;
      final rows = <SugeridoCalculoModel>[];
      do {
        final result = await ref
            .read(sugeridosApiProvider)
            .calcular(
              suc: filters.suc,
              prov: filters.prov,
              depa: filters.depa,
              subd: filters.subd,
              clas: filters.clas,
              scla: filters.scla,
              scla2: filters.scla2,
              dias: filters.dias,
              page: page,
              limit: _selectAllBatchLimit,
            );
        total = result.total;
        loaded += result.items.length;
        rows.addAll(result.items);
        page += 1;
        if (result.items.isEmpty) break;
      } while (loaded < total);
      if (rows.isEmpty) {
        _snack('No hay resultados para exportar.');
        return;
      }
      final excel = xls.Excel.createExcel();
      final sheet = excel['SUGERIDOS'];
      sheet.appendRow(
        _resultColumns
            .skip(1)
            .map((column) => _excelValue(column.label))
            .toList(growable: false),
      );
      for (var i = 0; i < rows.length; i += 1) {
        final item = rows[i];
        final row = i + 2;
        sheet.appendRow(
          [
            item.jerarquiaLarga,
            item.art,
            item.upc ?? '',
            item.des,
            item.base,
            item.sph,
            item.cyl,
            item.adic,
            item.stock,
            item.stockMin,
            item.estatus,
            item.diaReabasto,
            item.vta90,
            _excelFormula('IFERROR(M$row/90,0)'),
            _excelFormula('IFERROR(I$row/N$row,0)'),
            _excelFormula('L$row-O$row'),
            item.factComp,
            item.suc,
            item.tipo ?? '',
            _excelFormula(
              'IFERROR(IF(P$row<=0,0,ROUND((N$row*P$row)/Q$row,0)),0)',
            ),
            _excelFormula('IFERROR(ROUNDUP(J$row-I$row,0)/Q$row,0)'),
            item.unComp,
            _excelFormula('MAX(T$row,MAX(0,U$row))'),
          ].map(_excelValue).toList(growable: false),
        );
      }
      if (excel.tables.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }
      excel.setDefaultSheet('SUGERIDOS');
      final encoded = excel.encode();
      if (encoded == null || encoded.isEmpty) {
        _snack('No se pudo generar el archivo Excel.');
        return;
      }
      await saveBytesFile(
        Uint8List.fromList(encoded),
        'Sugeridos_${filters.suc}_${DateTime.now().millisecondsSinceEpoch}.xlsx',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      if (mounted) _snack('Excel generado con ${rows.length} articulos.');
    } catch (e) {
      if (mounted) _snack('No se pudo exportar: $e');
    }
  }

  Future<void> _createOrden(List<SugeridoCalculoModel> items) async {
    final selected = items
        .where((item) => item.cantFinalCompra > 0 || item.ped > 0)
        .toList();
    if (selected.isEmpty) {
      _snack('Selecciona al menos un articulo sugerido.');
      return;
    }
    final providerIds = selected.map((item) => item.nprov).toSet();
    if (providerIds.length != 1) {
      _snack('La orden debe consolidarse con un solo proveedor.');
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Crear orden de compra'),
        content: Text('Se creara una O.C. con ${selected.length} articulos.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      final created = await ref
          .read(sugeridosApiProvider)
          .create(suc: _suc, nprov: providerIds.first, items: selected);
      if (!mounted) return;
      _snack('O.C. ${created.nped} creada.');
      setState(() {
        _selectedArts.clear();
        _selectedItems.clear();
      });
      await showDialog<SugeridoOrdenModel>(
        context: context,
        builder: (context) => OrdenCompraDetalleDialog(doc: created),
      );
    } catch (e) {
      _snack('No se pudo crear la O.C.: $e');
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _FiltersPanel extends StatelessWidget {
  const _FiltersPanel({
    required this.suc,
    required this.prov,
    required this.depa,
    required this.subd,
    required this.clas,
    required this.scla,
    required this.scla2,
    required this.sucsAsync,
    required this.proveedoresAsync,
    required this.depaAsync,
    required this.subdAsync,
    required this.clasAsync,
    required this.sclaAsync,
    required this.scla2Async,
    required this.onSucChanged,
    required this.onProvChanged,
    required this.onDepaChanged,
    required this.onSubdChanged,
    required this.onClasChanged,
    required this.onSclaChanged,
    required this.onScla2Changed,
    required this.onApplyCalculo,
    required this.onClear,
  });

  final String suc;
  final int? prov;
  final List<double> depa;
  final List<double> subd;
  final List<double> clas;
  final List<double> scla;
  final List<double> scla2;
  final AsyncValue<List<String>> sucsAsync;
  final AsyncValue<List<SugeridoProveedorModel>> proveedoresAsync;
  final AsyncValue<List<JrqDepaModel>> depaAsync;
  final AsyncValue<List<JrqSubdModel>> subdAsync;
  final AsyncValue<List<JrqClasModel>> clasAsync;
  final AsyncValue<List<JrqSclaModel>> sclaAsync;
  final AsyncValue<List<JrqScla2Model>> scla2Async;
  final ValueChanged<String?> onSucChanged;
  final ValueChanged<int?> onProvChanged;
  final ValueChanged<List<double>> onDepaChanged;
  final ValueChanged<List<double>> onSubdChanged;
  final ValueChanged<List<double>> onClasChanged;
  final ValueChanged<List<double>> onSclaChanged;
  final ValueChanged<List<double>> onScla2Changed;
  final VoidCallback onApplyCalculo;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 160,
            child: sucsAsync.when(
              data: (items) {
                final sucs = _sucursalesPermitidas(items);
                return DropdownButtonFormField<String>(
                  initialValue: suc.isEmpty || !sucs.contains(suc) ? null : suc,
                  decoration: const InputDecoration(
                    labelText: 'Sucursal',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: sucs
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: onSucChanged,
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Sucursales: $e'),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 290,
            child: proveedoresAsync.when(
              data: (items) {
                final ordered = [...items]
                  ..sort((a, b) => a.id.compareTo(b.id));
                return DropdownButtonFormField<int>(
                  initialValue: prov,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Proveedor',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<int>(
                      value: null,
                      child: Text('Todos'),
                    ),
                    ...ordered.map(
                      (p) =>
                          DropdownMenuItem(value: p.id, child: Text(p.label)),
                    ),
                  ],
                  onChanged: onProvChanged,
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Proveedores: $e'),
            ),
          ),
          const SizedBox(width: 8),
          _JrqMultiFilter<JrqDepaModel>(
            label: 'DEPA',
            asyncItems: depaAsync,
            selected: depa,
            enabled: true,
            itemValue: (item) => item.depa,
            itemLabel: (item) => _formatJrqOption(item.depa, item.ddepa),
            onChanged: onDepaChanged,
          ),
          const SizedBox(width: 8),
          _JrqMultiFilter<JrqSubdModel>(
            label: 'SUBD',
            asyncItems: subdAsync,
            selected: subd,
            enabled: true,
            itemValue: (item) => item.subd,
            itemLabel: (item) => _formatJrqOption(item.subd, item.dsubd),
            onChanged: onSubdChanged,
          ),
          const SizedBox(width: 8),
          _JrqMultiFilter<JrqClasModel>(
            label: 'CLAS',
            asyncItems: clasAsync,
            selected: clas,
            enabled: true,
            itemValue: (item) => item.clas,
            itemLabel: (item) => _formatJrqOption(item.clas, item.dclas),
            onChanged: onClasChanged,
          ),
          const SizedBox(width: 8),
          _JrqMultiFilter<JrqSclaModel>(
            label: 'SCLA',
            asyncItems: sclaAsync,
            selected: scla,
            enabled: true,
            itemValue: (item) => item.scla,
            itemLabel: (item) => _formatJrqOption(item.scla, item.dscla),
            onChanged: onSclaChanged,
          ),
          const SizedBox(width: 8),
          _JrqMultiFilter<JrqScla2Model>(
            label: 'SCLA2',
            asyncItems: scla2Async,
            selected: scla2,
            enabled: true,
            itemValue: (item) => item.scla2,
            itemLabel: (item) => _formatJrqOption(item.scla2, item.dscla2),
            onChanged: onScla2Changed,
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: onApplyCalculo,
            icon: const Icon(Icons.calculate),
            label: const Text('Calcular'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.cleaning_services),
            label: const Text('Limpiar'),
          ),
        ],
      ),
    );
  }
}

List<String> _sucursalesPermitidas(List<String> items) {
  const requeridas = {'DF01', 'DF04', 'DF05', 'DF06'};
  final sucs = <String>{
    ...items.map((s) => s.trim().toUpperCase()).where((s) => s.isNotEmpty),
    ...requeridas,
  }.where((s) => requeridas.contains(s)).toList()..sort();
  return sucs;
}

class _JrqMultiFilter<T> extends StatelessWidget {
  const _JrqMultiFilter({
    required this.label,
    required this.asyncItems,
    required this.selected,
    required this.enabled,
    required this.itemValue,
    required this.itemLabel,
    required this.onChanged,
  });

  final String label;
  final AsyncValue<List<T>> asyncItems;
  final List<double> selected;
  final bool enabled;
  final double Function(T) itemValue;
  final String Function(T) itemLabel;
  final ValueChanged<List<double>> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      child: asyncItems.when(
        data: (items) => OutlinedButton(
          onPressed: enabled && items.isNotEmpty
              ? () => _openSelector(context, items)
              : null,
          style: OutlinedButton.styleFrom(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            minimumSize: const Size(120, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          child: Text(
            selected.isEmpty ? label : '$label (${selected.length})',
            overflow: TextOverflow.ellipsis,
          ),
        ),
        loading: () => const LinearProgressIndicator(),
        error: (_, _) => OutlinedButton(
          onPressed: null,
          child: Text('$label Err', overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }

  Future<void> _openSelector(BuildContext context, List<T> items) async {
    final picked = await showDialog<List<double>>(
      context: context,
      builder: (context) => _JrqMultiSelectDialog<T>(
        title: label,
        items: items,
        selected: selected.toSet(),
        itemValue: itemValue,
        itemLabel: itemLabel,
      ),
    );
    if (picked == null) return;
    onChanged(picked);
  }
}

class _JrqMultiSelectDialog<T> extends StatefulWidget {
  const _JrqMultiSelectDialog({
    required this.title,
    required this.items,
    required this.selected,
    required this.itemValue,
    required this.itemLabel,
  });

  final String title;
  final List<T> items;
  final Set<double> selected;
  final double Function(T) itemValue;
  final String Function(T) itemLabel;

  @override
  State<_JrqMultiSelectDialog<T>> createState() =>
      _JrqMultiSelectDialogState<T>();
}

class _JrqMultiSelectDialogState<T> extends State<_JrqMultiSelectDialog<T>> {
  late final Set<double> _selected = {...widget.selected};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        height: 460,
        child: ListView.builder(
          itemCount: widget.items.length,
          itemBuilder: (context, index) {
            final item = widget.items[index];
            final value = widget.itemValue(item);
            return CheckboxListTile(
              dense: true,
              value: _selected.contains(value),
              title: Text(widget.itemLabel(item)),
              onChanged: (checked) {
                setState(() {
                  if (checked == true) {
                    _selected.add(value);
                  } else {
                    _selected.remove(value);
                  }
                });
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, <double>[]),
          child: const Text('Limpiar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final values = _selected.toList()..sort();
            Navigator.pop(context, values);
          },
          child: const Text('Aplicar'),
        ),
      ],
    );
  }
}

String _formatJrqOption(double value, String? description) {
  final code = value % 1 == 0 ? value.toInt().toString() : value.toString();
  final desc = (description ?? '').trim();
  return desc.isEmpty ? code : '$code - $desc';
}

class _CalculoSection extends StatefulWidget {
  const _CalculoSection({
    required this.items,
    required this.totalItems,
    required this.page,
    required this.limit,
    required this.selectedArts,
    required this.selectingAll,
    required this.onToggle,
    required this.onSelectAll,
    required this.onExport,
    required this.onClear,
    required this.onCreate,
    required this.onPageChanged,
  });

  final List<SugeridoCalculoModel> items;
  final int totalItems;
  final int page;
  final int limit;
  final Set<String> selectedArts;
  final bool selectingAll;
  final void Function(SugeridoCalculoModel item, bool selected) onToggle;
  final VoidCallback onSelectAll;
  final VoidCallback onExport;
  final VoidCallback onClear;
  final VoidCallback onCreate;
  final ValueChanged<int> onPageChanged;

  @override
  State<_CalculoSection> createState() => _CalculoSectionState();
}

class _CalculoSectionState extends State<_CalculoSection> {
  final _horizontalCtrl = ScrollController();
  final _verticalCtrl = ScrollController();

  @override
  void didUpdateWidget(covariant _CalculoSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.page != widget.page && _verticalCtrl.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_verticalCtrl.hasClients) _verticalCtrl.jumpTo(0);
      });
    }
  }

  @override
  void dispose() {
    _horizontalCtrl.dispose();
    _verticalCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final selectedArts = widget.selectedArts;
    final total = items.fold<double>(0, (sum, item) => sum + item.importe);
    final totalPages = widget.totalItems <= 0
        ? 1
        : ((widget.totalItems + widget.limit - 1) ~/ widget.limit);
    final from = widget.totalItems == 0
        ? 0
        : ((widget.page - 1) * widget.limit) + 1;
    final to = ((widget.page - 1) * widget.limit + items.length).clamp(
      0,
      widget.totalItems,
    );
    final tableHeight = (MediaQuery.sizeOf(context).height - 270).clamp(
      320.0,
      680.0,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Sugeridos $from-$to de ${widget.totalItems}  Importe: ${_money(total)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                _PageIconButton(
                  tooltip: 'Primera pagina',
                  icon: Icons.first_page,
                  enabled: widget.page > 1,
                  onPressed: () => widget.onPageChanged(1),
                ),
                _PageIconButton(
                  tooltip: 'Pagina anterior',
                  icon: Icons.chevron_left,
                  enabled: widget.page > 1,
                  onPressed: () => widget.onPageChanged(widget.page - 1),
                ),
                Text('Pagina ${widget.page} de $totalPages'),
                _PageIconButton(
                  tooltip: 'Pagina siguiente',
                  icon: Icons.chevron_right,
                  enabled: widget.page < totalPages,
                  onPressed: () => widget.onPageChanged(widget.page + 1),
                ),
                _PageIconButton(
                  tooltip: 'Ultima pagina',
                  icon: Icons.last_page,
                  enabled: widget.page < totalPages,
                  onPressed: () => widget.onPageChanged(totalPages),
                ),
                OutlinedButton.icon(
                  onPressed: items.isEmpty || widget.selectingAll
                      ? null
                      : widget.onSelectAll,
                  icon: widget.selectingAll
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.select_all),
                  label: Text(
                    widget.selectingAll ? 'Seleccionando...' : 'Seleccionar',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: selectedArts.isEmpty ? null : widget.onClear,
                  icon: const Icon(Icons.deselect),
                  label: const Text('Limpiar'),
                ),
                FilledButton.icon(
                  onPressed: selectedArts.isEmpty ? null : widget.onCreate,
                  icon: const Icon(Icons.playlist_add_check),
                  label: Text('Crear O.C. (${selectedArts.length})'),
                ),
                OutlinedButton.icon(
                  onPressed: items.isEmpty ? null : widget.onExport,
                  icon: const Icon(Icons.table_view),
                  label: const Text('Descargar Excel'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Sin articulos sugeridos para los filtros.'),
              )
            else
              SizedBox(
                height: tableHeight,
                child: Scrollbar(
                  controller: _horizontalCtrl,
                  thumbVisibility: true,
                  trackVisibility: true,
                  interactive: true,
                  notificationPredicate: (notification) =>
                      notification.metrics.axis == Axis.horizontal,
                  child: SingleChildScrollView(
                    controller: _horizontalCtrl,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: _resultTableWidth,
                      child: Column(
                        children: [
                          const _ResultHeader(),
                          Expanded(
                            child: Scrollbar(
                              controller: _verticalCtrl,
                              thumbVisibility: true,
                              trackVisibility: true,
                              interactive: true,
                              child: ListView.builder(
                                controller: _verticalCtrl,
                                itemExtent: 56,
                                itemCount: items.length,
                                itemBuilder: (context, index) {
                                  final item = items[index];
                                  return _ResultRow(
                                    item: item,
                                    selected: selectedArts.contains(item.art),
                                    onToggle: (selected) =>
                                        widget.onToggle(item, selected),
                                  );
                                },
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
      ),
    );
  }
}

class _PageIconButton extends StatelessWidget {
  const _PageIconButton({
    required this.tooltip,
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.outlined(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon),
    );
  }
}

class _ResultColumn {
  const _ResultColumn(this.label, this.width, {this.numeric = false});

  final String label;
  final double width;
  final bool numeric;
}

const _resultColumns = <_ResultColumn>[
  _ResultColumn('Sel', 58),
  _ResultColumn('DESCRIPCION LARGA JERARQUIA', 280),
  _ResultColumn('ART', 105),
  _ResultColumn('UPC', 140),
  _ResultColumn('DES', 300),
  _ResultColumn('BASE', 84),
  _ResultColumn('SPH', 84, numeric: true),
  _ResultColumn('CYL', 84, numeric: true),
  _ResultColumn('ADIC', 84, numeric: true),
  _ResultColumn('STOCK', 96, numeric: true),
  _ResultColumn('STOCK_MIN', 112, numeric: true),
  _ResultColumn('ESTATUS', 118),
  _ResultColumn('DIA_REABASTO', 130, numeric: true),
  _ResultColumn('VTA_3MESES', 120, numeric: true),
  _ResultColumn('FACT_VTA_P_D', 130, numeric: true),
  _ResultColumn('DIAS_INV', 110, numeric: true),
  _ResultColumn('FAC_REAB', 110, numeric: true),
  _ResultColumn('FCTOR DE COMPRA', 145, numeric: true),
  _ResultColumn('SUC', 78),
  _ResultColumn('TIPO', 104),
  _ResultColumn('SUG', 92, numeric: true),
  _ResultColumn('PEDIDO', 96, numeric: true),
  _ResultColumn('Un de compra', 120),
  _ResultColumn('Cant Final Compra', 190, numeric: true),
];

const double _resultScrollGutter = 36;

final double _resultTableWidth = _resultColumns.fold<double>(
  _resultScrollGutter,
  (sum, column) => sum + column.width,
);

class _ResultHeader extends StatelessWidget {
  const _ResultHeader();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: [
          for (final column in _resultColumns)
            _ResultCell(
              width: column.width,
              numeric: column.numeric,
              child: Text(
                column.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          const SizedBox(width: _resultScrollGutter),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.item,
    required this.selected,
    required this.onToggle,
  });

  final SugeridoCalculoModel item;
  final bool selected;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => onToggle(!selected),
      child: Container(
        height: 56,
        color: selected
            ? scheme.primaryContainer.withValues(alpha: 0.35)
            : Colors.transparent,
        foregroundDecoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
        ),
        child: Row(
          children: [
            _ResultCell(
              width: _resultColumns[0].width,
              child: Checkbox(
                value: selected,
                onChanged: (value) => onToggle(value ?? false),
              ),
            ),
            _ResultCell(
              width: _resultColumns[1].width,
              child: Text(item.jerarquiaLarga),
            ),
            _ResultCell(width: _resultColumns[2].width, child: Text(item.art)),
            _ResultCell(
              width: _resultColumns[3].width,
              child: Text(item.upc ?? ''),
            ),
            _ResultCell(width: _resultColumns[4].width, child: Text(item.des)),
            _ResultCell(width: _resultColumns[5].width, child: Text(item.base)),
            _ResultCell(
              width: _resultColumns[6].width,
              numeric: true,
              child: Text(_num(item.sph)),
            ),
            _ResultCell(
              width: _resultColumns[7].width,
              numeric: true,
              child: Text(_num(item.cyl)),
            ),
            _ResultCell(
              width: _resultColumns[8].width,
              numeric: true,
              child: Text(_num(item.adic)),
            ),
            _ResultCell(
              width: _resultColumns[9].width,
              numeric: true,
              child: Text(_num(item.stock)),
            ),
            _ResultCell(
              width: _resultColumns[10].width,
              numeric: true,
              child: Text(_num(item.stockMin)),
            ),
            _ResultCell(
              width: _resultColumns[11].width,
              child: Text(item.estatus),
            ),
            _ResultCell(
              width: _resultColumns[12].width,
              numeric: true,
              child: Text(_num(item.diaReabasto)),
            ),
            _ResultCell(
              width: _resultColumns[13].width,
              numeric: true,
              child: Text(_num(item.vta90)),
            ),
            _ResultCell(
              width: _resultColumns[14].width,
              numeric: true,
              child: Text(_num(item.factVtaPD)),
            ),
            _ResultCell(
              width: _resultColumns[15].width,
              numeric: true,
              child: Text(_num(item.diasInv)),
            ),
            _ResultCell(
              width: _resultColumns[16].width,
              numeric: true,
              child: Text(_num(item.facReab)),
            ),
            _ResultCell(
              width: _resultColumns[17].width,
              numeric: true,
              child: Text(_num(item.factComp)),
            ),
            _ResultCell(width: _resultColumns[18].width, child: Text(item.suc)),
            _ResultCell(
              width: _resultColumns[19].width,
              child: Text(item.tipo ?? ''),
            ),
            _ResultCell(
              width: _resultColumns[20].width,
              numeric: true,
              child: Text('${item.sug.round()}'),
            ),
            _ResultCell(
              width: _resultColumns[21].width,
              numeric: true,
              child: Text(_num(item.pedido)),
            ),
            _ResultCell(
              width: _resultColumns[22].width,
              child: Text(item.unComp),
            ),
            _ResultCell(
              width: _resultColumns[23].width,
              numeric: true,
              child: Text(_num(item.cantFinalCompra)),
            ),
            const SizedBox(width: _resultScrollGutter),
          ],
        ),
      ),
    );
  }
}

class _ResultCell extends StatelessWidget {
  const _ResultCell({
    required this.width,
    required this.child,
    this.numeric = false,
  });

  final double width;
  final Widget child;
  final bool numeric;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Align(
          alignment: numeric ? Alignment.centerRight : Alignment.centerLeft,
          child: DefaultTextStyle.merge(
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            child: child,
          ),
        ),
      ),
    );
  }
}

class _LoadingBand extends StatelessWidget {
  const _LoadingBand({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(text),
        ],
      ),
    ),
  );
}

class _ErrorBand extends StatelessWidget {
  const _ErrorBand({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Text(message, style: TextStyle(color: Colors.red.shade700)),
    ),
  );
}

String _num(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(2);
}

String _money(double value) => '\$${value.toStringAsFixed(2)}';

xls.CellValue _excelValue(dynamic value) {
  if (value == null) return xls.TextCellValue('');
  if (value is xls.CellValue) return value;
  if (value is int) return xls.IntCellValue(value);
  if (value is double) return xls.DoubleCellValue(value);
  if (value is num) return xls.DoubleCellValue(value.toDouble());
  if (value is bool) return xls.BoolCellValue(value);
  return xls.TextCellValue(value.toString());
}

xls.FormulaCellValue _excelFormula(String formula) {
  return xls.FormulaCellValue(formula);
}
