import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ioe_app/core/api_error.dart';
import 'package:ioe_app/features/masterdata/sucursales/sucursales_models.dart';
import 'package:ioe_app/features/masterdata/sucursales/sucursales_providers.dart';
import 'package:ioe_app/features/modulos/catalogo/datart_models.dart';
import 'package:ioe_app/features/modulos/catalogo/datart_providers.dart';

import 'mb52_models.dart';
import 'mb52_providers.dart';

class Mb52ConsultasPage extends ConsumerStatefulWidget {
  const Mb52ConsultasPage({super.key});

  @override
  ConsumerState<Mb52ConsultasPage> createState() => _Mb52ConsultasPageState();
}

class _Mb52ConsultasPageState extends ConsumerState<Mb52ConsultasPage> {
  final _artCtrl = TextEditingController();
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
    super.dispose();
  }

  void _clearFilters() {
    _resetFilters();
  }

  void _buscar() {
    final selectedSucs = _normalizeList(ref.read(mb52SelectedSucsProvider));
    final selectedArts = _normalizeList(ref.read(mb52SelectedArtsProvider));
    final selectedAlmacenes = _normalizeList(ref.read(mb52SelectedAlmacenesProvider));

    final filtros = Mb52Filtros(
      sucs: selectedSucs.isEmpty ? null : selectedSucs,
      arts: selectedArts.isEmpty ? null : selectedArts,
      almacenes: selectedAlmacenes.isEmpty ? null : selectedAlmacenes,
    );

    ref.read(mb52FiltrosProvider.notifier).state = filtros;

    if (!mounted) return;
    context.go('/mb52/resultados', extra: filtros.toJson());
  }

  void _resetFilters({bool notify = true, bool clearAppState = true}) {
    if (notify) {
      setState(() {});
    }
    _artCtrl.clear();
    if (clearAppState) {
      ref.read(mb52SelectedSucsProvider.notifier).state = const [];
      ref.read(mb52SelectedArtsProvider.notifier).state = const [];
      ref.read(mb52SelectedAlmacenesProvider.notifier).state = const [];
    }
  }

  List<String> _normalizeList(List<String> list) {
    return list.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _sucLabel(SucursalModel s) {
    final desc = (s.desc ?? '').trim();
    return desc.isEmpty ? s.suc : '${s.suc} - $desc';
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
    ref.listen<AsyncValue<List<DatAlmacenModel>>>(mb52AlmacenCatalogProvider, (prev, next) {
      if (next.hasError && !(prev?.hasError ?? false)) {
        _showSnack('Error almacenes: ${apiErrorMessage(next.error!)}');
      }
    });
    ref.listen<AsyncValue<List<SucursalModel>>>(sucursalesListProvider, (prev, next) {
      if (next.hasError && !(prev?.hasError ?? false)) {
        _showSnack('Error sucursales: ${apiErrorMessage(next.error!)}');
      }
    });
    ref.listen<List<String>>(mb52SelectedArtsProvider, (prev, next) {
      final nextText = next.isNotEmpty ? next.first : '';
      if (_artCtrl.text != nextText) {
        _syncingArt = true;
        _artCtrl.text = nextText;
        _artCtrl.selection = TextSelection.fromPosition(TextPosition(offset: _artCtrl.text.length));
        _syncingArt = false;
      }
    });

    final almacenesAsync = ref.watch(mb52AlmacenCatalogProvider);
    final sucursalesAsync = ref.watch(sucursalesListProvider);
    final selectedSucs = ref.watch(mb52SelectedSucsProvider);
    final selectedArts = ref.watch(mb52SelectedArtsProvider);
    final selectedAlmacenes = ref.watch(mb52SelectedAlmacenesProvider);

    final almacenes = almacenesAsync.asData?.value ?? const <DatAlmacenModel>[];
    final sucursales = sucursalesAsync.asData?.value ?? const <SucursalModel>[];

    final sucSelected = selectedSucs.isNotEmpty ? selectedSucs.first : null;
    final almacenSelected = selectedAlmacenes.isNotEmpty ? selectedAlmacenes.first : null;

    final sucValue = sucursales.any((s) => s.suc == sucSelected) ? sucSelected : null;
    final almacenValue = almacenes.any((a) => a.almacen == almacenSelected) ? almacenSelected : null;

    final almacenHelper = almacenesAsync.isLoading
        ? 'Cargando almacenes...'
        : almacenesAsync.hasError
            ? 'Error al cargar almacenes'
            : null;
    final sucHelper = sucursalesAsync.isLoading
        ? 'Cargando sucursales...'
        : sucursalesAsync.hasError
            ? 'Error al cargar sucursales'
            : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('MB52 - Criterios'),
        actions: [
          IconButton(
            tooltip: 'Refrescar catálogos',
            onPressed: () {
              ref.invalidate(mb52AlmacenCatalogProvider);
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
                                            ref.read(mb52SelectedSucsProvider.notifier).state = values;
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
                                    ref.read(mb52SelectedSucsProvider.notifier).state =
                                        value == null ? const [] : [value];
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
                              ref.read(mb52SelectedArtsProvider.notifier).state =
                                  trimmed.isEmpty ? const [] : [trimmed];
                            },
                            decoration: InputDecoration(
                              labelText: 'Artículo (ART)',
                              border: const OutlineInputBorder(),
                              isDense: true,
                              suffixIcon: IconButton(
                                tooltip: 'Selección múltiple',
                                onPressed: () async {
                                  await _openArtSearchDialog(
                                    selected: selectedArts,
                                    onApply: (values) {
                                      ref.read(mb52SelectedArtsProvider.notifier).state = values;
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
                                            ref.read(mb52SelectedAlmacenesProvider.notifier).state = values;
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
                                    ref.read(mb52SelectedAlmacenesProvider.notifier).state =
                                        value == null ? const [] : [value];
                                  },
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

class _MultiOption<T> {
  final T value;
  final String label;

  const _MultiOption(this.value, this.label);
}
