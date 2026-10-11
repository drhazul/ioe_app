import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ioe_app/core/api_error.dart';
import 'package:ioe_app/features/modulos/reloj_checador/consultas/download_helper.dart';

import 'cfdi_quadrum_api.dart';
import 'cfdi_quadrum_providers.dart';

/// Ventana para emitir el complemento de pago (REP) de una factura a crédito.
///
/// El saldo no se captura: lo calcula la API sumando los complementos ya
/// timbrados de esa factura. Aquí solo se dice cuánto abonó el cliente, cuándo
/// y con qué forma de pago.
Future<void> mostrarComplementoPago(
  BuildContext context,
  Map<String, dynamic> fila,
) {
  return showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 700),
        child: _ComplementoPagoDialog(fila: fila),
      ),
    ),
  );
}

/// Formas de pago del SAT que se usan al cobrar. El 99 ("por definir") queda
/// fuera a propósito: solo vale en la factura a crédito, nunca al cobrarla.
const _formasDePago = <String, String>{
  '01': 'Efectivo',
  '02': 'Cheque nominativo',
  '03': 'Transferencia electrónica',
  '04': 'Tarjeta de crédito',
  '28': 'Tarjeta de débito',
  '29': 'Tarjeta de servicios',
  '05': 'Monedero electrónico',
  '17': 'Compensación',
};

class _ComplementoPagoDialog extends ConsumerStatefulWidget {
  const _ComplementoPagoDialog({required this.fila});

  final Map<String, dynamic> fila;

  @override
  ConsumerState<_ComplementoPagoDialog> createState() =>
      _ComplementoPagoDialogState();
}

class _ComplementoPagoDialogState
    extends ConsumerState<_ComplementoPagoDialog> {
  late final String _idFol = '${widget.fila['IDFOL'] ?? ''}';

  final _monto = TextEditingController();
  late final TextEditingController _fecha = TextEditingController(
    text: DateTime.now().toIso8601String().substring(0, 10),
  );
  String _forma = '03';

  Map<String, dynamic>? _estado;
  String? _resultado;
  bool _esError = false;
  bool _cargando = true;
  bool _ocupado = false;

  CfdiQuadrumApi get _api => ref.read(cfdiQuadrumApiProvider);

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _monto.dispose();
    _fecha.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final datos = await _api.estadoDePagos(_idFol);
      if (!mounted) return;
      setState(() {
        _estado = datos;
        _cargando = false;
        // Por omisión se propone liquidar: es lo más común.
        if (_monto.text.isEmpty) _monto.text = '${datos['saldo'] ?? ''}';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _resultado = apiErrorMessage(
          error,
          fallback: 'No se pudo leer el estado de la factura',
        );
        _esError = true;
        _cargando = false;
      });
    }
  }

  Map<String, dynamic>? get _pago {
    final monto = double.tryParse(_monto.text.trim().replaceAll(',', ''));
    if (monto == null || monto <= 0) return null;
    return {
      'confirmar': true,
      'fechaPago': _fecha.text.trim(),
      'formaDePago': _forma,
      'monto': monto,
    };
  }

  Future<void> _correr(
    Future<Map<String, dynamic>> Function(Map<String, dynamic> pago) accion, {
    String? confirmacion,
  }) async {
    final pago = _pago;
    if (pago == null) {
      setState(() {
        _resultado = 'Escribe cuánto abonó el cliente.';
        _esError = true;
      });
      return;
    }
    if (confirmacion != null && !await _confirmar(confirmacion)) return;

    setState(() {
      _ocupado = true;
      _resultado = null;
      _esError = false;
    });
    try {
      final respuesta = await accion(pago);
      if (!mounted) return;
      setState(() {
        _resultado = const JsonEncoder.withIndent('  ').convert(respuesta);
      });
      await _cargar();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _resultado = apiErrorMessage(error, fallback: 'La operación falló');
        _esError = true;
      });
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<bool> _confirmar(String mensaje) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar'),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, continuar'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _descargar(String uuid, {required bool pdf}) async {
    if (!supportsDownload) return;
    setState(() => _ocupado = true);
    try {
      final bytes = pdf
          ? await _api.descargarPdfNota(_idFol, uuid)
          : await _api.descargarXmlNota(_idFol, uuid);
      await saveBytesFile(
        bytes,
        '${_idFol}_PG_$uuid.${pdf ? 'pdf' : 'xml'}',
        pdf ? 'application/pdf' : 'application/xml',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _resultado = apiErrorMessage(
          error,
          fallback: 'No se pudo bajar el documento',
        );
        _esError = true;
      });
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Complemento de pago · folio $_idFol', style: texto.titleSmall),
          const SizedBox(height: 8),
          if (_cargando)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_estado != null) ...[
            _resumen(texto),
            const Divider(height: 20),
            _captura(),
            const SizedBox(height: 10),
            _acciones(),
          ],
          if (_resultado != null) ...[
            const SizedBox(height: 10),
            Flexible(child: _panelResultado(texto)),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resumen(TextTheme texto) {
    final e = _estado!;
    final pagos = (e['pagos'] as List?) ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Factura ${e['serieFolio']} · receptor ${e['rfcReceptor']}',
          style: texto.bodySmall,
        ),
        Text('UUID ${e['uuid']}', style: texto.bodySmall),
        const SizedBox(height: 6),
        Wrap(
          spacing: 18,
          children: [
            _dato('Total', '${e['total']}', texto),
            _dato('Cobrado', '${e['pagado']}', texto),
            _dato('Saldo', '${e['saldo']}', texto, destacar: true),
            _dato('Siguiente abono', '${e['siguienteParcialidad']}', texto),
          ],
        ),
        if (pagos.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Complementos emitidos', style: texto.bodySmall),
          for (final p in pagos.cast<Map<String, dynamic>>())
            _renglonPago(p, texto),
        ],
      ],
    );
  }

  Widget _dato(
    String etiqueta,
    String valor,
    TextTheme texto, {
    bool destacar = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(etiqueta, style: texto.bodySmall),
        Text(
          valor,
          style: destacar
              ? texto.titleSmall?.copyWith(fontWeight: FontWeight.bold)
              : texto.bodyMedium,
        ),
      ],
    );
  }

  Widget _renglonPago(Map<String, dynamic> pago, TextTheme texto) {
    final uuid = '${pago['uuid'] ?? ''}';
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Abono ${pago['parcialidad']} · ${pago['monto']} · '
              '${pago['fechaPago']} · ${pago['nomenclatura']}',
              style: texto.bodySmall,
            ),
          ),
          TextButton.icon(
            onPressed: uuid.isEmpty || _ocupado
                ? null
                : () => _descargar(uuid, pdf: false),
            icon: const Icon(Icons.code, size: 16),
            label: const Text('XML'),
          ),
          TextButton.icon(
            onPressed: uuid.isEmpty || _ocupado
                ? null
                : () => _descargar(uuid, pdf: true),
            icon: const Icon(Icons.picture_as_pdf, size: 16),
            label: const Text('PDF'),
          ),
        ],
      ),
    );
  }

  Widget _captura() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 150,
          child: TextField(
            controller: _monto,
            enabled: !_ocupado,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Monto abonado',
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
        ),
        SizedBox(
          width: 160,
          child: TextField(
            controller: _fecha,
            enabled: !_ocupado,
            decoration: const InputDecoration(
              labelText: 'Fecha del pago',
              hintText: 'aaaa-mm-dd',
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
        ),
        SizedBox(
          width: 250,
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _forma,
            decoration: const InputDecoration(
              labelText: 'Forma de pago',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            items: [
              for (final f in _formasDePago.entries)
                DropdownMenuItem(
                  value: f.key,
                  child: Text(
                    '${f.key} · ${f.value}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: _ocupado
                ? null
                : (v) => setState(() => _forma = v ?? '03'),
          ),
        ),
      ],
    );
  }

  Widget _acciones() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: _ocupado
              ? null
              : () => _correr((p) => _api.probarComplementoPago(_idFol, p)),
          icon: const Icon(Icons.science_outlined),
          label: const Text('Simular (no guarda nada)'),
        ),
        FilledButton.icon(
          onPressed: _ocupado
              ? null
              : () => _correr(
                  (p) => _api.emitirComplementoPago(_idFol, p),
                  confirmacion:
                      'Se va a emitir el complemento de pago por ${_monto.text}. '
                      'Genera un CFDI ante el SAT y no se deshace (solo se '
                      'puede cancelar). ¿Continuar?',
                ),
          icon: const Icon(Icons.payments),
          label: const Text('Emitir complemento'),
        ),
      ],
    );
  }

  Widget _panelResultado(TextTheme texto) {
    final color = _esError
        ? Theme.of(context).colorScheme.errorContainer
        : Theme.of(context).colorScheme.surfaceContainerHighest;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        child: SelectableText(
          _resultado!,
          style: texto.bodySmall?.copyWith(fontFamily: 'monospace'),
        ),
      ),
    );
  }
}
