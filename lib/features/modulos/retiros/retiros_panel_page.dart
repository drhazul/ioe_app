import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ioe_app/core/api_error.dart';
import 'package:ioe_app/core/terminal_name.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'retiros_models.dart';
import 'retiros_providers.dart';

class RetirosPanelPage extends ConsumerStatefulWidget {
  const RetirosPanelPage({super.key});

  @override
  ConsumerState<RetirosPanelPage> createState() => _RetirosPanelPageState();
}

class _RetirosPanelPageState extends ConsumerState<RetirosPanelPage> {
  bool _creating = false;
  String? _printingIdret;

  @override
  Widget build(BuildContext context) {
    final todayAsync = ref.watch(retirosTodayProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Regresar a Punto de Venta',
          onPressed: () => context.go('/punto-venta'),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Retiros parciales'),
        actions: [
          IconButton(
            tooltip: 'Cambio forma de pago',
            onPressed: () => context.go('/cambio-forma-pago/auth'),
            icon: const Icon(Icons.swap_horiz),
          ),
          IconButton(
            tooltip: 'Refrescar',
            onPressed: () => ref.invalidate(retirosTodayProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _creating ? null : _createRetiro,
        icon: _creating
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add),
        label: const Text('Nuevo retiro'),
      ),
      body: todayAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(retirosTodayProvider);
            await ref.read(retirosTodayProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (items.isEmpty)
                const Card(
                  elevation: 0,
                  child: Padding(
                    padding: EdgeInsets.all(14),
                    child: Text('No hay retiros registrados hoy.'),
                  ),
                )
              else
                ...items.map((item) => _RetiroTile(
                      item: item,
                      onOpen: () => _open(item.idret),
                      onPrint: () => _printTicket(item.idret),
                      printing: _printingIdret == item.idret,
                      canCancel:
                          item.esta == 'ABIERTO' || item.esta == 'FINALIZADO',
                      onCancel: () => _cancel(item.idret),
                    )),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createRetiro() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuevo retiro'),
        content: const Text('¿Crear nuevo retiro parcial?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _creating = true);
    try {
      final created = await ref.read(retirosApiProvider).createRetiro(
            ter: getTerminalName().trim(),
          );
      ref.invalidate(retirosTodayProvider);
      if (!mounted) return;
      _open(created.header.idret);
    } catch (e) {
      if (!mounted) return;
      _showError(apiErrorMessage(e, fallback: 'No se pudo crear retiro'));
    } finally {
      if (mounted) {
        setState(() => _creating = false);
      }
    }
  }

  Future<void> _cancel(String idret) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar retiro'),
        content: Text('¿Cancelar retiro $idret?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    try {
      await ref.read(retirosApiProvider).cancel(idret);
      ref.invalidate(retirosTodayProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Retiro cancelado')),
      );
    } catch (e) {
      if (!mounted) return;
      _showError(apiErrorMessage(e, fallback: 'No se pudo cancelar retiro'));
    }
  }

  Future<void> _printTicket(String idret) async {
    final idretNorm = idret.trim();
    if (idretNorm.isEmpty) return;
    if (_printingIdret != null) return;

    setState(() => _printingIdret = idretNorm);
    try {
      final widthMm = await _selectTicketWidth(context);
      if (widthMm == null) return;

      final detail = await ref.read(retirosApiProvider).fetchRetiro(idretNorm);
      final doc = _buildTicketPdf(detail, widthMm: widthMm);
      if (!mounted) return;
      await Printing.layoutPdf(
        name: 'retiro_${detail.header.idret}.pdf',
        onLayout: (_) async => doc.save(),
      );
    } catch (e) {
      if (!mounted) return;
      _showError(
        apiErrorMessage(
          e,
          fallback: 'No se pudo generar la impresión del retiro',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _printingIdret = null);
      }
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
    RetiroDetailResponse detail, {
    required double widthMm,
  }) {
    final doc = pw.Document();
    final header = detail.header;
    final line = '-' * (widthMm <= 58 ? 30 : 38);
    final baseFont = widthMm <= 58 ? 9.0 : 10.0;
    final smallFont = widthMm <= 58 ? 8.0 : 9.0;
    final widthPt = _mmToPt(widthMm);
    final pageHeightMm = _estimateTicketHeightMm(detail, widthMm);
    final impTotal = header.impr > 0 ? header.impr : _round2(detail.total);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat(widthPt, _mmToPt(pageHeightMm), marginAll: 0),
        margin: pw.EdgeInsets.only(
          left: _mmToPt(2),
          right: _mmToPt(2),
          top: _mmToPt(2),
          bottom: _mmToPt(2),
        ),
        build: (_) {
          return [
            pw.Center(
              child: pw.Text(
                'RETIRO PARCIAL',
                style: pw.TextStyle(
                  fontSize: baseFont + 1,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(line, style: pw.TextStyle(fontSize: smallFont)),
            pw.Text('FCNR: ${_fmtDateTime(header.fcnr)}', style: pw.TextStyle(fontSize: baseFont)),
            pw.Text('IDRET: ${_textOrDash(header.idret)}', style: pw.TextStyle(fontSize: baseFont)),
            _ticketRow('TER', _textOrDash(header.ter), baseFont),
            _ticketRow('OPV', _textOrDash(header.opv), baseFont),
            _ticketRow('ESTA', _textOrDash(header.esta), baseFont),
            _ticketRow('IMP TOTAL', _money(impTotal), baseFont),
            pw.Text('F. IMPR: ${_fmtDateTime(DateTime.now())}', style: pw.TextStyle(fontSize: smallFont)),
            pw.SizedBox(height: 2),
            pw.Text(line, style: pw.TextStyle(fontSize: smallFont)),
            pw.Text(
              'DETALLE',
              style: pw.TextStyle(
                fontSize: baseFont,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 2),
            if (detail.detalles.isEmpty)
              pw.Text(
                'Sin detalle de formas de pago',
                style: pw.TextStyle(fontSize: baseFont),
              )
            else
              ...detail.detalles.map(
                (row) => pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 3),
                  padding: const pw.EdgeInsets.all(2),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey600, width: 0.5),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _ticketRow('FORMA', _textOrDash(row.forma), baseFont),
                      _ticketRow('IMPF', _money(row.impf), baseFont),
                      if (row.isEfectivo && row.efectivo.isNotEmpty) ...[
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'DETALLE EFECTIVO',
                          style: pw.TextStyle(
                            fontSize: smallFont,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 1),
                        _efectivoHeaderRow(smallFont),
                        ...row.efectivo.map(
                          (efec) => _efectivoValueRow(
                            deno: efec.deno,
                            ctda: efec.ctda,
                            total: efec.total,
                            fontSize: smallFont,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            pw.Text(line, style: pw.TextStyle(fontSize: smallFont)),
            _ticketRow(
              'TOTAL RETIRO',
              _money(_round2(detail.total)),
              baseFont,
              bold: true,
            ),
            if (header.impr > 0)
              _ticketRow(
                'IMPR',
                _money(header.impr),
                baseFont,
              ),
          ];
        },
      ),
    );

    return doc;
  }

  pw.Widget _efectivoHeaderRow(double fontSize) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.grey700, width: 0.5),
          bottom: pw.BorderSide(color: PdfColors.grey700, width: 0.5),
        ),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 2,
            child: pw.Text(
              'DENO',
              style: pw.TextStyle(
                fontSize: fontSize,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Expanded(
            flex: 2,
            child: pw.Text(
              'CTDA',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                fontSize: fontSize,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Expanded(
            flex: 2,
            child: pw.Text(
              'TOTAL',
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                fontSize: fontSize,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _efectivoValueRow({
    required double deno,
    required double ctda,
    required double total,
    required double fontSize,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 0.5),
      child: pw.Row(
        children: [
          pw.Expanded(flex: 2, child: pw.Text(_money(deno), style: pw.TextStyle(fontSize: fontSize))),
          pw.Expanded(
            flex: 2,
            child: pw.Text(
              _fmtQty(ctda),
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: fontSize),
            ),
          ),
          pw.Expanded(
            flex: 2,
            child: pw.Text(
              _money(total),
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(fontSize: fontSize),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _ticketRow(
    String label,
    String value,
    double fontSize, {
    bool bold = false,
  }) {
    final style = pw.TextStyle(
      fontSize: fontSize,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Expanded(child: pw.Text(label, style: style)),
        pw.Text(value, style: style),
      ],
    );
  }

  double _estimateTicketHeightMm(RetiroDetailResponse detail, double widthMm) {
    final is58 = widthMm <= 58;
    var height = is58 ? 110.0 : 120.0;
    if (detail.detalles.isEmpty) {
      height += is58 ? 10 : 8;
    }
    for (final row in detail.detalles) {
      height += is58 ? 16.0 : 14.0;
      if (row.isEfectivo && row.efectivo.isNotEmpty) {
        height += (row.efectivo.length + 1) * (is58 ? 6.0 : 5.0);
      }
    }
    return height + (is58 ? 24.0 : 20.0);
  }

  String _fmtQty(double value) {
    final rounded = _round2(value);
    if ((rounded - rounded.roundToDouble()).abs() < 0.000001) {
      return rounded.toStringAsFixed(0);
    }
    var text = rounded.toStringAsFixed(3);
    text = text.replaceFirst(RegExp(r'0+$'), '');
    text = text.replaceFirst(RegExp(r'\.$'), '');
    return text;
  }

  String _textOrDash(String? value) {
    final text = (value ?? '').trim();
    return text.isEmpty ? '-' : text;
  }

  String _fmtDateTime(DateTime? value) {
    if (value == null) return '-';
    final local = value.toLocal();
    String p2(int n) => n.toString().padLeft(2, '0');
    return '${p2(local.day)}/${p2(local.month)}/${local.year} '
        '${p2(local.hour)}:${p2(local.minute)}';
  }

  double _round2(double value) =>
      (value.isFinite ? (value * 100).roundToDouble() / 100 : 0);

  double _mmToPt(double mm) => mm * (72.0 / 25.4);

  String _money(double value) => '\$${value.toStringAsFixed(2)}';

  void _open(String idret) {
    if (idret.trim().isEmpty) return;
    context.go('/retiros/${Uri.encodeComponent(idret)}');
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
}

class _RetiroTile extends StatelessWidget {
  const _RetiroTile({
    required this.item,
    required this.onOpen,
    this.onPrint,
    this.printing = false,
    this.canCancel = false,
    required this.onCancel,
  });

  final RetiroPanelItem item;
  final VoidCallback onOpen;
  final VoidCallback? onPrint;
  final bool printing;
  final bool canCancel;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final estado = item.esta.trim().toUpperCase();
    final color = switch (estado) {
      'ABIERTO' => Colors.orange.shade700,
      'FINALIZADO' => Colors.green.shade700,
      'CANCELADO' => Colors.red.shade700,
      _ => Colors.grey.shade700,
    };

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onOpen,
        title: Text(item.idret),
        subtitle: Text(
          'OPV: ${item.opv ?? '-'} | TER: ${item.ter ?? '-'}\n'
          'Importe: ${_money(item.impr)} | Detalles: ${item.detCount}',
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              estado,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              tooltip: 'Imprimir ticket',
              onPressed: printing ? null : onPrint,
              icon: printing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.print_outlined),
            ),
            IconButton(
              tooltip: 'Abrir',
              onPressed: onOpen,
              icon: const Icon(Icons.open_in_new),
            ),
            IconButton(
              tooltip: canCancel
                  ? 'Cancelar'
                  : 'Cancelar (solo retiros ABIERTO o FINALIZADO)',
              onPressed: canCancel ? onCancel : null,
              icon: const Icon(Icons.cancel_outlined),
            ),
          ],
        ),
      ),
    );
  }

  String _money(double value) => '\$${value.toStringAsFixed(2)}';
}
