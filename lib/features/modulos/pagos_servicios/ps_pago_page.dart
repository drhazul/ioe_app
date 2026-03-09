import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ioe_app/core/api_error.dart';
import 'package:ioe_app/core/auth/auth_controller.dart';
import 'package:ioe_app/features/masterdata/sucursales/sucursales_providers.dart';
import 'package:ioe_app/features/modulos/punto_venta/cotizaciones/pago/ref_detalle/ref_detalle_models.dart';
import 'package:ioe_app/features/modulos/punto_venta/cotizaciones/pago/ref_detalle/ref_detalle_page.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'ps_models.dart';
import 'ps_providers.dart';

const Set<String> _formasConReferencia = {
  'TARJETA',
  'CHEQUE',
  'TRANSFERENCIA',
  'DEPOSITO 3RO',
};

const Set<String> _formasNoPermitidasPs = {
  'CREDITO',
  'DEUDOR',
};

bool _formRequiereReferenciaTipo(String form) =>
    _formasConReferencia.contains(form.toUpperCase().trim());

class PsPagoPage extends ConsumerStatefulWidget {
  const PsPagoPage({super.key, required this.idFol});

  final String idFol;

  @override
  ConsumerState<PsPagoPage> createState() => _PsPagoPageState();
}

class _PsPagoPageState extends ConsumerState<PsPagoPage> {
  bool _saving = false;
  bool _printingTicket = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.invalidate(psPagoSummaryProvider(widget.idFol));
      ref.invalidate(psFormasPagoProvider(widget.idFol));
      ref.invalidate(psDetalleProvider(widget.idFol));
    });
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(psPagoSummaryProvider(widget.idFol));
    final formasAsync = ref.watch(psFormasPagoProvider(widget.idFol));
    final draftFormas = ref.watch(psPagoDraftFormasProvider(widget.idFol));
    final formasCatalogAsync = ref.watch(psFormasCatalogProvider);
    final formasDisponibles = _formasParaDialogo(formasCatalogAsync.valueOrNull ?? const []);
    final appBarSummary = summaryAsync.valueOrNull;
    final appBarIsPagado = _isEstadoPagado(appBarSummary?.esta);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(appBarIsPagado ? Icons.lock : Icons.arrow_back),
          onPressed: _saving
              ? null
              : appBarIsPagado
                  ? _onLockPressed
                  : _goToDetalle,
        ),
        title: Text('PS Pago - ${widget.idFol}'),
        actions: [
          IconButton(
            tooltip: 'Refrescar',
            onPressed: () {
              ref.invalidate(psPagoSummaryProvider(widget.idFol));
              ref.invalidate(psFormasPagoProvider(widget.idFol));
              ref.invalidate(psDetalleProvider(widget.idFol));
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: summaryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (summary) {
          final isPagado = _isEstadoPagado(summary.esta);
          if (isPagado && draftFormas.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(psPagoDraftFormasProvider(widget.idFol).notifier).clear();
            });
          }
          final draftAsFormas = draftFormas
              .map(
                (item) => PsFormaPagoItem(
                  idf: item.localId,
                  idfol: widget.idFol,
                  form: item.form.trim().toUpperCase(),
                  impp: _round2(item.impp),
                  aut: (item.aut ?? '').trim().isEmpty ? null : item.aut!.trim(),
                ),
              )
              .toList(growable: false);
          final pagadoDraft = _round2(
            draftAsFormas.fold<double>(0, (sum, item) => sum + item.impp),
          );
          final resumenEfectivo = isPagado
              ? summary
              : summary.copyWith(
                  pagado: pagadoDraft,
                  restante: _round2(summary.total > pagadoDraft ? summary.total - pagadoDraft : 0),
                  cambio: _round2(pagadoDraft > summary.total ? pagadoDraft - summary.total : 0),
                  formas: draftAsFormas,
                );
          final formasViewAsync =
              isPagado ? formasAsync : AsyncValue<List<PsFormaPagoItem>>.data(resumenEfectivo.formas);
          final canAddForma =
              !isPagado &&
              !_saving &&
              resumenEfectivo.total > 0 &&
              (resumenEfectivo.pagado + 0.0001) < resumenEfectivo.total &&
              formasDisponibles.isNotEmpty;
          final canFinalize =
              !isPagado &&
              !_saving &&
              resumenEfectivo.formas.isNotEmpty &&
              resumenEfectivo.total > 0 &&
              (resumenEfectivo.pagado + 0.0001) >= resumenEfectivo.total;
          final canPrint = isPagado && !_saving && !_printingTicket;

          final firstSection = _SectionContainer(
            child: _SummaryCard(summary: resumenEfectivo),
          );
          final secondSection = _SectionContainer(
            child: _FormasPagoCard(
              formasAsync: formasViewAsync,
              isPagado: isPagado,
              canAddForma: canAddForma,
              saving: _saving,
              onAddForma: () => _openAddFormaDialog(
                resumenEfectivo,
                formasDisponibles: formasDisponibles,
              ),
              onDeleteForma: _deleteForma,
              formasCatalogLoading: formasCatalogAsync.isLoading,
            ),
          );

          return LayoutBuilder(
            builder: (context, constraints) {
              final horizontalSplit = constraints.maxWidth >= 1200;
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (horizontalSplit)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: firstSection),
                        const SizedBox(width: 12),
                        Expanded(child: secondSection),
                      ],
                    )
                  else ...[
                    firstSection,
                    const SizedBox(height: 12),
                    secondSection,
                  ],
                  const SizedBox(height: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: canFinalize ? _finalizarPago : null,
                          icon: _saving
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.check_circle_outline),
                          label: Text(
                            _saving
                                ? 'Finalizando pago de servicio...'
                                : 'Finalizar Pago de servicio',
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: canPrint ? _imprimirTicket : null,
                          icon: _printingTicket
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.print_outlined),
                          label: Text(
                            _printingTicket
                                ? 'Imprimiendo...'
                                : 'Imprimir ticket',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openAddFormaDialog(
    PsPagoSummary summary, {
    required List<String> formasDisponibles,
  }) async {
    if (formasDisponibles.isEmpty) {
      _showError('No hay formas de pago disponibles en DAT_FORM para esta operación.');
      return;
    }
    final faltante = _round2(
      summary.total > summary.pagado ? summary.total - summary.pagado : 0,
    );
    final result = await showDialog<_FormaDialogResult>(
      context: context,
      builder: (_) => _FormaDialog(
        maxNoEfectivo: faltante,
        formasDisponibles: formasDisponibles,
        onSelectReferencia: ({
          required form,
          required impt,
          currentIdref,
        }) {
          return _openRefDetalleSelector(
            form: form,
            impt: impt,
            currentIdref: currentIdref,
          );
        },
      ),
    );
    if (result == null || !mounted) return;

    final isEfectivo = result.form.trim().toUpperCase() == 'EFECTIVO';
    if (!isEfectivo) {
      final restanteActual = _round2(
        summary.total > summary.pagado ? summary.total - summary.pagado : 0,
      );
      if ((result.impp - restanteActual) > 0.0001) {
        if (!mounted) return;
        _showError(
          'El importe de la forma no puede exceder el restante por pagar (${_money(restanteActual)})',
        );
        return;
      }
    }

    final localId =
        '${DateTime.now().microsecondsSinceEpoch}-${result.form.trim().toUpperCase()}';
    ref.read(psPagoDraftFormasProvider(widget.idFol).notifier).add(
          PsFormaPagoDraftItem(
            localId: localId,
            form: result.form,
            impp: result.impp,
            aut: result.aut,
          ),
        );
  }

  Future<RefDetalleSelectionResult?> _openRefDetalleSelector({
    required String form,
    required double impt,
    String? currentIdref,
  }) async {
    final tipo = form.trim().toUpperCase();
    if (tipo == 'EFECTIVO') return null;

    try {
      final detalle = await ref.read(psDetalleProvider(widget.idFol).future);
      final header = detalle.header;
      final suc = (header.suc ?? '').trim();
      final idc = header.clien ?? 0;
      final rqfac = (header.reqf ?? 0) == 1;
      final auth = ref.read(authControllerProvider);
      final opv = (header.opv ?? auth.username ?? '').trim();

      if (suc.isEmpty) {
        if (mounted) _showError('No se encontró sucursal del folio PS');
        return null;
      }
      if (idc <= 0) {
        if (mounted) _showError('El folio PS no tiene cliente válido');
        return null;
      }
      if (opv.isEmpty) {
        if (mounted) _showError('No se encontró OPV para crear/asignar referencia');
        return null;
      }

      final sucursales = await ref.read(sucursalesListProvider.future);
      final sucFound = sucursales
          .where((s) => s.suc.trim().toUpperCase() == suc.toUpperCase())
          .toList();
      final rfcEmisor = sucFound.isEmpty ? '' : (sucFound.first.rfc ?? '').trim();
      if (rfcEmisor.isEmpty) {
        if (mounted) _showError('No se encontró RFC emisor para la sucursal $suc');
        return null;
      }

      final summary = await ref.read(psApiProvider).fetchSummary(widget.idFol);
      final maxImpt = _round2(
        summary.total > summary.pagado ? summary.total - summary.pagado : 0,
      );
      if ((impt - maxImpt) > 0.0001) {
        if (mounted) {
          _showError(
            'El importe no puede exceder el restante por pagar (${_money(maxImpt)})',
          );
        }
        return null;
      }

      if (!mounted) return null;
      final args = RefDetallePageArgs(
        idfol: widget.idFol,
        suc: suc,
        idc: idc,
        opv: opv,
        rfcEmisor: rfcEmisor,
        tipo: tipo,
        impt: impt,
        maxImpt: maxImpt,
        rqfac: rqfac,
        initialIdref: currentIdref,
      );

      return Navigator.of(context).push<RefDetalleSelectionResult>(
        MaterialPageRoute(
          builder: (_) => RefDetallePage(args: args),
        ),
      );
    } catch (e) {
      if (mounted) {
        _showError(
          apiErrorMessage(
            e,
            fallback: 'No se pudo abrir la página de referencia',
          ),
        );
      }
      return null;
    }
  }

  Future<void> _deleteForma(PsFormaPagoItem item) async {
    final summary = ref.read(psPagoSummaryProvider(widget.idFol)).valueOrNull;
    final isPagado = _isEstadoPagado(summary?.esta);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar forma de pago'),
        content: Text('¿Eliminar la forma ${item.form}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    if (!isPagado) {
      ref.read(psPagoDraftFormasProvider(widget.idFol).notifier).removeByLocalId(item.idf);
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(psApiProvider).deleteFormaPago(
            idFol: widget.idFol,
            idF: item.idf,
          );
      ref.invalidate(psPagoSummaryProvider(widget.idFol));
      ref.invalidate(psFormasPagoProvider(widget.idFol));
      ref.invalidate(psDetalleProvider(widget.idFol));
    } catch (e) {
      if (!mounted) return;
      _showError(apiErrorMessage(e, fallback: 'No se pudo eliminar forma de pago'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _finalizarPago() async {
    final draft = ref.read(psPagoDraftFormasProvider(widget.idFol));
    if (draft.isEmpty) {
      _showError('Agregue al menos una forma de pago antes de finalizar');
      return;
    }

    setState(() => _saving = true);
    try {
      final currentIdFol = widget.idFol;
      final response = await ref.read(psApiProvider).finalizarPago(
            idFol: currentIdFol,
            formas: draft,
          );

      String resolvedIdFol = '';
      final resultPayload = response['result'];
      if (resultPayload is Map) {
        resolvedIdFol =
            ((resultPayload['IDFOL'] ?? resultPayload['idfol'] ?? '') as Object)
                .toString()
                .trim();
      }
      if (resolvedIdFol.isEmpty) {
        resolvedIdFol =
            ((response['idfol'] ?? response['IDFOL'] ?? '') as Object)
                .toString()
                .trim();
      }
      if (resolvedIdFol.isEmpty) {
        resolvedIdFol = currentIdFol;
      }

      ref.read(psPagoDraftFormasProvider(currentIdFol).notifier).clear();
      for (final idFol in <String>{currentIdFol, resolvedIdFol}) {
        ref.invalidate(psPagoSummaryProvider(idFol));
        ref.invalidate(psFormasPagoProvider(idFol));
        ref.invalidate(psDetalleProvider(idFol));
      }
      ref.invalidate(psFoliosProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Pago finalizado ($resolvedIdFol). Estado PAGADO aplicado. Puede imprimir ticket.',
          ),
        ),
      );
      if (resolvedIdFol != currentIdFol) {
        context.go('/ps/${Uri.encodeComponent(resolvedIdFol)}/pago');
      }
    } catch (e) {
      if (!mounted) return;
      _showError(apiErrorMessage(e, fallback: 'No se pudo finalizar pago PS'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _onLockPressed() async {
    setState(() => _saving = true);
    try {
      await ref.read(psApiProvider).updateEstado(
            idFol: widget.idFol,
            esta: 'TRANSMITIR',
          );
      ref.invalidate(psFoliosProvider);
      ref.invalidate(psPagoSummaryProvider(widget.idFol));
      ref.invalidate(psFormasPagoProvider(widget.idFol));
      ref.invalidate(psDetalleProvider(widget.idFol));
      if (!mounted) return;
      context.go('/ps');
    } catch (e) {
      if (!mounted) return;
      _showError(
        apiErrorMessage(
          e,
          fallback: 'No se pudo cambiar el folio a TRANSMITIR al regresar',
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _goToDetalle() {
    context.go('/ps/${Uri.encodeComponent(widget.idFol)}');
  }

  Future<void> _imprimirTicket() async {
    if (_printingTicket) return;
    setState(() => _printingTicket = true);
    try {
      final widthMm = await _selectTicketWidth(context);
      if (widthMm == null) return;

      final api = ref.read(psApiProvider);
      final summary = await api.fetchSummary(widget.idFol);
      PsDetalleResponse? detalle;
      try {
        detalle = await api.fetchDetalle(widget.idFol);
      } catch (_) {
        detalle = null;
      }
      final nonCashFormas = summary.formas
          .where((f) => f.form.trim().toUpperCase() != 'EFECTIVO')
          .toList(growable: false);

      final doc = _buildTicketPdf(
        summary: summary,
        detalle: detalle,
        widthMm: widthMm,
      );
      if (!mounted) return;
      await Printing.layoutPdf(
        name: 'ps_${summary.idfol}.pdf',
        onLayout: (_) async => doc.save(),
      );
      if (!mounted || nonCashFormas.isEmpty) return;
      final openVoucher = await _confirmOpenVoucherPreview(context);
      if (!mounted || !openVoucher) return;
      final voucherDoc = _buildVoucherPdf(
        summary: summary,
        detalle: detalle,
        widthMm: widthMm,
        nonCashFormas: nonCashFormas,
      );
      await Printing.layoutPdf(
        name: 'ps_${summary.idfol}_voucher.pdf',
        onLayout: (_) async => voucherDoc.save(),
      );
    } catch (e) {
      if (!mounted) return;
      _showError(
        apiErrorMessage(
          e,
          fallback: 'No se pudo generar la impresión del ticket PS',
        ),
      );
    } finally {
      if (mounted) setState(() => _printingTicket = false);
    }
  }

  Future<bool> _confirmOpenVoucherPreview(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Abrir voucher'),
          content: const Text(
            'Se cerró la vista previa del ticket. ¿Desea abrir ahora la vista previa del voucher?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('No'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Sí'),
            ),
          ],
        );
      },
    );
    return result == true;
  }

  Future<double?> _selectTicketWidth(BuildContext context) {
    return showDialog<double>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Selecciona ancho de impresion'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('58 mm (ticket compacto)'),
                onTap: () => Navigator.of(ctx).pop(58.0),
              ),
              ListTile(
                title: const Text('80 mm (ticket estandar)'),
                onTap: () => Navigator.of(ctx).pop(80.0),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    );
  }

  pw.Document _buildTicketPdf({
    required PsPagoSummary summary,
    required double widthMm,
    PsDetalleResponse? detalle,
  }) {
    final doc = pw.Document();
    final header = detalle?.header;
    final ticket = detalle?.ticket ?? const <PsTicketLine>[];
    final ords = _collectOrdsFromTicket(ticket);
    final opvValue = (header?.opv ?? '').trim();
    final opvmValue = (header?.opvm ?? '').trim();
    final opvLabel = [
      if (opvValue.isNotEmpty) opvValue,
      if (opvmValue.isNotEmpty) opvmValue,
    ].join(' - ');
    final transDate = _resolveTicketDate(summary.formas);
    final nonCashFormas = summary.formas
        .where((f) => f.form.trim().toUpperCase() != 'EFECTIVO')
        .toList(growable: false);
    final widthPt = _mmToPt(widthMm);
    final pageHeightMm = _estimateTicketHeightMm(summary, ticket, widthMm);
    final line = '-' * (widthMm <= 58 ? 30 : 38);
    final baseFont = widthMm <= 58 ? 9.0 : 10.0;
    final smallFont = widthMm <= 58 ? 8.0 : 9.0;
    final sucLabel = _textOrDash(header?.suc ?? summary.suc);
    final clienteIdLabel = header?.clien?.toString() ?? '-';
    final clienteNombreLabel = _textOrDash(header?.razonSocialReceptor);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat(widthPt, _mmToPt(pageHeightMm), marginAll: 0),
        margin: pw.EdgeInsets.only(left: _mmToPt(2)),
        maxPages: 120,
        build: (_) => [
          pw.Text(line, style: pw.TextStyle(fontSize: smallFont)),
          pw.Text(
            'SUC: $sucLabel',
            style: pw.TextStyle(fontSize: baseFont),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            'MODULO: PAGO DE SERVICIOS',
            style: pw.TextStyle(fontSize: smallFont),
          ),
          pw.SizedBox(height: 4),
          pw.Text(line, style: pw.TextStyle(fontSize: smallFont)),
          pw.Text(
            'DETALLE',
            style: pw.TextStyle(
              fontSize: baseFont,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          if (ticket.isEmpty)
            pw.Text(
              'Sin articulos registrados',
              style: pw.TextStyle(fontSize: smallFont),
            )
          else
            ...[
              for (var i = 0; i < ticket.length; i++)
                _buildPsTicketDetalleItem(
                  ticket[i],
                  index: i,
                  baseFontSize: baseFont,
                  smallFontSize: smallFont,
                ),
            ],
          pw.SizedBox(height: 4),
          pw.Text(line, style: pw.TextStyle(fontSize: smallFont)),
          pw.Text(
            'TOTALES',
            style: pw.TextStyle(fontSize: baseFont, fontWeight: pw.FontWeight.bold),
          ),
          _ticketRow('Total base', _money(summary.total), baseFont),
          _ticketRow('Subtotal', _money(summary.total), baseFont),
          _ticketRow('IVA', _money(0), baseFont),
          _ticketRow('Total final', _money(summary.total), baseFont),
          _ticketRow('Pagos', _money(summary.pagado), baseFont),
          _ticketRow('Faltante', _money(summary.restante), baseFont),
          _ticketRow('Cambio', _money(summary.cambio), baseFont),
          pw.SizedBox(height: 4),
          pw.Text(
            'FORMAS',
            style: pw.TextStyle(fontSize: baseFont, fontWeight: pw.FontWeight.bold),
          ),
          if (summary.formas.isEmpty)
            pw.Text(
              'Sin formas de pago',
              style: pw.TextStyle(fontSize: smallFont),
            )
          else
            ...summary.formas.map((f) {
              final ref = (f.aut ?? '').trim();
              return pw.Padding(
                padding: const pw.EdgeInsets.only(top: 2),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _ticketRow(f.form, _money(f.impp), baseFont),
                    if (ref.isNotEmpty)
                      pw.Text(
                        'REF: $ref',
                        style: pw.TextStyle(fontSize: smallFont),
                      ),
                    if (f.fcn != null)
                      pw.Text(
                        'FCN: ${_fmtDateTime(f.fcn)}',
                        style: pw.TextStyle(fontSize: smallFont),
                      ),
                  ],
                ),
              );
            }),
          pw.SizedBox(height: 4),
          pw.Text(line, style: pw.TextStyle(fontSize: smallFont)),
          pw.Text(
            'TRANSACCION',
            style: pw.TextStyle(
              fontSize: baseFont,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Text(
            'OPV: ${opvLabel.isEmpty ? '-' : opvLabel}',
            style: pw.TextStyle(fontSize: baseFont),
          ),
          pw.Text(
            'IDFOLIO: ${summary.idfol}',
            style: pw.TextStyle(fontSize: baseFont),
          ),
          pw.Text(
            'FCNM: ${_fmtDateTime(transDate)}',
            style: pw.TextStyle(fontSize: baseFont),
          ),
          pw.Text(
            'CLIENTE: $clienteNombreLabel ($clienteIdLabel)',
            style: pw.TextStyle(fontSize: baseFont),
          ),
          pw.SizedBox(height: 4),
          pw.Text(line, style: pw.TextStyle(fontSize: smallFont)),
          pw.Text(
            'RESUMEN DE ORDS',
            style: pw.TextStyle(
              fontSize: baseFont,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          if (ords.isEmpty)
            pw.Text(
              'Sin ORDs ligadas',
              style: pw.TextStyle(fontSize: smallFont),
            )
          else
            ...ords.map((ord) {
              return pw.Container(
                width: double.infinity,
                margin: const pw.EdgeInsets.only(bottom: 2),
                padding: const pw.EdgeInsets.symmetric(
                  vertical: 2,
                  horizontal: 2,
                ),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  border: pw.Border.all(color: PdfColors.grey500, width: 0.5),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'ORD: ${ord.ord}',
                      style: pw.TextStyle(fontSize: baseFont),
                    ),
                    pw.Text(
                      'DES: ${ord.description.isEmpty ? '-' : ord.description}',
                      style: pw.TextStyle(fontSize: smallFont),
                    ),
                    pw.Text(
                      'UPC: ${ord.upc.isEmpty ? '-' : ord.upc}',
                      style: pw.TextStyle(fontSize: smallFont),
                    ),
                  ],
                ),
              );
            }),
          if (nonCashFormas.isNotEmpty)
            pw.Text(
              'GRACIAS POR SU CONFIANZA',
              style: pw.TextStyle(
                fontSize: smallFont,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
        ],
      ),
    );

    return doc;
  }

  pw.Document _buildVoucherPdf({
    required PsPagoSummary summary,
    required double widthMm,
    required List<PsFormaPagoItem> nonCashFormas,
    PsDetalleResponse? detalle,
  }) {
    final doc = pw.Document();
    if (nonCashFormas.isEmpty) return doc;

    final header = detalle?.header;
    final transDate = _resolveTicketDate(summary.formas);
    final sucValue = (summary.suc).trim();
    final sucLabel = sucValue.isEmpty ? '-' : sucValue;

    final widthPt = _mmToPt(widthMm);
    final pageFormat = PdfPageFormat(
      widthPt,
      _mmToPt(
        _estimateVoucherHeightMm(
          voucherCount: nonCashFormas.length,
          widthMm: widthMm,
        ),
      ),
      marginAll: 0,
    );
    final leftMarginPt = _mmToPt(2);
    final baseFont = widthMm <= 58 ? 9.0 : 10.0;
    final smallFont = widthMm <= 58 ? 8.0 : 9.0;

    doc.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.only(left: leftMarginPt),
        maxPages: 120,
        build: (_) => [
          ...nonCashFormas.map(
            (forma) => _buildVoucherSectionPs(
              forma: forma,
              idfol: summary.idfol,
              suc: sucLabel,
              clienteNombre: header?.razonSocialReceptor,
              clienteId: header?.clien?.toString(),
              tra: header?.tra,
              fecha: forma.fcn ?? transDate,
              totalOperacion: summary.total,
              baseFontSize: baseFont,
              smallFontSize: smallFont,
            ),
          ),
        ],
      ),
    );
    return doc;
  }

  List<_PsTicketOrdSummary> _collectOrdsFromTicket(List<PsTicketLine> ticket) {
    final byOrd = <String, List<PsTicketLine>>{};
    for (final line in ticket) {
      final ord = (line.ord ?? '').trim();
      if (ord.isEmpty) continue;
      byOrd.putIfAbsent(ord, () => <PsTicketLine>[]).add(line);
    }

    final result = <_PsTicketOrdSummary>[];
    for (final entry in byOrd.entries) {
      final upcs = <String>{};
      final descriptions = <String>{};
      for (final line in entry.value) {
        final upc = (line.upc ?? '').trim();
        final description = (line.des ?? line.art ?? '').trim();
        if (upc.isNotEmpty) upcs.add(upc);
        if (description.isNotEmpty) descriptions.add(description);
      }
      result.add(
        _PsTicketOrdSummary(
          ord: entry.key,
          upc: upcs.join(', '),
          description: descriptions.join(' | '),
        ),
      );
    }
    result.sort((a, b) => a.ord.compareTo(b.ord));
    return result;
  }

  DateTime? _resolveTicketDate(List<PsFormaPagoItem> formas) {
    DateTime? latest;
    for (final forma in formas) {
      final current = forma.fcn;
      if (current == null) continue;
      if (latest == null || current.isAfter(latest)) {
        latest = current;
      }
    }
    return latest;
  }

  pw.Widget _buildPsTicketDetalleItem(
    PsTicketLine item, {
    required int index,
    required double baseFontSize,
    required double smallFontSize,
  }) {
    final name = (item.des ?? item.art ?? '-').trim();
    final qtyValue = item.ctd ?? 1;
    final qty = qtyValue.toStringAsFixed(2);
    final unitValue = item.pvta ?? (qtyValue != 0 ? (item.total ?? 0) / qtyValue : 0);
    final unit = _money(unitValue);
    final impValue = item.total ?? item.pvtat ?? (qtyValue * unitValue);
    final imp = _money(impValue);
    final upc = (item.upc ?? '').trim();
    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(bottom: 2),
      padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 2),
      decoration: pw.BoxDecoration(
        color: index.isEven ? PdfColors.white : PdfColors.grey100,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(name, style: pw.TextStyle(fontSize: baseFontSize)),
          pw.Text(
            'UPC: ${upc.isEmpty ? '-' : upc}',
            style: pw.TextStyle(fontSize: smallFontSize),
          ),
          pw.Text(
            '$qty x $unit = $imp',
            style: pw.TextStyle(fontSize: smallFontSize),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildVoucherSectionPs({
    required PsFormaPagoItem forma,
    required String idfol,
    required String suc,
    required String? clienteNombre,
    required String? clienteId,
    required String? tra,
    required DateTime? fecha,
    required double totalOperacion,
    required double baseFontSize,
    required double smallFontSize,
  }) {
    final form = forma.form.trim().isEmpty ? '-' : forma.form.trim().toUpperCase();
    final impd = _money(totalOperacion);
    final autRef = (forma.aut ?? '').trim().isEmpty ? '-' : forma.aut!.trim();
    final clienteNom = (clienteNombre ?? '').trim().isEmpty ? '-' : clienteNombre!.trim();
    final clienteCodigo = (clienteId ?? '').trim().isEmpty ? '-' : clienteId!.trim();
    final traValue = (tra ?? '').trim().isEmpty ? '-' : tra!.trim();

    pw.Widget lineText(String text, {bool bold = false}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(top: 1, bottom: 1),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: smallFontSize,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      );
    }

    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 2),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildVoucherCutLine(smallFontSize: smallFontSize),
          pw.Text(
            'VOUCHER',
            style: pw.TextStyle(
              fontSize: baseFontSize,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            'SOPORTE RECEPCION\nPAGO',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: baseFontSize,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            'Detalle',
            style: pw.TextStyle(
              fontSize: smallFontSize,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          lineText('FORM   $form'),
          lineText('IMPD   $impd'),
          lineText('AUT o REF   $autRef'),
          lineText('Nombre de cliente   $clienteNom'),
          lineText('IDC   $clienteCodigo'),
          lineText('FCN   ${_fmtDateTime(fecha)}'),
          pw.SizedBox(height: 16),
          lineText('____________________________'),
          lineText('Firma cliente'),
          lineText('SUC   $suc   TRA   $traValue'),
          lineText('IDFOL   $idfol', bold: true),
        ],
      ),
    );
  }

  pw.Widget _buildVoucherCutLine({required double smallFontSize}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 2, bottom: 2),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              '----------------',
              style: pw.TextStyle(fontSize: smallFontSize),
            ),
          ),
          pw.SizedBox(width: 4),
          pw.Text(
            '✂',
            style: pw.TextStyle(
              fontSize: smallFontSize + 1,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(width: 4),
          pw.Expanded(
            child: pw.Text(
              '----------------',
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(fontSize: smallFontSize),
            ),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  bool _isEstadoPagado(String? value) {
    final estado = (value ?? '').trim().toUpperCase();
    return estado == 'PAGADO' || estado == 'TRANSMITIR';
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final PsPagoSummary summary;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Resumen de pago',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            _row('IDFOL', summary.idfol),
            _row('SUC', summary.suc.isEmpty ? '-' : summary.suc),
            _row('ESTA', summary.esta.isEmpty ? '-' : summary.esta),
            _row('Total', _money(summary.total)),
            _row('Pagado', _money(summary.pagado)),
            _row('Restante', _money(summary.restante)),
            _row('Cambio', _money(summary.cambio)),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _FormasPagoCard extends StatelessWidget {
  const _FormasPagoCard({
    required this.formasAsync,
    required this.isPagado,
    required this.canAddForma,
    required this.saving,
    required this.formasCatalogLoading,
    required this.onAddForma,
    required this.onDeleteForma,
  });

  final AsyncValue<List<PsFormaPagoItem>> formasAsync;
  final bool isPagado;
  final bool canAddForma;
  final bool saving;
  final bool formasCatalogLoading;
  final VoidCallback onAddForma;
  final Future<void> Function(PsFormaPagoItem item) onDeleteForma;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Formas de pago',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                FilledButton.icon(
                  onPressed: (!formasCatalogLoading && canAddForma) ? onAddForma : null,
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            formasAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('Error: $e'),
              data: (formas) {
                if (formas.isEmpty) {
                  return const Text('Sin formas agregadas');
                }
                return Column(
                  children: formas.map((item) {
                    final aut = (item.aut ?? '').trim();
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text('${item.form} - ${_money(item.impp)}'),
                      subtitle: aut.isEmpty ? null : Text('Ref: $aut'),
                      trailing: isPagado
                          ? null
                          : IconButton(
                              tooltip: 'Eliminar',
                              onPressed: saving
                                  ? null
                                  : () async => onDeleteForma(item),
                              icon: const Icon(Icons.delete_outline),
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
}

class _SectionContainer extends StatelessWidget {
  const _SectionContainer({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final borderColor = Theme.of(context).dividerColor.withValues(alpha: 0.35);
    return Container(
      width: double.infinity,
      alignment: Alignment.topLeft,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }
}

typedef _SelectReferenciaCallback =
    Future<RefDetalleSelectionResult?> Function({
      required String form,
      required double impt,
      String? currentIdref,
    });

class _FormaDialog extends StatefulWidget {
  const _FormaDialog({
    required this.maxNoEfectivo,
    required this.formasDisponibles,
    required this.onSelectReferencia,
  });

  final double maxNoEfectivo;
  final List<String> formasDisponibles;
  final _SelectReferenciaCallback onSelectReferencia;

  @override
  State<_FormaDialog> createState() => _FormaDialogState();
}

class _FormaDialogState extends State<_FormaDialog> {
  late String _form;
  final TextEditingController _imppCtrl = TextEditingController();
  String? _aut;
  String? _error;

  @override
  void initState() {
    super.initState();
    _form = _defaultFormaInicial(widget.formasDisponibles);
  }

  @override
  void dispose() {
    _imppCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final needsAut = _formRequiereReferenciaTipo(_form);

    return AlertDialog(
      title: const Text('Agregar forma'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _form,
              items: widget.formasDisponibles
                  .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _form = value;
                  if (!_formRequiereReferenciaTipo(_form)) _aut = null;
                  _error = null;
                });
              },
              decoration: const InputDecoration(
                labelText: 'Forma',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _imppCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Importe',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            if (needsAut) ...[
              const SizedBox(height: 10),
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Autorización / referencia',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                child: Text(
                  (_aut ?? '').trim().isEmpty ? 'Sin referencia asignada' : _aut!,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _generateReferencia,
                  icon: const Icon(Icons.manage_search),
                  label: const Text('Generar/Asignar referencia'),
                ),
              ),
            ],
            if ((_error ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Guardar'),
        ),
      ],
    );
  }

  void _save() {
    final impp = double.tryParse(_imppCtrl.text.trim().replaceAll(',', '.'));
    if (impp == null || impp <= 0) {
      setState(() => _error = 'Capture un importe válido');
      return;
    }

    final isEfectivo = _form.trim().toUpperCase() == 'EFECTIVO';
    final needsAut = _formRequiereReferenciaTipo(_form);
    final aut = (_aut ?? '').trim();
    if (needsAut && aut.isEmpty) {
      setState(() => _error = 'La forma seleccionada requiere autorización/referencia');
      return;
    }
    if (!isEfectivo && (impp - widget.maxNoEfectivo) > 0.0001) {
      setState(
        () => _error =
            'El importe no puede exceder el faltante por pagar (${_money(widget.maxNoEfectivo)})',
      );
      return;
    }

    Navigator.of(context).pop(
      _FormaDialogResult(
        form: _form,
        impp: _round2(impp),
        aut: needsAut ? (_aut ?? '').trim() : null,
      ),
    );
  }

  Future<void> _generateReferencia() async {
    final impt = double.tryParse(_imppCtrl.text.trim().replaceAll(',', '.'));
    if (impt == null || impt <= 0) {
      setState(() => _error = 'Capture un importe válido antes de asignar referencia');
      return;
    }
    if (_formRequiereReferenciaTipo(_form) &&
        (_round2(impt) - widget.maxNoEfectivo) > 0.0001) {
      setState(
        () => _error =
            'El importe no puede exceder el faltante por pagar (${_money(widget.maxNoEfectivo)})',
      );
      return;
    }
    final selectedRef = await widget.onSelectReferencia(
      form: _form,
      impt: _round2(impt),
      currentIdref: _aut,
    );
    if (!mounted || selectedRef == null) return;
    final normalized = selectedRef.idref.trim();
    if (normalized.isEmpty) return;
    setState(() {
      _aut = normalized;
      _imppCtrl.text = selectedRef.impt.toStringAsFixed(2);
      _error = null;
    });
  }
}

class _FormaDialogResult {
  _FormaDialogResult({
    required this.form,
    required this.impp,
    required this.aut,
  });

  final String form;
  final double impp;
  final String? aut;
}

class _PsTicketOrdSummary {
  const _PsTicketOrdSummary({
    required this.ord,
    required this.upc,
    required this.description,
  });

  final String ord;
  final String upc;
  final String description;
}

List<_PsTicketOrdSummary> _collectPsTicketOrdSummary(
  List<PsTicketLine> ticket,
) {
  final byOrd = <String, List<PsTicketLine>>{};
  for (final item in ticket) {
    final ord = (item.ord ?? '').trim();
    if (ord.isEmpty) continue;
    byOrd.putIfAbsent(ord, () => <PsTicketLine>[]).add(item);
  }

  final result = <_PsTicketOrdSummary>[];
  for (final entry in byOrd.entries) {
    final upcs = <String>{};
    final descriptions = <String>{};
    for (final item in entry.value) {
      final upc = (item.upc ?? '').trim();
      final description = (item.des ?? item.art ?? '').trim();
      if (upc.isNotEmpty) upcs.add(upc);
      if (description.isNotEmpty) descriptions.add(description);
    }
    result.add(
      _PsTicketOrdSummary(
        ord: entry.key,
        upc: upcs.join(', '),
        description: descriptions.join(' | '),
      ),
    );
  }
  result.sort((a, b) => a.ord.compareTo(b.ord));
  return result;
}

double _estimateTicketHeightMm(
  PsPagoSummary summary,
  List<PsTicketLine> ticket,
  double widthMm,
) {
  final is58 = widthMm <= 58;
  final charsPerLine = is58 ? 28 : 34;
  final lineMm = is58 ? 3.3 : 3.9;
  final ords = _collectPsTicketOrdSummary(ticket);
  double mm = 0;

  mm += 6;
  mm += _measureTextHeightMm('SUC: ${summary.suc}', charsPerLine, lineMm);
  mm += _measureTextHeightMm('MODULO: PAGO DE SERVICIOS', charsPerLine, lineMm);

  mm += 8;
  if (ticket.isEmpty) {
    mm += lineMm;
  } else {
    for (final item in ticket) {
      final name = (item.des ?? item.art ?? '-').trim();
      final upc = (item.upc ?? '').trim();
      mm += _measureTextHeightMm(name, charsPerLine, lineMm);
      mm += _measureTextHeightMm(
        'UPC: ${upc.isEmpty ? '-' : upc}',
        charsPerLine,
        lineMm,
      );
      mm += lineMm;
      mm += 1.4;
    }
  }

  mm += 8;
  mm += lineMm * 7;

  mm += 5;
  if (summary.formas.isEmpty) {
    mm += lineMm;
  } else {
    for (final forma in summary.formas) {
      mm += lineMm;
      final ref = (forma.aut ?? '').trim();
      if (ref.isNotEmpty) {
        mm += _measureTextHeightMm('REF: $ref', charsPerLine, lineMm);
      }
      if (forma.fcn != null) {
        mm += lineMm;
      }
    }
  }

  mm += 7;
  mm += _measureTextHeightMm('OPV: -', charsPerLine, lineMm);
  mm += _measureTextHeightMm('IDFOLIO: ${summary.idfol}', charsPerLine, lineMm);
  mm += _measureTextHeightMm('FCNM: -', charsPerLine, lineMm);
  mm += _measureTextHeightMm('CLIENTE: - (-)', charsPerLine, lineMm);

  mm += 7;
  if (ords.isEmpty) {
    mm += lineMm;
  } else {
    for (final ord in ords) {
      mm += _measureTextHeightMm('ORD: ${ord.ord}', charsPerLine, lineMm);
      mm += _measureTextHeightMm(
        'DES: ${ord.description.isEmpty ? '-' : ord.description}',
        charsPerLine,
        lineMm,
      );
      mm += _measureTextHeightMm(
        'UPC: ${ord.upc.isEmpty ? '-' : ord.upc}',
        charsPerLine,
        lineMm,
      );
      mm += 2.5;
    }
  }
  mm += is58 ? 10 : 16;
  final minMm = is58 ? 180.0 : 230.0;
  final maxMm = is58 ? 1800.0 : 2400.0;
  return mm.clamp(minMm, maxMm).toDouble();
}

double _estimateVoucherHeightMm({
  required int voucherCount,
  required double widthMm,
}) {
  final is58 = widthMm <= 58;
  final perVoucher = is58 ? 108.0 : 120.0;
  final padding = is58 ? 14.0 : 18.0;
  final minMm = is58 ? 140.0 : 170.0;
  final maxMm = is58 ? 1800.0 : 2400.0;
  final mm = (voucherCount * perVoucher) + padding;
  return mm.clamp(minMm, maxMm).toDouble();
}

double _measureTextHeightMm(String text, int charsPerLine, double lineMm) {
  final value = text.trim();
  if (value.isEmpty) return 0;
  final normalized = value.replaceAll('\r', '');
  var totalLines = 0;
  for (final rawLine in normalized.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty) {
      totalLines += 1;
      continue;
    }
    totalLines += math.max(1, (line.length / charsPerLine).ceil());
  }
  return totalLines * lineMm;
}

pw.Widget _ticketRow(String label, String value, double fontSize) {
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Expanded(
        child: pw.Text(label, style: pw.TextStyle(fontSize: fontSize)),
      ),
      pw.Text(value, style: pw.TextStyle(fontSize: fontSize)),
    ],
  );
}

String _textOrDash(String? value) {
  final text = (value ?? '').trim();
  return text.isEmpty ? '-' : text;
}

String _money(double value) => '\$${value.toStringAsFixed(2)}';

String _fmtDateTime(DateTime? value) {
  if (value == null) return '-';
  final local = value.toLocal();
  String p2(int n) => n.toString().padLeft(2, '0');
  return '${p2(local.day)}/${p2(local.month)}/${local.year} ${p2(local.hour)}:${p2(local.minute)}';
}

double _round2(double value) =>
    (value.isFinite ? (value * 100).roundToDouble() / 100 : 0.0);

double _mmToPt(double mm) => mm * (72.0 / 25.4);

List<String> _formasParaDialogo(List<PsFormaCatalogItem> catalogo) {
  final result = <String>[];
  final seen = <String>{};
  for (final item in catalogo) {
    final form = item.form.trim().toUpperCase();
    if (form.isEmpty) continue;
    if (_formasNoPermitidasPs.contains(form)) continue;
    if (seen.add(form)) result.add(form);
  }
  if (!seen.contains('EFECTIVO')) {
    result.insert(0, 'EFECTIVO');
  }
  return result;
}

String _defaultFormaInicial(List<String> formas) {
  if (formas.contains('EFECTIVO')) return 'EFECTIVO';
  return formas.isNotEmpty ? formas.first : 'EFECTIVO';
}

