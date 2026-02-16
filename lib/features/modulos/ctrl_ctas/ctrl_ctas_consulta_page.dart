import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ioe_app/core/api_error.dart';
import 'package:ioe_app/features/masterdata/sucursales/sucursales_models.dart';
import 'package:ioe_app/features/masterdata/sucursales/sucursales_providers.dart';

import 'ctrl_ctas_models.dart';
import 'ctrl_ctas_providers.dart';

class CtrlCtasConsultaPage extends ConsumerStatefulWidget {
  const CtrlCtasConsultaPage({super.key});

  @override
  ConsumerState<CtrlCtasConsultaPage> createState() => _CtrlCtasConsultaPageState();
}

class _CtrlCtasConsultaPageState extends ConsumerState<CtrlCtasConsultaPage> {
  final _clsdCtrl = TextEditingController();
  final _idfolCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(ctrlCtasFiltrosProvider.notifier).reset();
    });
  }

  @override
  void dispose() {
    _clsdCtrl.dispose();
    _idfolCtrl.dispose();
    super.dispose();
  }

  Color _multiIconColor(BuildContext context, int count, {bool enabled = true}) {
    if (!enabled) return Theme.of(context).disabledColor;
    return count > 1 ? Colors.orange : Theme.of(context).colorScheme.primary;
  }

  String _sucLabel(SucursalModel suc) {
    final desc = (suc.desc ?? '').trim();
    return desc.isEmpty ? suc.suc : '${suc.suc} - $desc';
  }

  String _fmtDate(DateTime? value) {
    if (value == null) return '-';
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$d/$m/$y';
  }

  Future<void> _pickDateRange(CtrlCtasFiltros filtros) async {
    final initial = filtros.fecIni != null && filtros.fecFin != null
        ? DateTimeRange(start: filtros.fecIni!, end: filtros.fecFin!)
        : null;

    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: initial,
    );

    if (!mounted) return;
    if (range == null) return;
    final notifier = ref.read(ctrlCtasFiltrosProvider.notifier);
    notifier.setFecIni(range.start);
    notifier.setFecFin(range.end);
  }

  void _addChipValue({
    required String raw,
    required List<String> current,
    required ValueChanged<List<String>> onSet,
    TextEditingController? clearController,
  }) {
    final value = raw.trim();
    if (value.isEmpty) return;
    final next = <String>{...current, value}.toList();
    onSet(next);
    clearController?.clear();
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

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filtered = options.where((opt) {
              if (query.trim().isEmpty) return true;
              final q = query.toLowerCase();
              return opt.label.toLowerCase().contains(q) || opt.value.toString().toLowerCase().contains(q);
            }).toList();

            return AlertDialog(
              title: Text(title),
              content: SizedBox(
                width: 560,
                height: 480,
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
                                final option = filtered[index];
                                final checked = selectedSet.contains(option.value);
                                return CheckboxListTile(
                                  value: checked,
                                  controlAffinity: ListTileControlAffinity.leading,
                                  title: Text(option.label),
                                  onChanged: (value) {
                                    setDialogState(() {
                                      if (value == true) {
                                        selectedSet.add(option.value);
                                      } else {
                                        selectedSet.remove(option.value);
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
                TextButton(onPressed: () => Navigator.pop(context, <T>[]), child: const Text('Limpiar')),
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
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
    final filtros = ref.watch(ctrlCtasFiltrosProvider);
    final configAsync = ref.watch(ctrlCtasConfigProvider);
    final sucursalesAsync = ref.watch(sucursalesListProvider);
    final ctasAsync = ref.watch(catCtasProvider(CtrlCatalogParams(sucs: filtros.sucs)));
    final clientesAsync = ref.watch(clientesProvider(CtrlCatalogParams(sucs: filtros.sucs)));

    ref.listen<AsyncValue<CtrlCtasConfig>>(ctrlCtasConfigProvider, (previous, next) {
      if (!next.hasValue) return;
      final cfg = next.value!;
      if (cfg.isAdmin) return;

      final allowed = cfg.allowedSucs
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toSet();
      if (allowed.isEmpty) {
        final forced = (cfg.forcedSuc ?? '').trim();
        if (forced.isNotEmpty) allowed.add(forced);
      }
      if (allowed.isEmpty) return;

      final current = ref.read(ctrlCtasFiltrosProvider);
      final filtered = current.sucs.where((value) => allowed.contains(value)).toList();

      if (filtered.length != current.sucs.length) {
        ref.read(ctrlCtasFiltrosProvider.notifier).setSucs(filtered);
        return;
      }

      if (filtered.isEmpty && allowed.length == 1) {
        ref.read(ctrlCtasFiltrosProvider.notifier).setSucs([allowed.first]);
      }
    });

    final config = configAsync.asData?.value;
    final hasConfig = config != null;
    final isAdmin = config?.isAdmin ?? true;
    final showOpv = config?.hasIdopv ?? false;
    final allowedFromConfig = (config?.allowedSucs ?? const <String>[])
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    final forcedSuc = (config?.forcedSuc ?? '').trim();
    final allowedSucs = allowedFromConfig.isNotEmpty
        ? allowedFromConfig
        : (forcedSuc.isEmpty ? const <String>[] : <String>[forcedSuc]);
    final canSelectSucs = isAdmin || (config?.canSelectSucs ?? (allowedSucs.length > 1));

    final sucs = sucursalesAsync.asData?.value ?? const <SucursalModel>[];
    final sucsByCode = {for (final suc in sucs) suc.suc: suc};
    final sucsVisibles = (!hasConfig || isAdmin)
        ? sucs
        : allowedSucs
            .map((code) => sucsByCode[code] ?? SucursalModel(suc: code))
            .toList();
    final ctas = ctasAsync.asData?.value ?? const <CtrlCtaOption>[];
    final clientes = clientesAsync.asData?.value ?? const <CtrlClienteOption>[];
    final opvAsync = showOpv ? ref.watch(opvProvider(CtrlCatalogParams(sucs: filtros.sucs))) : null;
    final opvs = opvAsync?.asData?.value ?? const <CtrlOpvOption>[];

    final sucValue = filtros.sucs.isNotEmpty ? filtros.sucs.first : null;
    final ctaValue = filtros.ctas.isNotEmpty ? filtros.ctas.first : null;
    final clientValue = filtros.clients.isNotEmpty ? filtros.clients.first : null;
    final opvValue = filtros.opvs.isNotEmpty ? filtros.opvs.first : null;

    final sucExists = sucsVisibles.any((item) => item.suc == sucValue);
    final ctaExists = ctas.any((item) => item.cta == ctaValue);
    final clientExists = clientes.any((item) => item.client == clientValue);
    final opvExists = opvs.any((item) => item.idopv == opvValue);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Control de Cuentas - Consulta'),
        actions: [
          IconButton(
            tooltip: 'Refrescar catalogos',
            onPressed: () {
              ref.invalidate(ctrlCtasConfigProvider);
              ref.invalidate(sucursalesListProvider);
              ref.invalidate(catCtasProvider(CtrlCatalogParams(sucs: filtros.sucs)));
              ref.invalidate(clientesProvider(CtrlCatalogParams(sucs: filtros.sucs)));
              ref.invalidate(opvProvider(CtrlCatalogParams(sucs: filtros.sucs)));
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth > 1000 ? 2 : 1;
          const spacing = 12.0;
          final fieldWidth = columns == 1 ? constraints.maxWidth : (constraints.maxWidth - spacing) / columns;

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
                            key: ValueKey(sucExists ? sucValue : null),
                            initialValue: sucExists ? sucValue : null,
                            decoration: InputDecoration(
                              labelText: 'Sucursal (SUC)',
                              border: const OutlineInputBorder(),
                              isDense: true,
                              helperText: !isAdmin
                                  ? (canSelectSucs
                                      ? 'Sucursales autorizadas por acceso'
                                      : 'SUC forzada por usuario')
                                  : null,
                              suffixIcon: IconButton(
                                tooltip: 'Seleccion multiple',
                                onPressed: !canSelectSucs || sucsVisibles.isEmpty
                                    ? null
                                    : () async {
                                        final options = sucsVisibles
                                            .where((item) => item.suc.trim().isNotEmpty)
                                            .map((item) => _MultiOption<String>(item.suc, _sucLabel(item)))
                                            .toList();
                                        await _openMultiSelectDialog<String>(
                                          title: 'Seleccionar sucursales',
                                          options: options,
                                          selected: filtros.sucs,
                                          onApply: (values) {
                                            ref.read(ctrlCtasFiltrosProvider.notifier).setSucs(values);
                                          },
                                        );
                                      },
                                icon: Icon(
                                  Icons.playlist_add,
                                  color: _multiIconColor(
                                    context,
                                    filtros.sucs.length,
                                    enabled: canSelectSucs && sucsVisibles.isNotEmpty,
                                  ),
                                ),
                              ),
                            ),
                            items: [
                              const DropdownMenuItem<String?>(value: null, child: Text('Todas')),
                              for (final suc in sucsVisibles)
                                DropdownMenuItem<String?>(
                                  value: suc.suc,
                                  child: Text(_sucLabel(suc), overflow: TextOverflow.ellipsis),
                                ),
                            ],
                            onChanged: !canSelectSucs
                                ? null
                                : (value) {
                                    ref.read(ctrlCtasFiltrosProvider.notifier).setSucs(
                                          value == null ? const [] : [value],
                                        );
                                  },
                          ),
                        ),
                        SizedBox(
                          width: fieldWidth,
                          child: DropdownButtonFormField<String?>(
                            key: ValueKey(ctaExists ? ctaValue : null),
                            initialValue: ctaExists ? ctaValue : null,
                            decoration: InputDecoration(
                              labelText: 'Cuenta (CTA)',
                              border: const OutlineInputBorder(),
                              isDense: true,
                              helperText: ctasAsync.isLoading
                                  ? 'Cargando cuentas...'
                                  : ctasAsync.hasError
                                      ? 'Error: ${apiErrorMessage(ctasAsync.error!)}'
                                      : null,
                              suffixIcon: IconButton(
                                tooltip: 'Seleccion multiple',
                                onPressed: ctas.isEmpty
                                    ? null
                                    : () async {
                                        final options = ctas
                                            .where((item) => item.cta.trim().isNotEmpty)
                                            .map((item) => _MultiOption<String>(item.cta, item.label))
                                            .toList();
                                        await _openMultiSelectDialog<String>(
                                          title: 'Seleccionar cuentas',
                                          options: options,
                                          selected: filtros.ctas,
                                          onApply: (values) {
                                            ref.read(ctrlCtasFiltrosProvider.notifier).setCtas(values);
                                          },
                                        );
                                      },
                                icon: Icon(
                                  Icons.playlist_add,
                                  color: _multiIconColor(
                                    context,
                                    filtros.ctas.length,
                                    enabled: ctas.isNotEmpty,
                                  ),
                                ),
                              ),
                            ),
                            items: [
                              const DropdownMenuItem<String?>(value: null, child: Text('Todas')),
                              for (final item in ctas)
                                DropdownMenuItem<String?>(
                                  value: item.cta,
                                  child: Text(item.label, overflow: TextOverflow.ellipsis),
                                ),
                            ],
                            onChanged: ctasAsync.isLoading
                                ? null
                                : (value) {
                                    ref.read(ctrlCtasFiltrosProvider.notifier).setCtas(
                                          value == null ? const [] : [value],
                                        );
                                  },
                          ),
                        ),
                        SizedBox(
                          width: fieldWidth,
                          child: DropdownButtonFormField<String?>(
                            key: ValueKey(clientExists ? clientValue : null),
                            initialValue: clientExists ? clientValue : null,
                            decoration: InputDecoration(
                              labelText: 'Deudor (CLIENT)',
                              border: const OutlineInputBorder(),
                              isDense: true,
                              helperText: clientesAsync.isLoading
                                  ? 'Cargando deudores...'
                                  : clientesAsync.hasError
                                      ? 'Error: ${apiErrorMessage(clientesAsync.error!)}'
                                      : null,
                              suffixIcon: IconButton(
                                tooltip: 'Seleccion multiple',
                                onPressed: clientes.isEmpty
                                    ? null
                                    : () async {
                                        final options = clientes
                                            .where((item) => item.client.trim().isNotEmpty)
                                            .map((item) => _MultiOption<String>(item.client, item.label))
                                            .toList();
                                        await _openMultiSelectDialog<String>(
                                          title: 'Seleccionar deudores',
                                          options: options,
                                          selected: filtros.clients,
                                          onApply: (values) {
                                            ref.read(ctrlCtasFiltrosProvider.notifier).setClients(values);
                                          },
                                        );
                                      },
                                icon: Icon(
                                  Icons.playlist_add,
                                  color: _multiIconColor(
                                    context,
                                    filtros.clients.length,
                                    enabled: clientes.isNotEmpty,
                                  ),
                                ),
                              ),
                            ),
                            items: [
                              const DropdownMenuItem<String?>(value: null, child: Text('Todos')),
                              for (final item in clientes)
                                DropdownMenuItem<String?>(
                                  value: item.client,
                                  child: Text(item.label, overflow: TextOverflow.ellipsis),
                                ),
                            ],
                            onChanged: clientesAsync.isLoading
                                ? null
                                : (value) {
                                    ref.read(ctrlCtasFiltrosProvider.notifier).setClients(
                                          value == null ? const [] : [value],
                                        );
                                  },
                          ),
                        ),
                        SizedBox(
                          width: fieldWidth,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: _clsdCtrl,
                                decoration: InputDecoration(
                                  labelText: 'Clase doc (CLSD)',
                                  border: const OutlineInputBorder(),
                                  isDense: true,
                                  suffixIcon: IconButton(
                                    tooltip: 'Agregar',
                                    onPressed: () => _addChipValue(
                                      raw: _clsdCtrl.text,
                                      current: filtros.clsds,
                                      onSet: (values) => ref.read(ctrlCtasFiltrosProvider.notifier).setClsds(values),
                                      clearController: _clsdCtrl,
                                    ),
                                    icon: const Icon(Icons.add),
                                  ),
                                ),
                                onSubmitted: (value) => _addChipValue(
                                  raw: value,
                                  current: filtros.clsds,
                                  onSet: (values) => ref.read(ctrlCtasFiltrosProvider.notifier).setClsds(values),
                                  clearController: _clsdCtrl,
                                ),
                              ),
                              if (filtros.clsds.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: filtros.clsds
                                      .map(
                                        (value) => InputChip(
                                          label: Text(value),
                                          onDeleted: () {
                                            final next = [...filtros.clsds]..remove(value);
                                            ref.read(ctrlCtasFiltrosProvider.notifier).setClsds(next);
                                          },
                                        ),
                                      )
                                      .toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                        SizedBox(
                          width: fieldWidth,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: _idfolCtrl,
                                decoration: InputDecoration(
                                  labelText: 'Ticket/Folio (IDFOL)',
                                  border: const OutlineInputBorder(),
                                  isDense: true,
                                  suffixIcon: IconButton(
                                    tooltip: 'Agregar',
                                    onPressed: () => _addChipValue(
                                      raw: _idfolCtrl.text,
                                      current: filtros.idfols,
                                      onSet: (values) => ref.read(ctrlCtasFiltrosProvider.notifier).setIdfols(values),
                                      clearController: _idfolCtrl,
                                    ),
                                    icon: const Icon(Icons.add),
                                  ),
                                ),
                                onSubmitted: (value) => _addChipValue(
                                  raw: value,
                                  current: filtros.idfols,
                                  onSet: (values) => ref.read(ctrlCtasFiltrosProvider.notifier).setIdfols(values),
                                  clearController: _idfolCtrl,
                                ),
                              ),
                              if (filtros.idfols.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: filtros.idfols
                                      .map(
                                        (value) => InputChip(
                                          label: Text(value),
                                          onDeleted: () {
                                            final next = [...filtros.idfols]..remove(value);
                                            ref.read(ctrlCtasFiltrosProvider.notifier).setIdfols(next);
                                          },
                                        ),
                                      )
                                      .toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                        SizedBox(
                          width: fieldWidth,
                          child: InkWell(
                            onTap: () => _pickDateRange(filtros),
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Rango fechas FCND',
                                border: const OutlineInputBorder(),
                                isDense: true,
                                suffixIcon: IconButton(
                                  tooltip: 'Limpiar',
                                  onPressed: () {
                                    ref.read(ctrlCtasFiltrosProvider.notifier).setFecIni(null);
                                    ref.read(ctrlCtasFiltrosProvider.notifier).setFecFin(null);
                                  },
                                  icon: const Icon(Icons.clear),
                                ),
                              ),
                              child: Text('${_fmtDate(filtros.fecIni)} - ${_fmtDate(filtros.fecFin)}'),
                            ),
                          ),
                        ),
                        if (showOpv)
                          SizedBox(
                            width: fieldWidth,
                            child: DropdownButtonFormField<String?>(
                              key: ValueKey(opvExists ? opvValue : null),
                              initialValue: opvExists ? opvValue : null,
                              decoration: InputDecoration(
                                labelText: 'Colaborador (IDOPV)',
                                border: const OutlineInputBorder(),
                                isDense: true,
                                helperText: opvAsync?.isLoading == true
                                    ? 'Cargando colaboradores...'
                                    : opvAsync?.hasError == true
                                        ? 'Error: ${apiErrorMessage(opvAsync!.error!)}'
                                        : null,
                                suffixIcon: IconButton(
                                  tooltip: 'Seleccion multiple',
                                  onPressed: opvs.isEmpty
                                      ? null
                                      : () async {
                                          final options = opvs
                                              .where((item) => item.idopv.trim().isNotEmpty)
                                              .map((item) => _MultiOption<String>(item.idopv, item.label))
                                              .toList();
                                          await _openMultiSelectDialog<String>(
                                            title: 'Seleccionar colaboradores',
                                            options: options,
                                            selected: filtros.opvs,
                                            onApply: (values) {
                                              ref.read(ctrlCtasFiltrosProvider.notifier).setOpvs(values);
                                            },
                                          );
                                        },
                                  icon: Icon(
                                    Icons.playlist_add,
                                    color: _multiIconColor(
                                      context,
                                      filtros.opvs.length,
                                      enabled: opvs.isNotEmpty,
                                    ),
                                  ),
                                ),
                              ),
                              items: [
                                const DropdownMenuItem<String?>(value: null, child: Text('Todos')),
                                for (final item in opvs)
                                  DropdownMenuItem<String?>(
                                    value: item.idopv,
                                    child: Text(item.label, overflow: TextOverflow.ellipsis),
                                  ),
                              ],
                              onChanged: opvAsync?.isLoading == true
                                  ? null
                                  : (value) {
                                      ref.read(ctrlCtasFiltrosProvider.notifier).setOpvs(
                                            value == null ? const [] : [value],
                                          );
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
                          onPressed: () {
                            ref.read(ctrlCtasFiltrosProvider.notifier).reset();
                            _clsdCtrl.clear();
                            _idfolCtrl.clear();
                          },
                          icon: const Icon(Icons.clear),
                          label: const Text('Limpiar'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: configAsync.isLoading
                              ? null
                              : () {
                                  final effective = ref.read(ctrlCtasFiltrosProvider);
                                  if (!mounted) return;
                                  context.go('/ctrl-ctas/resumen-cliente', extra: effective.toJson());
                                },
                          icon: const Icon(Icons.search),
                          label: const Text('Consultar'),
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
