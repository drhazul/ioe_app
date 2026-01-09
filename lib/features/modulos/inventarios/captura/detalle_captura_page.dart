import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'captura_models.dart';
import 'captura_providers.dart';

class DetalleCapturaPage extends ConsumerStatefulWidget {
  const DetalleCapturaPage({super.key, this.cont});

  final String? cont;

  @override
  ConsumerState<DetalleCapturaPage> createState() => _DetalleCapturaPageState();
}

class _DetalleCapturaPageState extends ConsumerState<DetalleCapturaPage> {
  String? _selectedCont;
  String _almacenFilter = 'TODOS';
  int _page = 1;
  final int _limit = 50;
  bool _scannerOpen = false;

  final _upcCtrl = TextEditingController();
  final _upcFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _selectedCont = widget.cont;
  }

  @override
  void dispose() {
    _upcCtrl.dispose();
    _upcFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final conteosAsync = ref.watch(conteosDisponiblesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle captura'),
        actions: [
          IconButton(
            onPressed: _selectedCont == null
                ? null
                : () {
                    final query = _buildQuery();
                    if (query != null) {
                      ref.invalidate(capturasListProvider(query));
                    }
                  },
            icon: const Icon(Icons.refresh),
            tooltip: 'Refrescar',
          ),
        ],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/inventarios/captura'),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(conteosDisponiblesProvider);
          final query = _buildQuery();
          if (query != null) {
            ref.invalidate(capturasListProvider(query));
            await ref.read(capturasListProvider(query).future);
          }
        },
        child: conteosAsync.when(
          data: (conteos) {
            _syncSelection(conteos);

            final query = _buildQuery();
            final capturesSection = query == null
                ? const Padding(
                    padding: EdgeInsets.only(top: 32),
                    child: Text('Selecciona un conteo para ver sus capturas.'),
                  )
                : _CapturasList(
                    query: query,
                    onPageChange: _handlePageChange,
                  );

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                _buildConteoDropdown(conteos),
                const SizedBox(height: 12),
                _buildAlmacenChips(),
                const SizedBox(height: 12),
                _buildFiltersRow(),
                const SizedBox(height: 16),
                capturesSection,
                const SizedBox(height: 24),
              ],
            );
          },
          loading: () => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(height: 180),
              Center(child: CircularProgressIndicator()),
            ],
          ),
          error: (e, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Text('Error al cargar conteos: $e'),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(conteosDisponiblesProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConteoDropdown(List<ConteoDisponible> conteos) {
    final items = conteos
        .map(
          (c) => DropdownMenuItem<String>(
            value: c.cont ?? c.tokenreg,
            child: Text('${c.cont ?? c.tokenreg} · ${c.suc ?? '-'} · ${c.estado ?? ''}'),
          ),
        )
        .toList();

    return DropdownButtonFormField<String>(
      initialValue: _selectedCont,
      decoration: const InputDecoration(
        labelText: 'Conteo',
        border: OutlineInputBorder(),
      ),
      items: items,
      onChanged: (v) {
        setState(() {
          _selectedCont = v;
          _page = 1;
        });
      },
    );
  }

  Widget _buildAlmacenChips() {
    const opciones = ['TODOS', '001', '002', 'M001', 'T001'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Almacén', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: opciones
              .map(
                (alm) => ChoiceChip(
                  label: Text(alm),
                  selected: _almacenFilter == alm,
                  onSelected: (v) => v ? _applyFilter(almacen: alm, resetPage: true) : null,
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildFiltersRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _upcCtrl,
          focusNode: _upcFocus,
          decoration: InputDecoration(
            labelText: 'UPC / EAN13 (filtro)',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              tooltip: 'Escanear código',
              icon: const Icon(Icons.qr_code_scanner),
              onPressed: _openScanner,
            ),
          ),
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _applyFilter(resetPage: true),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: () => _applyFilter(resetPage: true),
              icon: const Icon(Icons.filter_list),
              label: const Text('Filtrar'),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: _clearFilters,
              icon: const Icon(Icons.clear),
              label: const Text('Limpiar'),
            ),
          ],
        ),
      ],
    );
  }

  void _applyFilter({String? almacen, bool resetPage = false}) {
    setState(() {
      _almacenFilter = almacen ?? _almacenFilter;
      _page = resetPage ? 1 : _page;
    });
  }

  void _clearFilters() {
    setState(() {
      _almacenFilter = 'TODOS';
      _page = 1;
      _upcCtrl.clear();
    });
  }

  void _handlePageChange(int newPage) {
    setState(() {
      _page = newPage;
    });
  }

  CapturaListQuery? _buildQuery() {
    final cont = _selectedCont;
    if (cont == null || cont.trim().isEmpty) return null;
    return CapturaListQuery(
      cont: cont.trim(),
      almacen: _almacenFilter,
      upc: _upcCtrl.text.trim(),
      page: _page,
      limit: _limit,
    );
  }

  void _syncSelection(List<ConteoDisponible> conteos) {
    if (_selectedCont != null && _selectedCont!.isNotEmpty) return;
    if (conteos.isEmpty) return;
    final first = conteos.first;
    _selectedCont = first.cont ?? first.tokenreg;
  }

  Future<void> _openScanner() async {
    if (_scannerOpen) return;
    _scannerOpen = true;
    final controller = MobileScannerController(
      formats: const [BarcodeFormat.ean13, BarcodeFormat.upcA],
      detectionSpeed: DetectionSpeed.normal,
    );

    String? scanned;
    bool reportedInvalid = false;

    try {
      if (!mounted) return;
      scanned = await showDialog<String>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: const Text('Escanear código'),
            actions: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
          body: MobileScanner(
            controller: controller,
            onDetect: (capture) {
              for (final barcode in capture.barcodes) {
                final raw = barcode.rawValue;
                if (raw == null || raw.isEmpty) continue;

                final format = barcode.format;
                final allowed = format == BarcodeFormat.ean13 || format == BarcodeFormat.upcA;
                if (!allowed) {
                  if (!reportedInvalid) {
                    reportedInvalid = true;
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Código no válido')));
                  }
                  continue;
                }

                controller.stop();
                HapticFeedback.mediumImpact();
                SystemSound.play(SystemSoundType.click);
                Navigator.of(ctx).pop(raw);
                return;
              }
            },
          ),
        ),
      );
    } finally {
      controller.dispose();
      _scannerOpen = false;
    }

    if (!mounted || scanned == null) return;

    setState(() {
      _upcCtrl.text = scanned!;
      _page = 1;
    });
    await Future<void>.delayed(const Duration(milliseconds: 50));
    _applyFilter(resetPage: true);
    _upcFocus.requestFocus();
  }
}

class _CapturasList extends ConsumerWidget {
  const _CapturasList({required this.query, required this.onPageChange});

  final CapturaListQuery query;
  final void Function(int newPage) onPageChange;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(capturasListProvider(query));

    return dataAsync.when(
      data: (res) {
        if (res.data.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text('No hay capturas para este conteo con los filtros actuales.'),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total registros: ${res.total} (página ${res.page}/${res.totalPages})'),
            const SizedBox(height: 12),
            const _CapturasHeader(),
            const SizedBox(height: 8),
            ...res.data.map((item) => _CapturaTile(item: item)),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: res.page > 1 ? () => onPageChange(res.page - 1) : null,
                  icon: const Icon(Icons.chevron_left),
                  label: const Text('Anterior'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: res.page < res.totalPages ? () => onPageChange(res.page + 1) : null,
                  icon: const Icon(Icons.chevron_right),
                  label: const Text('Siguiente'),
                ),
              ],
            ),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Error al cargar capturas: $e'),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(capturasListProvider(query)),
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CapturaTile extends StatelessWidget {
  const _CapturaTile({required this.item});

  final CapturaRecord item;

  @override
  Widget build(BuildContext context) {
    String fmt(double? value) {
      if (value == null) return '-';
      final asInt = value.toInt();
      if (asInt.toDouble() == value) return asInt.toString();
      return value.toStringAsFixed(2);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _CaptureCell(width: 120, child: Text(item.art)),
              _CaptureCell(width: 150, child: Text(item.upc?.isNotEmpty == true ? item.upc! : '-')),
              _CaptureCell(
                width: 100,
                child: Text('${fmt(item.cantidad)}${item.tipoMov != null ? ' (${item.tipoMov})' : ''}'),
              ),
              _CaptureCell(width: 90, child: Text('${item.idUsuario ?? '-'}')),
              _CaptureCell(width: 220, child: Text(item.fcnr?.toIso8601String() ?? '-')),
              _CaptureCell(
                width: 90,
                child: item.almacen.isNotEmpty ? Chip(label: Text(item.almacen)) : const Text('-'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CapturasHeader extends StatelessWidget {
  const _CapturasHeader();

  @override
  Widget build(BuildContext context) {
    final headerStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: DefaultTextStyle(
          style: headerStyle ?? const TextStyle(fontWeight: FontWeight.bold),
          child: const Row(
            children: [
              _CaptureCell(width: 120, child: Text('Articulo')),
              _CaptureCell(width: 150, child: Text('UPC')),
              _CaptureCell(width: 100, child: Text('Cant')),
              _CaptureCell(width: 90, child: Text('Usuario')),
              _CaptureCell(width: 220, child: Text('FCNR')),
              _CaptureCell(width: 90, child: Text('Almacén')),
            ],
          ),
        ),
      ),
    );
  }
}

class _CaptureCell extends StatelessWidget {
  const _CaptureCell({required this.width, required this.child});

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
