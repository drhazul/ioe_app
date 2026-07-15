import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../reloj_checador/consultas/download_helper.dart';
import '../../domain/sugeridos_models.dart';
import '../../providers/sugeridos_provider.dart';

class SugeridosPage extends ConsumerStatefulWidget {
  const SugeridosPage({super.key});

  @override
  ConsumerState<SugeridosPage> createState() => _SugeridosPageState();
}

class _SugeridosPageState extends ConsumerState<SugeridosPage> {
  final _marcaCtrl = TextEditingController();
  final _tipoCtrl = TextEditingController();
  final _lineaProductoCtrl = TextEditingController();
  final _categoriaCtrl = TextEditingController();
  String _marca = '';
  String _tipo = '';
  String _lineaProducto = '';
  String _categoria = '';
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
  void dispose() {
    _marcaCtrl.dispose();
    _tipoCtrl.dispose();
    _lineaProductoCtrl.dispose();
    _categoriaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sucsAsync = ref.watch(sugeridosSucursalesProvider);
    final proveedoresAsync = ref.watch(sugeridosProveedoresProvider);
    final calculoFilters = _suc.isEmpty
        ? null
        : SugeridosCalculoFilters(
            suc: _suc,
            prov: _prov,
            marca: _marca,
            tipo: _tipo,
            lineaProducto: _lineaProducto,
            categoria: _categoria,
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
            tooltip: 'Nueva orden de compra',
            onPressed: () => _createOrden(_selectedItems.values.toList()),
            icon: const Icon(Icons.add_circle_outline),
          ),
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
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _FiltersPanel(
            marcaCtrl: _marcaCtrl,
            tipoCtrl: _tipoCtrl,
            lineaProductoCtrl: _lineaProductoCtrl,
            categoriaCtrl: _categoriaCtrl,
            suc: _suc,
            prov: _prov,
            sucsAsync: sucsAsync,
            proveedoresAsync: proveedoresAsync,
            onSucChanged: (value) => setState(() => _suc = value ?? ''),
            onProvChanged: (value) => setState(() => _prov = value),
            onApplyCalculo: _applyCalculo,
            onClear: _clearFilters,
          ),
          const SizedBox(height: 12),
          if (calculoAsync != null)
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
                onClear: () => setState(() {
                  _selectedArts.clear();
                  _selectedItems.clear();
                }),
                onCreate: () => _createOrden(_selectedItems.values.toList()),
                onPageChanged: _changeCalculoPage,
              ),
              loading: () => const _LoadingBand(text: 'Calculando sugerido...'),
              error: (e, _) => _ErrorBand(message: 'No se pudo calcular: $e'),
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
    setState(() {
      _marca = _marcaCtrl.text.trim();
      _tipo = _tipoCtrl.text.trim();
      _lineaProducto = _lineaProductoCtrl.text.trim();
      _categoria = _categoriaCtrl.text.trim();
      _calculoPage = 1;
      _selectedArts.clear();
      _selectedItems.clear();
      _calculoAplicado = true;
    });
  }

  void _clearFilters() {
    setState(() {
      _marcaCtrl.clear();
      _tipoCtrl.clear();
      _lineaProductoCtrl.clear();
      _categoriaCtrl.clear();
      _marca = '';
      _tipo = '';
      _lineaProducto = '';
      _categoria = '';
      _suc = '';
      _prov = null;
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
              marca: filters.marca,
              tipo: filters.tipo,
              lineaProducto: filters.lineaProducto,
              categoria: filters.categoria,
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
      _openDetalle(created.nped);
    } catch (e) {
      _snack('No se pudo crear la O.C.: $e');
    }
  }

  Future<void> _openDetalle(String nped) async {
    try {
      final doc = await ref.read(sugeridosApiProvider).fetchOne(nped);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => _DetalleDialog(doc: doc),
      );
    } catch (e) {
      _snack('No se pudo abrir el detalle: $e');
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
    required this.marcaCtrl,
    required this.tipoCtrl,
    required this.lineaProductoCtrl,
    required this.categoriaCtrl,
    required this.suc,
    required this.prov,
    required this.sucsAsync,
    required this.proveedoresAsync,
    required this.onSucChanged,
    required this.onProvChanged,
    required this.onApplyCalculo,
    required this.onClear,
  });

  final TextEditingController marcaCtrl;
  final TextEditingController tipoCtrl;
  final TextEditingController lineaProductoCtrl;
  final TextEditingController categoriaCtrl;
  final String suc;
  final int? prov;
  final AsyncValue<List<String>> sucsAsync;
  final AsyncValue<List<SugeridoProveedorModel>> proveedoresAsync;
  final ValueChanged<String?> onSucChanged;
  final ValueChanged<int?> onProvChanged;
  final VoidCallback onApplyCalculo;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 160,
              child: sucsAsync.when(
                data: (items) {
                  final sucs = _sucursalesPermitidas(items);
                  return DropdownButtonFormField<String>(
                    initialValue: suc.isEmpty || !sucs.contains(suc)
                        ? null
                        : suc,
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
            SizedBox(
              width: 290,
              child: proveedoresAsync.when(
                data: (items) => DropdownButtonFormField<int>(
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
                    ...items.map(
                      (p) =>
                          DropdownMenuItem(value: p.id, child: Text(p.label)),
                    ),
                  ],
                  onChanged: onProvChanged,
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Proveedores: $e'),
              ),
            ),
            SizedBox(
              width: 180,
              child: TextField(
                controller: lineaProductoCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Linea de producto',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            SizedBox(
              width: 160,
              child: TextField(
                controller: categoriaCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Categoria',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            SizedBox(
              width: 190,
              child: TextField(
                controller: marcaCtrl,
                decoration: const InputDecoration(
                  labelText: 'Marca',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            SizedBox(
              width: 150,
              child: TextField(
                controller: tipoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tipo de producto',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: onApplyCalculo,
              icon: const Icon(Icons.calculate),
              label: const Text('Calcular'),
            ),
            OutlinedButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.cleaning_services),
              label: const Text('Limpiar'),
            ),
          ],
        ),
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
              child: Text(_num(item.sug)),
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

class _DetalleDialog extends StatelessWidget {
  const _DetalleDialog({required this.doc});

  final SugeridoOrdenModel doc;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('O.C. ${doc.nped}'),
      content: SizedBox(
        width: 900,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  Text('Sucursal: ${doc.suc}'),
                  Text('Proveedor: ${doc.alias ?? doc.nprov}'),
                  Text('Estatus: ${doc.estatus}'),
                  Text('Importe: ${_money(doc.impp)}'),
                ],
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Pos')),
                    DataColumn(label: Text('Articulo')),
                    DataColumn(label: Text('Descripcion')),
                    DataColumn(label: Text('Cantidad'), numeric: true),
                    DataColumn(label: Text('Costo'), numeric: true),
                    DataColumn(label: Text('Total'), numeric: true),
                  ],
                  rows: [
                    for (final item in doc.detalle.where((d) => d.bloq != -1))
                      DataRow(
                        cells: [
                          DataCell(Text('${item.pos}')),
                          DataCell(Text(item.art)),
                          DataCell(
                            SizedBox(width: 280, child: Text(item.des ?? '')),
                          ),
                          DataCell(Text(_num(item.ctdped))),
                          DataCell(Text(_money(item.cto))),
                          DataCell(Text(_money(item.ctot))),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton.icon(
          onPressed: doc.detalle.isEmpty ? null : () => _exportCsv(context),
          icon: const Icon(Icons.table_view),
          label: const Text('Excel CSV'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }

  Future<void> _exportCsv(BuildContext context) async {
    final rows = <List<String>>[
      ['NPED', 'POS', 'ART', 'DES', 'CTDPED', 'UNCOM', 'CTO', 'TOTAL'],
      for (final item in doc.detalle.where((d) => d.bloq != -1))
        [
          doc.nped,
          '${item.pos}',
          item.art,
          item.des ?? '',
          _num(item.ctdped),
          item.uncom,
          _num(item.cto),
          _num(item.ctot),
        ],
    ];
    final csv = rows.map((row) => row.map(_csvCell).join(',')).join('\r\n');
    await saveBytesFile(
      Uint8List.fromList(utf8.encode(csv)),
      'OC_${doc.nped}.csv',
      'text/csv;charset=utf-8',
    );
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Archivo CSV generado.')));
    }
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

String _csvCell(String value) {
  final escaped = value.replaceAll('"', '""');
  return '"$escaped"';
}

String _num(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(2);
}

String _money(double value) => '\$${value.toStringAsFixed(2)}';
