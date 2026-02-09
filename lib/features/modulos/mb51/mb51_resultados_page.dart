import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ioe_app/core/api_error.dart';
import 'package:ioe_app/core/csv_exporter.dart';

import 'mb51_models.dart';
import 'mb51_providers.dart';

class Mb51ResultadosPage extends ConsumerStatefulWidget {
  const Mb51ResultadosPage({super.key, this.filtros});

  final Mb51Filtros? filtros;

  @override
  ConsumerState<Mb51ResultadosPage> createState() => _Mb51ResultadosPageState();
}

class _Mb51ResultadosPageState extends ConsumerState<Mb51ResultadosPage> {
  final _searchCtrl = TextEditingController();
  final _verticalCtrl = ScrollController();
  final _horizontalCtrl = ScrollController();
  Timer? _debounce;
  String _searchTerm = '';
  int _sortColumnIndex = 0;
  bool _sortAscending = false;
  bool _exporting = false;

  static const double _rowHeight = 32;
  static const double _headerHeight = _rowHeight;
  static const double _cellHPadding = 8;
  static const double _cellVPadding = 6;
  static const List<_Mb51Column> _columns = [
    _Mb51Column(key: 'fcnd', label: 'Fecha Doc', minWidth: 90, maxWidth: 110),
    _Mb51Column(key: 'fcnc', label: 'Fecha Cont', minWidth: 90, maxWidth: 110),
    _Mb51Column(key: 'art', label: 'ART', minWidth: 70, maxWidth: 120),
    _Mb51Column(key: 'des', label: 'DES', minWidth: 160, maxWidth: 320),
    _Mb51Column(key: 'docp', label: 'DOCP', minWidth: 120, maxWidth: 240),
    _Mb51Column(key: 'clsm', label: 'CLSM', minWidth: 70, maxWidth: 90, align: TextAlign.right, numeric: true),
    _Mb51Column(key: 'almacen', label: 'ALMACEN', minWidth: 70, maxWidth: 100),
    _Mb51Column(key: 'ctda', label: 'CTDA', minWidth: 80, maxWidth: 110, align: TextAlign.right, numeric: true),
    _Mb51Column(key: 'ctot', label: 'CTOT', minWidth: 80, maxWidth: 110, align: TextAlign.right, numeric: true),
    _Mb51Column(key: 'txt', label: 'TXT', minWidth: 160, maxWidth: 360),
    _Mb51Column(key: 'user', label: 'USER', minWidth: 80, maxWidth: 120),
    _Mb51Column(key: 'suc', label: 'SUC', minWidth: 60, maxWidth: 80),
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

  Future<void> _exportCsv(List<DatMb51Model> rows) async {
    if (_exporting) return;
    if (rows.isEmpty) {
      _showSnack('Sin resultados para exportar.');
      return;
    }

    setState(() => _exporting = true);
    try {
      final headers = [
        'Fecha Doc',
        'Fecha Cont',
        'ART',
        'DES',
        'DOCP',
        'CLSM',
        'ALMACEN',
        'CTDA',
        'CTOT',
        'TXT',
        'USER',
        'SUC',
      ];

      final lines = <String>[];
      lines.add(headers.map(_csvEscape).join(','));

      for (final row in rows) {
        final values = [
          _fmtDateCsv(row.fcnd),
          _fmtDateCsv(row.fcnc),
          row.art ?? '',
          row.des ?? '',
          row.docp ?? '',
          _fmtNumberCsv(row.clsm, decimals: 2),
          row.almacen ?? '',
          _fmtNumberCsv(row.ctda, decimals: 2),
          _fmtNumberCsv(row.ctot, decimals: 2),
          row.txt ?? '',
          row.user ?? '',
          row.suc ?? '',
        ];
        lines.add(values.map(_csvEscape).join(','));
      }

      final csv = lines.join('\r\n');
      final bytes = Uint8List.fromList(utf8.encode(csv));
      final filename = 'MB51_${_fmtFileDate(DateTime.now())}.csv';

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
    final Mb51Filtros filtros = widget.filtros ?? ref.watch(mb51FiltrosProvider);
    final resultsAsync = ref.watch(mb51SearchProvider(filtros));

    List<DatMb51Model> exportRows = const [];
    Widget body;

    if (resultsAsync.isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (resultsAsync.hasError) {
      body = Center(child: Text('Error: ${apiErrorMessage(resultsAsync.error!)}'));
    } else {
      final result = resultsAsync.value;
      if (result == null) {
        body = const Center(child: Text('Sin datos'));
      } else {
      final filtered = _applyQuickFilter(result.items, _searchTerm);
      exportRows = filtered;
      final sorted = _applySort(filtered);
      final groups = _groupByArt(sorted);
      final totals = _sumTotals(filtered);
      final layout = _calcColumnLayout(filtered, groups);
      final rowItems = _buildRowItems(groups, totals);

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
                          labelText: 'Búsqueda rápida (ART / DES / DOCP / TXT)',
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
        title: const Text('MB51 - Resultados'),
        actions: [
          IconButton(
            tooltip: 'Refrescar',
            onPressed: () => ref.invalidate(mb51SearchProvider(filtros)),
            icon: const Icon(Icons.refresh),
          ),
          exportAction,
        ],
      ),
      body: body,
    );
  }

  _ColumnLayout _calcColumnLayout(List<DatMb51Model> rows, List<_Mb51Group> groups) {
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
        artMax = max(artMax, 'Subtotal ${group.art}'.length);
      }
      artMax = max(artMax, 'TOTAL GENERAL'.length);
      maxChars['art'] = artMax;
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

  List<_Mb51RowItem> _buildRowItems(List<_Mb51Group> groups, _Totals totals) {
    final rows = <_Mb51RowItem>[];
    for (final group in groups) {
      for (final item in group.items) {
        rows.add(_Mb51RowItem.data(item));
      }
      rows.add(_Mb51RowItem.subtotal(group));
    }
    rows.add(_Mb51RowItem.total(totals));
    return rows;
  }

  Widget _buildTable(List<_Mb51RowItem> rows, _ColumnLayout layout) {
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
                    delegate: _Mb51HeaderDelegate(
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

  Widget _buildRow(_Mb51RowItem item, _ColumnLayout layout, int index) {
    final color = switch (item.kind) {
      _RowKind.subtotal => Colors.amber.shade50,
      _RowKind.total => Colors.amber.shade100,
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

  List<Widget> _buildRowCells(_Mb51RowItem item, _ColumnLayout layout) {
    final cells = <Widget>[];
    for (final col in _columns) {
      var text = '';
      var bold = false;
      var align = col.align;

      if (item.kind == _RowKind.data) {
        text = _valueForColumn(item.data!, col.key);
      } else if (item.kind == _RowKind.subtotal) {
        if (col.key == 'art') {
          text = 'Subtotal ${item.group!.art}';
          bold = true;
        } else if (col.key == 'ctda') {
          text = _fmtNumber(item.group!.subtotalCtda, decimals: 2);
          bold = true;
          align = TextAlign.right;
        } else if (col.key == 'ctot') {
          text = _fmtNumber(item.group!.subtotalCtot, decimals: 2);
          bold = true;
          align = TextAlign.right;
        }
      } else {
        if (col.key == 'art') {
          text = 'TOTAL GENERAL';
          bold = true;
        } else if (col.key == 'ctda') {
          text = _fmtNumber(item.totals!.ctda, decimals: 2);
          bold = true;
          align = TextAlign.right;
        } else if (col.key == 'ctot') {
          text = _fmtNumber(item.totals!.ctot, decimals: 2);
          bold = true;
          align = TextAlign.right;
        }
      }

      cells.add(_buildCell(col, layout, text, bold: bold, align: align));
    }
    return cells;
  }

  Widget _buildCell(_Mb51Column column, _ColumnLayout layout, String text, {bool bold = false, TextAlign? align}) {
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

  String _valueForColumn(DatMb51Model row, String key) {
    return switch (key) {
      'fcnd' => _fmtDate(row.fcnd),
      'fcnc' => _fmtDate(row.fcnc),
      'art' => row.art ?? '-',
      'des' => row.des ?? '-',
      'docp' => row.docp ?? '-',
      'clsm' => _fmtNumber(row.clsm, decimals: 0),
      'almacen' => row.almacen ?? '-',
      'ctda' => _fmtNumber(row.ctda, decimals: 2),
      'ctot' => _fmtNumber(row.ctot, decimals: 2),
      'txt' => row.txt ?? '-',
      'user' => row.user ?? '-',
      'suc' => row.suc ?? '-',
      _ => '-',
    };
  }

  List<DatMb51Model> _applyQuickFilter(List<DatMb51Model> rows, String term) {
    final q = term.trim().toLowerCase();
    if (q.isEmpty) return rows;
    return rows.where((row) {
      final art = (row.art ?? '').toLowerCase();
      final des = (row.des ?? '').toLowerCase();
      final docp = (row.docp ?? '').toLowerCase();
      final txt = (row.txt ?? '').toLowerCase();
      return art.contains(q) || des.contains(q) || docp.contains(q) || txt.contains(q);
    }).toList();
  }

  List<DatMb51Model> _applySort(List<DatMb51Model> rows) {
    final sorted = [...rows];
    sorted.sort((a, b) {
      int result;
      switch (_sortColumnIndex) {
        case 0:
          result = _compareNum(a.fcnd?.millisecondsSinceEpoch, b.fcnd?.millisecondsSinceEpoch);
          break;
        case 1:
          result = _compareNum(a.fcnc?.millisecondsSinceEpoch, b.fcnc?.millisecondsSinceEpoch);
          break;
        case 2:
          result = _compareString(a.art, b.art);
          break;
        case 3:
          result = _compareString(a.des, b.des);
          break;
        case 4:
          result = _compareString(a.docp, b.docp);
          break;
        case 5:
          result = _compareNum(a.clsm, b.clsm);
          break;
        case 6:
          result = _compareString(a.almacen, b.almacen);
          break;
        case 7:
          result = _compareNum(a.ctda, b.ctda);
          break;
        case 8:
          result = _compareNum(a.ctot, b.ctot);
          break;
        case 9:
          result = _compareString(a.txt, b.txt);
          break;
        case 10:
          result = _compareString(a.user, b.user);
          break;
        case 11:
          result = _compareString(a.suc, b.suc);
          break;
        default:
          result = 0;
      }
      return _sortAscending ? result : -result;
    });
    return sorted;
  }

  List<_Mb51Group> _groupByArt(List<DatMb51Model> rows) {
    final map = <String, _Mb51GroupBuilder>{};
    for (final row in rows) {
      final keyRaw = (row.art ?? '').trim();
      final key = keyRaw.isEmpty ? '(SIN ART)' : keyRaw;
      map.putIfAbsent(key, () => _Mb51GroupBuilder(key)).add(row);
    }
    return map.values.map((b) => b.build()).toList();
  }

  _Totals _sumTotals(List<DatMb51Model> rows) {
    double ctda = 0;
    double ctot = 0;
    for (final row in rows) {
      ctda += row.ctda ?? 0;
      ctot += row.ctot ?? 0;
    }
    return _Totals(ctda: ctda, ctot: ctot);
  }

  String _fmtDate(DateTime? value) {
    if (value == null) return '-';
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$d/$m/$y';
  }

  String _fmtDateCsv(DateTime? value) {
    if (value == null) return '';
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _fmtFileDate(DateTime value) {
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }

  String _fmtNumber(double? value, {int decimals = 0}) {
    if (value == null) return '-';
    return value.toStringAsFixed(decimals);
  }

  String _fmtNumberCsv(double? value, {int decimals = 0}) {
    if (value == null) return '';
    return value.toStringAsFixed(decimals);
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

class _Mb51Group {
  _Mb51Group({required this.art, required this.items, required this.subtotalCtda, required this.subtotalCtot});

  final String art;
  final List<DatMb51Model> items;
  final double subtotalCtda;
  final double subtotalCtot;
}

class _Mb51GroupBuilder {
  _Mb51GroupBuilder(this.art);

  final String art;
  final List<DatMb51Model> items = [];

  void add(DatMb51Model row) => items.add(row);

  _Mb51Group build() {
    double ctda = 0;
    double ctot = 0;
    for (final row in items) {
      ctda += row.ctda ?? 0;
      ctot += row.ctot ?? 0;
    }
    return _Mb51Group(art: art, items: items, subtotalCtda: ctda, subtotalCtot: ctot);
  }
}

class _Totals {
  _Totals({required this.ctda, required this.ctot});

  final double ctda;
  final double ctot;
}

class _Mb51Column {
  final String key;
  final String label;
  final TextAlign align;
  final double minWidth;
  final double maxWidth;
  final bool numeric;

  const _Mb51Column({
    required this.key,
    required this.label,
    this.align = TextAlign.left,
    this.minWidth = 60,
    this.maxWidth = 200,
    this.numeric = false,
  });
}

class _ColumnLayout {
  final Map<String, double> widths;
  final double totalWidth;

  const _ColumnLayout({required this.widths, required this.totalWidth});

  double widthFor(String key) => widths[key] ?? 80;
}

enum _RowKind { data, subtotal, total }

class _Mb51RowItem {
  final _RowKind kind;
  final DatMb51Model? data;
  final _Mb51Group? group;
  final _Totals? totals;

  const _Mb51RowItem._({
    required this.kind,
    this.data,
    this.group,
    this.totals,
  });

  factory _Mb51RowItem.data(DatMb51Model data) => _Mb51RowItem._(kind: _RowKind.data, data: data);

  factory _Mb51RowItem.subtotal(_Mb51Group group) =>
      _Mb51RowItem._(kind: _RowKind.subtotal, group: group);

  factory _Mb51RowItem.total(_Totals totals) =>
      _Mb51RowItem._(kind: _RowKind.total, totals: totals);
}

class _Mb51HeaderDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final List<_Mb51Column> columns;
  final _ColumnLayout layout;
  final int sortColumnIndex;
  final bool sortAscending;
  final void Function(int index, bool ascending) onSort;
  final double cellHPadding;
  final double cellVPadding;

  _Mb51HeaderDelegate({
    required this.height,
    required this.columns,
    required this.layout,
    required this.sortColumnIndex,
    required this.sortAscending,
    required this.onSort,
    required this.cellHPadding,
    required this.cellVPadding,
  });

  @override
  double get maxExtent => height;

  @override
  double get minExtent => height;

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
          children: [
            for (var i = 0; i < columns.length; i++) _buildHeaderCell(context, columns[i], i),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCell(BuildContext context, _Mb51Column column, int index) {
    final isSorted = index == sortColumnIndex;
    final icon = isSorted ? (sortAscending ? Icons.arrow_drop_up : Icons.arrow_drop_down) : null;
    final labelStyle = Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600);

    return InkWell(
      onTap: () => onSort(index, isSorted ? !sortAscending : true),
      child: SizedBox(
        width: layout.widthFor(column.key),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: cellHPadding, vertical: cellVPadding),
          child: Row(
            children: [
              Expanded(child: Text(column.label, overflow: TextOverflow.ellipsis, style: labelStyle)),
              if (icon != null) Icon(icon, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _Mb51HeaderDelegate oldDelegate) {
    return oldDelegate.sortColumnIndex != sortColumnIndex ||
        oldDelegate.sortAscending != sortAscending ||
        oldDelegate.layout != layout ||
        oldDelegate.columns != columns;
  }
}
