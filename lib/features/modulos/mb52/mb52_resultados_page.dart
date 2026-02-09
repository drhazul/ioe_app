import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ioe_app/core/api_error.dart';
import 'package:ioe_app/core/csv_exporter.dart';

import 'mb52_models.dart';
import 'mb52_providers.dart';

class Mb52ResultadosPage extends ConsumerStatefulWidget {
  const Mb52ResultadosPage({super.key, this.filtros});

  final Mb52Filtros? filtros;

  @override
  ConsumerState<Mb52ResultadosPage> createState() => _Mb52ResultadosPageState();
}

class _Mb52ResultadosPageState extends ConsumerState<Mb52ResultadosPage> {
  final _searchCtrl = TextEditingController();
  final _verticalCtrl = ScrollController();
  final _horizontalCtrl = ScrollController();
  Timer? _debounce;
  String _searchTerm = '';
  int _sortColumnIndex = 0;
  bool _sortAscending = true;
  bool _exporting = false;

  static const double _rowHeight = 32;
  static const double _headerHeight = _rowHeight;
  static const double _cellHPadding = 8;
  static const double _cellVPadding = 6;
  static const List<_Mb52Column> _columns = [
    _Mb52Column(key: 'suc', label: 'SUC', minWidth: 80, maxWidth: 120),
    _Mb52Column(key: 'art', label: 'ART', minWidth: 80, maxWidth: 140),
    _Mb52Column(key: 'des', label: 'DES', minWidth: 160, maxWidth: 280),
    _Mb52Column(key: 'almacen', label: 'ALMACEN', minWidth: 90, maxWidth: 140),
    _Mb52Column(key: 'stock_total_ctda', label: 'STOCK_TOTAL', minWidth: 120, maxWidth: 160, align: TextAlign.right),
    _Mb52Column(key: 'costo_total_ctot', label: 'COSTO_TOTAL', minWidth: 120, maxWidth: 160, align: TextAlign.right),
  ];

  static const Duration _debounceDuration = Duration(milliseconds: 350);

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _verticalCtrl.dispose();
    _horizontalCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, () {
      if (!mounted) return;
      setState(() => _searchTerm = value.trim());
    });
  }

  void _setSort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
    });
  }

  Future<void> _exportCsv(List<DatMb52ResumenModel> rows) async {
    if (_exporting) return;
    if (rows.isEmpty) {
      _showSnack('Sin resultados para exportar.');
      return;
    }

    setState(() => _exporting = true);
    try {
      final headers = [
        'SUC',
        'ART',
        'DES',
        'ALMACEN',
        'STOCK_TOTAL_CTDA',
        'COSTO_TOTAL_CTOT',
      ];

      final lines = <String>[];
      lines.add(headers.map(_csvEscape).join(','));

      for (final row in rows) {
        final values = [
          row.suc ?? '',
          row.art ?? '',
          row.des ?? '',
          row.almacen ?? '',
          _fmtNumberCsv(row.stockTotalCtda, decimals: 2),
          _fmtNumberCsv(row.costoTotalCtot, decimals: 2),
        ];
        lines.add(values.map(_csvEscape).join(','));
      }

      final csv = lines.join('\r\n');
      final bytes = Uint8List.fromList(utf8.encode(csv));
      final filename = 'MB52_${_fmtFileDate(DateTime.now())}.csv';

      final saved = await getCsvExporter().save(bytes, filename);
      if (!saved) {
        _showSnack('Exportación cancelada.');
      } else {
        _showSnack('CSV generado: $filename');
      }
    } catch (e) {
      _showSnack('No se pudo exportar: ${apiErrorMessage(e)}');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final Mb52Filtros filtros = widget.filtros ?? ref.watch(mb52FiltrosProvider);
    final resultsAsync = ref.watch(mb52ResumenProvider(filtros));

    List<DatMb52ResumenModel> exportRows = const [];
    Widget body;

    if (resultsAsync.isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (resultsAsync.hasError) {
      body = Center(child: Text('Error: ${apiErrorMessage(resultsAsync.error!)}'));
    } else {
      final items = resultsAsync.value ?? const <DatMb52ResumenModel>[];
      final filtered = _applyQuickFilter(items, _searchTerm);
      exportRows = filtered;
      final sorted = _applySort(filtered);
      final groups = _groupBySucArt(sorted);
      final totals = _sumTotals(sorted);
      final rowItems = _buildRowItems(groups, totals);
      final layout = _calcColumnLayout(sorted, groups);

      body = Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: _onSearchChanged,
                        decoration: InputDecoration(
                          labelText: 'Búsqueda rápida (SUC / ART / DES / ALMACEN)',
                          border: const OutlineInputBorder(),
                          isDense: true,
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchCtrl.text.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    _onSearchChanged('');
                                  },
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    Text('Registros: ${filtered.length}'),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('Sin resultados'))
                : _buildTable(rowItems, layout),
          ),
        ],
      );
    }

    final canExport = !_exporting && exportRows.isNotEmpty;
    final exportAction = _exporting
        ? const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        : IconButton(
            tooltip: 'Exportar CSV',
            onPressed: canExport ? () => _exportCsv(exportRows) : null,
            icon: const Icon(Icons.download),
          );

    return Scaffold(
      appBar: AppBar(
        title: const Text('MB52 - Resultados'),
        actions: [
          IconButton(
            tooltip: 'Refrescar',
            onPressed: () => ref.invalidate(mb52ResumenProvider(filtros)),
            icon: const Icon(Icons.refresh),
          ),
          exportAction,
        ],
      ),
      body: body,
    );
  }

  _ColumnLayout _calcColumnLayout(List<DatMb52ResumenModel> rows, List<_SucGroup> groups) {
    final maxChars = <String, int>{};
    for (final col in _columns) {
      maxChars[col.key] = col.label.length;
    }

    final sampleSize = min(rows.length, 200);
    for (var i = 0; i < sampleSize; i++) {
      final row = rows[i];
      for (final col in _columns) {
        final text = _valueForColumn(row, col.key);
        final current = maxChars[col.key] ?? col.label.length;
        maxChars[col.key] = max(current, text.length);
      }
    }

    if (maxChars.containsKey('art')) {
      var artMax = maxChars['art'] ?? 0;
      for (final group in groups) {
        for (final artGroup in group.arts) {
          artMax = max(artMax, 'Subtotal ART ${artGroup.art}'.length);
        }
      }
      maxChars['art'] = artMax;
    }
    if (maxChars.containsKey('suc')) {
      var sucMax = maxChars['suc'] ?? 0;
      for (final group in groups) {
        sucMax = max(sucMax, 'Subtotal SUC ${group.suc}'.length);
      }
      sucMax = max(sucMax, 'TOTAL GENERAL'.length);
      maxChars['suc'] = sucMax;
    }

    const charWidth = 7.0;
    final widths = <String, double>{};
    for (final col in _columns) {
      final len = maxChars[col.key] ?? col.label.length;
      var width = (len * charWidth) + (_cellHPadding * 2) + 4;
      width = max(width, col.minWidth);
      width = min(width, col.maxWidth);
      widths[col.key] = width;
    }

    final totalWidth = widths.values.fold<double>(0, (sum, w) => sum + w);
    return _ColumnLayout(widths: widths, totalWidth: totalWidth);
  }

  Widget _buildTable(List<_Mb52RowItem> rows, _ColumnLayout layout) {
    return Scrollbar(
      controller: _horizontalCtrl,
      thumbVisibility: true,
      trackVisibility: true,
      notificationPredicate: (notification) => notification.metrics.axis == Axis.horizontal,
      child: SingleChildScrollView(
        controller: _horizontalCtrl,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: layout.totalWidth,
          child: Scrollbar(
            controller: _verticalCtrl,
            thumbVisibility: true,
            trackVisibility: true,
            notificationPredicate: (notification) => notification.metrics.axis == Axis.vertical,
            child: SelectionArea(
              child: CustomScrollView(
                controller: _verticalCtrl,
                slivers: [
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _Mb52HeaderDelegate(
                      height: _headerHeight,
                      columns: _columns,
                      layout: layout,
                      sortColumnIndex: _sortColumnIndex,
                      sortAscending: _sortAscending,
                      onSort: _setSort,
                      cellHPadding: _cellHPadding,
                      cellVPadding: _cellVPadding,
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildRow(rows[index], layout, index),
                      childCount: rows.length,
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRow(_Mb52RowItem item, _ColumnLayout layout, int index) {
    final color = switch (item.kind) {
      _RowKind.subtotalArt => Colors.amber.shade50,
      _RowKind.subtotalSuc => Colors.amber.shade100,
      _RowKind.total => Colors.amber.shade200,
      _RowKind.data => index.isEven ? Colors.white : Colors.grey.shade50,
    };

    return Container(
      height: _rowHeight,
      decoration: BoxDecoration(
        color: color,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 0.5)),
      ),
      child: Row(
        children: _buildRowCells(item, layout),
      ),
    );
  }

  List<Widget> _buildRowCells(_Mb52RowItem item, _ColumnLayout layout) {
    final cells = <Widget>[];
    for (final col in _columns) {
      var text = '';
      var bold = false;
      var align = col.align;

      if (item.kind == _RowKind.data) {
        text = _valueForColumn(item.data!, col.key);
      } else if (item.kind == _RowKind.subtotalArt) {
        if (col.key == 'art') {
          text = 'Subtotal ART ${item.artGroup!.art}';
          bold = true;
        } else if (col.key == 'stock_total_ctda') {
          text = _fmtNumber(item.artGroup!.stockTotalCtda, decimals: 2);
          bold = true;
          align = TextAlign.right;
        } else if (col.key == 'costo_total_ctot') {
          text = _fmtNumber(item.artGroup!.costoTotalCtot, decimals: 2);
          bold = true;
          align = TextAlign.right;
        }
      } else if (item.kind == _RowKind.subtotalSuc) {
        if (col.key == 'suc') {
          text = 'Subtotal SUC ${item.sucGroup!.suc}';
          bold = true;
        } else if (col.key == 'stock_total_ctda') {
          text = _fmtNumber(item.sucGroup!.stockTotalCtda, decimals: 2);
          bold = true;
          align = TextAlign.right;
        } else if (col.key == 'costo_total_ctot') {
          text = _fmtNumber(item.sucGroup!.costoTotalCtot, decimals: 2);
          bold = true;
          align = TextAlign.right;
        }
      } else {
        if (col.key == 'suc') {
          text = 'TOTAL GENERAL';
          bold = true;
        } else if (col.key == 'stock_total_ctda') {
          text = _fmtNumber(item.totals!.stockTotalCtda, decimals: 2);
          bold = true;
          align = TextAlign.right;
        } else if (col.key == 'costo_total_ctot') {
          text = _fmtNumber(item.totals!.costoTotalCtot, decimals: 2);
          bold = true;
          align = TextAlign.right;
        }
      }

      cells.add(_buildCell(col, layout, text, bold: bold, align: align));
    }
    return cells;
  }

  Widget _buildCell(_Mb52Column column, _ColumnLayout layout, String text,
      {bool bold = false, TextAlign? align}) {
    return SizedBox(
      width: layout.widthFor(column.key),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: _cellHPadding, vertical: _cellVPadding),
        child: Text(
          text,
          overflow: TextOverflow.ellipsis,
          textAlign: align ?? column.align,
          style: bold ? const TextStyle(fontWeight: FontWeight.w600) : null,
        ),
      ),
    );
  }

  String _valueForColumn(DatMb52ResumenModel row, String key) {
    return switch (key) {
      'suc' => row.suc ?? '-',
      'art' => row.art ?? '-',
      'des' => row.des ?? '-',
      'almacen' => row.almacen ?? '-',
      'stock_total_ctda' => _fmtNumber(row.stockTotalCtda, decimals: 2),
      'costo_total_ctot' => _fmtNumber(row.costoTotalCtot, decimals: 2),
      _ => '-',
    };
  }

  List<DatMb52ResumenModel> _applyQuickFilter(List<DatMb52ResumenModel> rows, String term) {
    final q = term.trim().toLowerCase();
    if (q.isEmpty) return rows;
    return rows.where((row) {
      final suc = (row.suc ?? '').toLowerCase();
      final art = (row.art ?? '').toLowerCase();
      final des = (row.des ?? '').toLowerCase();
      final almacen = (row.almacen ?? '').toLowerCase();
      return suc.contains(q) || art.contains(q) || des.contains(q) || almacen.contains(q);
    }).toList();
  }

  List<DatMb52ResumenModel> _applySort(List<DatMb52ResumenModel> rows) {
    final sorted = [...rows];
    sorted.sort((a, b) {
      int result;
      switch (_sortColumnIndex) {
        case 0:
          result = _compareString(a.suc, b.suc);
          break;
        case 1:
          result = _compareString(a.art, b.art);
          break;
        case 2:
          result = _compareString(a.des, b.des);
          break;
        case 3:
          result = _compareString(a.almacen, b.almacen);
          break;
        case 4:
          result = _compareNum(a.stockTotalCtda, b.stockTotalCtda);
          break;
        case 5:
          result = _compareNum(a.costoTotalCtot, b.costoTotalCtot);
          break;
        default:
          result = 0;
      }
      return _sortAscending ? result : -result;
    });
    return sorted;
  }

  List<_SucGroup> _groupBySucArt(List<DatMb52ResumenModel> rows) {
    final map = <String, _SucGroupBuilder>{};
    for (final row in rows) {
      final sucRaw = (row.suc ?? '').trim();
      final artRaw = (row.art ?? '').trim();
      final sucKey = sucRaw.isEmpty ? '(SIN SUC)' : sucRaw;
      final artKey = artRaw.isEmpty ? '(SIN ART)' : artRaw;
      map.putIfAbsent(sucKey, () => _SucGroupBuilder(sucKey)).add(artKey, row);
    }
    return map.values.map((b) => b.build()).toList();
  }

  _Totals _sumTotals(List<DatMb52ResumenModel> rows) {
    double stock = 0;
    double costo = 0;
    for (final row in rows) {
      stock += row.stockTotalCtda ?? 0;
      costo += row.costoTotalCtot ?? 0;
    }
    return _Totals(stockTotalCtda: stock, costoTotalCtot: costo);
  }

  List<_Mb52RowItem> _buildRowItems(List<_SucGroup> groups, _Totals totals) {
    final rows = <_Mb52RowItem>[];
    for (final group in groups) {
      for (final artGroup in group.arts) {
        for (final item in artGroup.items) {
          rows.add(_Mb52RowItem.data(item));
        }
        rows.add(_Mb52RowItem.subtotalArt(artGroup));
      }
      rows.add(_Mb52RowItem.subtotalSuc(group));
    }
    rows.add(_Mb52RowItem.total(totals));
    return rows;
  }

  String _fmtNumber(double? value, {int decimals = 0}) {
    if (value == null) return '-';
    return value.toStringAsFixed(decimals);
  }

  String _fmtNumberCsv(double? value, {int decimals = 0}) {
    if (value == null) return '';
    return value.toStringAsFixed(decimals);
  }

  String _fmtFileDate(DateTime value) {
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }

  String _csvEscape(String value) {
    final needsQuotes = value.contains(',') || value.contains('"') || value.contains('\n') || value.contains('\r');
    if (!needsQuotes) return value;
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  int _compareString(String? a, String? b) {
    final aValue = (a ?? '').toLowerCase();
    final bValue = (b ?? '').toLowerCase();
    return aValue.compareTo(bValue);
  }

  int _compareNum(num? a, num? b) {
    final aValue = a ?? double.negativeInfinity;
    final bValue = b ?? double.negativeInfinity;
    return aValue.compareTo(bValue);
  }
}

class _Mb52Column {
  final String key;
  final String label;
  final TextAlign align;
  final double minWidth;
  final double maxWidth;

  const _Mb52Column({
    required this.key,
    required this.label,
    this.align = TextAlign.left,
    required this.minWidth,
    required this.maxWidth,
  });
}

class _Mb52RowItem {
  final _RowKind kind;
  final DatMb52ResumenModel? data;
  final _ArtGroup? artGroup;
  final _SucGroup? sucGroup;
  final _Totals? totals;

  _Mb52RowItem._({
    required this.kind,
    this.data,
    this.artGroup,
    this.sucGroup,
    this.totals,
  });

  factory _Mb52RowItem.data(DatMb52ResumenModel row) =>
      _Mb52RowItem._(kind: _RowKind.data, data: row);

  factory _Mb52RowItem.subtotalArt(_ArtGroup group) =>
      _Mb52RowItem._(kind: _RowKind.subtotalArt, artGroup: group);

  factory _Mb52RowItem.subtotalSuc(_SucGroup group) =>
      _Mb52RowItem._(kind: _RowKind.subtotalSuc, sucGroup: group);

  factory _Mb52RowItem.total(_Totals totals) =>
      _Mb52RowItem._(kind: _RowKind.total, totals: totals);
}

enum _RowKind { data, subtotalArt, subtotalSuc, total }

class _ArtGroup {
  _ArtGroup({
    required this.art,
    required this.items,
    required this.stockTotalCtda,
    required this.costoTotalCtot,
  });

  final String art;
  final List<DatMb52ResumenModel> items;
  final double stockTotalCtda;
  final double costoTotalCtot;
}

class _SucGroup {
  _SucGroup({
    required this.suc,
    required this.arts,
    required this.stockTotalCtda,
    required this.costoTotalCtot,
  });

  final String suc;
  final List<_ArtGroup> arts;
  final double stockTotalCtda;
  final double costoTotalCtot;
}

class _ArtGroupBuilder {
  _ArtGroupBuilder(this.art);

  final String art;
  final List<DatMb52ResumenModel> items = [];

  void add(DatMb52ResumenModel row) => items.add(row);

  _ArtGroup build() {
    double stock = 0;
    double costo = 0;
    for (final row in items) {
      stock += row.stockTotalCtda ?? 0;
      costo += row.costoTotalCtot ?? 0;
    }
    return _ArtGroup(
      art: art,
      items: items,
      stockTotalCtda: stock,
      costoTotalCtot: costo,
    );
  }
}

class _SucGroupBuilder {
  _SucGroupBuilder(this.suc);

  final String suc;
  final Map<String, _ArtGroupBuilder> arts = {};

  void add(String art, DatMb52ResumenModel row) {
    arts.putIfAbsent(art, () => _ArtGroupBuilder(art)).add(row);
  }

  _SucGroup build() {
    final artGroups = arts.values.map((b) => b.build()).toList();
    double stock = 0;
    double costo = 0;
    for (final g in artGroups) {
      stock += g.stockTotalCtda;
      costo += g.costoTotalCtot;
    }
    return _SucGroup(
      suc: suc,
      arts: artGroups,
      stockTotalCtda: stock,
      costoTotalCtot: costo,
    );
  }
}

class _Totals {
  _Totals({
    required this.stockTotalCtda,
    required this.costoTotalCtot,
  });

  final double stockTotalCtda;
  final double costoTotalCtot;
}

class _ColumnLayout {
  final Map<String, double> widths;
  final double totalWidth;

  const _ColumnLayout({required this.widths, required this.totalWidth});

  double widthFor(String key) => widths[key] ?? 100;
}

class _Mb52HeaderDelegate extends SliverPersistentHeaderDelegate {
  _Mb52HeaderDelegate({
    required this.height,
    required this.columns,
    required this.layout,
    required this.sortColumnIndex,
    required this.sortAscending,
    required this.onSort,
    required this.cellHPadding,
    required this.cellVPadding,
  });

  final double height;
  final List<_Mb52Column> columns;
  final _ColumnLayout layout;
  final int sortColumnIndex;
  final bool sortAscending;
  final void Function(int, bool) onSort;
  final double cellHPadding;
  final double cellVPadding;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final theme = Theme.of(context);
    final borderColor = Colors.grey.shade300;
    return SizedBox(
      height: height,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(bottom: BorderSide(color: borderColor, width: 0.8)),
        ),
        child: Row(
          children: List.generate(columns.length, (index) {
            final col = columns[index];
            final isSorted = index == sortColumnIndex;
            final icon = isSorted
                ? (sortAscending ? Icons.arrow_drop_up : Icons.arrow_drop_down)
                : null;
            final labelStyle = theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600);

            return SizedBox(
              width: layout.widthFor(col.key),
              child: InkWell(
                onTap: () => onSort(index, isSorted ? !sortAscending : true),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: cellHPadding, vertical: cellVPadding),
                  child: Row(
                    mainAxisAlignment: col.align == TextAlign.right
                        ? MainAxisAlignment.end
                        : MainAxisAlignment.start,
                    children: [
                      Flexible(
                        child: Text(
                          col.label,
                          overflow: TextOverflow.ellipsis,
                          style: labelStyle,
                        ),
                      ),
                      if (icon != null) Icon(icon, size: 18),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _Mb52HeaderDelegate oldDelegate) {
    return oldDelegate.sortColumnIndex != sortColumnIndex ||
        oldDelegate.sortAscending != sortAscending ||
        oldDelegate.layout.totalWidth != layout.totalWidth;
  }
}
