import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ioe_app/core/api_error.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'inventarios_models.dart';
import 'inventarios_providers.dart';

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

  @override
  void dispose() {
    _pageController.dispose();
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
        data: (resp) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(inventarioDetalleProvider(query));
            ref.invalidate(inventarioDetalleSummaryProvider(widget.cont));
            await Future.wait([
              ref.read(inventarioDetalleProvider(query).future),
              ref.read(inventarioDetalleSummaryProvider(widget.cont).future),
            ]);
          },
          child: Scrollbar(
            controller: _pageController,
            thumbVisibility: true,
            trackVisibility: true,
            child: ListView(
              controller: _pageController,
              padding: const EdgeInsets.all(12),
              children: [
                _SummaryCard(summaryAsync: summaryAsync),
                const SizedBox(height: 12),
                if (resp.data.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: Text('Sin resultados')),
                  )
                else
                  _TableListado(
                    data: resp.data,
                    contStatus: summaryAsync.asData?.value.esta,
                    onRefresh: () async {
                      ref.invalidate(inventarioDetalleProvider(query));
                      ref.invalidate(inventarioDetalleSummaryProvider(widget.cont));
                      await ref.read(inventarioDetalleProvider(query).future);
                      await ref.read(inventarioDetalleSummaryProvider(widget.cont).future);
                    },
                  ),
                const SizedBox(height: 12),
                _PaginationBar(
                  page: resp.page,
                  totalPages: resp.totalPages,
                  onPrev: resp.page > 1 ? () => _setPage(resp.page - 1) : null,
                  onNext: resp.page < resp.totalPages ? () => _setPage(resp.page + 1) : null,
                  totalRecords: resp.total,
                  limit: resp.limit,
                ),
              ],
            ),
          ),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  void _setPage(int page) {
    if (page < 1 || page == _page) return;
    setState(() => _page = page);
  }

  Future<void> _exportPdf(
    AsyncValue<ConteoDetResponse> detalleAsync,
    AsyncValue<ConteoSummaryModel> summaryAsync,
  ) async {
    final resp = detalleAsync.asData?.value;
    final summary = summaryAsync.asData?.value;

    if (resp == null || summary == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Primero carga el detalle y el resumen.')),
      );
      return;
    }

    final doc = pw.Document();
    final displayTotal = resp.totalPages < 1 ? 1 : resp.totalPages;
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

    final rows = resp.data
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
          pw.Text('Total: ${resp.total} · Página ${resp.page} de $displayTotal · Límite ${resp.limit}',
              style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    );

    await Printing.layoutPdf(
      name: 'detalle_${widget.cont}.pdf',
      onLayout: (format) async => doc.save(),
    );
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

class _TableListado extends ConsumerStatefulWidget {
  const _TableListado({required this.data, this.contStatus, this.onRefresh});

  final List<DatDetSvrModel> data;
  final String? contStatus;
  final Future<void> Function()? onRefresh;

  @override
  ConsumerState<_TableListado> createState() => _TableListadoState();
}

class _TableListadoState extends ConsumerState<_TableListado> {
  final Set<int> _updating = {};
  final Map<int, bool> _overrides = {};
  final ScrollController _horizontalController = ScrollController();

  @override
  void dispose() {
    _horizontalController.dispose();
    super.dispose();
  }

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
    final headerStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold);
    final status = (widget.contStatus ?? '').trim().toUpperCase();
    final isAdjusted = status == 'AJUSTADO' || status == 'CERRADO_AJUSTADO';

    return SelectionArea(
      child: Scrollbar(
        controller: _horizontalController,
        thumbVisibility: true,
        trackVisibility: true,
        child: SingleChildScrollView(
          controller: _horizontalController,
          scrollDirection: Axis.horizontal,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Row(
                  children: const [
                    _TableCell(width: 120, child: Text('Articulo')),
                    _TableCell(width: 130, child: Text('UPC')),
                    _TableCell(width: 320, child: Text('Descripción')),
                    _TableCell(width: 130, child: Text('CONTEO')),
                    _TableCell(width: 130, child: Text('EXISTENCIA')),
                    _TableCell(width: 130, child: Text('Dif')),
                    _TableCell(width: 130, child: Text('CTOP')),
                    _TableCell(width: 110, child: Text('Dif CTOP')),
                    _TableCell(width: 90, child: Text('EXT')),
                  ],
                ),
              ),
              ...widget.data.map(
                (m) => Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.4)),
                    ),
                  ),
                  child: Row(
                    children: [
                      _TableCell(width: 120, child: Text(m.art ?? '-', style: headerStyle)),
                      _TableCell(width: 130, child: Text(m.upc ?? '-')),
                      _TableCell(
                        width: 320,
                        child: Text(m.descripcion ?? '-', maxLines: 2, overflow: TextOverflow.ellipsis),
                      ),
                      _TableCell(width: 130, child: Text(_fmtNumber(m.total))),
                      _TableCell(width: 130, child: Text(_fmtNumber(m.mb52T))),
                      _TableCell(width: 130, child: Text(_fmtNumber(m.difT))),
                      _TableCell(width: 130, child: Text(_fmtNumber(m.ctop))),
                      _TableCell(width: 110, child: Text(_fmtNumber(m.difCtop))),
                      _TableCell(
                        width: 90,
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
                ),
              ),
            ],
          ),
        ),
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
