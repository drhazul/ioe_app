import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ioe_app/core/api_error.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../devoluciones_models.dart';
import '../devoluciones_providers.dart';

class PagoDevolucionPage extends ConsumerStatefulWidget {
  const PagoDevolucionPage({
    super.key,
    required this.idfolDev,
  });

  final String idfolDev;

  @override
  ConsumerState<PagoDevolucionPage> createState() => _PagoDevolucionPageState();
}

class _PagoDevolucionPageState extends ConsumerState<PagoDevolucionPage> {
  DevolucionPagoPreviewResponse? _preview;
  final List<DevolucionFormaDraft> _formas = [];
  bool _rqfac = false;
  bool _loading = true;
  bool _submitting = false;
  bool _imprimiendoTicket = false;
  bool _printEnabled = false;
  String? _estadoDev;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isWide = screenWidth >= 1200;
    final minPanelHeight = (screenHeight - 190).clamp(420.0, 1200.0);
    final isEstadoPagado = _isEstadoPagado(_estadoDev ?? preview?.context.estaDev);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(isEstadoPagado ? Icons.lock : Icons.arrow_back),
          onPressed: (_submitting || _loading)
              ? null
              : () => _onBackPressed(isEstadoPagado: isEstadoPagado),
        ),
        title: const Text('Pago devolución'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadPreview,
            icon: const Icon(Icons.refresh),
            tooltip: 'Recalcular',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF6F2EB), Color(0xFFEFE7DB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : preview == null
                ? Center(
                    child: Text(_error ?? 'No se pudo cargar el pago'),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (isWide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _SectionContainer(
                                minHeight: minPanelHeight,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _ContextCard(preview: preview),
                                    const SizedBox(height: 10),
                                    _TotalsCard(
                                      totals: preview.totals,
                                      rqfac: _rqfac,
                                      onRqfacChanged: null,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _SectionContainer(
                                minHeight: minPanelHeight,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _FormasCard(
                                      formas: _formas,
                                      total: preview.totals.total,
                                    ),
                                    if ((_error ?? '').isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      Text(
                                        _error!,
                                        style: TextStyle(color: Colors.red.shade700),
                                      ),
                                    ],
                                    const SizedBox(height: 14),
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 8,
                                      children: [
                                        FilledButton.icon(
                                          onPressed: (_submitting || _printEnabled)
                                              ? null
                                              : _finalizar,
                                          icon: _submitting
                                              ? const SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child: CircularProgressIndicator(strokeWidth: 2),
                                                )
                                              : const Icon(Icons.check_circle_outline),
                                          label: const Text('Devolver cotización'),
                                        ),
                                        OutlinedButton.icon(
                                          onPressed: (_printEnabled && !_imprimiendoTicket)
                                              ? () => _imprimirTicket(context)
                                              : null,
                                          icon: _imprimiendoTicket
                                              ? const SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child: CircularProgressIndicator(strokeWidth: 2),
                                                )
                                              : const Icon(Icons.print_outlined),
                                          label: Text(
                                            _imprimiendoTicket ? 'Imprimiendo...' : 'Imprimir ticket',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      else ...[
                        _SectionContainer(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _ContextCard(preview: preview),
                              const SizedBox(height: 10),
                              _TotalsCard(
                                totals: preview.totals,
                                rqfac: _rqfac,
                                onRqfacChanged: null,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _SectionContainer(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _FormasCard(
                                formas: _formas,
                                total: preview.totals.total,
                              ),
                              if ((_error ?? '').isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text(
                                  _error!,
                                  style: TextStyle(color: Colors.red.shade700),
                                ),
                              ],
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 10,
                                runSpacing: 8,
                                children: [
                                  FilledButton.icon(
                                    onPressed: (_submitting || _printEnabled)
                                        ? null
                                        : _finalizar,
                                    icon: _submitting
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : const Icon(Icons.check_circle_outline),
                                    label: const Text('Devolver cotización'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: (_printEnabled && !_imprimiendoTicket)
                                        ? () => _imprimirTicket(context)
                                        : null,
                                    icon: _imprimiendoTicket
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : const Icon(Icons.print_outlined),
                                    label: Text(
                                      _imprimiendoTicket ? 'Imprimiendo...' : 'Imprimir ticket',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
      ),
    );
  }

  Future<void> _loadPreview() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final preview = await ref.read(devolucionesApiProvider).previewPago(
            idfolDev: widget.idfolDev,
            rqfac: null,
          );
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _rqfac = preview.totals.rqfac;
        _estadoDev = preview.context.estaDev;
        _printEnabled = _isEstadoPrintable(preview.context.estaDev);
        _formas
          ..clear()
          ..addAll(
            preview.formasSugeridas.map(
              (item) => item.copyWith(id: _nextId()),
            ),
          );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = apiErrorMessage(e, fallback: 'No se pudo calcular preview');
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  bool _isEstadoPrintable(String? value) {
    final estado = (value ?? '').trim().toUpperCase();
    return estado.contains('TRANSMITIR') || estado.contains('PAGADO');
  }

  bool _isEstadoPagado(String? value) {
    final estado = (value ?? '').trim().toUpperCase();
    return estado == 'PAGADO' || estado == 'TRANSMITIR';
  }

  Future<void> _onBackPressed({required bool isEstadoPagado}) async {
    if (isEstadoPagado) {
      try {
        await ref.read(devolucionesApiProvider).updateEstado(
              idfol: widget.idfolDev,
              esta: 'TRANSMITIR',
            );
        if (!mounted) return;
        ref.invalidate(devolucionesPanelProvider);
        setState(() => _estadoDev = 'TRANSMITIR');
        context.go('/punto-venta/devoluciones');
      } catch (e) {
        if (!mounted) return;
        final msg = apiErrorMessage(
          e,
          fallback: 'No se pudo actualizar la devolución a TRANSMITIR al regresar',
        );
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
      return;
    }
    if (!mounted) return;
    context.go('/punto-venta/devoluciones/${Uri.encodeComponent(widget.idfolDev)}/detalle');
  }

  Future<void> _finalizar() async {
    final preview = _preview;
    if (preview == null) return;

    if (_formas.isEmpty) {
      setState(() => _error = 'Debe agregar al menos una forma de pago');
      return;
    }

    final total = preview.totals.total;
    final sum = _formas.fold<double>(0, (acc, item) => acc + item.impp);
    final hasEfectivo = _formas.any((item) => item.form == 'EFECTIVO');
    if (sum + 0.0001 < total) {
      setState(() {
        _error = 'Las formas no cubren el total (\$${total.toStringAsFixed(2)})';
      });
      return;
    }
    if (!hasEfectivo && sum - total > 0.0001) {
      setState(() {
        _error = 'El excedente solo se permite cuando existe forma EFECTIVO';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final res = await ref.read(devolucionesApiProvider).finalizarPago(
            idfolDev: widget.idfolDev,
            rqfac: _rqfac,
            formas: _formas,
          );
      final resolvedIdfolDev = res.idfolDev.trim().isEmpty
          ? widget.idfolDev
          : res.idfolDev.trim();
      if (!mounted) return;
      setState(() {
        _printEnabled = true;
        _estadoDev = 'PAGADO';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Devolución finalizada ($resolvedIdfolDev) - estado PAGADO confirmado. Ya puede imprimir ticket.',
          ),
        ),
      );
      if (resolvedIdfolDev != widget.idfolDev) {
        context.go(
          '/punto-venta/devoluciones/${Uri.encodeComponent(resolvedIdfolDev)}/pago',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = apiErrorMessage(e, fallback: 'No se pudo finalizar devolución');
      });
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
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
          .read(devolucionesApiProvider)
          .fetchPrintPreview(widget.idfolDev);
      final nonCashFormas = preview.formas
          .where((f) => f.form.trim().toUpperCase() != 'EFECTIVO')
          .toList(growable: false);
      final doc = _buildTicketPdf(preview, widthMm: widthMm);
      if (!context.mounted) return;
      await Printing.layoutPdf(
        name: 'devolucion_${preview.idfolDev}.pdf',
        onLayout: (_) async => doc.save(),
      );
      if (!context.mounted || nonCashFormas.isEmpty) return;
      final openVoucher = await _confirmOpenVoucherPreview(context);
      if (!context.mounted || !openVoucher) return;
      final voucherDoc = _buildVoucherPdf(
        preview,
        widthMm: widthMm,
        nonCashFormas: nonCashFormas,
      );
      await Printing.layoutPdf(
        name: 'devolucion_${preview.idfolDev}_voucher.pdf',
        onLayout: (_) async => voucherDoc.save(),
      );
    } catch (e) {
      if (!context.mounted) return;
      final msg = apiErrorMessage(
        e,
        fallback:
            'Devolución finalizada, pero no se pudo generar la vista previa PDF',
      );
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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

  pw.Document _buildTicketPdf(
    DevolucionPrintPreviewResponse data, {
    required double widthMm,
  }) {
    final doc = pw.Document();
    final header = data.header;
    final totals = data.totals;
    final footer = data.footer;
    final ords = _collectOrdsFromItems(data.items);
    final fcnTrans = _resolveTicketDate(data.formas);
    final isCotizacionAbierta = totals.tipotran.trim().toUpperCase() == 'CA';
    final widthPt = _mmToPt(widthMm);
    final pageFormat = PdfPageFormat(
      widthPt,
      _mmToPt(_estimateTicketHeightMm(data, widthMm)),
      marginAll: 0,
    );
    final leftMarginPt = _mmToPt(2);
    final baseFontSize = widthMm <= 58 ? 9.0 : 10.0;
    final smallFontSize = widthMm <= 58 ? 8.0 : 9.0;
    final line = '-' * (widthMm <= 58 ? 30 : 38);
    final opvLabel = [
      if ((footer.opv ?? '').trim().isNotEmpty) footer.opv!.trim(),
      if ((footer.opvNombre ?? '').trim().isNotEmpty) footer.opvNombre!.trim(),
    ].join(' - ');
    final nonCashFormas = data.formas
        .where((f) => f.form.trim().toUpperCase() != 'EFECTIVO')
        .toList(growable: false);

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
                    if (f.fcn != null)
                      pw.Text(
                        'FCN: ${_fmtDateTime(f.fcn)}',
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
            'IDFOL DEV: ${footer.idfolDev}',
            style: pw.TextStyle(fontSize: baseFontSize),
          ),
          pw.Text(
            'IDFOL ORIG: ${footer.idfolOrig}',
            style: pw.TextStyle(fontSize: baseFontSize),
          ),
          pw.Text(
            'FCNM: ${_fmtDateTime(fcnTrans)}',
            style: pw.TextStyle(fontSize: baseFontSize),
          ),
          pw.Text(
            'ESTADO: ${footer.esta ?? '-'}',
            style: pw.TextStyle(fontSize: baseFontSize),
          ),
          pw.Text(
            'AUT: ${footer.aut ?? '-'}',
            style: pw.TextStyle(fontSize: baseFontSize),
          ),
          pw.Text(
            'CLIENTE: ${footer.clienteNombre ?? '-'} (${footer.clienteId?.toStringAsFixed(0) ?? '-'})',
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
          if (ords.isEmpty)
            pw.Text(
              'Sin ORDs ligadas',
              style: pw.TextStyle(fontSize: smallFontSize),
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
                      style: pw.TextStyle(fontSize: baseFontSize),
                    ),
                    pw.Text(
                      'DES: ${ord.description.isEmpty ? '-' : ord.description}',
                      style: pw.TextStyle(fontSize: smallFontSize),
                    ),
                    pw.Text(
                      'UPC: ${ord.upc.isEmpty ? '-' : ord.upc}',
                      style: pw.TextStyle(fontSize: smallFontSize),
                    ),
                  ],
                ),
              );
            }),
          if (nonCashFormas.isNotEmpty)
            pw.Text(
              'GRACIAS POR SU CONFIANZA',
              style: pw.TextStyle(
                fontSize: smallFontSize,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
        ],
      ),
    );
    return doc;
  }

  pw.Document _buildVoucherPdf(
    DevolucionPrintPreviewResponse data, {
    required double widthMm,
    required List<DevolucionPrintForma> nonCashFormas,
  }) {
    final doc = pw.Document();
    if (nonCashFormas.isEmpty) return doc;

    final header = data.header;
    final totals = data.totals;
    final footer = data.footer;
    final fcnTrans = _resolveTicketDate(data.formas);

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
    final baseFontSize = widthMm <= 58 ? 9.0 : 10.0;
    final smallFontSize = widthMm <= 58 ? 8.0 : 9.0;

    doc.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.only(left: leftMarginPt),
        maxPages: 120,
        build: (_) => [
          ...nonCashFormas.map(
            (forma) => _buildVoucherSectionDevolucion(
              forma: forma,
              idfol: footer.idfolDev,
              suc: header.suc,
              clienteNombre: footer.clienteNombre,
              clienteId: footer.clienteId?.toStringAsFixed(0),
              tra: null,
              fecha: forma.fcn ?? fcnTrans,
              totalOperacion: totals.total,
              baseFontSize: baseFontSize,
              smallFontSize: smallFontSize,
            ),
          ),
        ],
      ),
    );
    return doc;
  }

  List<_DevolucionTicketOrdSummary> _collectOrdsFromItems(
    List<DevolucionPrintItem> items,
  ) {
    final byOrd = <String, List<DevolucionPrintItem>>{};
    for (final item in items) {
      final ord = (item.ord ?? '').trim();
      if (ord.isEmpty) continue;
      byOrd.putIfAbsent(ord, () => <DevolucionPrintItem>[]).add(item);
    }

    final result = <_DevolucionTicketOrdSummary>[];
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
        _DevolucionTicketOrdSummary(
          ord: entry.key,
          upc: upcs.join(', '),
          description: descriptions.join(' | '),
        ),
      );
    }
    result.sort((a, b) => a.ord.compareTo(b.ord));
    return result;
  }

  DateTime? _resolveTicketDate(List<DevolucionPrintForma> formas) {
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

  pw.Widget _buildVoucherSectionDevolucion({
    required DevolucionPrintForma forma,
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
          pw.SizedBox(height: 6),
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

  pw.Widget _buildTicketDetalleItem(
    DevolucionPrintItem item, {
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

  double _estimateTicketHeightMm(DevolucionPrintPreviewResponse data, double widthMm) {
    final is58 = widthMm <= 58;
    final charsPerLine = is58 ? 28 : 34;
    final lineMm = is58 ? 3.3 : 3.9;
    final isCotizacionAbierta = data.totals.tipotran.trim().toUpperCase() == 'CA';
    final ords = _collectOrdsFromItems(data.items);
    double mm = 0;

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
      mm += _measureTextHeightMm(
        'RFC: ${data.header.rfc}',
        charsPerLine,
        lineMm,
      );
    }

    mm += 8;
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
        mm += lineMm + 1.4;
      }
    }

    mm += 8;
    mm += lineMm;
    if (!isCotizacionAbierta) {
      mm += lineMm * 6;
      mm += 5;
      if (data.formas.isEmpty) {
        mm += lineMm;
      } else {
        for (final forma in data.formas) {
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
    }

    final footer = data.footer;
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
    mm += _measureTextHeightMm('IDFOL DEV: ${footer.idfolDev}', charsPerLine, lineMm);
    mm += _measureTextHeightMm(
      'IDFOL ORIG: ${footer.idfolOrig}',
      charsPerLine,
      lineMm,
    );
    mm += _measureTextHeightMm(
      'FCNM: ${_fmtDateTime(_resolveTicketDate(data.formas))}',
      charsPerLine,
      lineMm,
    );
    mm += _measureTextHeightMm('ESTADO: ${footer.esta ?? '-'}', charsPerLine, lineMm);
    mm += _measureTextHeightMm('AUT: ${footer.aut ?? '-'}', charsPerLine, lineMm);
    mm += _measureTextHeightMm(
      'CLIENTE: ${footer.clienteNombre ?? '-'} (${footer.clienteId?.toStringAsFixed(0) ?? '-'})',
      charsPerLine,
      lineMm,
    );

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
    final minMm = is58 ? 170.0 : 220.0;
    final maxMm = is58 ? 1400.0 : 1900.0;
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
      totalLines += max(1, (line.length / charsPerLine).ceil());
    }
    return totalLines * lineMm;
  }

  double _mmToPt(double mm) => mm * PdfPageFormat.mm;

  String _money(double value) => '\$${value.toStringAsFixed(2)}';

  String _fmtDateTime(DateTime? value) {
    if (value == null) return '-';
    final local = value.toLocal();
    String p2(int n) => n.toString().padLeft(2, '0');
    return '${p2(local.day)}/${p2(local.month)}/${local.year} ${p2(local.hour)}:${p2(local.minute)}';
  }

  String _nextId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final rnd = Random.secure().nextInt(0x100000000).toRadixString(16);
    return '$now-$rnd';
  }
}

class _DevolucionTicketOrdSummary {
  const _DevolucionTicketOrdSummary({
    required this.ord,
    required this.upc,
    required this.description,
  });

  final String ord;
  final String upc;
  final String description;
}

class _SectionContainer extends StatelessWidget {
  const _SectionContainer({
    required this.child,
    this.minHeight,
  });

  final Widget child;
  final double? minHeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: minHeight == null
          ? null
          : BoxConstraints(minHeight: minHeight!),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        color: Colors.white.withValues(alpha: 0.2),
      ),
      child: child,
    );
  }
}

class _ContextCard extends StatelessWidget {
  const _ContextCard({required this.preview});

  final DevolucionPagoPreviewResponse preview;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 14,
          runSpacing: 8,
          children: [
            _kv('Folio devolución', preview.context.idfolDev),
            _kv('Folio origen', preview.context.idfolOrig),
            _kv('IDFOLINICIAL', preview.context.idfolInicial ?? '-'),
            _kv('AUT', preview.context.autDev),
            _kv('ESTA', (preview.context.estaDev ?? '-').toUpperCase()),
            _kv('ORIGEN_AUT', (preview.context.origenAut ?? '-').toUpperCase()),
            _kv('Sucursal', preview.context.suc),
            _kv('Cliente', preview.context.clien?.toStringAsFixed(0) ?? '-'),
          ],
        ),
      ),
    );
  }

  Widget _kv(String key, String value) {
    return SizedBox(
      width: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            key,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(value),
        ],
      ),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({
    required this.totals,
    required this.rqfac,
    required this.onRqfacChanged,
  });

  final DevolucionPagoTotales totals;
  final bool rqfac;
  final ValueChanged<bool>? onRqfacChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Totales devolución',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Row(
                  children: [
                    const Text('RQFAC'),
                    Switch(
                      value: rqfac,
                      onChanged: onRqfacChanged,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 2),
            const Text(
              'RQFAC se toma del folio origen y no es editable en devoluciones.',
              style: TextStyle(fontSize: 11, color: Colors.black54),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 22,
              runSpacing: 6,
              children: [
                _money('Subtotal', totals.subtotal),
                _money('IVA', totals.iva),
                _money('Total', totals.total),
                _money('Total base', totals.totalBase),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _money(String label, double value) {
    return SizedBox(
      width: 140,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text('\$${value.toStringAsFixed(2)}'),
        ],
      ),
    );
  }
}

class _FormasCard extends StatelessWidget {
  const _FormasCard({
    required this.formas,
    required this.total,
  });

  final List<DevolucionFormaDraft> formas;
  final double total;

  @override
  Widget build(BuildContext context) {
    final sum = formas.fold<double>(0, (acc, item) => acc + item.impp);
    final faltante = (total - sum).clamp(0, double.infinity);
    final cambio = (sum - total).clamp(0, double.infinity);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Formas de devolución',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            const Text(
              'Las formas se toman del folio origen (incluyendo no efectivo) para devolver por el mismo concepto.',
              style: TextStyle(fontSize: 11, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            if (formas.isEmpty)
              const Text('Sin formas agregadas')
            else
              ...formas.map((item) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      SizedBox(width: 150, child: Text(item.form)),
                      SizedBox(width: 120, child: Text('\$${item.impp.toStringAsFixed(2)}')),
                      Expanded(
                        child: Text(
                          (item.aut ?? '').isEmpty ? '-' : item.aut!,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            const Divider(height: 20),
            Wrap(
              spacing: 20,
              runSpacing: 6,
              children: [
                Text('Suma formas: \$${sum.toStringAsFixed(2)}'),
                Text('Faltante: \$${faltante.toStringAsFixed(2)}'),
                Text('Cambio: \$${cambio.toStringAsFixed(2)}'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}



