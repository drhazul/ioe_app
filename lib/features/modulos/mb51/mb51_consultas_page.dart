import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ioe_app/core/api_error.dart';
import 'package:ioe_app/features/masterdata/sucursales/sucursales_models.dart';
import 'package:ioe_app/features/masterdata/sucursales/sucursales_providers.dart';
import 'package:ioe_app/features/modulos/catalogo/datart_models.dart';
import 'package:ioe_app/features/modulos/catalogo/datart_providers.dart';

import 'mb51_models.dart';
import 'mb51_providers.dart';

class Mb51ConsultasPage extends ConsumerStatefulWidget {
  const Mb51ConsultasPage({super.key});

  @override
  ConsumerState<Mb51ConsultasPage> createState() => _Mb51ConsultasPageState();
}

class _Mb51ConsultasPageState extends ConsumerState<Mb51ConsultasPage> {
  final _artCtrl = TextEditingController();
  final _docCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _txtCtrl = TextEditingController();

  DateTimeRange? _docRange;
  DateTimeRange? _contRange;
  bool _syncingArt = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _resetFilters(notify: false, clearAppState: true);
    });
  }

  @override
  void dispose() {
    _artCtrl.dispose();
    _docCtrl.dispose();
    _userCtrl.dispose();
    _txtCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDocRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _docRange,
    );
    if (!mounted) return;
    if (range != null) {
      setState(() => _docRange = range);
    }
  }

  Future<void> _pickContRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _contRange,
    );
    if (!mounted) return;
    if (range != null) {
      setState(() => _contRange = range);
    }
  }

  void _clearFilters() {
    _resetFilters();
  }

  void _buscar() {
    final selectedSucs = _normalizeList(ref.read(mb51SelectedSucsProvider));
    final selectedArts = _normalizeList(ref.read(mb51SelectedArtsProvider));
    final selectedAlmacenes = _normalizeList(ref.read(mb51SelectedAlmacenesProvider));
    final selectedClsms = _normalizeNumList(ref.read(mb51SelectedClsmsProvider));

    final artSingle = selectedArts.length == 1 ? selectedArts.first : _norm(_artCtrl.text);
    final artsList = selectedArts.length > 1 ? selectedArts : null;
    final sucSingle = selectedSucs.length == 1 ? selectedSucs.first : null;
    final sucsList = selectedSucs.length > 1 ? selectedSucs : null;
    final almacenSingle = selectedAlmacenes.length == 1 ? selectedAlmacenes.first : null;
    final almacenesList = selectedAlmacenes.length > 1 ? selectedAlmacenes : null;
    final clsmSingle = selectedClsms.length == 1 ? selectedClsms.first : null;
    final clsmsList = selectedClsms.length > 1 ? selectedClsms : null;

    final filtros = Mb51Filtros(
      fechaDocDesde: _docRange?.start,
      fechaDocHasta: _docRange?.end,
      fechaContDesde: _contRange?.start,
      fechaContHasta: _contRange?.end,
      art: artSingle,
      arts: artsList,
      docp: _norm(_docCtrl.text),
      almacen: almacenSingle,
      almacenes: almacenesList,
      suc: sucSingle,
      sucs: sucsList,
      clsm: clsmSingle,
      clsms: clsmsList,
      user: _norm(_userCtrl.text),
      txt: _norm(_txtCtrl.text),
    );

    ref.read(mb51FiltrosProvider.notifier).state = filtros;

    if (!mounted) return;
    context.go('/mb51/resultados', extra: filtros.toJson());
  }

  String? _norm(String? value) {
    final trimmed = (value ?? '').trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String _fmtRange(DateTimeRange? range) {
    if (range == null) return 'Sin rango';
    final start = _fmtDate(range.start);
    final end = _fmtDate(range.end);
    return '$start - $end';
  }

  String _fmtDate(DateTime value) {
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$d/$m/$y';
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _sucLabel(SucursalModel s) {
    final desc = (s.desc ?? '').trim();
    return desc.isEmpty ? s.suc : '${s.suc} - $desc';
  }

  void _resetFilters({bool notify = true, bool clearAppState = true}) {
    if (notify) {
      setState(() {
        _docRange = null;
        _contRange = null;
      });
    } else {
      _docRange = null;
      _contRange = null;
    }
    _artCtrl.clear();
    _docCtrl.clear();
    _userCtrl.clear();
    _txtCtrl.clear();
    if (clearAppState) {
      ref.read(mb51SelectedSucsProvider.notifier).state = const [];
      ref.read(mb51SelectedArtsProvider.notifier).state = const [];
      ref.read(mb51SelectedAlmacenesProvider.notifier).state = const [];
      ref.read(mb51SelectedClsmsProvider.notifier).state = const [];
    }
  }

  List<String> _normalizeList(List<String> list) {
    final values = list.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    return values;
  }

  List<double> _normalizeNumList(List<double> list) {
    final values = list.where((e) => e.isFinite).toList();
    return values;
  }

  Future<void> _openMultiSelectDialog<T>({
    required String title,
    required List<_MultiOption<T>> options,
    required List<T> selected,
    required ValueChanged<List<T>> onApply,
  }) async {
    final result = await showDialog<List<T>>(
      context: context,
      builder: (context) {
        var query = '';
        final selectedSet = <T>{...selected};
        final dialogWidth = MediaQuery.of(context).size.width * 0.9;
        final dialogHeight = MediaQuery.of(context).size.height * 0.7;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filtered = options.where((opt) {
              if (query.trim().isEmpty) return true;
              final q = query.toLowerCase();
              final label = opt.label.toLowerCase();
              final value = opt.value.toString().toLowerCase();
              return label.contains(q) || value.contains(q);
            }).toList();

            return AlertDialog(
              title: Text(title),
              content: SizedBox(
                width: dialogWidth > 560 ? 560 : dialogWidth,
                height: dialogHeight,
                child: Column(
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Buscar',
                        border: OutlineInputBorder(),
                        isDense: true,
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) => setDialogState(() => query = value),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(child: Text('Sin opciones'))
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final opt = filtered[index];
                                final checked = selectedSet.contains(opt.value);
                                return CheckboxListTile(
                                  value: checked,
                                  controlAffinity: ListTileControlAffinity.leading,
                                  title: Text(opt.label),
                                  onChanged: (value) {
                                    setDialogState(() {
                                      if (value == true) {
                                        selectedSet.add(opt.value);
                                      } else {
                                        selectedSet.remove(opt.value);
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, <T>[]),
                  child: const Text('Limpiar'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, selectedSet.toList()),
                  child: const Text('Aplicar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted) return;
    if (result != null) {
      onApply(result);
    }
  }

  Future<void> _openArtSearchDialog({
    required List<String> selected,
    required ValueChanged<List<String>> onApply,
  }) async {
    final api = ref.read(datArtApiProvider);
    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) {
        final selectedSet = <String>{...selected};
        final searchCtrl = TextEditingController();
        var loading = false;
        var items = <DatArtModel>[];

        Future<void> runSearch(StateSetter setDialogState) async {
          final query = searchCtrl.text.trim();
          if (query.isEmpty) return;
          setDialogState(() => loading = true);
          try {
            final results = await Future.wait([
              api.fetchArticulos(art: query, page: 1, limit: 50),
              api.fetchArticulos(upc: query, page: 1, limit: 50),
              api.fetchArticulos(des: query, page: 1, limit: 50),
            ]);
            final merged = <String, DatArtModel>{};
            for (final list in results) {
              for (final item in list) {
                final art = item.art.trim();
                if (art.isEmpty) continue;
                final existing = merged[art];
                if (existing == null) {
                  merged[art] = item;
                  continue;
                }
                final existingDes = (existing.des ?? '').trim();
                final newDes = (item.des ?? '').trim();
                final existingUpc = existing.upc.trim();
                final newUpc = item.upc.trim();
                if (existingDes.isEmpty && newDes.isNotEmpty) {
                  merged[art] = item;
                } else if (existingUpc.isEmpty && newUpc.isNotEmpty) {
                  merged[art] = item;
                }
              }
            }
            final list = merged.values.toList()
              ..sort((a, b) => a.art.toLowerCase().compareTo(b.art.toLowerCase()));
            setDialogState(() => items = list);
          } catch (_) {
            setDialogState(() => items = []);
          } finally {
            setDialogState(() => loading = false);
          }
        }

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Seleccionar artículos'),
              content: SizedBox(
                width: 560,
                height: 460,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: searchCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Buscar ART / UPC / DES',
                              border: OutlineInputBorder(),
                              isDense: true,
                              prefixIcon: Icon(Icons.search),
                            ),
                            onSubmitted: (_) => runSearch(setDialogState),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: loading ? null : () => runSearch(setDialogState),
                          child: const Text('Buscar'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () {
                            final value = searchCtrl.text.trim();
                            if (value.isEmpty) return;
                            setDialogState(() => selectedSet.add(value));
                          },
                          child: const Text('Agregar'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (loading) const LinearProgressIndicator(),
                    const SizedBox(height: 8),
                    Expanded(
                      child: items.isEmpty
                          ? const Center(child: Text('Sin resultados'))
                          : ListView.builder(
                              itemCount: items.length,
                              itemBuilder: (context, index) {
                                final item = items[index];
                                final art = item.art.trim();
                                if (art.isEmpty) return const SizedBox.shrink();
                                final upc = item.upc.trim();
                                final des = (item.des ?? '').trim();
                                final parts = <String>[art];
                                if (upc.isNotEmpty) parts.add(upc);
                                if (des.isNotEmpty) parts.add(des);
                                final label = parts.join(' - ');
                                final checked = selectedSet.contains(art);
                                return CheckboxListTile(
                                  value: checked,
                                  controlAffinity: ListTileControlAffinity.leading,
                                  title: Text(label),
                                  secondary: IconButton(
                                    tooltip: 'Agregar ART',
                                    onPressed: () => setDialogState(() => selectedSet.add(art)),
                                    icon: Icon(
                                      Icons.add_circle,
                                      color: checked ? Colors.green : null,
                                    ),
                                  ),
                                  onChanged: (value) {
                                    setDialogState(() {
                                      if (value == true) {
                                        selectedSet.add(art);
                                      } else {
                                        selectedSet.remove(art);
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'ART seleccionados (${selectedSet.length})',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 64,
                      child: selectedSet.isEmpty
                          ? const Align(
                              alignment: Alignment.centerLeft,
                              child: Text('Sin artículos seleccionados'),
                            )
                          : SingleChildScrollView(
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: (selectedSet.toList()..sort())
                                    .map(
                                      (art) => InputChip(
                                        label: Text(art),
                                        onDeleted: () => setDialogState(() => selectedSet.remove(art)),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, <String>[]),
                  child: const Text('Limpiar'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, selectedSet.toList()),
                  child: const Text('Aplicar'),
                ),
              ],
            );
          },
        );
      },
    );
    if (!mounted) return;
    if (result != null) {
      onApply(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<List<DatAlmacenModel>>>(almacenCatalogProvider, (prev, next) {
      if (next.hasError && !(prev?.hasError ?? false)) {
        _showSnack('Error almacenes: ${apiErrorMessage(next.error!)}');
      }
    });
    ref.listen<AsyncValue<List<DatCmovModel>>>(cmovCatalogProvider, (prev, next) {
      if (next.hasError && !(prev?.hasError ?? false)) {
        _showSnack('Error clases: ${apiErrorMessage(next.error!)}');
      }
    });
    ref.listen<AsyncValue<List<SucursalModel>>>(sucursalesListProvider, (prev, next) {
      if (next.hasError && !(prev?.hasError ?? false)) {
        _showSnack('Error sucursales: ${apiErrorMessage(next.error!)}');
      }
    });
    ref.listen<List<String>>(mb51SelectedArtsProvider, (prev, next) {
      final nextText = next.isNotEmpty ? next.first : '';
      if (_artCtrl.text != nextText) {
        _syncingArt = true;
        _artCtrl.text = nextText;
        _artCtrl.selection = TextSelection.fromPosition(TextPosition(offset: _artCtrl.text.length));
        _syncingArt = false;
      }
    });

    final almacenesAsync = ref.watch(almacenCatalogProvider);
    final cmovAsync = ref.watch(cmovCatalogProvider);
    final sucursalesAsync = ref.watch(sucursalesListProvider);
    final selectedSucs = ref.watch(mb51SelectedSucsProvider);
    final selectedArts = ref.watch(mb51SelectedArtsProvider);
    final selectedAlmacenes = ref.watch(mb51SelectedAlmacenesProvider);
    final selectedClsms = ref.watch(mb51SelectedClsmsProvider);

    final almacenes = almacenesAsync.asData?.value ?? const <DatAlmacenModel>[];
    final cmov = cmovAsync.asData?.value ?? const <DatCmovModel>[];
    final sucursales = sucursalesAsync.asData?.value ?? const <SucursalModel>[];

    final sucSelected = selectedSucs.isNotEmpty ? selectedSucs.first : null;
    final almacenSelected = selectedAlmacenes.isNotEmpty ? selectedAlmacenes.first : null;
    final clsmSelected = selectedClsms.isNotEmpty ? selectedClsms.first : null;

    final almacenValue = almacenes.any((a) => a.almacen == almacenSelected) ? almacenSelected : null;
    final clsmValue = cmov.any((c) => c.clsm == clsmSelected) ? clsmSelected : null;
    final sucValue = sucursales.any((s) => s.suc == sucSelected) ? sucSelected : null;

    final almacenHelper = almacenesAsync.isLoading
        ? 'Cargando almacenes...'
        : almacenesAsync.hasError
            ? 'Error al cargar almacenes'
            : null;

    final cmovHelper = cmovAsync.isLoading
        ? 'Cargando clases...'
        : cmovAsync.hasError
            ? 'Error al cargar clases'
            : null;
    final sucHelper = sucursalesAsync.isLoading
        ? 'Cargando sucursales...'
        : sucursalesAsync.hasError
            ? 'Error al cargar sucursales'
            : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('MB51 - Criterios'),
        actions: [
          IconButton(
            tooltip: 'Refrescar catálogos',
            onPressed: () {
              ref.invalidate(almacenCatalogProvider);
              ref.invalidate(cmovCatalogProvider);
              ref.invalidate(sucursalesListProvider);
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth > 900 ? 2 : 1;
          const spacing = 12.0;
          final fieldWidth = columns == 1
              ? constraints.maxWidth
              : (constraints.maxWidth - spacing) / columns;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: [
                        SizedBox(
                          width: fieldWidth,
                          child: DropdownButtonFormField<String?>(
                            key: ValueKey(sucValue),
                            initialValue: sucValue,
                            decoration: InputDecoration(
                              labelText: 'Sucursal (SUC)',
                              border: const OutlineInputBorder(),
                              isDense: true,
                              helperText: sucHelper,
                              suffixIcon: IconButton(
                                tooltip: 'Selección múltiple',
                                onPressed: sucursales.isEmpty
                                    ? null
                                    : () async {
                                        final options = sucursales
                                            .where((s) => s.suc.trim().isNotEmpty)
                                            .map((s) => _MultiOption<String>(s.suc, _sucLabel(s)))
                                            .toList();
                                        await _openMultiSelectDialog<String>(
                                          title: 'Seleccionar sucursales',
                                          options: options,
                                          selected: selectedSucs,
                                          onApply: (values) {
                                            ref.read(mb51SelectedSucsProvider.notifier).state = values;
                                          },
                                        );
                                      },
                                icon: Icon(
                                  Icons.playlist_add,
                                  color: selectedSucs.length > 1 ? Colors.orange : null,
                                ),
                              ),
                            ),
                            items: [
                              const DropdownMenuItem<String?>(value: null, child: Text('Todas')),
                              for (final s in sucursales)
                                if (s.suc.trim().isNotEmpty)
                                  DropdownMenuItem<String?>(
                                    value: s.suc,
                                    child: Text(_sucLabel(s), overflow: TextOverflow.ellipsis),
                                  ),
                            ],
                            onChanged: sucursalesAsync.isLoading
                                ? null
                                : (value) {
                                    ref.read(mb51SelectedSucsProvider.notifier).state = value == null ? const [] : [value];
                                  },
                          ),
                        ),
                        SizedBox(
                          width: fieldWidth,
                          child: TextField(
                            controller: _artCtrl,
                            onChanged: (value) {
                              if (_syncingArt) return;
                              final trimmed = value.trim();
                              ref.read(mb51SelectedArtsProvider.notifier).state =
                                  trimmed.isEmpty ? const [] : [trimmed];
                            },
                            decoration: InputDecoration(
                              labelText: 'Artículo (ART)',
                              border: OutlineInputBorder(),
                              isDense: true,
                              suffixIcon: IconButton(
                                tooltip: 'Selección múltiple',
                                onPressed: () async {
                                  await _openArtSearchDialog(
                                    selected: selectedArts,
                                    onApply: (values) {
                                      ref.read(mb51SelectedArtsProvider.notifier).state = values;
                                    },
                                  );
                                },
                                icon: Icon(
                                  Icons.playlist_add,
                                  color: selectedArts.length > 1 ? Colors.orange : null,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: fieldWidth,
                          child: DropdownButtonFormField<String?>(
                            key: ValueKey(almacenValue),
                            initialValue: almacenValue,
                            decoration: InputDecoration(
                              labelText: 'Almacén',
                              border: const OutlineInputBorder(),
                              isDense: true,
                              helperText: almacenHelper,
                              suffixIcon: IconButton(
                                tooltip: 'Selección múltiple',
                                onPressed: almacenes.isEmpty
                                    ? null
                                    : () async {
                                        final options = almacenes
                                            .where((a) => a.almacen.trim().isNotEmpty)
                                            .map((a) => _MultiOption<String>(a.almacen, a.label))
                                            .toList();
                                        await _openMultiSelectDialog<String>(
                                          title: 'Seleccionar almacenes',
                                          options: options,
                                          selected: selectedAlmacenes,
                                          onApply: (values) {
                                            ref.read(mb51SelectedAlmacenesProvider.notifier).state = values;
                                          },
                                        );
                                      },
                                icon: Icon(
                                  Icons.playlist_add,
                                  color: selectedAlmacenes.length > 1 ? Colors.orange : null,
                                ),
                              ),
                            ),
                            items: [
                              const DropdownMenuItem<String?>(value: null, child: Text('Todos')),
                              for (final a in almacenes)
                                if (a.almacen.trim().isNotEmpty)
                                  DropdownMenuItem<String?>(
                                    value: a.almacen,
                                    child: Text(a.label, overflow: TextOverflow.ellipsis),
                                  ),
                            ],
                            onChanged: almacenesAsync.isLoading
                                ? null
                                : (value) {
                                    ref.read(mb51SelectedAlmacenesProvider.notifier).state =
                                        value == null ? const [] : [value];
                                  },
                          ),
                        ),
                        SizedBox(
                          width: fieldWidth,
                          child: DropdownButtonFormField<double?>(
                            key: ValueKey(clsmValue),
                            initialValue: clsmValue,
                            decoration: InputDecoration(
                              labelText: 'Clase de movimiento (CLSM)',
                              border: const OutlineInputBorder(),
                              isDense: true,
                              helperText: cmovHelper,
                              suffixIcon: IconButton(
                                tooltip: 'Selección múltiple',
                                onPressed: cmov.isEmpty
                                    ? null
                                    : () async {
                                        final options = cmov
                                            .where((c) => c.clsm != null)
                                            .map((c) => _MultiOption<double>(c.clsm!, c.label))
                                            .toList();
                                        await _openMultiSelectDialog<double>(
                                          title: 'Seleccionar clases de movimiento',
                                          options: options,
                                          selected: selectedClsms,
                                          onApply: (values) {
                                            ref.read(mb51SelectedClsmsProvider.notifier).state = values;
                                          },
                                        );
                                      },
                                icon: Icon(
                                  Icons.playlist_add,
                                  color: selectedClsms.length > 1 ? Colors.orange : null,
                                ),
                              ),
                            ),
                            items: [
                              const DropdownMenuItem<double?>(value: null, child: Text('Todas')),
                              for (final c in cmov)
                                if (c.clsm != null)
                                  DropdownMenuItem<double?>(
                                    value: c.clsm,
                                    child: Text(c.label, overflow: TextOverflow.ellipsis),
                                  ),
                            ],
                            onChanged: cmovAsync.isLoading
                                ? null
                                : (value) {
                                    ref.read(mb51SelectedClsmsProvider.notifier).state =
                                        value == null ? const [] : [value];
                                  },
                          ),
                        ),
                        SizedBox(
                          width: fieldWidth,
                          child: TextField(
                            controller: _userCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Usuario (USER)',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: fieldWidth,
                          child: TextField(
                            controller: _docCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Documento (DOCP)',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: fieldWidth,
                          child: _RangeField(
                            label: 'Fecha documento (FCND)',
                            value: _fmtRange(_docRange),
                            onPick: _pickDocRange,
                            onClear: _docRange == null ? null : () => setState(() => _docRange = null),
                          ),
                        ),
                        SizedBox(
                          width: fieldWidth,
                          child: _RangeField(
                            label: 'Fecha contabilización (FCNC)',
                            value: _fmtRange(_contRange),
                            onPick: _pickContRange,
                            onClear: _contRange == null ? null : () => setState(() => _contRange = null),
                          ),
                        ),
                        SizedBox(
                          width: fieldWidth,
                          child: TextField(
                            controller: _txtCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Texto (TXT)',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _clearFilters,
                          icon: const Icon(Icons.clear),
                          label: const Text('Limpiar'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: _buscar,
                          icon: const Icon(Icons.search),
                          label: const Text('Buscar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RangeField extends StatelessWidget {
  const _RangeField({
    required this.label,
    required this.value,
    required this.onPick,
    this.onClear,
  });

  final String label;
  final String value;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPick,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
          suffixIcon: onClear == null
              ? const Icon(Icons.date_range)
              : IconButton(
                  onPressed: onClear,
                  icon: const Icon(Icons.clear),
                  tooltip: 'Limpiar',
                ),
        ),
        child: Text(value),
      ),
    );
  }
}

class _MultiOption<T> {
  final T value;
  final String label;

  const _MultiOption(this.value, this.label);
}
