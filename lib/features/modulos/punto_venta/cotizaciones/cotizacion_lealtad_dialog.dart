import 'package:flutter/material.dart';

import 'cotizaciones_models.dart';
import 'cotizacion_lealtad_error.dart';

/// Only repeats the participation GET for an already persisted quotation.
class CotizacionLealtadDialog extends StatefulWidget {
  const CotizacionLealtadDialog({
    super.key,
    required this.clienteId,
    required this.consultar,
    this.resultadoInicial,
    this.errorInicial,
  });

  final int clienteId;
  final Future<CotizacionLealtadParticipacionModel> Function() consultar;
  final CotizacionLealtadParticipacionModel? resultadoInicial;
  final CotizacionLealtadError? errorInicial;

  @override
  State<CotizacionLealtadDialog> createState() =>
      _CotizacionLealtadDialogState();
}

class _CotizacionLealtadDialogState extends State<CotizacionLealtadDialog> {
  CotizacionLealtadParticipacionModel? _resultado;
  CotizacionLealtadError? _error;
  bool _consultando = false;

  @override
  void initState() {
    super.initState();
    _resultado = widget.resultadoInicial;
    _error = widget.errorInicial;
  }

  Future<void> _reintentar() async {
    setState(() => _consultando = true);
    CotizacionLealtadParticipacionModel? resultado;
    CotizacionLealtadError? error;
    try {
      resultado = await widget.consultar();
    } on CotizacionLealtadError catch (e) {
      error = e;
    } catch (_) {
      error = const CotizacionLealtadError('LEALTAD_NO_DISPONIBLE');
    }
    if (!mounted) return;
    setState(() {
      _resultado = resultado;
      _error = error;
      _consultando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mensaje = switch (_resultado?.participante) {
      true =>
        'El cliente ${widget.clienteId} participa en el programa de lealtad.',
      false =>
        'El cliente ${widget.clienteId} no participa en el programa de lealtad.',
      null =>
        '${_error?.message ?? 'No se pudo consultar el programa de lealtad.'}\n'
            'La cotización se conserva. La participación queda sin confirmar.',
    };
    return AlertDialog(
      title: const Text('Consulta de lealtad'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(mensaje),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text('Referencia: ${_error!.code}'),
          ],
          if (_consultando) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _consultando ? null : _reintentar,
          child: const Text('Volver a consultar'),
        ),
        FilledButton(
          onPressed: _consultando ? null : () => Navigator.of(context).pop(),
          child: const Text('Continuar'),
        ),
      ],
    );
  }
}
