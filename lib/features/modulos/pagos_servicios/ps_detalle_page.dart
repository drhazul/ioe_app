import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ioe_app/core/api_error.dart';

import 'ps_models.dart';
import 'ps_providers.dart';

class PsDetallePage extends ConsumerStatefulWidget {
  const PsDetallePage({super.key, required this.idFol});

  final String idFol;

  @override
  ConsumerState<PsDetallePage> createState() => _PsDetallePageState();
}

class _PsDetallePageState extends ConsumerState<PsDetallePage> {
  bool _showAdeudos = false;
  bool _updatingCliente = false;
  bool _processingServicio = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.invalidate(psDetalleProvider(widget.idFol));
      ref.invalidate(psPagoSummaryProvider(widget.idFol));
      ref.read(psSelectedArtProvider.notifier).state = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(psDetalleProvider(widget.idFol));
    final selectedArt = ref.watch(psSelectedArtProvider);
    final appBarHeader = detailAsync.maybeWhen(
      data: (detail) => detail.header,
      orElse: () => null,
    );
    final appBarCanProcesar = detailAsync.maybeWhen(
      data: (detail) {
        final estado = (detail.header.esta ?? '').trim().toUpperCase();
        return estado == 'PENDIENTE' || estado == 'PAGADO2';
      },
      orElse: () => false,
    );
    final appBarBlockedByStatus = detailAsync.maybeWhen(
      data: (detail) {
        final estado = (detail.header.esta ?? '').trim().toUpperCase();
        return estado == 'PAGADO2';
      },
      orElse: () => false,
    );

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: _HeaderInlineTitle(
          header: appBarHeader,
          fallbackIdFol: widget.idFol,
        ),
        actions: [
          IconButton(
            tooltip: 'Procesar servicio',
            onPressed: appBarCanProcesar && !_processingServicio
                ? _procesarServicio
                : null,
            icon: _processingServicio
                ? const SizedBox(
                    width: 18,
                    height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.point_of_sale),
          ),
          IconButton(
            tooltip: 'Refrescar',
            onPressed: appBarBlockedByStatus
                ? null
                : () {
                    ref.invalidate(psDetalleProvider(widget.idFol));
                    ref.invalidate(psPagoSummaryProvider(widget.idFol));
                    ref.invalidate(psAdeudosProvider);
                  },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (detail) {
          final header = detail.header;
          final estado = (header.esta ?? '').trim().toUpperCase();
          final blockedByStatus = estado == 'PAGADO2';
          final editable = estado == 'PENDIENTE' && !blockedByStatus;
          final client = header.clien ?? 0;
          final ticketTypes = detail.ticket
              .map((line) => (line.upc ?? '').trim().toUpperCase())
              .where((upc) => upc.isNotEmpty)
              .toSet();
          final hasAdeudoService = ticketTypes.any((upc) => upc == 'AD' || upc == 'AP' || upc == 'CR');
          final hasGastoService = ticketTypes.any((upc) => upc == 'DC' || upc == 'DG');
          final canUseAdeudos = client > 1;
          final hasTicketLines = detail.ticket.isNotEmpty;
          final adeudosAsync = (_showAdeudos && canUseAdeudos && hasAdeudoService && !blockedByStatus)
              ? ref.watch(psAdeudosProvider(client))
              : null;

          final topLine = _TopActionsLine(
            services: detail.servicios,
            editable: editable,
            showAdeudos: _showAdeudos,
            canUseAdeudos: canUseAdeudos,
            hasAdeudoService: hasAdeudoService,
            hasTicketLines: hasTicketLines,
            selectingCliente: _updatingCliente,
            blockedByStatus: blockedByStatus,
            onSelectCliente: () => _seleccionarCliente(header, detail.ticket),
            onToggleAdeudos: () => setState(() => _showAdeudos = !_showAdeudos),
            onAddService: _agregarServicio,
          );

          final ticketSection = _TicketSection(
            lines: detail.ticket,
            selectedArt: selectedArt,
            editable: editable,
            interactive: !blockedByStatus,
            onSelect: (art) => ref.read(psSelectedArtProvider.notifier).state = art,
            onEdit: _editarPvta,
            onDelete: _eliminarLinea,
          );

          final rightSection = ListView(
            padding: EdgeInsets.zero,
            children: [
              if (_showAdeudos && canUseAdeudos && hasAdeudoService)
                _AdeudosSection(
                  adeudosAsync: adeudosAsync,
                  selectedArt: selectedArt,
                  editable: editable,
                  onAssign: _asignarReferenciaAdeudo,
                  onViewDetalle: _mostrarRegistrosAdeudo,
                ),
              if (_showAdeudos && canUseAdeudos && hasAdeudoService) const SizedBox(height: 12),
              if (hasGastoService)
                _ReferenciasGastoSection(
                  refs: detail.referenciasGasto,
                  selectedArt: selectedArt,
                  editable: editable,
                  onAssign: _asignarReferenciaGasto,
                ),
              if (!hasGastoService && !(_showAdeudos && canUseAdeudos && hasAdeudoService))
                const Card(
                  elevation: 0,
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Agregue un servicio DG/DC para habilitar referencias de gasto.'),
                  ),
                ),
            ],
          );

          return LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 1200;
              if (!isWide) {
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    topLine,
                    const SizedBox(height: 14),
                    ticketSection,
                    const SizedBox(height: 12),
                    if (_showAdeudos && canUseAdeudos && hasAdeudoService)
                      _AdeudosSection(
                        adeudosAsync: adeudosAsync,
                        selectedArt: selectedArt,
                        editable: editable,
                        onAssign: _asignarReferenciaAdeudo,
                        onViewDetalle: _mostrarRegistrosAdeudo,
                      ),
                    if (_showAdeudos && canUseAdeudos && hasAdeudoService) const SizedBox(height: 12),
                    if (hasGastoService)
                      _ReferenciasGastoSection(
                        refs: detail.referenciasGasto,
                        selectedArt: selectedArt,
                        editable: editable,
                        onAssign: _asignarReferenciaGasto,
                      ),
                    if (!hasGastoService && !(_showAdeudos && canUseAdeudos && hasAdeudoService))
                      const Card(
                        elevation: 0,
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('Agregue un servicio DG/DC para habilitar referencias de gasto.'),
                        ),
                      ),
                  ],
                );
              }

              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    topLine,
                    const SizedBox(height: 14),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _SplitPane(
                              child: ListView(
                                padding: EdgeInsets.zero,
                                children: [ticketSection],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _SplitPane(
                              child: rightSection,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _agregarServicio(PsServicioItem item) async {
    final ids = item.ids.trim().toUpperCase();
    final detail = ref.read(psDetalleProvider(widget.idFol)).valueOrNull;
    final clien = detail?.header.clien ?? 0;
    if ((ids == 'AD' || ids == 'AP' || ids == 'CR') && clien <= 1) {
      _showError('Seleccione Cliente');
      return;
    }

    try {
      final res = await ref.read(psApiProvider).addService(
            idFol: widget.idFol,
            ids: item.ids,
          );
      ref.invalidate(psDetalleProvider(widget.idFol));
      if (!mounted) return;
      final requiresAuth = res['requiresAuthorizationForm'] == true;
      if (requiresAuth) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Autorización requerida'),
            content: const Text(
              'Este servicio requiere autorización previa (flujo pendiente de integración).',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Aceptar'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showError(apiErrorMessage(e, fallback: 'No se pudo agregar servicio'));
    }
  }

  Future<void> _seleccionarCliente(
    PsDetalleHeader header,
    List<PsTicketLine> ticket,
  ) async {
    if (ticket.isNotEmpty) {
      _showError('No se puede cambiar cliente: el ticket ya tiene líneas capturadas.');
      return;
    }

    final suc = (header.suc ?? '').trim().toUpperCase();
    setState(() => _updatingCliente = true);
    try {
      final clientes = await ref.read(psApiProvider).fetchClientes();
      if (!mounted) return;

      final filtered = suc.isEmpty
          ? clientes
          : clientes
                .where((c) => (c.suc ?? '').trim().toUpperCase() == suc)
                .toList();
      if (filtered.isEmpty) {
        _showError('No hay clientes disponibles para la sucursal ${suc.isEmpty ? '-' : suc}.');
        return;
      }

      final selected = await showDialog<PsClienteItem>(
        context: context,
        builder: (ctx) => _PsClientePickerDialog(
          clientes: filtered,
          suc: suc,
          selectedClienteId: header.clien,
        ),
      );
      if (!mounted || selected == null) return;

      await ref.read(psApiProvider).updateFolioCliente(
            idFol: widget.idFol,
            clien: selected.idc,
          );
      ref.invalidate(psDetalleProvider(widget.idFol));
      ref.invalidate(psPagoSummaryProvider(widget.idFol));
      ref.invalidate(psFoliosProvider);
      if (!mounted) return;
      setState(() => _showAdeudos = false);
    } catch (e) {
      if (!mounted) return;
      _showError(apiErrorMessage(e, fallback: 'No se pudo actualizar cliente del folio'));
    } finally {
      if (mounted) setState(() => _updatingCliente = false);
    }
  }

  Future<void> _editarPvta(PsTicketLine line) async {
    final art = (line.art ?? '').trim();
    if (art.isEmpty) {
      _showError('La línea no tiene ART válido');
      return;
    }

    final ctrl = TextEditingController(
      text: line.pvta == null ? '' : line.pvta!.toStringAsFixed(2),
    );
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Editar PVTA - $art'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'PVTA',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(ctrl.text.trim().replaceAll(',', '.'));
              if (value == null || value <= 0) return;
              Navigator.of(ctx).pop(value);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (!mounted || result == null) return;

    try {
      await ref.read(psApiProvider).updatePvta(
            idFol: widget.idFol,
            art: art,
            pvta: result,
          );
      ref.invalidate(psDetalleProvider(widget.idFol));
    } catch (e) {
      if (!mounted) return;
      _showError(apiErrorMessage(e, fallback: 'No se pudo actualizar PVTA'));
    }
  }

  Future<void> _eliminarLinea(PsTicketLine line) async {
    final art = (line.art ?? '').trim();
    if (art.isEmpty) {
      _showError('La línea no tiene ART válido');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar línea'),
        content: Text('¿Eliminar la línea $art del ticket?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    try {
      await ref.read(psApiProvider).deleteLine(idFol: widget.idFol, art: art);
      ref.invalidate(psDetalleProvider(widget.idFol));
      ref.read(psSelectedArtProvider.notifier).state = null;
    } catch (e) {
      if (!mounted) return;
      _showError(apiErrorMessage(e, fallback: 'No se pudo eliminar la línea'));
    }
  }

  Future<void> _asignarReferenciaAdeudo(Map<String, dynamic> row) async {
    final art = (ref.read(psSelectedArtProvider) ?? '').trim();
    if (art.isEmpty) {
      _showError('Seleccione primero una línea del ticket (ART)');
      return;
    }

    final idFolRef = _resolveAdeudoFolio(row);
    if (idFolRef.isEmpty) {
      _showError('El registro de adeudo no contiene folio de referencia');
      return;
    }

    try {
      await ref.read(psApiProvider).setReferenceFolio(
            idFol: widget.idFol,
            art: art,
            idFolRef: idFolRef,
          );
      ref.invalidate(psDetalleProvider(widget.idFol));
    } catch (e) {
      if (!mounted) return;
      _showError(apiErrorMessage(e, fallback: 'No se pudo asignar referencia de adeudo'));
    }
  }

  Future<void> _mostrarRegistrosAdeudo(Map<String, dynamic> row) async {
    final detail = ref.read(psDetalleProvider(widget.idFol)).valueOrNull;
    final headerClient = detail?.header.clien ?? 0;
    final rowClientText = (row['CLIENT'] ?? row['client'] ?? '').toString().trim();
    final rowClient = int.tryParse(rowClientText.split('.').first) ?? 0;
    final client = headerClient > 0 ? headerClient : rowClient;

    if (client <= 0) {
      _showError('No se encontró cliente válido para consultar DAT_CTRL_CTAS');
      return;
    }

    final idFolRef = _resolveAdeudoFolio(row);
    if (idFolRef.isEmpty) {
      _showError('El registro seleccionado no contiene IDFOL');
      return;
    }

    try {
      final rows = await ref.read(psApiProvider).fetchAdeudosFolioDetalle(
            client: client,
            idFol: idFolRef,
          );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => _AdeudoDetalleDialog(
          idFol: idFolRef,
          rows: rows,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showError(
        apiErrorMessage(
          e,
          fallback: 'No se pudieron consultar registros DAT_CTRL_CTAS del folio',
        ),
      );
    }
  }

  Future<void> _asignarReferenciaGasto(PsRefGastoItem item) async {
    final art = (ref.read(psSelectedArtProvider) ?? '').trim();
    if (art.isEmpty) {
      _showError('Seleccione primero una línea del ticket (ART)');
      return;
    }

    try {
      await ref.read(psApiProvider).setReferenceGasto(
            idFol: widget.idFol,
            art: art,
            refGasto: item.refgasto,
          );
      ref.invalidate(psDetalleProvider(widget.idFol));
    } catch (e) {
      if (!mounted) return;
      _showError(apiErrorMessage(e, fallback: 'No se pudo asignar referencia de gasto'));
    }
  }

  Future<void> _procesarServicio() async {
    setState(() => _processingServicio = true);
    try {
      await ref.read(psApiProvider).procesar(widget.idFol);
      ref.invalidate(psDetalleProvider(widget.idFol));
      ref.invalidate(psPagoSummaryProvider(widget.idFol));
      if (!mounted) return;
      context.go('/ps/${Uri.encodeComponent(widget.idFol)}/pago');
    } catch (e) {
      if (!mounted) return;
      _showError(apiErrorMessage(e, fallback: 'No se pudo procesar servicio'));
    } finally {
      if (mounted) setState(() => _processingServicio = false);
    }
  }

  String _resolveAdeudoFolio(Map<String, dynamic> row) {
    const keys = [
      'IDFOL',
      'idfol',
      'IdFol',
      'NDOC',
      'ndoc',
      'NDoc',
      'ORD',
      'ord',
    ];
    for (final key in keys) {
      final value = (row[key] ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  void _showError(String message) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          FilledButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Aceptar')),
        ],
      ),
    );
  }
}

class _HeaderInlineTitle extends StatelessWidget {
  const _HeaderInlineTitle({
    required this.header,
    required this.fallbackIdFol,
  });

  final PsDetalleHeader? header;
  final String fallbackIdFol;

  @override
  Widget build(BuildContext context) {
    final idfol = _textOrFallback(header?.idfol, fallbackIdFol);
    final suc = _textOrFallback(header?.suc, '-');
    final esta = _textOrFallback(header?.esta, '-').toUpperCase();
    final clien = header?.clien == null ? '-' : header!.clien.toString();
    final cliente = _textOrFallback(header?.razonSocialReceptor, '-');

    return Row(
      children: [
        const Text(
          'Pago de servicios',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip('IDFOL: $idfol'),
                const SizedBox(width: 6),
                _chip('SUC: $suc'),
                const SizedBox(width: 6),
                _chip('ESTA: $esta'),
                const SizedBox(width: 6),
                _chip('CLIEN: $clien'),
                const SizedBox(width: 6),
                _chip('CLIENTE: $cliente'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(38),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  String _textOrFallback(String? value, String fallback) {
    final normalized = (value ?? '').trim();
    return normalized.isEmpty ? fallback : normalized;
  }
}

class _TopActionsLine extends StatelessWidget {
  const _TopActionsLine({
    required this.services,
    required this.editable,
    required this.showAdeudos,
    required this.canUseAdeudos,
    required this.hasAdeudoService,
    required this.hasTicketLines,
    required this.selectingCliente,
    required this.blockedByStatus,
    required this.onSelectCliente,
    required this.onToggleAdeudos,
    required this.onAddService,
  });

  final List<PsServicioItem> services;
  final bool editable;
  final bool showAdeudos;
  final bool canUseAdeudos;
  final bool hasAdeudoService;
  final bool hasTicketLines;
  final bool selectingCliente;
  final bool blockedByStatus;
  final VoidCallback onSelectCliente;
  final VoidCallback onToggleAdeudos;
  final ValueChanged<PsServicioItem> onAddService;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withAlpha(96),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          OutlinedButton.icon(
            onPressed: (hasTicketLines || selectingCliente || blockedByStatus)
                ? null
                : onSelectCliente,
            icon: selectingCliente
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.person_search),
            label: const Text('Seleccione Cliente'),
          ),
          OutlinedButton.icon(
            onPressed: (canUseAdeudos && hasAdeudoService && !blockedByStatus)
                ? onToggleAdeudos
                : null,
            icon: Icon(showAdeudos ? Icons.visibility_off : Icons.receipt_long),
            label: Text(showAdeudos ? 'Ocultar adeudos' : 'Adeudos cliente'),
          ),
          ...services.map((item) {
            return ActionChip(
              label: Text('${item.ids} - ${item.dessv}'),
              onPressed: (editable && !blockedByStatus) ? () => onAddService(item) : null,
            );
          }),
        ],
      ),
    );
  }
}

class _PsClientePickerDialog extends StatefulWidget {
  const _PsClientePickerDialog({
    required this.clientes,
    required this.suc,
    required this.selectedClienteId,
  });

  final List<PsClienteItem> clientes;
  final String suc;
  final int? selectedClienteId;

  @override
  State<_PsClientePickerDialog> createState() => _PsClientePickerDialogState();
}

class _PsClientePickerDialogState extends State<_PsClientePickerDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  PsClienteItem? _selected;

  @override
  void initState() {
    super.initState();
    final selectedId = widget.selectedClienteId;
    if (selectedId != null) {
      for (final item in widget.clientes) {
        if (item.idc == selectedId) {
          _selected = item;
          break;
        }
      }
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filter(widget.clientes, _searchCtrl.text);
    final sucLabel = widget.suc.isEmpty ? '-' : widget.suc;
    return AlertDialog(
      title: Text('Seleccionar cliente - SUC $sucLabel'),
      content: SizedBox(
        width: 760,
        height: 460,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Buscar por IDC, nombre o RFC',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('Sin resultados'))
                  : RadioGroup<int>(
                      groupValue: _selected?.idc,
                      onChanged: (value) {
                        if (value == null) return;
                        for (final item in filtered) {
                          if (item.idc == value) {
                            setState(() => _selected = item);
                            return;
                          }
                        }
                      },
                      child: ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final c = filtered[index];
                          final selected = _selected?.idc == c.idc;
                          return ListTile(
                            dense: true,
                            selected: selected,
                            onTap: () => setState(() => _selected = c),
                            leading: Radio<int>(value: c.idc),
                            title: Text(
                              '${c.idc} - ${c.razonSocialReceptor}',
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              'RFC: ${c.rfcReceptor}${(c.suc ?? '').trim().isEmpty ? '' : ' | SUC: ${c.suc}'}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _selected == null
              ? null
              : () => Navigator.of(context).pop(_selected),
          child: const Text('Seleccionar'),
        ),
      ],
    );
  }

  List<PsClienteItem> _filter(List<PsClienteItem> input, String raw) {
    final term = raw.trim().toLowerCase();
    if (term.isEmpty) return input;
    return input.where((c) {
      final byId = c.idc.toString().toLowerCase().contains(term);
      final byName = c.razonSocialReceptor.toLowerCase().contains(term);
      final byRfc = c.rfcReceptor.toLowerCase().contains(term);
      return byId || byName || byRfc;
    }).toList();
  }
}

class _SplitPane extends StatelessWidget {
  const _SplitPane({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withAlpha(96),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}

class _TicketSection extends StatelessWidget {
  const _TicketSection({
    required this.lines,
    required this.selectedArt,
    required this.editable,
    required this.interactive,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
  });

  final List<PsTicketLine> lines;
  final String? selectedArt;
  final bool editable;
  final bool interactive;
  final ValueChanged<String?> onSelect;
  final ValueChanged<PsTicketLine> onEdit;
  final ValueChanged<PsTicketLine> onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ticket', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (lines.isEmpty)
              const Text('Sin líneas en ticket')
            else
              Column(
                children: lines.map((line) {
                  final art = (line.art ?? '').trim();
                    final selected = art.isNotEmpty && art == (selectedArt ?? '').trim();
                    return Container(
                      color: selected ? Colors.blue.shade50 : null,
                      child: ListTile(
                        dense: true,
                        onTap: interactive ? () => onSelect(art.isEmpty ? null : art) : null,
                        title: Text('${line.art ?? '-'} | ${line.des ?? '-'}'),
                      subtitle: Text(
                        'ORD: ${line.ord ?? '-'} | CTD: ${line.ctd ?? 0} | PVTA: ${line.pvta ?? '-'} | TOTAL: ${line.total ?? '-'}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Editar PVTA',
                            onPressed: editable ? () => onEdit(line) : null,
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: 'Eliminar',
                            onPressed: editable ? () => onDelete(line) : null,
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _AdeudosSection extends StatelessWidget {
  const _AdeudosSection({
    required this.adeudosAsync,
    required this.selectedArt,
    required this.editable,
    required this.onAssign,
    required this.onViewDetalle,
  });

  final AsyncValue<PsAdeudosResponse>? adeudosAsync;
  final String? selectedArt;
  final bool editable;
  final ValueChanged<Map<String, dynamic>> onAssign;
  final ValueChanged<Map<String, dynamic>> onViewDetalle;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Adeudos (subres)', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (adeudosAsync == null)
              const Text('No hay cliente para consultar adeudos')
            else
              adeudosAsync!.when(
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => Text('Error: $e'),
                data: (data) {
                  final rows = data.adeudosRes.isNotEmpty ? data.adeudosRes : data.adeudosR;
                  if (rows.isEmpty) {
                    return const Text('Sin adeudos disponibles');
                  }
                  return Column(
                    children: rows.take(30).map((row) {
                      final folio = _firstText(row, const ['IDFOL', 'idfol', 'NDOC', 'ndoc', 'ORD', 'ord']);
                      final relacion = _firstText(row, const ['RELACION', 'relacion']);
                      final adeudo = _firstText(row, const ['ADEUDO', 'adeudo']);
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text('Folio: ${folio.isEmpty ? '-' : folio} | Relación: ${relacion.isEmpty ? '-' : relacion}'),
                        subtitle: Text('Adeudo: ${adeudo.isEmpty ? '-' : adeudo}'),
                        trailing: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 260),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.end,
                            children: [
                              OutlinedButton(
                                onPressed: folio.isEmpty ? null : () => onViewDetalle(row),
                                child: const Text('Ver registros'),
                              ),
                              OutlinedButton(
                                onPressed: editable && (selectedArt ?? '').trim().isNotEmpty
                                    ? () => onAssign(row)
                                    : null,
                                child: const Text('Asignar referencia'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  String _firstText(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = (row[key] ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }
    return '';
  }
}

class _AdeudoDetalleDialog extends StatefulWidget {
  const _AdeudoDetalleDialog({
    required this.idFol,
    required this.rows,
  });

  final String idFol;
  final List<Map<String, dynamic>> rows;

  @override
  State<_AdeudoDetalleDialog> createState() => _AdeudoDetalleDialogState();
}

class _AdeudoDetalleDialogState extends State<_AdeudoDetalleDialog> {
  late final ScrollController _horizontalCtrl;
  late final ScrollController _verticalCtrl;

  @override
  void initState() {
    super.initState();
    _horizontalCtrl = ScrollController();
    _verticalCtrl = ScrollController();
  }

  @override
  void dispose() {
    _horizontalCtrl.dispose();
    _verticalCtrl.dispose();
    super.dispose();
  }

  static const List<String> _columns = [
    'SUC',
    'IDFOL',
    'IMPT',
    'NDOC',
    'CTA',
    'CLIENT',
    'FCND',
    'CLSD',
    'RTXT',
    'IDOPV',
  ];

  @override
  Widget build(BuildContext context) {
    final tableRows = widget.rows.asMap().entries.map((entry) {
      final row = entry.value;
      final index = entry.key + 1;
      final ndoc = _value(row, const ['NDOC', 'ndoc']);
      final cta = _value(row, const ['CTA', 'cta']);
      final client = _value(row, const ['CLIENT', 'client']);
      final fcnd = _value(row, const ['FCND', 'fcnd', 'FCN', 'fcn', 'FCNR', 'fcnr']);
      final clsd = _value(row, const ['CLSD', 'clsd', 'CMOV', 'cmov']);
      final idfol = _value(row, const ['IDFOL', 'idfol']);
      final rtxt = _value(row, const ['RTXT', 'rtxt']);
      final impt = _formatAmount(_value(row, const ['IMPT', 'impt']));
      final suc = _value(row, const ['SUC', 'suc']);
      final idopv = _value(row, const ['IDOPV', 'idopv', 'OPV', 'opv']);

      return DataRow(
        cells: [
          DataCell(Text(index.toString())),
          DataCell(SelectableText(suc)),
          DataCell(SelectableText(idfol)),
          DataCell(
            Align(
              alignment: Alignment.centerRight,
              child: SelectableText(impt),
            ),
          ),
          DataCell(SelectableText(ndoc)),
          DataCell(SelectableText(cta)),
          DataCell(SelectableText(client)),
          DataCell(SelectableText(fcnd)),
          DataCell(SelectableText(clsd)),
          DataCell(SelectableText(rtxt)),
          DataCell(SelectableText(idopv)),
        ],
      );
    }).toList(growable: false);

    return AlertDialog(
      title: Text('DAT_CTRL_CTAS - Folio ${widget.idFol}'),
      content: SizedBox(
        width: 900,
        height: 520,
        child: widget.rows.isEmpty
            ? const Center(
                child: Text('Sin registros para este folio en DAT_CTRL_CTAS'),
              )
            : Scrollbar(
                controller: _horizontalCtrl,
                thumbVisibility: true,
                notificationPredicate: (notification) =>
                    notification.metrics.axis == Axis.horizontal,
                child: SingleChildScrollView(
                  controller: _horizontalCtrl,
                  scrollDirection: Axis.horizontal,
                  primary: false,
                  child: SizedBox(
                    width: 1450,
                    child: Scrollbar(
                      controller: _verticalCtrl,
                      thumbVisibility: true,
                      notificationPredicate: (notification) =>
                          notification.metrics.axis == Axis.vertical,
                      child: SingleChildScrollView(
                        controller: _verticalCtrl,
                        primary: false,
                        child: DataTable(
                          headingRowHeight: 34,
                          dataRowMinHeight: 32,
                          dataRowMaxHeight: 36,
                          columnSpacing: 18,
                          border: TableBorder.all(
                            color: Theme.of(context).dividerColor.withValues(alpha: 0.45),
                            width: 0.8,
                          ),
                          columns: [
                            const DataColumn(label: Text('#')),
                            ..._columns.map((name) => DataColumn(label: Text(name))),
                          ],
                          rows: tableRows,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }

  String _value(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '-';
  }

  String _formatAmount(String raw) {
    final value = double.tryParse(raw.replaceAll(',', ''));
    if (value == null) return raw;
    return value.toStringAsFixed(2);
  }
}

class _ReferenciasGastoSection extends StatelessWidget {
  const _ReferenciasGastoSection({
    required this.refs,
    required this.selectedArt,
    required this.editable,
    required this.onAssign,
  });

  final List<PsRefGastoItem> refs;
  final String? selectedArt;
  final bool editable;
  final ValueChanged<PsRefGastoItem> onAssign;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Referencias de gasto', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (refs.isEmpty)
              const Text('Sin referencias de gasto')
            else
              Column(
                children: refs.map((item) {
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text('${item.idr} - ${item.refgasto}'),
                    trailing: OutlinedButton(
                      onPressed: editable && (selectedArt ?? '').trim().isNotEmpty
                          ? () => onAssign(item)
                          : null,
                      child: const Text('Asignar'),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}
