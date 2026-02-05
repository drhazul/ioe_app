import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../clientes/clientes_models.dart';
import '../../clientes/clientes_providers.dart';
import '../cotizaciones_models.dart';
import '../cotizaciones_providers.dart';
import 'cotizacion_local_state.dart';
import 'datart_models.dart';
import 'datart_providers.dart';
import 'jrq_models.dart';
import 'jrq_providers.dart';
import 'pvticketlog_models.dart';
import 'pvticketlog_providers.dart';

class DetalleCotPage extends ConsumerStatefulWidget {
  const DetalleCotPage({super.key, required this.idfol});

  final String idfol;

  @override
  ConsumerState<DetalleCotPage> createState() => _DetalleCotPageState();
}

class _DetalleCotPageState extends ConsumerState<DetalleCotPage> {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  final _sphCtrl = TextEditingController();
  final _cylCtrl = TextEditingController();
  final _adicCtrl = TextEditingController();
  String _searchBy = 'UPC';
  String _appliedSearchBy = 'UPC';
  String _searchTerm = '';
  double? _selectedDepa;
  double? _selectedSubd;
  double? _selectedClas;
  double? _selectedScla;
  double? _selectedScla2;
  double? _appliedDepa;
  double? _appliedSubd;
  double? _appliedClas;
  double? _appliedScla;
  double? _appliedScla2;
  double? _appliedSph;
  double? _appliedCyl;
  double? _appliedAdic;
  bool _didMergeRemote = false;
  bool _syncingPending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _requestSearchFocus());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _sphCtrl.dispose();
    _cylCtrl.dispose();
    _adicCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cotizacionAsync = ref.watch(cotizacionProvider(widget.idfol));
    final localState = ref.watch(cotizacionLocalProvider(widget.idfol));
    final ticketLogAsync = ref.watch(pvTicketLogListProvider(widget.idfol));
    ref.listen<AsyncValue<List<PvTicketLogItem>>>(
      pvTicketLogListProvider(widget.idfol),
      (prev, next) {
        next.whenData((items) async {
          if (_didMergeRemote) return;
          final remoteItems = items.map(_toLocalItem).toList();
          await ref.read(cotizacionLocalProvider(widget.idfol).notifier).mergeRemote(remoteItems);
          _didMergeRemote = true;
          _syncPendingItems();
        });
      },
    );

    return cotizacionAsync.when(
      data: (cot) => _buildScaffold(context, cot, localState, ticketLogAsync),
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    PvCtrFolAsvrModel cot,
    CotizacionLocalState localState,
    AsyncValue<List<PvTicketLogItem>> ticketLogAsync,
  ) {
    final clientesAsync = ref.watch(clientesListProvider);
    final razonSocial = cot.clien == null
        ? '-'
        : clientesAsync.when(
            data: (clientes) {
              final idc = cot.clien!.toDouble();
              final cliente = clientes.firstWhere(
                (c) => c.idc == idc,
                orElse: () => const FactClientShpModel(
                  idc: 0,
                  razonSocialReceptor: '-',
                  rfcReceptor: '-',
                  emailReceptor: '-',
                  rfcEmisor: '-',
                  usoCfdi: '-',
                  codigoPostalReceptor: '-',
                  regimenFiscalReceptor: 0,
                ),
              );
              return cliente.razonSocialReceptor.isEmpty ? '-' : cliente.razonSocialReceptor;
            },
            loading: () => 'Cargando...',
            error: (_, _) => '-',
          );
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF3B3B3B),
        foregroundColor: Colors.white,
        titleSpacing: 12,
        title: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: _InfoBarInline(
            cotizacion: cot,
            razonSocialReceptor: razonSocial,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Limpiar local',
            onPressed: localState.loading || ticketLogAsync.isLoading
                ? null
                : () => ref.read(cotizacionLocalProvider(widget.idfol).notifier).clearAll(),
            icon: const Icon(Icons.delete_sweep),
          ),
        ],
      ),
      body: _buildBody(context, cot, localState, razonSocial),
    );
  }

  Widget _buildBody(
    BuildContext context,
    PvCtrFolAsvrModel cot,
    CotizacionLocalState localState,
    String razonSocial,
  ) {
    final datArtQuery = DatArtQuery(
      suc: cot.suc ?? '',
      by: _appliedSearchBy,
      term: _searchTerm,
      depa: _appliedDepa,
      subd: _appliedSubd,
      clas: _appliedClas,
      scla: _appliedScla,
      scla2: _appliedScla2,
      sph: _appliedSph,
      cyl: _appliedCyl,
      adic: _appliedAdic,
    );
    final hasSearchCriteria = _searchTerm.trim().isNotEmpty ||
        _appliedDepa != null ||
        _appliedSubd != null ||
        _appliedClas != null ||
        _appliedScla != null ||
        _appliedScla2 != null ||
        _appliedSph != null ||
        _appliedCyl != null ||
        _appliedAdic != null;
    final datArtAsync = ref.watch(datArtListProvider(datArtQuery));
    final depaAsync = ref.watch(jrqDepaListProvider);
    final subdAsync = ref.watch(jrqSubdListProvider(_selectedDepa));
    final clasAsync = ref.watch(jrqClasListProvider(_selectedSubd));
    final sclaAsync = ref.watch(jrqSclaListProvider(_selectedClas));
    final scla2Async = ref.watch(jrqScla2ListProvider(_selectedScla));
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1100;
        final leftPanel = _LeftPanel(
          localState: localState,
          onRemove: _removeLocalItem,
          onEditQty: _editQuantity,
        );
        final rightPanel = _RightPanel(
          datArtAsync: datArtAsync,
          hasSearchCriteria: hasSearchCriteria,
          onAdd: _addFromDatArt,
        );
        final headerSearch = ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: _SearchHeaderPanel(
            searchCtrl: _searchCtrl,
            searchFocus: _searchFocus,
            searchBy: _searchBy,
            onSearchByChanged: (value) => setState(() => _searchBy = value ?? 'UPC'),
            depaAsync: depaAsync,
            subdAsync: subdAsync,
            clasAsync: clasAsync,
            sclaAsync: sclaAsync,
            scla2Async: scla2Async,
            selectedDepa: _selectedDepa,
            selectedSubd: _selectedSubd,
            selectedClas: _selectedClas,
            selectedScla: _selectedScla,
            selectedScla2: _selectedScla2,
            onDepaChanged: (value) {
              setState(() {
                _selectedDepa = value;
                _selectedSubd = null;
                _selectedClas = null;
                _selectedScla = null;
                _selectedScla2 = null;
              });
            },
            onSubdChanged: (value) {
              setState(() {
                _selectedSubd = value;
                _selectedClas = null;
                _selectedScla = null;
                _selectedScla2 = null;
              });
            },
            onClasChanged: (value) {
              setState(() {
                _selectedClas = value;
                _selectedScla = null;
                _selectedScla2 = null;
              });
            },
            onSclaChanged: (value) {
              setState(() {
                _selectedScla = value;
                _selectedScla2 = null;
              });
            },
            onScla2Changed: (value) => setState(() => _selectedScla2 = value),
            sphCtrl: _sphCtrl,
            cylCtrl: _cylCtrl,
            adicCtrl: _adicCtrl,
            onSearchApply: _applySearch,
            onClearSearch: _clearSearch,
          ),
        );

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _HeaderSection(
                          trailing: headerSearch,
                        ),
                        const SizedBox(height: 12),
                        rightPanel,
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: leftPanel),
                ],
              )
            else ...[
              _HeaderSection(
                trailing: headerSearch,
              ),
              const SizedBox(height: 12),
              rightPanel,
              const SizedBox(height: 12),
              leftPanel,
            ],
          ],
        );
      },
    );
  }

  void _applySearch() {
    final sph = _parseNumber(_sphCtrl.text);
    final cyl = _parseNumber(_cylCtrl.text);
    final adic = _parseNumber(_adicCtrl.text);
    setState(() {
      _searchTerm = _searchCtrl.text.trim();
      _appliedSearchBy = _searchBy;
      _appliedDepa = _selectedDepa;
      _appliedSubd = _selectedSubd;
      _appliedClas = _selectedClas;
      _appliedScla = _selectedScla;
      _appliedScla2 = _selectedScla2;
      _appliedSph = sph;
      _appliedCyl = cyl;
      _appliedAdic = adic;
    });
  }

  void _clearSearch() {
    _searchCtrl.clear();
    _sphCtrl.clear();
    _cylCtrl.clear();
    _adicCtrl.clear();
    setState(() {
      _searchBy = 'UPC';
      _appliedSearchBy = 'UPC';
      _searchTerm = '';
      _selectedDepa = null;
      _selectedSubd = null;
      _selectedClas = null;
      _selectedScla = null;
      _selectedScla2 = null;
      _appliedDepa = null;
      _appliedSubd = null;
      _appliedClas = null;
      _appliedScla = null;
      _appliedScla2 = null;
      _appliedSph = null;
      _appliedCyl = null;
      _appliedAdic = null;
    });
  }

  double? _parseNumber(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final normalized = trimmed.replaceAll(',', '.');
    return double.tryParse(normalized);
  }

  Future<void> _removeLocalItem(CotizacionLocalItem item) async {
    ref.read(cotizacionLocalProvider(widget.idfol).notifier).removeItem(item.id);
    if (item.syncStatus == SyncStatus.synced) {
      try {
        await ref.read(pvTicketLogApiProvider).remove(item.id);
        ref.invalidate(pvTicketLogListProvider(widget.idfol));
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No se pudo eliminar del ticket log: $e')),
          );
        }
      }
    }
  }

  Future<void> _markEditando() async {
    try {
      await ref.read(cotizacionesApiProvider).updateCotizacion(widget.idfol, {'ESTA': 'EDITANDO'});
      ref.invalidate(cotizacionProvider(widget.idfol));
      ref.invalidate(cotizacionesListProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo actualizar a EDITANDO: $e')),
        );
      }
    }
  }

  Future<void> _syncItem(CotizacionLocalItem item) async {
    if (item.syncStatus == SyncStatus.synced) return;
    try {
      final api = ref.read(pvTicketLogApiProvider);
      final payload = _toTicketLog(item);
      await api.create(payload);
      await ref.read(cotizacionLocalProvider(widget.idfol).notifier).setSyncStatus(
            item.id,
            SyncStatus.synced,
            error: null,
          );
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 409) {
        await ref.read(cotizacionLocalProvider(widget.idfol).notifier).setSyncStatus(
              item.id,
              SyncStatus.synced,
              error: null,
            );
        return;
      }
      await ref.read(cotizacionLocalProvider(widget.idfol).notifier).setSyncStatus(
            item.id,
            SyncStatus.error,
            error: e.toString(),
          );
    }
  }

  Future<void> _editQuantity(CotizacionLocalItem item) async {
    final nextQty = await _showQuantityDialog(item.ctd);
    if (nextQty == null) return;
    await ref.read(cotizacionLocalProvider(widget.idfol).notifier).updateItem(
          item.id,
          ctd: nextQty,
        );
    final updated = ref
        .read(cotizacionLocalProvider(widget.idfol))
        .items
        .firstWhere((e) => e.id == item.id, orElse: () => item);
    await ref.read(cotizacionLocalProvider(widget.idfol).notifier).setSyncStatus(
          item.id,
          SyncStatus.pending,
          error: null,
        );
    try {
      await _upsertTicketLog(updated);
      await ref.read(cotizacionLocalProvider(widget.idfol).notifier).setSyncStatus(
            item.id,
            SyncStatus.synced,
            error: null,
          );
    } catch (e) {
      await ref.read(cotizacionLocalProvider(widget.idfol).notifier).setSyncStatus(
            item.id,
            SyncStatus.error,
            error: e.toString(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo actualizar cantidad: $e')),
        );
      }
    }
  }

  Future<void> _upsertTicketLog(CotizacionLocalItem item) async {
    final api = ref.read(pvTicketLogApiProvider);
    final nextPvtat = item.pvta == null ? item.pvtat : item.ctd * item.pvta!;
    try {
      await api.update(item.id, {
        'CTD': item.ctd,
        'PVTAT': nextPvtat,
      });
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 404) {
        await api.create(_toTicketLog(item));
        return;
      }
      if (e is DioException && e.response?.statusCode == 409) {
        return;
      }
      rethrow;
    }
  }

  Future<double?> _showQuantityDialog(double current) async {
    final ctrl = TextEditingController(text: _formatQty(current));
    String? error;
    StateSetter? dialogSetState;
    return showDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Editar cantidad'),
          content: StatefulBuilder(
            builder: (context, setState) {
              dialogSetState = setState;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: ctrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Ej. 1 o 1.5',
                      errorText: error,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text('Solo enteros o incrementos de 0.5'),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final raw = ctrl.text.trim().replaceAll(',', '.');
                final value = double.tryParse(raw);
                if (value == null || value <= 0) {
                  error = 'Cantidad inválida';
                  dialogSetState?.call(() {});
                  return;
                }
                final doubleTimes2 = value * 2;
                final isHalfStep = (doubleTimes2 - doubleTimes2.round()).abs() < 0.0001;
                if (!isHalfStep) {
                  error = 'Solo enteros o .5';
                  dialogSetState?.call(() {});
                  return;
                }
                Navigator.of(context).pop(value);
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  String _formatQty(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2);
  }

  Future<void> _syncPendingItems() async {
    if (_syncingPending) return;
    _syncingPending = true;
    final items = ref.read(cotizacionLocalProvider(widget.idfol)).items;
    for (final item in items) {
      if (item.syncStatus != SyncStatus.synced) {
        await _syncItem(item);
      }
    }
    _syncingPending = false;
  }

  Future<void> _addFromDatArt(DatArtModel match) async {
    final wasEmpty = ref.read(cotizacionLocalProvider(widget.idfol)).items.isEmpty;
    final pvta = match.pvta;
    final pvtat = (pvta ?? 0) * 1;
    final item = CotizacionLocalItem(
      id: _generateUuid(),
      idfol: widget.idfol,
      upc: match.upc,
      art: match.art,
      des: match.des ?? 'No existe en el catalogo',
      ctd: 1,
      pvta: pvta,
      pvtat: pvtat,
      ord: null,
      updatedAt: DateTime.now(),
      syncStatus: SyncStatus.pending,
    );
    await ref.read(cotizacionLocalProvider(widget.idfol).notifier).addItem(item);
    if (wasEmpty) {
      await _markEditando();
    }
    await _syncItem(item);
    _requestSearchFocus();
  }

  void _requestSearchFocus() {
    if (!mounted) return;
    _searchFocus.requestFocus();
  }

  String _generateUuid() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String toHex(int value) => value.toRadixString(16).padLeft(2, '0');
    final b = bytes.map(toHex).toList();
    return '${b[0]}${b[1]}${b[2]}${b[3]}-${b[4]}${b[5]}-${b[6]}${b[7]}-${b[8]}${b[9]}-${b[10]}${b[11]}${b[12]}${b[13]}${b[14]}${b[15]}';
  }

  CotizacionLocalItem _toLocalItem(PvTicketLogItem item) {
    final qty = item.ctd ?? 0;
    final price = item.pvta ?? 0;
    return CotizacionLocalItem(
      id: item.id,
      idfol: item.idfol ?? widget.idfol,
      upc: item.upc,
      art: item.art,
      des: item.des,
      ctd: qty,
      pvta: item.pvta,
      pvtat: item.pvtat ?? (qty * price),
      ord: int.tryParse(item.ord ?? ''),
      iddev: item.iddev,
      ctdd: item.ctdd,
      ctddf: item.ctddf,
      updatedAt: item.updatedAt ?? DateTime.now(),
      syncStatus: SyncStatus.synced,
      syncError: null,
    );
  }

  PvTicketLogItem _toTicketLog(CotizacionLocalItem item) {
    return PvTicketLogItem(
      id: item.id,
      idfol: item.idfol,
      upc: item.upc,
      art: item.art,
      des: item.des,
      ctd: item.ctd,
      pvta: item.pvta,
      pvtat: item.pvtat,
      ord: item.ord?.toString(),
      iddev: item.iddev,
      ctdd: item.ctdd,
      ctddf: item.ctddf,
      updatedAt: item.updatedAt,
    );
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection({
    this.trailing,
  });

  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final headerColor = const Color(0xFF8FC1D4);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: headerColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (trailing != null) trailing!,
        ],
      ),
    );
  }

  static String _formatDateTime(DateTime? value) {
    if (value == null) return '-';
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$d/$m/$y';
  }

}

class _InfoBarInline extends StatelessWidget {
  const _InfoBarInline({
    required this.cotizacion,
    required this.razonSocialReceptor,
  });

  final PvCtrFolAsvrModel cotizacion;
  final String razonSocialReceptor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _InfoTile(label: 'Sucursal', value: cotizacion.suc ?? '-'),
        const SizedBox(width: 12),
        _InfoTile(label: 'Cotizacion', value: cotizacion.idfol),
        const SizedBox(width: 12),
        _InfoTile(label: 'Fecha', value: _HeaderSection._formatDateTime(cotizacion.fcn)),
        const SizedBox(width: 12),
        _InfoTile(label: 'Nombre OPV', value: cotizacion.opv ?? '-'),
        const SizedBox(width: 12),
        _InfoTile(label: 'N Cliente', value: cotizacion.clien?.toString() ?? '-'),
        const SizedBox(width: 12),
        _InfoTile(label: 'Nombre Cliente', value: razonSocialReceptor),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 90, maxWidth: 220),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
            ),
            child: SelectableText(
              value,
              maxLines: 1,
              style: const TextStyle(fontSize: 12, color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeftPanel extends StatelessWidget {
  const _LeftPanel({
    required this.localState,
    required this.onRemove,
    required this.onEditQty,
  });

  final CotizacionLocalState localState;
  final Future<void> Function(CotizacionLocalItem item) onRemove;
  final Future<void> Function(CotizacionLocalItem item) onEditQty;

  @override
  Widget build(BuildContext context) {
    final headerStyle = Theme.of(context).textTheme.titleSmall;
    final totalText = _formatMoney(localState.total);
    final sortedItems = [...localState.items]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    const rowsVisible = 10;
    const rowHeight = 34.0;
    const separatorHeight = 1.0;
    const listHeight = rowsVisible * rowHeight + (rowsVisible - 1) * separatorHeight;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total compra', style: headerStyle),
            const SizedBox(height: 8),
            Text('Pzs totales: ${_formatQty(localState.totalPiezas)}'),
            const SizedBox(height: 4),
            Text('Total: $totalText'),
            const SizedBox(height: 12),
            _TableHeader(
              columns: const ['DES', 'CTD', 'PVTA', 'PVTAT', 'ORD'],
              widths: const [240, 60, 80, 90, 60],
            ),
            const Divider(height: 1),
            if (localState.loading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (localState.items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Sin articulos agregados.'),
              )
            else
              SizedBox(
                height: listHeight,
                child: ListView.separated(
                  itemCount: sortedItems.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final item = sortedItems[index];
                    final pvtaText = item.pvta == null ? '-' : _formatMoney(item.pvta!);
                    final pvtatText = item.pvta == null ? '-' : _formatMoney(item.pvtat);
                    return SizedBox(
                      height: rowHeight,
                      child: _TableRow(
                        children: [
                          _TableCell(width: 240, child: Text(item.des ?? '-', overflow: TextOverflow.ellipsis)),
                          _TableCell(
                            width: 60,
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onDoubleTap: () => onEditQty(item),
                                child: Text(item.ctd.toStringAsFixed(2)),
                              ),
                            ),
                          ),
                          _TableCell(width: 80, child: Text(pvtaText)),
                          _TableCell(width: 90, child: Text(pvtatText)),
                          _TableCell(width: 60, child: Text(item.ord?.toString() ?? '-')),
                          IconButton(
                            tooltip: 'Quitar',
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => onRemove(item),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _formatMoney(double value) => '\$${value.toStringAsFixed(2)}';

  static String _formatQty(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2);
  }
}

class _RightPanel extends StatelessWidget {
  const _RightPanel({
    required this.datArtAsync,
    required this.hasSearchCriteria,
    required this.onAdd,
  });

  final AsyncValue<List<DatArtModel>> datArtAsync;
  final bool hasSearchCriteria;
  final ValueChanged<DatArtModel> onAdd;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TableHeader(
              columns: const ['ART', 'UPC', 'DES', 'STOCK', 'PVTA', ''],
              widths: const [80, 100, 240, 80, 70, 36],
            ),
            const Divider(height: 1),
            SizedBox(
              height: 240,
              child: !hasSearchCriteria
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Ingresa un criterio o selecciona filtros para ver articulos.'),
                    )
                  : datArtAsync.when(
                data: (items) {
                  if (items.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Sin articulos para la sucursal seleccionada.'),
                    );
                  }
                  return ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final item = items[index];
                      return _TableRow(
                        children: [
                          _TableCell(width: 80, child: Text(item.art)),
                          _TableCell(width: 100, child: Text(item.upc)),
                          _TableCell(
                            width: 260,
                            child: Text(item.des ?? '-', overflow: TextOverflow.ellipsis),
                          ),
                          _TableCell(
                            width: 80,
                            child: Text(item.stock?.toStringAsFixed(2) ?? '-'),
                          ),
                          _TableCell(
                            width: 70,
                            child: Text(item.pvta == null ? '-' : '\$${item.pvta!.toStringAsFixed(2)}'),
                          ),
                          IconButton(
                            tooltip: 'Agregar',
                            icon: const Icon(Icons.add_circle_outline, size: 18),
                            onPressed: () => onAdd(item),
                          ),
                        ],
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('Error al cargar DAT_ART: $e'),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _SearchHeaderPanel extends StatelessWidget {
  const _SearchHeaderPanel({
    required this.searchCtrl,
    required this.searchFocus,
    required this.searchBy,
    required this.onSearchByChanged,
    required this.depaAsync,
    required this.subdAsync,
    required this.clasAsync,
    required this.sclaAsync,
    required this.scla2Async,
    required this.selectedDepa,
    required this.selectedSubd,
    required this.selectedClas,
    required this.selectedScla,
    required this.selectedScla2,
    required this.onDepaChanged,
    required this.onSubdChanged,
    required this.onClasChanged,
    required this.onSclaChanged,
    required this.onScla2Changed,
    required this.sphCtrl,
    required this.cylCtrl,
    required this.adicCtrl,
    required this.onSearchApply,
    required this.onClearSearch,
  });

  final TextEditingController searchCtrl;
  final FocusNode searchFocus;
  final String searchBy;
  final ValueChanged<String?> onSearchByChanged;
  final AsyncValue<List<JrqDepaModel>> depaAsync;
  final AsyncValue<List<JrqSubdModel>> subdAsync;
  final AsyncValue<List<JrqClasModel>> clasAsync;
  final AsyncValue<List<JrqSclaModel>> sclaAsync;
  final AsyncValue<List<JrqScla2Model>> scla2Async;
  final double? selectedDepa;
  final double? selectedSubd;
  final double? selectedClas;
  final double? selectedScla;
  final double? selectedScla2;
  final ValueChanged<double?> onDepaChanged;
  final ValueChanged<double?> onSubdChanged;
  final ValueChanged<double?> onClasChanged;
  final ValueChanged<double?> onSclaChanged;
  final ValueChanged<double?> onScla2Changed;
  final TextEditingController sphCtrl;
  final TextEditingController cylCtrl;
  final TextEditingController adicCtrl;
  final VoidCallback onSearchApply;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    return _SearchFilters(
      searchCtrl: searchCtrl,
      searchFocus: searchFocus,
      searchBy: searchBy,
      onSearchByChanged: onSearchByChanged,
      depaAsync: depaAsync,
      subdAsync: subdAsync,
      clasAsync: clasAsync,
      sclaAsync: sclaAsync,
      scla2Async: scla2Async,
      selectedDepa: selectedDepa,
      selectedSubd: selectedSubd,
      selectedClas: selectedClas,
      selectedScla: selectedScla,
      selectedScla2: selectedScla2,
      onDepaChanged: onDepaChanged,
      onSubdChanged: onSubdChanged,
      onClasChanged: onClasChanged,
      onSclaChanged: onSclaChanged,
      onScla2Changed: onScla2Changed,
      sphCtrl: sphCtrl,
      cylCtrl: cylCtrl,
      adicCtrl: adicCtrl,
      onSearchApply: onSearchApply,
      onClearSearch: onClearSearch,
    );
  }
}

class _SearchFilters extends StatelessWidget {
  const _SearchFilters({
    required this.searchCtrl,
    required this.searchFocus,
    required this.searchBy,
    required this.onSearchByChanged,
    required this.depaAsync,
    required this.subdAsync,
    required this.clasAsync,
    required this.sclaAsync,
    required this.scla2Async,
    required this.selectedDepa,
    required this.selectedSubd,
    required this.selectedClas,
    required this.selectedScla,
    required this.selectedScla2,
    required this.onDepaChanged,
    required this.onSubdChanged,
    required this.onClasChanged,
    required this.onSclaChanged,
    required this.onScla2Changed,
    required this.sphCtrl,
    required this.cylCtrl,
    required this.adicCtrl,
    required this.onSearchApply,
    required this.onClearSearch,
  });

  final TextEditingController searchCtrl;
  final FocusNode searchFocus;
  final String searchBy;
  final ValueChanged<String?> onSearchByChanged;
  final AsyncValue<List<JrqDepaModel>> depaAsync;
  final AsyncValue<List<JrqSubdModel>> subdAsync;
  final AsyncValue<List<JrqClasModel>> clasAsync;
  final AsyncValue<List<JrqSclaModel>> sclaAsync;
  final AsyncValue<List<JrqScla2Model>> scla2Async;
  final double? selectedDepa;
  final double? selectedSubd;
  final double? selectedClas;
  final double? selectedScla;
  final double? selectedScla2;
  final ValueChanged<double?> onDepaChanged;
  final ValueChanged<double?> onSubdChanged;
  final ValueChanged<double?> onClasChanged;
  final ValueChanged<double?> onSclaChanged;
  final ValueChanged<double?> onScla2Changed;
  final TextEditingController sphCtrl;
  final TextEditingController cylCtrl;
  final TextEditingController adicCtrl;
  final VoidCallback onSearchApply;
  final VoidCallback onClearSearch;
  static const double _filterHeight = 28;
  static const double _filterFontSize = 12;
  static const EdgeInsets _filterPadding = EdgeInsets.symmetric(horizontal: 8, vertical: 6);
  static const double _filterMenuWidth = 260;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Buscar por:', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              SizedBox(
                width: 120,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  iconSize: 16,
                  style: const TextStyle(fontSize: _filterFontSize),
                  items: const [
                    DropdownMenuItem(value: 'ART', child: Text('ART', style: TextStyle(fontSize: _filterFontSize))),
                    DropdownMenuItem(value: 'UPC', child: Text('UPC', style: TextStyle(fontSize: _filterFontSize))),
                    DropdownMenuItem(value: 'DES', child: Text('DES', style: TextStyle(fontSize: _filterFontSize))),
                    DropdownMenuItem(value: 'MODELO', child: Text('MODELO', style: TextStyle(fontSize: _filterFontSize))),
                  ],
                  initialValue: searchBy,
                  onChanged: onSearchByChanged,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: _filterPadding,
                    constraints: BoxConstraints.tightFor(height: _filterHeight),
                  ),
                ),
              ),
              SizedBox(
                width: 140,
                child: TextField(
                  controller: searchCtrl,
                  focusNode: searchFocus,
                  onSubmitted: (_) => onSearchApply(),
                  style: const TextStyle(fontSize: _filterFontSize),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: _filterPadding,
                    constraints: BoxConstraints.tightFor(height: _filterHeight),
                    hintText: 'Digite o Escane',
                    hintStyle: TextStyle(fontSize: _filterFontSize),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _JrqDropdown<JrqDepaModel>(
                label: 'DEP',
                width: 80,
                asyncItems: depaAsync,
                value: selectedDepa,
                enabled: true,
                itemValue: (item) => item.depa,
                itemLabel: (item) => _formatOption(item.depa, item.ddepa),
                onChanged: onDepaChanged,
              ),
              _JrqDropdown<JrqSubdModel>(
                label: 'SDEP',
                width: 80,
                asyncItems: subdAsync,
                value: selectedSubd,
                enabled: selectedDepa != null,
                itemValue: (item) => item.subd,
                itemLabel: (item) => _formatOption(item.subd, item.dsubd),
                onChanged: onSubdChanged,
              ),
              _JrqDropdown<JrqClasModel>(
                label: 'CLS',
                width: 80,
                asyncItems: clasAsync,
                value: selectedClas,
                enabled: selectedSubd != null,
                itemValue: (item) => item.clas,
                itemLabel: (item) => _formatOption(item.clas, item.dclas),
                onChanged: onClasChanged,
              ),
              _JrqDropdown<JrqSclaModel>(
                label: 'SCLS',
                width: 80,
                asyncItems: sclaAsync,
                value: selectedScla,
                enabled: selectedClas != null,
                itemValue: (item) => item.scla,
                itemLabel: (item) => _formatOption(item.scla, item.dscla),
                onChanged: onSclaChanged,
              ),
              _JrqDropdown<JrqScla2Model>(
                label: 'SCLS2',
                width: 80,
                asyncItems: scla2Async,
                value: selectedScla2,
                enabled: selectedScla != null,
                itemValue: (item) => item.scla2,
                itemLabel: (item) => _formatOption(item.scla2, item.dscla2),
                onChanged: onScla2Changed,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _MiniField(label: 'SPH', controller: sphCtrl),
              _MiniField(label: 'CYL', controller: cylCtrl),
              _MiniField(label: 'ADIC', controller: adicCtrl),
              IconButton(
                tooltip: 'Buscar',
                onPressed: onSearchApply,
                icon: const Icon(Icons.search, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(width: _filterHeight, height: _filterHeight),
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                tooltip: 'Limpiar',
                onPressed: onClearSearch,
                icon: const Icon(Icons.clear, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(width: _filterHeight, height: _filterHeight),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatOption(double value, String? description) {
    final id = _formatNumber(value);
    final desc = (description ?? '').trim();
    if (desc.isEmpty) return id;
    return '$id - $desc';
  }

  static String _formatNumber(double value) {
    final intValue = value.toInt();
    if (value == intValue) return intValue.toString();
    return value.toString();
  }
}

class _MiniField extends StatelessWidget {
  const _MiniField({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 70,
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding: _SearchFilters._filterPadding,
          labelStyle: const TextStyle(fontSize: _SearchFilters._filterFontSize),
          constraints: const BoxConstraints.tightFor(height: _SearchFilters._filterHeight),
          border: const OutlineInputBorder(),
        ),
        style: const TextStyle(fontSize: _SearchFilters._filterFontSize),
      ),
    );
  }
}

class _JrqDropdown<T> extends StatelessWidget {
  const _JrqDropdown({
    required this.label,
    required this.width,
    required this.asyncItems,
    required this.value,
    required this.enabled,
    required this.itemValue,
    required this.itemLabel,
    required this.onChanged,
  });

  final String label;
  final double width;
  final AsyncValue<List<T>> asyncItems;
  final double? value;
  final bool enabled;
  final double Function(T) itemValue;
  final String Function(T) itemLabel;
  final ValueChanged<double?> onChanged;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final maxMenuWidth = screenWidth - 24;
    final menuWidth = min(
      maxMenuWidth,
      max(width, _SearchFilters._filterMenuWidth),
    );
    return SizedBox(
      width: width,
      child: asyncItems.when(
        data: (items) {
          final menuItems = <DropdownMenuItem<double?>>[
            const DropdownMenuItem<double?>(
              value: null,
              child: Text('', style: TextStyle(fontSize: _SearchFilters._filterFontSize)),
            ),
            ...items.map(
              (item) => DropdownMenuItem<double?>(
                value: itemValue(item),
                child: Text(
                  itemLabel(item),
                  overflow: TextOverflow.visible,
                  softWrap: true,
                  style: const TextStyle(fontSize: _SearchFilters._filterFontSize),
                ),
              ),
            ),
          ];
          final selectedWidgets = <Widget>[
            const Text('', style: TextStyle(fontSize: _SearchFilters._filterFontSize)),
            ...items.map(
              (item) => Text(
                itemLabel(item),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: _SearchFilters._filterFontSize),
              ),
            ),
          ];
          final hasValue = value != null && menuItems.any((item) => item.value == value);
          return _buildDropdown(
            context: context,
            menuItems: menuItems,
            selectedItemBuilder: (context) => selectedWidgets,
            value: hasValue ? value : null,
            enabled: enabled,
            menuWidth: menuWidth,
          );
        },
        loading: () => _buildDropdown(
          context: context,
          menuItems: const [
            DropdownMenuItem<double?>(
              value: null,
              child: Text('...', style: TextStyle(fontSize: _SearchFilters._filterFontSize)),
            ),
          ],
          value: null,
          enabled: false,
          menuWidth: menuWidth,
        ),
        error: (_, _) => _buildDropdown(
          context: context,
          menuItems: const [
            DropdownMenuItem<double?>(
              value: null,
              child: Text('Err', style: TextStyle(fontSize: _SearchFilters._filterFontSize)),
            ),
          ],
          value: null,
          enabled: false,
          menuWidth: menuWidth,
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required BuildContext context,
    required List<DropdownMenuItem<double?>> menuItems,
    DropdownButtonBuilder? selectedItemBuilder,
    required double? value,
    required bool enabled,
    required double menuWidth,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
        contentPadding: _SearchFilters._filterPadding,
        labelStyle: const TextStyle(fontSize: _SearchFilters._filterFontSize),
        constraints: const BoxConstraints.tightFor(height: _SearchFilters._filterHeight),
      ),
      isEmpty: value == null,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<double?>(
          key: ValueKey<double?>(value),
          isExpanded: true,
          iconSize: 16,
          value: value,
          items: menuItems,
          selectedItemBuilder: selectedItemBuilder,
          onChanged: enabled ? onChanged : null,
          style: const TextStyle(fontSize: _SearchFilters._filterFontSize),
          itemHeight: null,
          menuWidth: menuWidth,
          isDense: true,
        ),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader({required this.columns, required this.widths});

  final List<String> columns;
  final List<double> widths;

  @override
  Widget build(BuildContext context) {
    return _TableRow(
      children: [
        for (var i = 0; i < columns.length; i++)
          _TableCell(
            width: widths[i],
            child: Text(columns[i], style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
      ],
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: children),
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: DefaultTextStyle.merge(
          style: const TextStyle(fontSize: _SearchFilters._filterFontSize),
          child: child,
        ),
      ),
    );
  }
}
