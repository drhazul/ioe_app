import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ioe_app/core/api_error.dart';
import 'package:ioe_app/features/modulos/reloj_checador/consultas/download_helper.dart';

import 'cfdi_quadrum_api.dart';
import 'cfdi_quadrum_providers.dart';

/// Ventana para emitir una nota de crédito de una factura ya timbrada.
///
/// Los conceptos NO se capturan: salen del XML timbrado de la factura, que es
/// la única fuente que no puede discrepar de lo que el SAT ya tiene. Aquí solo
/// se elige qué artículos y cuántas piezas se devuelven.
Future<void> mostrarNotaCredito(
  BuildContext context,
  Map<String, dynamic> fila,
) {
  return showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 700),
        child: _NotaCreditoDialog(fila: fila),
      ),
    ),
  );
}

class _NotaCreditoDialog extends ConsumerStatefulWidget {
  const _NotaCreditoDialog({required this.fila});

  final Map<String, dynamic> fila;

  @override
  ConsumerState<_NotaCreditoDialog> createState() => _NotaCreditoDialogState();
}

class _NotaCreditoDialogState extends ConsumerState<_NotaCreditoDialog> {
  late final String _idFol = '${widget.fila['IDFOL'] ?? ''}';

  /// Piezas a devolver por posición del concepto en la factura.
  final Map<int, double> _elegidos = {};

  Map<String, dynamic>? _factura;
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

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final datos = await _api.conceptosNotaCredito(_idFol);
      if (!mounted) return;
      setState(() {
        _factura = datos;
        _cargando = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _resultado = apiErrorMessage(
          error,
          fallback: 'No se pudieron leer los conceptos de la factura',
        );
        _esError = true;
        _cargando = false;
      });
    }
  }

  List<Map<String, dynamic>> get _seleccion => _elegidos.entries
      .where((e) => e.value > 0)
      .map((e) => {'indice': e.key, 'cantidad': e.value})
      .toList();

  Future<void> _correr(
    Future<Map<String, dynamic>> Function() accion, {
    String? confirmacion,
  }) async {
    if (_seleccion.isEmpty) {
      setState(() {
        _resultado = 'Elige al menos un artículo y cuántas piezas se devuelven.';
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
      final respuesta = await accion();
      if (!mounted) return;
      setState(() {
        _resultado = const JsonEncoder.withIndent('  ').convert(respuesta);
      });
      // Tras emitir, lo disponible cambia: hay que volver a leerlo.
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

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Nota de crédito · folio $_idFol', style: texto.titleSmall),
          const SizedBox(height: 8),
          if (_cargando)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_factura != null) ...[
            _encabezado(texto),
            const Divider(height: 20),
            Flexible(child: _tablaConceptos(texto)),
            const SizedBox(height: 8),
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

  Widget _encabezado(TextTheme texto) {
    final f = _factura!;
    final previas = (f['notasPrevias'] as List?) ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Factura ${f['serieFolio']} · total ${f['totalFactura']} · '
          'receptor ${f['rfcReceptor']}',
          style: texto.bodySmall,
        ),
        Text('UUID ${f['uuid']}', style: texto.bodySmall),
        if (previas.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('Notas de credito emitidas', style: texto.bodySmall),
          for (final n in previas.cast<Map<String, dynamic>>())
            _renglonNota(n, texto),
        ],
      ],
    );
  }

  /// Una nota ya emitida, con sus dos descargas.
  Widget _renglonNota(Map<String, dynamic> nota, TextTheme texto) {
    final uuid = '${nota['uuid'] ?? ''}';
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${nota['nomenclatura']}  ·  $uuid',
              style: texto.bodySmall,
            ),
          ),
          TextButton.icon(
            onPressed: uuid.isEmpty || _ocupado
                ? null
                : () => _descargarNota(uuid, pdf: false),
            icon: const Icon(Icons.code, size: 16),
            label: const Text('XML'),
          ),
          TextButton.icon(
            onPressed: uuid.isEmpty || _ocupado
                ? null
                : () => _descargarNota(uuid, pdf: true),
            icon: const Icon(Icons.picture_as_pdf, size: 16),
            label: const Text('PDF'),
          ),
        ],
      ),
    );
  }

  /// Baja el XML o el PDF de una nota ya emitida.
  Future<void> _descargarNota(String uuid, {required bool pdf}) async {
    if (!supportsDownload) return;
    setState(() => _ocupado = true);
    try {
      final bytes = pdf
          ? await _api.descargarPdfNota(_idFol, uuid)
          : await _api.descargarXmlNota(_idFol, uuid);
      await saveBytesFile(
        bytes,
        '${_idFol}_NC_$uuid.${pdf ? 'pdf' : 'xml'}',
        pdf ? 'application/pdf' : 'application/xml',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _resultado = apiErrorMessage(
          error,
          fallback: 'No se pudo bajar el documento de la nota',
        );
        _esError = true;
      });
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Widget _tablaConceptos(TextTheme texto) {
    final conceptos = (_factura!['conceptos'] as List?) ?? const [];
    if (conceptos.isEmpty) {
      return const Text('La factura no tiene conceptos.');
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          for (final c in conceptos.cast<Map<String, dynamic>>())
            _renglon(c, texto),
        ],
      ),
    );
  }

  Widget _renglon(Map<String, dynamic> c, TextTheme texto) {
    final indice = (c['indice'] as num).toInt();
    final disponible = (c['cantidadDisponible'] as num?)?.toDouble() ?? 0;
    final facturada = (c['cantidadFacturada'] as num?)?.toDouble() ?? 0;
    final acreditada = (c['cantidadAcreditada'] as num?)?.toDouble() ?? 0;
    final elegida = _elegidos[indice] ?? 0;
    final agotado = disponible <= 0;

    return Opacity(
      opacity: agotado ? 0.5 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${c['descripcion']}', style: texto.bodyMedium),
                  Text(
                    'Art. ${c['noIdentificacion']} · unitario '
                    '${c['valorUnitario']} · facturadas ${_num(facturada)}'
                    '${acreditada > 0 ? ' · ya devueltas ${_num(acreditada)}' : ''}',
                    style: texto.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (agotado)
              const Text('Sin saldo')
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Menos',
                    onPressed: elegida <= 0 || _ocupado
                        ? null
                        : () => setState(() {
                            final nueva = elegida - 1;
                            if (nueva <= 0) {
                              _elegidos.remove(indice);
                            } else {
                              _elegidos[indice] = nueva;
                            }
                          }),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  SizedBox(
                    width: 42,
                    child: Text(
                      _num(elegida),
                      textAlign: TextAlign.center,
                      style: texto.titleSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Más',
                    onPressed: elegida >= disponible || _ocupado
                        ? null
                        : () => setState(() => _elegidos[indice] = elegida + 1),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                  TextButton(
                    onPressed: _ocupado
                        ? null
                        : () => setState(() => _elegidos[indice] = disponible),
                    child: Text('Todo (${_num(disponible)})'),
                  ),
                ],
              ),
          ],
        ),
      ),
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
              : () => _correr(() => _api.probarNotaCredito(_idFol, _seleccion)),
          icon: const Icon(Icons.science_outlined),
          label: const Text('Simular (no guarda nada)'),
        ),
        FilledButton.icon(
          onPressed: _ocupado
              ? null
              : () => _correr(
                  () => _api.emitirNotaCredito(_idFol, _seleccion),
                  confirmacion:
                      'Se va a emitir una nota de crédito por los artículos '
                      'elegidos. Genera un CFDI ante el SAT y no se deshace '
                      '(solo se puede cancelar). ¿Continuar?',
                ),
          icon: const Icon(Icons.undo),
          label: const Text('Emitir nota de crédito'),
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

  /// 1 en vez de 1.0, pero 1.5 cuando de verdad hay fracción.
  String _num(double valor) =>
      valor == valor.roundToDouble() ? '${valor.round()}' : '$valor';
}
