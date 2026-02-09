import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ioe_app/core/api_error.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'inventarios_models.dart';
import 'inventarios_providers.dart';

const double _pagePadding = 10;
const double _tableHeaderHeight = 48;
const double _tableRowHorizontalPadding = 6;
const double _tableRowVerticalPadding = 0;
const double _tableFontSize = 11;
// Nota: Ajustar anchos/estilos de la tabla para afinar la visualizacion de la consulta.
const double _colArticuloWidth = 60;
const double _colUpcWidth = 100;
const double _colDescripcionWidth = 250;
const double _colConteoWidth = 130;
const double _colExistenciaWidth = 130;
const double _colDifWidth = 130;
const double _colCtopWidth = 130;
const double _colDifCtopWidth = 110;
const double _colExtWidth = 90;
const double _tableWidth = _colArticuloWidth +
    _colUpcWidth +
    _colDescripcionWidth +
    _colConteoWidth +
    _colExistenciaWidth +
    _colDifWidth +
    _colCtopWidth +
    _colDifCtopWidth +
    _colExtWidth;
const double _tableContentWidth = _tableWidth + _tableRowHorizontalPadding * 2;

class InventarioDetallePage extends ConsumerStatefulWidget {
  const InventarioDetallePage({super.key, required this.cont});

  final String cont;

  @override
  ConsumerState<InventarioDetallePage> createState() => _InventarioDetallePageState();
}

class _InventarioDetallePageState extends ConsumerState<InventarioDetallePage> {
  static const int _limit = 50;
  int _page = 1;
  final _pageController = ScrollController();
  final _horizontalController = ScrollController();
  final _searchController = TextEditingController();
  String _searchBy = 'ART';
  String _appliedSearchBy = 'ART';
  String _searchTerm = '';

  @override
  void dispose() {
    _pageController.dispose();
    _horizontalController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ConteoDetQuery(cont: widget.cont, page: _page, limit: _limit);
    final detalleAsync = ref.watch(inventarioDetalleProvider(query));
    final summaryAsync = ref.watch(inventarioDetalleSummaryProvider(widget.cont));

    return Scaffold(
      appBar: AppBar(
        title: Text('Detalle ${widget.cont}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refrescar',
            onPressed: () {
              ref.invalidate(inventarioDetalleProvider(query));
              ref.invalidate(inventarioDetalleSummaryProvider(widget.cont));
            },
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Exportar PDF',
            onPressed: () => _exportPdf(detalleAsync, summaryAsync),
          ),
        ],
      ),
      body: detalleAsync.when(
        data: (resp) {
          final filteredData = _filterData(resp.data);
          final hasData = filteredData.isNotEmpty;
          return RefreshIndicator(
            notificationPredicate: (notification) => notification.metrics.axis == Axis.vertical,
            onRefresh: () async {
              ref.invalidate(inventarioDetalleProvider(query));
              ref.invalidate(inventarioDetalleSummaryProvider(widget.cont));
              await Future.wait([
                ref.read(inventarioDetalleProvider(query).future),
                ref.read(inventarioDetalleSummaryProvider(widget.cont).future),
              ]);
            },
            child: LayoutBuilder(
              builder: (context, constraints) {
                final minWidth = hasData ? _tableContentWidth + _pagePadding * 2 : constraints.maxWidth;
                final contentWidth = constraints.maxWidth > minWidth ? constraints.maxWidth : minWidth;

                return Scrollbar(
                  controller: _pageController,
                  thumbVisibility: true,
                  trackVisibility: true,
                  notificationPredicate: (notification) => notification.metrics.axis == Axis.vertical,
                  child: Scrollbar(
                    controller: _horizontalController,
                    thumbVisibility: true,
                    trackVisibility: true,
                    notificationPredicate: (notification) => notification.metrics.axis == Axis.horizontal,
                    child: SingleChildScrollView(
                      controller: _horizontalController,
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: contentWidth,
                        child: SelectionArea(
                          child: CustomScrollView(
                            controller: _pageController,
                            slivers: [
                              const SliverToBoxAdapter(child: SizedBox(height: _pagePadding)),
                              SliverPadding(
                                padding: const EdgeInsets.symmetric(horizontal: _pagePadding),
                                sliver: SliverToBoxAdapter(
                                  child: _SummaryCard(summaryAsync: summaryAsync),
                                ),
                              ),
                              const SliverToBoxAdapter(child: SizedBox(height: _pagePadding)),
                              SliverPadding(
                                padding: const EdgeInsets.symmetric(horizontal: _pagePadding),
                                sliver: SliverToBoxAdapter(
                                  child: _SearchBar(
                                    controller: _searchController,
                                    searchBy: _searchBy,
                                    onSearchByChanged: (value) => setState(() => _searchBy = value ?? 'ART'),
                                    onSearch: _applySearch,
                                    onClear: _clearSearch,
                                  ),
                                ),
                              ),
                              const SliverToBoxAdapter(child: SizedBox(height: _pagePadding)),
                              if (hasData) ...[
                                SliverPadding(
                                  padding: const EdgeInsets.symmetric(horizontal: _pagePadding),
                                  sliver: SliverPersistentHeader(
                                    pinned: true,
                                    delegate: const _TableHeaderDelegate(),
                                  ),
                                ),
                                SliverPadding(
                                  padding: const EdgeInsets.symmetric(horizontal: _pagePadding),
                                  sliver: _TableRowsSliver(
                                    data: filteredData,
                                    contStatus: summaryAsync.asData?.value.esta,
                                    onRefresh: () async {
                                      ref.invalidate(inventarioDetalleProvider(query));
                                      ref.invalidate(inventarioDetalleSummaryProvider(widget.cont));
                                      await ref.read(inventarioDetalleProvider(query).future);
                                      await ref.read(inventarioDetalleSummaryProvider(widget.cont).future);
                                    },
                                  ),
                                ),
                              ] else
                                SliverPadding(
                                  padding: const EdgeInsets.symmetric(horizontal: _pagePadding),
                                  sliver: const SliverToBoxAdapter(
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(vertical: 48),
                                      child: Center(child: Text('Sin resultados')),
                                    ),
                                  ),
                                ),
                              const SliverToBoxAdapter(child: SizedBox(height: _pagePadding)),
                              SliverPadding(
                                padding: const EdgeInsets.symmetric(horizontal: _pagePadding),
                                sliver: SliverToBoxAdapter(
                                  child: _PaginationBar(
                                    page: resp.page,
                                    totalPages: resp.totalPages,
                                    onPrev: resp.page > 1 ? () => _setPage(resp.page - 1) : null,
                                    onNext: resp.page < resp.totalPages ? () => _setPage(resp.page + 1) : null,
                                    totalRecords: resp.total,
                                    limit: resp.limit,
                                  ),
                                ),
                              ),
                              const SliverToBoxAdapter(child: SizedBox(height: _pagePadding)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
        error: (e, _) => Center(child: Text('Error: $e')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  void _setPage(int page) {
    if (page < 1 || page == _page) return;
    setState(() => _page = page);
  }

  void _applySearch() {
    setState(() {
      _searchTerm = _searchController.text.trim();
      _appliedSearchBy = _searchBy;
      _page = 1;
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchBy = 'ART';
      _appliedSearchBy = 'ART';
      _searchTerm = '';
      _page = 1;
    });
  }

  List<DatDetSvrModel> _filterData(List<DatDetSvrModel> data) {
    final term = _searchTerm.trim().toLowerCase();
    if (term.isEmpty) return data;
    bool matches(String? value) => (value ?? '').toLowerCase().contains(term);
    switch (_appliedSearchBy) {
      case 'UPC':
        return data.where((m) => matches(m.upc)).toList();
      case 'DES':
        return data.where((m) => matches(m.descripcion)).toList();
      case 'ART':
      default:
        return data.where((m) => matches(m.art)).toList();
    }
  }

  Future<void> _exportPdf(
    AsyncValue<ConteoDetResponse> detalleAsync,
    AsyncValue<ConteoSummaryModel> summaryAsync,
  ) async {
    bool dialogShown = false;
    if (mounted) {
      dialogShown = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
    }

    try {
      final api = ref.read(inventariosApiProvider);
      final summary = summaryAsync.asData?.value ?? await api.fetchDetalleSummary(widget.cont);
      final baseResp = detalleAsync.asData?.value ?? await api.fetchDetalles(widget.cont, page: 1, limit: _limit);
      final totalPages = baseResp.totalPages < 1 ? 1 : baseResp.totalPages;
      final limit = baseResp.limit < 1 ? _limit : baseResp.limit;

      final pagesData = <int, List<DatDetSvrModel>>{baseResp.page: baseResp.data};
      for (var page = 1; page <= totalPages; page++) {
        if (page == baseResp.page) continue;
        final pageResp = await api.fetchDetalles(widget.cont, page: page, limit: limit);
        pagesData[page] = pageResp.data;
      }

      final sortedPages = pagesData.keys.toList()..sort();
      final allData = <DatDetSvrModel>[];
      for (final page in sortedPages) {
        allData.addAll(pagesData[page]!);
      }

      if (allData.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sin resultados para exportar.')),
        );
        return;
      }

      final doc = pw.Document();
      final headers = [
        'Articulo',
        'UPC',
        'Descripcion',
        'CONTEO',
        'EXISTENCIA',
        'Dif',
        'CTOP',
        'Dif CTOP',
        'EXT',
      ];

      final rows = allData
          .map((m) => [
                m.art ?? '-',
                m.upc ?? '-',
                m.descripcion ?? '-',
                _fmtNumber(m.total),
                _fmtNumber(m.mb52T),
                _fmtNumber(m.difT),
                _fmtNumber(m.ctop),
                _fmtNumber(m.difCtop),
                (m.ext ?? 0) == 0 ? 'NO' : 'SI',
              ])
          .toList();

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(24),
          build: (context) => [
            pw.Text(
              'Detalle ${widget.cont}',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 12),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Resumen del conteo',
                            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 4),
                        pw.Text('SUC: ${summary.suc} · CONT: ${summary.cont}'),
                      ],
                    ),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Dif total \$ ${summary.sumDifCtop.toStringAsFixed(2)}',
                        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text('Dif piezas: ${_fmtNumber(summary.sumDifT)}'),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),
            pw.TableHelper.fromTextArray(
              headers: headers,
              data: rows,
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              cellAlignment: pw.Alignment.centerLeft,
              columnWidths: const {
                0: pw.FixedColumnWidth(60),
                1: pw.FixedColumnWidth(90),
                2: pw.FlexColumnWidth(2),
                3: pw.FixedColumnWidth(60),
                4: pw.FixedColumnWidth(70),
                5: pw.FixedColumnWidth(50),
                6: pw.FixedColumnWidth(60),
                7: pw.FixedColumnWidth(70),
                8: pw.FixedColumnWidth(40),
              },
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              'Total: ${baseResp.total} · Registros exportados: ${allData.length}',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ],
        ),
      );

      if (mounted && dialogShown) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogShown = false;
      }

      await Printing.layoutPdf(
        name: 'detalle_${widget.cont}.pdf',
        onLayout: (format) async => doc.save(),
      );
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo exportar: ${apiErrorMessage(err)}')),
      );
    } finally {
      if (mounted && dialogShown) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summaryAsync});

  final AsyncValue<ConteoSummaryModel> summaryAsync;

  @override
  Widget build(BuildContext context) {
    return summaryAsync.when(
      data: (data) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Resumen del conteo', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text('SUC: ${data.suc} · CONT: ${data.cont}'),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Dif total \$ ${data.sumDifCtop.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.titleMedium),
                    Text('Dif piezas: ${_fmtNumber(data.sumDifT)}', style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(12),
        child: LinearProgressIndicator(),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(12),
        child: Text('No se pudo cargar el resumen: $e'),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.searchBy,
    required this.onSearchByChanged,
    required this.onClear,
    required this.onSearch,
  });

  final TextEditingController controller;
  final String searchBy;
  final ValueChanged<String?> onSearchByChanged;
  final VoidCallback onClear;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            const Text('Buscar por:'),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: searchBy,
              items: const [
                DropdownMenuItem(value: 'ART', child: Text('ART')),
                DropdownMenuItem(value: 'UPC', child: Text('UPC')),
                DropdownMenuItem(value: 'DES', child: Text('DES')),
              ],
              onChanged: onSearchByChanged,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'Digite busqueda',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => onSearch(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Buscar',
              onPressed: onSearch,
              icon: const Icon(Icons.search),
            ),
            IconButton(
              tooltip: 'Limpiar',
              onPressed: onClear,
              icon: const Icon(Icons.clear),
            ),
          ],
        ),
      ),
    );
  }
}

class _TableHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _TableHeaderDelegate();

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final headerStyle =
        Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: _tableFontSize, fontWeight: FontWeight.bold);
    return Container(
      height: _tableHeaderHeight,
      padding: const EdgeInsets.symmetric(
        vertical: _tableRowVerticalPadding,
        horizontal: _tableRowHorizontalPadding,
      ),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          _TableCell(width: _colArticuloWidth, child: Text('Articulo', style: headerStyle)),
          _TableCell(width: _colUpcWidth, child: Text('UPC', style: headerStyle)),
          _TableCell(width: _colDescripcionWidth, child: Text('Descripción', style: headerStyle)),
          _TableCell(width: _colConteoWidth, child: Text('CONTEO', style: headerStyle)),
          _TableCell(width: _colExistenciaWidth, child: Text('EXISTENCIA', style: headerStyle)),
          _TableCell(width: _colDifWidth, child: Text('Dif', style: headerStyle)),
          _TableCell(width: _colCtopWidth, child: Text('CTOP', style: headerStyle)),
          _TableCell(width: _colDifCtopWidth, child: Text('Dif CTOP', style: headerStyle)),
          _TableCell(width: _colExtWidth, child: Text('EXT', style: headerStyle)),
        ],
      ),
    );
  }

  @override
  double get maxExtent => _tableHeaderHeight;

  @override
  double get minExtent => _tableHeaderHeight;

  @override
  bool shouldRebuild(covariant _TableHeaderDelegate oldDelegate) => false;
}

class _TableRowsSliver extends ConsumerStatefulWidget {
  const _TableRowsSliver({required this.data, this.contStatus, this.onRefresh});

  final List<DatDetSvrModel> data;
  final String? contStatus;
  final Future<void> Function()? onRefresh;

  @override
  ConsumerState<_TableRowsSliver> createState() => _TableRowsSliverState();
}

class _TableRowsSliverState extends ConsumerState<_TableRowsSliver> {
  final Set<int> _updating = {};
  final Map<int, bool> _overrides = {};

  bool _extValue(DatDetSvrModel model) {
    final id = model.id;
    if (id != null && _overrides.containsKey(id)) return _overrides[id]!;
    return (model.ext ?? 0) != 0;
  }

  Future<void> _toggleExt(DatDetSvrModel model, bool value) async {
    final id = model.id;
    if (id == null) return;

    setState(() {
      _updating.add(id);
      _overrides[id] = value;
    });

    try {
      await ref.read(inventariosApiProvider).updateDetalleExt(id: id, value: value);
      if (!mounted) return;
      if (widget.onRefresh != null) {
        await widget.onRefresh!();
        if (!mounted) return;
        setState(() => _overrides.remove(id));
      }
    } catch (err) {
      if (!mounted) return;
      setState(() => _overrides.remove(id));
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error al actualizar EXT: ${apiErrorMessage(err)}')));
    } finally {
      if (mounted) {
        setState(() => _updating.remove(id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseStyle = Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: _tableFontSize);
    final headerStyle = baseStyle?.copyWith(fontWeight: FontWeight.bold);
    final status = (widget.contStatus ?? '').trim().toUpperCase();
    final isAdjusted = status == 'AJUSTADO' || status == 'CERRADO_AJUSTADO';

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final m = widget.data[index];
          return Container(
            padding: const EdgeInsets.symmetric(
              vertical: _tableRowVerticalPadding,
              horizontal: _tableRowHorizontalPadding,
            ),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.4)),
              ),
            ),
            child: Row(
              children: [
                _TableCell(width: _colArticuloWidth, child: Text(m.art ?? '-', style: headerStyle)),
                _TableCell(width: _colUpcWidth, child: Text(m.upc ?? '-', style: baseStyle)),
                _TableCell(
                  width: _colDescripcionWidth,
                  child:
                      Text(m.descripcion ?? '-', maxLines: 2, overflow: TextOverflow.ellipsis, style: baseStyle),
                ),
                _TableCell(width: _colConteoWidth, child: Text(_fmtNumber(m.total), style: baseStyle)),
                _TableCell(width: _colExistenciaWidth, child: Text(_fmtNumber(m.mb52T), style: baseStyle)),
                _TableCell(width: _colDifWidth, child: Text(_fmtNumber(m.difT), style: baseStyle)),
                _TableCell(width: _colCtopWidth, child: Text(_fmtNumber(m.ctop), style: baseStyle)),
                _TableCell(width: _colDifCtopWidth, child: Text(_fmtNumber(m.difCtop), style: baseStyle)),
                _TableCell(
                  width: _colExtWidth,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Switch.adaptive(
                      value: _extValue(m),
                      onChanged: (m.id == null || _updating.contains(m.id) || isAdjusted)
                          ? null
                          : (v) => _toggleExt(m, v),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        childCount: widget.data.length,
      ),
    );
  }
}

class _TableCell extends StatelessWidget {
  const _TableCell({required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: child,
    );
  }
}

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.page,
    required this.totalPages,
    required this.onPrev,
    required this.onNext,
    required this.totalRecords,
    required this.limit,
  });

  final int page;
  final int totalPages;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final int totalRecords;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final displayTotal = totalPages < 1 ? 1 : totalPages;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(child: Text('Total: $totalRecords · Página $page de $displayTotal · Límite $limit')),
          Row(
            children: [
              IconButton(onPressed: onPrev, tooltip: 'Anterior', icon: const Icon(Icons.chevron_left)),
              IconButton(onPressed: onNext, tooltip: 'Siguiente', icon: const Icon(Icons.chevron_right)),
            ],
          ),
        ],
      ),
    );
  }
}

String _fmtNumber(num? value) {
  if (value == null) return '-';
  final doubleVal = value.toDouble();
  if (doubleVal == doubleVal.roundToDouble()) return doubleVal.toStringAsFixed(0);
  return doubleVal.toStringAsFixed(2);
}
