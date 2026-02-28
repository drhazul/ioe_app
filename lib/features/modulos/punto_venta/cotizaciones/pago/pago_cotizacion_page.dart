import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ioe_app/core/api_error.dart';
import 'package:ioe_app/core/auth/auth_controller.dart';
import 'package:ioe_app/features/masterdata/sucursales/sucursales_providers.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../cotizaciones_providers.dart';
import '../detalle_cot/pvticketlog_providers.dart';
import 'pago_cotizacion_models.dart';
import 'pago_cotizacion_providers.dart';
import 'ref_detalle/ref_detalle_models.dart';
import 'ref_detalle/ref_detalle_providers.dart';

const Set<String> _formasConReferencia = {
  'TARJETA',
  'CHEQUE',
  'TRANSFERENCIA',
  'DEPOSITO 3RO',
};

bool _formRequiereReferenciaTipo(String form) =>
    _formasConReferencia.contains(form.toUpperCase().trim());

// Ajustes de tipografia para etiquetas/importes en resumenes.
const double _kResumenTituloSize = 16;
const double _kResumenLabelSize = 15;
const double _kResumenImporteSize = 17;
const double _kFormasItemSize = 15;
const double _kFormasRefSize = 14;

class PagoCotizacionPage extends ConsumerStatefulWidget {
  const PagoCotizacionPage({
    super.key,
    required this.idfol,
    required this.initialTipoTran,
    required this.initialRqfac,
  });

  final String idfol;
  final String initialTipoTran;
  final bool initialRqfac;

  @override
  ConsumerState<PagoCotizacionPage> createState() => _PagoCotizacionPageState();
}

class _PagoCotizacionPageState extends ConsumerState<PagoCotizacionPage> {
  bool _imprimiendoTicket = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref
          .read(pagoCotizacionControllerProvider(widget.idfol).notifier)
          .initialize(
            tipotran: widget.initialTipoTran,
            rqfac: widget.initialRqfac,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pagoCotizacionControllerProvider(widget.idfol));
    final notifier = ref.read(
      pagoCotizacionControllerProvider(widget.idfol).notifier,
    );
    final formasCatalogAsync = ref.watch(pagoFormasCatalogProvider);
    final formasDisponibles = _formasParaDialogo(
      tipotran: state.tipotran,
      catalogo: formasCatalogAsync.valueOrNull ?? const [],
    );
    final isEstadoPagado = _isEstadoPagado(state.context?.esta);

    final total = state.totales?.total ?? 0;
    final sumPagos = state.sumPagos;
    final canAddForma =
        !isEstadoPagado &&
        !state.submitting &&
        total > 0 &&
        (sumPagos + 0.0001) < total;
    final faltante = _round2(total > sumPagos ? total - sumPagos : 0.0);
    final cambio = _round2(sumPagos > total ? sumPagos - total : 0.0);
    final canFinalize =
        !isEstadoPagado &&
        !state.submitting &&
        state.formas.isNotEmpty &&
        total > 0 &&
        sumPagos >= total;
    final canChangeTipoCierre =
        !isEstadoPagado && !state.submitting && state.formas.isEmpty;
    final canChangeRqfac =
        !isEstadoPagado &&
        !state.submitting &&
        state.formas.isEmpty &&
        state.tipotran != 'CA';
    final firstSection = _SectionContainer(
      child: _TotalesCard(
        state: state,
        loading: state.loading,
        sumPagos: sumPagos,
        faltante: faltante,
        cambio: cambio,
      ),
    );
    final secondSection = _SectionContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
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
                        onPressed: canAddForma
                            ? () => _addForma(
                                context,
                                state,
                                formasDisponibles: formasDisponibles,
                              )
                            : null,
                        icon: const Icon(Icons.add),
                        label: const Text('Agregar'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (state.formas.isEmpty)
                    const Text('Sin formas agregadas')
                  else
                    Column(
                      children: state.formas.map((item) {
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.payments_outlined),
                          title: Text(
                            '${item.form} - ${_money(item.impp)}',
                            style: const TextStyle(
                              fontSize: _kFormasItemSize,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: item.aut == null || item.aut!.isEmpty
                              ? null
                              : Text(
                                  'Ref: ${item.aut}',
                                  style: const TextStyle(
                                    fontSize: _kFormasRefSize,
                                  ),
                                ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Editar',
                                onPressed: state.submitting || isEstadoPagado
                                    ? null
                                    : () => _editForma(
                                        context,
                                        state,
                                        item,
                                        formasDisponibles: formasDisponibles,
                                      ),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                tooltip: 'Eliminar',
                                onPressed: state.submitting || isEstadoPagado
                                    ? null
                                    : () => notifier.removeForma(item.id),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(isEstadoPagado ? Icons.lock : Icons.arrow_back),
          onPressed: state.submitting
              ? null
              : () => _onBackPressed(context, state),
        ),
        title: Text('Pago y cierre - ${widget.idfol}'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(62),
          child: _TipoCierreAppBarContent(
            tipotran: state.tipotran,
            rqfac: state.rqfac,
            canChangeTipoCierre: canChangeTipoCierre,
            canChangeRqfac: canChangeRqfac,
            onTipoChanged: (value) => notifier.setTipoTran(value),
            onRqfacChanged: (value) => notifier.setRqfac(value),
          ),
        ),
      ),
      body: state.loading && !state.initialized
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
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
                    if ((state.error ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        state.error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: canFinalize
                          ? () => _finalizar(context, state)
                          : null,
                      icon: state.submitting
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_circle_outline),
                      label: Text(
                        state.submitting
                            ? 'Finalizando...'
                            : 'Finalizar cierre',
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: isEstadoPagado && !_imprimiendoTicket
                          ? () => _imprimirTicket(context)
                          : null,
                      icon: _imprimiendoTicket
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.print_outlined),
                      label: Text(
                        _imprimiendoTicket
                            ? 'Imprimiendo...'
                            : 'Imprimir ticket',
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Future<void> _addForma(
    BuildContext context,
    PagoCotizacionState state, {
    required List<String> formasDisponibles,
  }) async {
    final total = state.totales?.total ?? 0;
    if (total > 0 && (state.sumPagos + 0.0001) >= total) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'El importe de la cotización ya está cubierto. No puede agregar más formas de pago.',
          ),
        ),
      );
      return;
    }

    if (formasDisponibles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No hay formas de pago disponibles en DAT_FORM para esta operación.',
          ),
        ),
      );
      return;
    }

    final result = await _showFormaDialog(
      context,
      state: state,
      existing: state.formas,
      formasDisponibles: formasDisponibles,
    );
    if (result == null) return;
    ref
        .read(pagoCotizacionControllerProvider(widget.idfol).notifier)
        .addForma(form: result.form, impp: result.impp, aut: result.aut);
  }

  Future<void> _editForma(
    BuildContext context,
    PagoCotizacionState state,
    PagoCierreFormaDraft item, {
    required List<String> formasDisponibles,
  }) async {
    final result = await _showFormaDialog(
      context,
      state: state,
      existing: state.formas.where((e) => e.id != item.id).toList(),
      initial: item,
      formasDisponibles: formasDisponibles,
    );
    if (result == null) return;
    ref
        .read(pagoCotizacionControllerProvider(widget.idfol).notifier)
        .updateForma(
          item.id,
          form: result.form,
          impp: result.impp,
          aut: result.aut,
        );
  }

  Future<void> _finalizar(
    BuildContext context,
    PagoCotizacionState state,
  ) async {
    final auth = ref.read(authControllerProvider);
    final idopv = (auth.username ?? '').trim().isEmpty ? null : auth.username;

    try {
      final refSinUsar = await _findReferenciaSinUsar(state);
      if (refSinUsar != null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Se detectaron referencias ligadas al folio sin utilizar. Gestionelas en REF_DETALLE para continuar.',
            ),
          ),
        );
        await _openRefDetalleGestionSinUso(
          context,
          state: state,
          refSinUsar: refSinUsar,
        );
        return;
      }

      final result = await ref
          .read(pagoCotizacionControllerProvider(widget.idfol).notifier)
          .finalizar(idopv: idopv);

      if (!context.mounted) return;

      ref.invalidate(cotizacionProvider(widget.idfol));
      ref.invalidate(cotizacionesListProvider);
      ref.invalidate(pvTicketLogListProvider(widget.idfol));
      final latestState = ref.read(pagoCotizacionControllerProvider(widget.idfol));
      final cierrePagado = _isEstadoPagado(latestState.context?.esta);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            cierrePagado
                ? 'Cierre completado. Total ${_money(result.totales.total)} | Cambio ${_money(result.cambio)}. Estado PAGADO confirmado. Puede imprimir ticket.'
                : 'Cierre completado. Total ${_money(result.totales.total)} | Cambio ${_money(result.cambio)}. Recargue para confirmar estado PAGADO.',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      final msg = apiErrorMessage(
        e,
        fallback: 'No se pudo finalizar el cierre',
      );
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _onBackPressed(
    BuildContext context,
    PagoCotizacionState state,
  ) async {
    if (_isEstadoPagado(state.context?.esta)) {
      try {
        await ref.read(pagoCotizacionApiProvider).updateEstado(
              idfol: widget.idfol,
              esta: 'TRANSMITIR',
            );
        ref.invalidate(cotizacionProvider(widget.idfol));
        ref.invalidate(cotizacionesListProvider);
        if (!context.mounted) return;
        context.go('/punto-venta/cotizaciones');
      } catch (e) {
        if (!context.mounted) return;
        final msg = apiErrorMessage(
          e,
          fallback:
              'No se pudo actualizar la cotización a TRANSMITIR al regresar',
        );
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
      return;
    }
    final idfolEncoded = Uri.encodeComponent(widget.idfol);
    context.go('/punto-venta/cotizaciones/$idfolEncoded/detalle');
  }

  bool _isEstadoPagado(String? value) {
    final estado = (value ?? '').trim().toUpperCase();
    return estado.contains('PAGADO');
  }

  Future<void> _imprimirTicket(BuildContext context) async {
    if (_imprimiendoTicket) return;
    setState(() => _imprimiendoTicket = true);
    try {
      await _mostrarVistaPreviaImpresion(context);
    } finally {
      if (mounted) {
        setState(() => _imprimiendoTicket = false);
      }
    }
  }

  Future<void> _mostrarVistaPreviaImpresion(BuildContext context) async {
    try {
      final widthMm = await _selectTicketWidth(context);
      if (widthMm == null) return;
      final preview = await ref
          .read(pagoCotizacionApiProvider)
          .fetchPrintPreview(widget.idfol);
      final doc = _buildTicketPdf(preview, widthMm: widthMm);
      if (!context.mounted) return;
      await Printing.layoutPdf(
        name: 'cotizacion_${preview.idfol}.pdf',
        onLayout: (_) async => doc.save(),
      );
    } catch (e) {
      if (!context.mounted) return;
      final msg = apiErrorMessage(
        e,
        fallback:
            'Cierre completado, pero no se pudo generar la vista previa PDF',
      );
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
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

  pw.Document _buildTicketPdf(
    PagoCierrePrintPreviewResponse data, {
    required double widthMm,
  }) {
    final doc = pw.Document();
    final header = data.header;
    final totals = data.totals;
    final footer = data.footer;

    final widthPt = _mmToPt(widthMm);
    final pageHeightMm = _estimateTicketHeightMm(data, widthMm);
    final leftMarginPt = _mmToPt(2);
    final pageFormat = PdfPageFormat(
      widthPt,
      _mmToPt(pageHeightMm),
      marginAll: 0,
    );
    final baseFontSize = widthMm <= 58 ? 9.0 : 10.0;
    final smallFontSize = widthMm <= 58 ? 8.0 : 9.0;
    final line = '-' * (widthMm <= 58 ? 30 : 38);
    final isCotizacionAbierta = totals.tipotran.trim().toUpperCase() == 'CA';

    final opvLabel = [
      if ((footer.opv ?? '').trim().isNotEmpty) footer.opv!.trim(),
      if ((footer.opvNombre ?? '').trim().isNotEmpty) footer.opvNombre!.trim(),
    ].join(' - ');

    doc.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.only(left: leftMarginPt),
        maxPages: 120,
        build: (_) => [
          pw.Text(line, style: pw.TextStyle(fontSize: smallFontSize)),
          pw.Text(
            'SUC: ${header.suc}  ${header.desc ?? ''}'.trim(),
            style: pw.TextStyle(fontSize: baseFontSize),
          ),
          if ((header.direccion ?? '').isNotEmpty)
            pw.Text(
              header.direccion!,
              style: pw.TextStyle(fontSize: smallFontSize),
            ),
          if ((header.contacto ?? '').isNotEmpty)
            pw.Text(
              'Contacto: ${header.contacto}',
              style: pw.TextStyle(fontSize: smallFontSize),
            ),
          if ((header.rfc ?? '').isNotEmpty)
            pw.Text(
              'RFC: ${header.rfc}',
              style: pw.TextStyle(fontSize: smallFontSize),
            ),
          pw.SizedBox(height: 4),
          pw.Text(line, style: pw.TextStyle(fontSize: smallFontSize)),
          pw.Text(
            'DETALLE',
            style: pw.TextStyle(
              fontSize: baseFontSize,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          if (data.items.isEmpty)
            pw.Text(
              'Sin articulos registrados',
              style: pw.TextStyle(fontSize: smallFontSize),
            )
          else
            ...[
              for (var i = 0; i < data.items.length; i++)
                _buildTicketDetalleItem(
                  data.items[i],
                  index: i,
                  baseFontSize: baseFontSize,
                  smallFontSize: smallFontSize,
                ),
            ],
          pw.SizedBox(height: 4),
          pw.Text(line, style: pw.TextStyle(fontSize: smallFontSize)),
          pw.Text(
            'TOTALES',
            style: pw.TextStyle(
              fontSize: baseFontSize,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          _ticketRow('Total base', _money(totals.totalBase), baseFontSize),
          if (!isCotizacionAbierta) ...[
            _ticketRow('Subtotal', _money(totals.subtotal), baseFontSize),
            _ticketRow('IVA', _money(totals.iva), baseFontSize),
            _ticketRow('Total final', _money(totals.total), baseFontSize),
            _ticketRow('Pagos', _money(totals.sumPagos), baseFontSize),
            _ticketRow('Faltante', _money(totals.faltante), baseFontSize),
            _ticketRow('Cambio', _money(totals.cambio), baseFontSize),
          ],
          if (!isCotizacionAbierta) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              'FORMAS',
              style: pw.TextStyle(
                fontSize: baseFontSize,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            if (data.formas.isEmpty)
              pw.Text(
                'Sin formas de pago',
                style: pw.TextStyle(fontSize: smallFontSize),
              )
            else
              ...data.formas.map((f) {
                final ref = (f.aut ?? '').trim();
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _ticketRow(f.form, _money(f.impp), baseFontSize),
                    if (ref.isNotEmpty)
                      pw.Text(
                        'REF: $ref',
                        style: pw.TextStyle(fontSize: smallFontSize),
                      ),
                  ],
                );
              }),
            pw.SizedBox(height: 4),
          ],
          pw.Text(line, style: pw.TextStyle(fontSize: smallFontSize)),
          pw.Text(
            'TRANSACCION',
            style: pw.TextStyle(
              fontSize: baseFontSize,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Text(
            'OPV: ${opvLabel.isEmpty ? '-' : opvLabel}',
            style: pw.TextStyle(fontSize: baseFontSize),
          ),
          pw.Text(
            'IDFOLIO: ${footer.idfol}',
            style: pw.TextStyle(fontSize: baseFontSize),
          ),
          pw.Text(
            'FCNM: ${_fmtDateTime(footer.fcnm)}',
            style: pw.TextStyle(fontSize: baseFontSize),
          ),
          pw.Text(
            'CLIENTE: ${footer.clienteNombre ?? '-'} (${footer.clienteId?.toString() ?? '-'})',
            style: pw.TextStyle(fontSize: baseFontSize),
          ),
          pw.SizedBox(height: 4),
          pw.Text(line, style: pw.TextStyle(fontSize: smallFontSize)),
          pw.Text(
            'RESUMEN DE ORDS',
            style: pw.TextStyle(
              fontSize: baseFontSize,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          if (data.ords.isEmpty)
            pw.Text(
              'Sin ORDs ligadas',
              style: pw.TextStyle(fontSize: smallFontSize),
            )
          else
            ...data.ords.map((ord) {
              final ordUpc = _resolveOrdUpc(ord, data.items);
              final ordDesc = (ord.desc ?? '').trim();
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
                      'ORD: ${ord.iord}',
                      style: pw.TextStyle(fontSize: baseFontSize),
                    ),
                    pw.Text(
                      'DES: ${ordDesc.isEmpty ? '-' : ordDesc}',
                      style: pw.TextStyle(fontSize: smallFontSize),
                    ),
                    pw.Text(
                      'UPC: ${ordUpc.isEmpty ? '-' : ordUpc}',
                      style: pw.TextStyle(fontSize: smallFontSize),
                    ),
                  ],
                ),
              );
            }),
          pw.SizedBox(height: 4),
          pw.Text(line, style: pw.TextStyle(fontSize: smallFontSize)),
          pw.Text(
            'ORDS',
            style: pw.TextStyle(
              fontSize: baseFontSize,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          if (data.ords.isEmpty)
            pw.Text(
              'Sin ORDs ligadas',
              style: pw.TextStyle(fontSize: smallFontSize),
            )
          else
              ...data.ords.map((ord) {
                final ordUpc = _resolveOrdUpc(ord, data.items);
                final ordDesc = (ord.desc ?? '').trim();
                final ordTipo = (ord.tipo ?? '').trim();
                final barcodeData = _sanitizeCode39Data(ord.iord);
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildOrdCutLine(smallFontSize: smallFontSize),
                    pw.Text(
                      'ORD: ${ord.iord}',
                      style: pw.TextStyle(fontSize: baseFontSize),
                    ),
                    pw.Text(
                      'UPC: ${ordUpc.isEmpty ? '-' : ordUpc}',
                      style: pw.TextStyle(fontSize: smallFontSize),
                    ),
                    if (ordDesc.isNotEmpty)
                      pw.Text(
                        ordDesc,
                        style: pw.TextStyle(fontSize: smallFontSize),
                      ),
                    if (ordTipo.isNotEmpty)
                      pw.Text(
                        'TIPO: $ordTipo',
                        style: pw.TextStyle(fontSize: smallFontSize),
                      ),
                    if (barcodeData.isNotEmpty)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 2, bottom: 3),
                        child: pw.BarcodeWidget(
                          barcode: pw.Barcode.code39(),
                          data: barcodeData,
                          drawText: true,
                          textStyle: pw.TextStyle(fontSize: smallFontSize),
                          width: widthMm <= 58 ? _mmToPt(48) : _mmToPt(70),
                          height: widthMm <= 58 ? 30 : 36,
                        ),
                      ),
                    _buildOrdDetailsTable(
                      ord,
                      smallFontSize: smallFontSize,
                    ),
                    pw.SizedBox(height: 2),
                  ],
                );
            }),
        ],
      ),
    );
    return doc;
  }

  pw.Widget _buildTicketDetalleItem(
    PagoCierrePrintItem item, {
    required int index,
    required double baseFontSize,
    required double smallFontSize,
  }) {
    final name = (item.des ?? item.art ?? '-').trim();
    final qty = item.ctd.toStringAsFixed(2);
    final unit = _money(item.pvta);
    final imp = _money(item.importe);
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

  pw.Widget _buildOrdCutLine({required double smallFontSize}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 2, bottom: 2),
      child: pw.Row(
        children: [
          pw.Expanded(child: pw.Container(height: 0.8, color: PdfColors.grey700)),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 4),
            child: pw.Text(
              '✂',
              style: pw.TextStyle(
                fontSize: smallFontSize + 1,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Expanded(child: pw.Container(height: 0.8, color: PdfColors.grey700)),
        ],
      ),
    );
  }

  double _estimateTicketHeightMm(
    PagoCierrePrintPreviewResponse data,
    double widthMm,
  ) {
    final is58 = widthMm <= 58;
    final charsPerLine = is58 ? 28 : 34;
    final lineMm = is58 ? 3.3 : 3.9;
    final isCotizacionAbierta = data.totals.tipotran.trim().toUpperCase() == 'CA';
    final footer = data.footer;

    double mm = 0;

    // Cabecera y separadores iniciales.
    mm += 6;
    mm += _measureTextHeightMm(
      'SUC: ${data.header.suc}  ${data.header.desc ?? ''}'.trim(),
      charsPerLine,
      lineMm,
    );
    if ((data.header.direccion ?? '').trim().isNotEmpty) {
      mm += _measureTextHeightMm(data.header.direccion!, charsPerLine, lineMm);
    }
    if ((data.header.contacto ?? '').trim().isNotEmpty) {
      mm += _measureTextHeightMm(
        'Contacto: ${data.header.contacto}',
        charsPerLine,
        lineMm,
      );
    }
    if ((data.header.rfc ?? '').trim().isNotEmpty) {
      mm += _measureTextHeightMm('RFC: ${data.header.rfc}', charsPerLine, lineMm);
    }

    // Detalle.
    mm += 8; // linea + titulo + espacio
    if (data.items.isEmpty) {
      mm += lineMm;
    } else {
      for (final item in data.items) {
        final name = (item.des ?? item.art ?? '-').trim();
        final upc = (item.upc ?? '').trim();
        mm += _measureTextHeightMm(name, charsPerLine, lineMm);
        mm += _measureTextHeightMm(
          'UPC: ${upc.isEmpty ? '-' : upc}',
          charsPerLine,
          lineMm,
        );
        mm += lineMm; // linea qty x unit = imp
        mm += 1.4; // padding/margen de renglon
      }
    }

    // Totales / Formas.
    mm += 8;
    mm += lineMm; // total base
    if (!isCotizacionAbierta) {
      mm += lineMm * 6; // subtotal iva total pagos faltante cambio
      mm += 5; // titulo FORMAS + espacio
      if (data.formas.isEmpty) {
        mm += lineMm;
      } else {
        for (final f in data.formas) {
          mm += lineMm;
          final ref = (f.aut ?? '').trim();
          if (ref.isNotEmpty) {
            mm += _measureTextHeightMm('REF: $ref', charsPerLine, lineMm);
          }
        }
      }
      mm += 2;
    }

    // Transaccion.
    final opvLabel = [
      if ((footer.opv ?? '').trim().isNotEmpty) footer.opv!.trim(),
      if ((footer.opvNombre ?? '').trim().isNotEmpty) footer.opvNombre!.trim(),
    ].join(' - ');
    mm += 7;
    mm += _measureTextHeightMm(
      'OPV: ${opvLabel.isEmpty ? '-' : opvLabel}',
      charsPerLine,
      lineMm,
    );
    mm += _measureTextHeightMm('IDFOLIO: ${footer.idfol}', charsPerLine, lineMm);
    mm += _measureTextHeightMm(
      'FCNM: ${_fmtDateTime(footer.fcnm)}',
      charsPerLine,
      lineMm,
    );
    mm += _measureTextHeightMm(
      'CLIENTE: ${footer.clienteNombre ?? '-'} (${footer.clienteId?.toString() ?? '-'})',
      charsPerLine,
      lineMm,
    );

    // Resumen ORDs.
    mm += 7;
    if (data.ords.isEmpty) {
      mm += lineMm;
    } else {
      for (final ord in data.ords) {
        final ordUpc = _resolveOrdUpc(ord, data.items);
        final ordDesc = (ord.desc ?? '').trim();
        mm += lineMm; // ORD
        mm += _measureTextHeightMm(
          'DES: ${ordDesc.isEmpty ? '-' : ordDesc}',
          charsPerLine,
          lineMm,
        );
        mm += _measureTextHeightMm(
          'UPC: ${ordUpc.isEmpty ? '-' : ordUpc}',
          charsPerLine,
          lineMm,
        );
        mm += 2.5; // borde/padding del bloque resumen
      }
    }

    // ORDs detalle.
    mm += 7;
    if (data.ords.isEmpty) {
      mm += lineMm;
    } else {
      for (final ord in data.ords) {
        final ordUpc = _resolveOrdUpc(ord, data.items);
        final ordDesc = (ord.desc ?? '').trim();
        final ordTipo = (ord.tipo ?? '').trim();
        final barcodeData = _sanitizeCode39Data(ord.iord);
        mm += 4.0; // linea de recorte
        mm += _measureTextHeightMm('ORD: ${ord.iord}', charsPerLine, lineMm);
        mm += _measureTextHeightMm(
          'UPC: ${ordUpc.isEmpty ? '-' : ordUpc}',
          charsPerLine,
          lineMm,
        );
        if (ordDesc.isNotEmpty) {
          mm += _measureTextHeightMm(ordDesc, charsPerLine, lineMm);
        }
        if (ordTipo.isNotEmpty) {
          mm += _measureTextHeightMm('TIPO: $ordTipo', charsPerLine, lineMm);
        }
        if (barcodeData.isNotEmpty) {
          mm += is58 ? 16.0 : 20.0;
        }
        mm += is58 ? 22.0 : 31.0; // tabla JOB/ESF/CIL/EJE
        mm += 2.0;
      }
    }

    // Ajuste final para evitar saltos por redondeo/render.
    // En 80mm se aplica un buffer extra porque el bloque de ORDs puede consumir
    // algo mas de alto en preview/impresion (tabla + barcode) y provocar hoja extra.
    mm += is58 ? 10.0 : (42.0 + (data.ords.length * 10.0));
    final minMm = is58 ? 180.0 : 230.0;
    final maxMm = is58 ? 1800.0 : 2400.0;
    return mm.clamp(minMm, maxMm).toDouble();
  }

  double _measureTextHeightMm(
    String text,
    int charsPerLine,
    double lineMm,
  ) {
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

  String _resolveOrdUpc(
    PagoCierrePrintOrd ord,
    List<PagoCierrePrintItem> items,
  ) {
    final iord = ord.iord.trim().toUpperCase();
    final ordArt = (ord.art ?? '').trim().toUpperCase();
    final upcs = <String>{};

    for (final item in items) {
      final itemOrd = (item.ord ?? '').trim().toUpperCase();
      final upc = (item.upc ?? '').trim();
      if (itemOrd == iord && upc.isNotEmpty) {
        upcs.add(upc);
      }
    }

    if (upcs.isEmpty && ordArt.isNotEmpty) {
      for (final item in items) {
        final itemArt = (item.art ?? '').trim().toUpperCase();
        final upc = (item.upc ?? '').trim();
        if (itemArt == ordArt && upc.isNotEmpty) {
          upcs.add(upc);
        }
      }
    }

    return upcs.join(', ');
  }

  String _sanitizeCode39Data(String value) {
    final raw = value.trim().toUpperCase();
    if (raw.isEmpty) return '';
    final reg = RegExp(r'^[0-9A-Z\-\.\ \$\/\+\%]$');
    final sb = StringBuffer();
    for (final codeUnit in raw.codeUnits) {
      final ch = String.fromCharCode(codeUnit);
      sb.write(reg.hasMatch(ch) ? ch : '-');
    }
    final sanitized = sb.toString().trim();
    return sanitized.isEmpty ? '' : sanitized;
  }

  pw.Widget _buildOrdDetailsTable(
    PagoCierrePrintOrd ord, {
    required double smallFontSize,
  }) {
    final rows = ord.details
        .map(
          (d) => [
            (d.job ?? '').trim(),
            (d.esf ?? '').trim(),
            (d.cil ?? '').trim(),
            (d.eje ?? '').trim(),
          ],
        )
        .toList();

    if (rows.isEmpty) {
      rows.add(['', '', '', '']);
    }

    pw.Widget cell(
      String text, {
      required bool header,
    }) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 3),
        alignment: pw.Alignment.center,
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: smallFontSize,
            fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      );
    }

    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 2, bottom: 2),
      child: pw.Table(
        border: pw.TableBorder.all(
          color: PdfColors.grey700,
          width: 0.6,
        ),
        columnWidths: const {
          0: pw.FlexColumnWidth(1.0),
          1: pw.FlexColumnWidth(1.2),
          2: pw.FlexColumnWidth(1.2),
          3: pw.FlexColumnWidth(1.2),
        },
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
            children: [
              cell('JOB', header: true),
              cell('ESF', header: true),
              cell('CIL', header: true),
              cell('EJE', header: true),
            ],
          ),
          ...rows.map(
            (row) => pw.TableRow(
              children: [
                cell(row[0], header: false),
                cell(row[1], header: false),
                cell(row[2], header: false),
                cell(row[3], header: false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<_ReferenciaSinUsar?> _findReferenciaSinUsar(
    PagoCotizacionState state,
  ) async {
    try {
      final refs = await ref
          .read(refDetalleApiProvider)
          .fetchByFolio(idfol: widget.idfol);
      final used = state.formas
          .map((item) => (item.aut ?? '').trim().toUpperCase())
          .where((idref) => idref.isNotEmpty)
          .toSet();

      for (final row in refs) {
        final idref = row.idref.trim().toUpperCase();
        if (idref.isEmpty) continue;
        final status = (row.estatus ?? '').trim().toUpperCase();
        final isAbierta = status == 'CAPTURADO' || status == 'PROCESADO';
        if (isAbierta && !used.contains(idref)) {
          return _ReferenciaSinUsar(
            idref: row.idref.trim(),
            tipo: (row.tipo ?? '').trim().toUpperCase(),
            impt: row.impt ?? 0,
          );
        }
      }
      return null;
    } catch (_) {
      // Si falla esta validacion previa, se permite continuar y backend valida.
      return null;
    }
  }

  Future<void> _openRefDetalleGestionSinUso(
    BuildContext context, {
    required PagoCotizacionState state,
    required _ReferenciaSinUsar refSinUsar,
  }) async {
    final contextInfo = state.context;
    if (contextInfo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo cargar el contexto del folio'),
        ),
      );
      return;
    }

    final suc = contextInfo.suc.trim();
    final idc = contextInfo.clien ?? 0;
    final total = state.totales?.total ?? 0.0;
    final faltante = _round2(
      total > state.sumPagos ? total - state.sumPagos : 0.0,
    );
    final impt = _round2(refSinUsar.impt > 0 ? refSinUsar.impt : faltante);
    try {
      final sucursales = await ref.read(sucursalesListProvider.future);
      final sucFound = sucursales.where((s) => s.suc.trim() == suc).toList();
      final rfcEmisor = sucFound.isEmpty
          ? ''
          : (sucFound.first.rfc ?? '').trim();
      if (!context.mounted) return;

      final auth = ref.read(authControllerProvider);
      final opv = (auth.username ?? '').trim();
      if (opv.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se encontró OPV del usuario')),
        );
        return;
      }

      final args = RefDetallePageArgs(
        idfol: widget.idfol,
        suc: suc,
        idc: idc,
        opv: opv,
        rfcEmisor: rfcEmisor,
        tipo: refSinUsar.tipo,
        impt: impt,
        maxImpt: faltante,
        rqfac: state.rqfac,
        initialIdref: refSinUsar.idref,
      );

      await context.push<RefDetalleSelectionResult>(
        '/punto-venta/cotizaciones/${Uri.encodeComponent(widget.idfol)}/ref-detalle',
        extra: args,
      );
    } catch (e) {
      if (!context.mounted) return;
      final msg = apiErrorMessage(
        e,
        fallback: 'No se pudo abrir REF_DETALLE para gestionar referencias',
      );
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<_FormaDialogResult?> _showFormaDialog(
    BuildContext context, {
    required PagoCotizacionState state,
    required List<PagoCierreFormaDraft> existing,
    required List<String> formasDisponibles,
    PagoCierreFormaDraft? initial,
  }) async {
    final formas = [...formasDisponibles];
    final initialFormNorm = (initial?.form ?? '').trim().toUpperCase();
    if (initialFormNorm.isNotEmpty && !formas.contains(initialFormNorm)) {
      formas.insert(0, initialFormNorm);
    }
    if (formas.isEmpty) return null;

    final form = _defaultFormaInicial(formas: formas, initial: initial);
    final existingSum = existing.fold<double>(
      0.0,
      (acc, item) => acc + item.impp,
    );
    final total = state.totales?.total ?? 0.0;
    final maxRefImpt = _round2(
      (total - existingSum) > 0 ? (total - existingSum) : 0.0,
    );
    String? aut = (initial?.aut ?? '').trim();
    if (aut.isEmpty) aut = null;
    if (!_formRequiereReferencia(form)) aut = null;
    return showDialog<_FormaDialogResult>(
      context: context,
      builder: (_) {
        return _FormaDialog(
          initial: initial,
          existing: existing,
          formas: formas,
          tipotran: state.tipotran,
          maxRefImpt: maxRefImpt,
          initialForm: form,
          initialAut: aut,
          onSelectReferencia: ({required form, required impt, currentIdref}) {
            return _openRefDetalleSelector(
              context,
              state: state,
              form: form,
              impt: impt,
              maxImpt: maxRefImpt,
              currentIdref: currentIdref,
            );
          },
        );
      },
    );
  }

  bool _formRequiereReferencia(String form) {
    return _formRequiereReferenciaTipo(form);
  }

  String _defaultFormaInicial({
    required List<String> formas,
    required PagoCierreFormaDraft? initial,
  }) {
    final initialForm = (initial?.form ?? '').trim().toUpperCase();
    if (initialForm.isNotEmpty && formas.contains(initialForm)) {
      return initialForm;
    }
    if (formas.contains('EFECTIVO')) return 'EFECTIVO';
    return formas.first;
  }

  List<String> _formasParaDialogo({
    required String tipotran,
    required List<PagoFormaCatalogItem> catalogo,
  }) {
    final normalizedTipo = tipotran.trim().toUpperCase();
    final result = <String>[];
    final seen = <String>{};

    for (final item in catalogo) {
      if (!item.estado) continue;
      final form = item.form.trim().toUpperCase();
      if (form.isEmpty) continue;
      if (normalizedTipo == 'CA' && form != 'EFECTIVO') continue;
      if (seen.add(form)) result.add(form);
    }

    if (normalizedTipo == 'CA') {
      return result.contains('EFECTIVO') ? const ['EFECTIVO'] : const [];
    }

    return result;
  }

  Future<RefDetalleSelectionResult?> _openRefDetalleSelector(
    BuildContext context, {
    required PagoCotizacionState state,
    required String form,
    required double impt,
    required double maxImpt,
    String? currentIdref,
  }) async {
    final contextInfo = state.context;
    if (contextInfo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo cargar el contexto del folio'),
        ),
      );
      return null;
    }

    final tipo = form.toUpperCase().trim();
    if (!_formRequiereReferencia(tipo)) return null;

    if (impt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El importe debe ser mayor a 0')),
      );
      return null;
    }
    if ((impt - maxImpt) > 0.0001) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'El importe no puede ser mayor al restante por pagar (${_money(maxImpt)})',
          ),
        ),
      );
      return null;
    }

    final idc = contextInfo.clien;
    if (idc == null || idc <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La cotización no tiene cliente válido')),
      );
      return null;
    }
    if ((state.rqfac || tipo != 'EFECTIVO') && idc == 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Para formas no efectivo o con factura, el cliente no puede ser 1',
          ),
        ),
      );
      return null;
    }

    final suc = contextInfo.suc.trim();
    final sucursales = await ref.read(sucursalesListProvider.future);
    final sucFound = sucursales.where((s) => s.suc.trim() == suc).toList();
    final rfcEmisor = sucFound.isEmpty ? '' : (sucFound.first.rfc ?? '').trim();
    if (!context.mounted) return null;
    if (rfcEmisor.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se encontró RFC emisor para la sucursal $suc'),
        ),
      );
      return null;
    }

    final auth = ref.read(authControllerProvider);
    final opv = (auth.username ?? '').trim();
    if (opv.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se encontró OPV del usuario')),
      );
      return null;
    }

    final args = RefDetallePageArgs(
      idfol: widget.idfol,
      suc: suc,
      idc: idc,
      opv: opv,
      rfcEmisor: rfcEmisor,
      tipo: tipo,
      impt: impt,
      maxImpt: maxImpt,
      rqfac: state.rqfac,
      initialIdref: currentIdref,
    );

    final result = await context.push<RefDetalleSelectionResult>(
      '/punto-venta/cotizaciones/${Uri.encodeComponent(widget.idfol)}/ref-detalle',
      extra: args,
    );
    if (!context.mounted) return null;
    return result;
  }
}

class _TipoCierreAppBarContent extends StatelessWidget {
  const _TipoCierreAppBarContent({
    required this.tipotran,
    required this.rqfac,
    required this.canChangeTipoCierre,
    required this.canChangeRqfac,
    required this.onTipoChanged,
    required this.onRqfacChanged,
  });

  final String tipotran;
  final bool rqfac;
  final bool canChangeTipoCierre;
  final bool canChangeRqfac;
  final ValueChanged<String> onTipoChanged;
  final ValueChanged<bool> onRqfacChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              const Text(
                'Tipo de cierre',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment<String>(
                    value: 'CA',
                    label: Text('CA - Cotizacion Abierta'),
                  ),
                  ButtonSegment<String>(
                    value: 'VF',
                    label: Text('VF - Venta Finalizada'),
                  ),
                ],
                selected: {tipotran},
                onSelectionChanged: !canChangeTipoCierre
                    ? null
                    : (value) {
                        if (value.isEmpty) return;
                        onTipoChanged(value.first);
                      },
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  children: [
                    const Text(
                      'RQFAC',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Switch(
                      value: tipotran == 'CA' ? false : rqfac,
                      onChanged: canChangeRqfac ? onRqfacChanged : null,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    Text(
                      tipotran == 'CA' ? 'No aplica en CA' : 'Requiere factura',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
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

class _TotalesCard extends StatelessWidget {
  const _TotalesCard({
    required this.state,
    required this.loading,
    required this.sumPagos,
    required this.faltante,
    required this.cambio,
  });

  final PagoCotizacionState state;
  final bool loading;
  final double sumPagos;
  final double faltante;
  final double cambio;

  @override
  Widget build(BuildContext context) {
    final totales = state.totales;
    final total = totales?.total ?? 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Total Caculado por Cotizacion',
                    style: TextStyle(
                      fontSize: _kResumenTituloSize,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (loading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            _ResumenRow(
              label: 'Total base',
              value: _money(totales?.totalBase ?? 0),
            ),
            _ResumenRow(
              label: 'Subtotal',
              value: _money(totales?.subtotal ?? 0),
            ),
            _ResumenRow(label: 'IVA', value: _money(totales?.iva ?? 0)),
            _ResumenRow(
              label: 'Total final',
              value: _money(total),
              emphasize: true,
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(height: 1),
            ),
            const Text(
              'Totales de formas de pago',
              style: TextStyle(
                fontSize: _kResumenTituloSize,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            _ResumenRow(label: 'Pagos', value: _money(sumPagos)),
            _ResumenRow(label: 'Faltante', value: _money(faltante)),
            _ResumenRow(
              label: 'Cambio',
              value: _money(cambio),
              emphasize: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _ResumenRow extends StatelessWidget {
  const _ResumenRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final valueStyle = TextStyle(
      fontSize: _kResumenImporteSize,
      fontWeight: emphasize ? FontWeight.w700 : FontWeight.w600,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: _kResumenLabelSize,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(value, style: valueStyle),
        ],
      ),
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
    required this.initial,
    required this.existing,
    required this.formas,
    required this.tipotran,
    required this.maxRefImpt,
    required this.initialForm,
    required this.initialAut,
    required this.onSelectReferencia,
  });

  final PagoCierreFormaDraft? initial;
  final List<PagoCierreFormaDraft> existing;
  final List<String> formas;
  final String tipotran;
  final double maxRefImpt;
  final String initialForm;
  final String? initialAut;
  final _SelectReferenciaCallback onSelectReferencia;

  @override
  State<_FormaDialog> createState() => _FormaDialogState();
}

class _FormaDialogState extends State<_FormaDialog> {
  late final TextEditingController _importeCtrl;
  late String _form;
  String? _aut;
  String? _error;

  @override
  void initState() {
    super.initState();
    _form = widget.initialForm;
    _aut = (widget.initialAut ?? '').trim().isEmpty
        ? null
        : widget.initialAut!.trim();
    if (!_formRequiereReferenciaTipo(_form)) {
      _aut = null;
    }
    _importeCtrl = TextEditingController(
      text: widget.initial == null
          ? ''
          : widget.initial!.impp.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _importeCtrl.dispose();
    super.dispose();
  }

  void _setError(String value) {
    setState(() => _error = value);
  }

  double? _parseImporte() {
    return double.tryParse(_importeCtrl.text.trim().replaceAll(',', '.'));
  }

  Future<void> _selectReferencia() async {
    final impt = _parseImporte();
    if (impt == null || impt <= 0) {
      _setError('Importe invalido');
      return;
    }

    final selectedRef = await widget.onSelectReferencia(
      form: _form,
      impt: _round2(impt),
      currentIdref: _aut,
    );
    if (!mounted || selectedRef == null) return;
    setState(() {
      _aut = selectedRef.idref.trim();
      _importeCtrl.text = selectedRef.impt.toStringAsFixed(2);
      _error = null;
    });
  }

  void _save() {
    final value = _parseImporte();
    if (value == null || value <= 0) {
      _setError('Importe invalido');
      return;
    }
    final isEfectivo = _form.trim().toUpperCase() == 'EFECTIVO';
    if (!isEfectivo && (value - widget.maxRefImpt) > 0.0001) {
      _setError(
        'El importe no puede ser mayor al restante por pagar (${_money(widget.maxRefImpt)})',
      );
      return;
    }

    if (_formRequiereReferenciaTipo(_form)) {
      if ((_aut ?? '').trim().isEmpty) {
        _setError('Debe generar/asignar referencia para $_form');
        return;
      }
    }

    if (widget.tipotran == 'CA' && widget.existing.isNotEmpty) {
      final first = widget.existing.first.form.toUpperCase().trim();
      if (first != _form.toUpperCase().trim()) {
        _setError(
          'En cierre CA solo se permite una forma (${widget.existing.first.form})',
        );
        return;
      }
    }

    Navigator.of(context).pop(
      _FormaDialogResult(
        form: _form,
        impp: _round2(value),
        aut: _formRequiereReferenciaTipo(_form)
            ? (_aut ?? '').trim().isEmpty
                  ? null
                  : _aut!.trim()
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Agregar forma' : 'Editar forma'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _form,
            decoration: const InputDecoration(
              labelText: 'Forma',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: widget.formas
                .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _form = value;
                if (!_formRequiereReferenciaTipo(_form)) {
                  _aut = null;
                }
              });
            },
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _importeCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Importe',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          if (_formRequiereReferenciaTipo(_form)) ...[
            const SizedBox(height: 10),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Autorizacion / referencia',
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
                onPressed: _selectReferencia,
                icon: const Icon(Icons.manage_search),
                label: const Text('Generar/Asignar referencia'),
              ),
            ),
          ],
          if ((_error ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _save, child: const Text('Guardar')),
      ],
    );
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

class _ReferenciaSinUsar {
  const _ReferenciaSinUsar({
    required this.idref,
    required this.tipo,
    required this.impt,
  });

  final String idref;
  final String tipo;
  final double impt;
}

String _money(double value) => '\$${value.toStringAsFixed(2)}';

double _mmToPt(double mm) => mm * (72.0 / 25.4);

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

String _fmtDateTime(DateTime? value) {
  if (value == null) return '-';
  final local = value.toLocal();
  String p2(int n) => n.toString().padLeft(2, '0');
  return '${p2(local.day)}/${p2(local.month)}/${local.year} ${p2(local.hour)}:${p2(local.minute)}';
}

double _round2(double value) =>
    (value.isFinite ? (value * 100).roundToDouble() / 100 : 0.0);
