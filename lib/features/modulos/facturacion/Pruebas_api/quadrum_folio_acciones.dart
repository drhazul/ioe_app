import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ioe_app/core/api_error.dart';
import 'package:ioe_app/features/modulos/facturacion/csd/csd_providers.dart';

import 'package:ioe_app/features/modulos/reloj_checador/consultas/download_helper.dart';
import 'cfdi_quadrum_api.dart';
import 'cfdi_quadrum_providers.dart';
import 'facturacion_quadrum_providers.dart';
import 'complemento_pago_dialog.dart';
import 'nota_credito_dialog.dart';

/// Acciones de Quadrum sobre UN folio de la tabla.
///
/// Se abre con clic derecho (o pulsacion larga) sobre el renglon. El RFC
/// emisor del folio es lo que amarra todo: con el se busca su certificado
/// entre los cargados en FACT_CSD, y si no hay, no se deja timbrar.
///
/// La simulacion no escribe nada; timbrar y cancelar si, y ambas piden
/// confirmacion aparte.
Future<void> mostrarAccionesQuadrum(
  BuildContext context,
  Map<String, dynamic> fila,
) {
  return showDialog<void>(
    context: context,
    builder: (_) => _AccionesQuadrumDialog(fila: fila),
  );
}

String _texto(Map<String, dynamic> fila, List<String> claves) {
  for (final clave in claves) {
    for (final entrada in fila.entries) {
      if (entrada.key.toUpperCase() != clave.toUpperCase()) continue;
      final valor = entrada.value;
      if (valor == null) continue;
      final texto = '$valor'.trim();
      if (texto.isNotEmpty && texto != 'null') return texto;
    }
  }
  return '';
}

class _AccionesQuadrumDialog extends ConsumerStatefulWidget {
  const _AccionesQuadrumDialog({required this.fila});

  final Map<String, dynamic> fila;

  @override
  ConsumerState<_AccionesQuadrumDialog> createState() =>
      _AccionesQuadrumDialogState();
}

class _AccionesQuadrumDialogState
    extends ConsumerState<_AccionesQuadrumDialog> {
  late final String _idFol = _texto(widget.fila, ['IDFOL']);
  late final String _rfcEmisor = _texto(widget.fila, ['RFCEMISOR', 'RfcEmisor']);
  late final String _rfcReceptor = _texto(widget.fila, [
    'RFCRECEPTOR',
    'RfcReceptor',
  ]);
  late final String _uuid = _texto(widget.fila, ['CFDI_UUID']);
  late final String _pac = _texto(widget.fila, ['CFDI_PAC']);
  late final String _estatus = _texto(widget.fila, ['ESTATUS']);
  late final String _cancelStatus = _texto(widget.fila, [
    'CFDI_CANCEL_STATUS',
  ]);
  late final String _cfdiStatus = _texto(widget.fila, ['CFDI_STATUS']);

  /// Cancelada o en proceso de cancelarse: en ambos casos ya no se le puede
  /// emitir una nota de credito.
  late final bool _estaCancelada =
      _cfdiStatus.toUpperCase() == 'CANCELADO' || _cancelStatus.isNotEmpty;

  /// Cancelado, o con la cancelacion en tramite: el SAT ya acepto la
  /// solicitud, asi que el folio quedo libre para volver a facturarse.
  late final bool _puedeRefacturar =
      _cfdiStatus.toUpperCase() == 'CANCELADO' || _cancelStatus.isNotEmpty;

  late final TextEditingController _totalCtrl = TextEditingController(
    text: _texto(widget.fila, ['IMPT', 'TOTAL']),
  );

  String _canMotivo = '02';
  String? _resultado;
  bool _esError = false;
  bool _ocupado = false;

  @override
  void dispose() {
    _totalCtrl.dispose();
    super.dispose();
  }

  CfdiQuadrumApi get _api => ref.read(cfdiQuadrumApiProvider);

  /// Ejecuta una accion contra la API y muestra su respuesta.
  ///
  /// `cambiaElFolio` refresca la tabla al terminar. Hay que marcarlo en todo
  /// lo que escribe en la base —timbrar, cancelar, y consultar el estatus,
  /// que marca el folio cuando el SAT ya confirmo la cancelacion— o el
  /// renglon se queda con el estatus viejo hasta recargar.
  Future<void> _correr(
    Future<Map<String, dynamic>> Function() accion, {
    String? confirmacion,
    bool cambiaElFolio = false,
  }) async {
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
      if (cambiaElFolio) ref.invalidate(facturasPendientesProvider);
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
    final csdAsync = ref.watch(csdListProvider);
    final pac = ref.watch(cfdiEstadoProvider).asData?.value['pac'];
    // Solo se timbra de verdad cuando el PAC apunta a produccion.
    final enProduccion =
        pac is Map && '${pac['ambiente'] ?? ''}' == 'PRODUCCION';
    final motivos = ref.watch(cfdiMotivosCancelacionProvider).asData?.value ??
        const <Map<String, dynamic>>[];

    // El certificado del RFC emisor de ESTE folio.
    final csd = csdAsync.asData?.value
        .where((c) => c.activo && c.rfc.toUpperCase() == _rfcEmisor.toUpperCase())
        .firstOrNull;
    final tieneCsd = csd != null;
    final yaTimbrado = _uuid.isNotEmpty;
    final esDeFacturify = _pac.isNotEmpty && _pac.toUpperCase() != 'QUADRUM';
    final puedeTimbrar =
        tieneCsd && (!yaTimbrado || _puedeRefacturar) && !esDeFacturify && enProduccion && !_ocupado;

    return AlertDialog(
      title: Text('Quadrum · folio $_idFol'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _datos(),
              const SizedBox(height: 10),
              _estadoCsd(csdAsync.isLoading, tieneCsd, csd?.noCertificado),
              const Divider(height: 24),
              Text(
                'Timbrado',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _ocupado
                        ? null
                        : () => _correr(() => _api.probarFolio(_idFol)),
                    icon: const Icon(Icons.science_outlined),
                    label: const Text('Simular (no guarda nada)'),
                  ),
                  FilledButton.icon(
                    onPressed: puedeTimbrar
                        ? () => _correr(
                            () => _api.emitirFolio(_idFol),
                            confirmacion:
                                'Se va a timbrar el folio $_idFol con Quadrum. '
                                'Genera un CFDI ante el SAT y marca el folio en la '
                                'base como timbrado por QUADRUM. ¿Continuar?',
                            cambiaElFolio: true,
                          )
                        : null,
                    icon: const Icon(Icons.bolt_outlined),
                    label: const Text('Timbrar con Quadrum'),
                  ),
                ],
              ),
              if (!puedeTimbrar)
                _razonBloqueo(
                  tieneCsd,
                  yaTimbrado,
                  esDeFacturify,
                  enProduccion: enProduccion,
                ),
              const Divider(height: 24),
              Text(
                'Sobre el CFDI ya timbrado',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 170,
                    child: TextField(
                      controller: _totalCtrl,
                      enabled: !_ocupado,
                      decoration: const InputDecoration(
                        labelText: 'Total del CFDI',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 300,
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _canMotivo,
                      decoration: const InputDecoration(
                        labelText: 'Motivo de cancelación',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items: (motivos.isEmpty
                              ? const [
                                  {'clave': '02', 'descripcion': 'Con errores sin relación'},
                                ]
                              : motivos)
                          .map(
                            (m) => DropdownMenuItem(
                              value: '${m['clave']}',
                              child: Text(
                                '${m['clave']} · ${m['descripcion']}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: _ocupado
                          ? null
                          : (v) => setState(() => _canMotivo = v ?? '02'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: yaTimbrado && !_ocupado
                        ? () => _correr(() => _api.consultar(_uuid))
                        : null,
                    icon: const Icon(Icons.search),
                    label: const Text('Consultar en el PAC'),
                  ),
                  OutlinedButton.icon(
                    onPressed: yaTimbrado && !_ocupado
                        ? () => _correr(
                            () => _api.estatusCancelacion(
                              uuid: _uuid,
                              rfcReceptor: _rfcReceptor,
                              total: _totalCtrl.text.trim(),
                            ),
                            cambiaElFolio: true,
                          )
                        : null,
                    icon: const Icon(Icons.fact_check_outlined),
                    label: const Text('¿Es cancelable?'),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                    onPressed: yaTimbrado && !_ocupado
                        ? () => _correr(
                            () => _api.cancelar(
                              uuid: _uuid,
                              motivo: _canMotivo,
                              rfcReceptor: _rfcReceptor,
                              total: _totalCtrl.text.trim(),
                            ),
                            confirmacion:
                                'Cancelar ante el SAT NO se deshace. '
                                '¿Cancelar el CFDI $_uuid con motivo $_canMotivo?',
                            cambiaElFolio: true,
                          )
                        : null,
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Cancelar CFDI'),
                  ),
                  OutlinedButton.icon(
                    onPressed: yaTimbrado && !_ocupado
                        ? () => _descargarAcuse()
                        : null,
                    icon: const Icon(Icons.receipt_long),
                    label: const Text('Acuse de cancelacion'),
                  ),
                ],
              ),
              if (!yaTimbrado)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    'Este folio no tiene UUID: consultar y cancelar no aplican.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              const Divider(height: 24),
              Text(
                'Nota de crédito y complemento de pago',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: yaTimbrado && !_estaCancelada && !_ocupado
                        ? () => mostrarNotaCredito(context, widget.fila)
                        : null,
                    icon: const Icon(Icons.undo_outlined),
                    label: const Text('Nota de crédito'),
                  ),
                  if (yaTimbrado && _estaCancelada)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Este CFDI esta cancelado o en proceso de cancelacion: '
                        'una nota de credito ya no procede.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: yaTimbrado && !_estaCancelada && !_ocupado
                        ? () => mostrarComplementoPago(context, widget.fila)
                        : null,
                    icon: const Icon(Icons.payments_outlined),
                    label: const Text('Complemento de pago'),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                    'La nota de credito aplica a facturas vigentes; el '
                    'complemento de pago, solo a las de credito (PPD).',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              if (_ocupado)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(),
                ),
              if (_resultado != null) ...[
                const SizedBox(height: 12),
                _Resultado(texto: _resultado!, esError: _esError),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _ocupado ? null : () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }

  Widget _datos() {
    final filas = <(String, String)>[
      ('RFC emisor', _rfcEmisor.isEmpty ? '-' : _rfcEmisor),
      ('RFC receptor', _rfcReceptor.isEmpty ? '-' : _rfcReceptor),
      ('Estatus', _estatus.isEmpty ? '-' : _estatus),
      ('UUID', _uuid.isEmpty ? '(sin timbrar)' : _uuid),
      ('PAC', _pac.isEmpty ? '(sin marca)' : _pac),
    ];
    return Column(
      children: filas
          .map(
            (f) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(
                      f.$1,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Expanded(child: SelectableText(f.$2)),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _estadoCsd(bool cargando, bool tieneCsd, String? noCertificado) {
    if (cargando) {
      return const Chip(
        avatar: SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        label: Text('Buscando certificado...'),
      );
    }
    return Chip(
      avatar: Icon(
        tieneCsd ? Icons.verified_outlined : Icons.report_gmailerrorred_outlined,
        size: 18,
        color: tieneCsd ? Colors.green.shade700 : Theme.of(context).colorScheme.error,
      ),
      label: Text(
        tieneCsd
            ? 'CSD cargado: $noCertificado'
            : 'Sin CSD cargado para $_rfcEmisor',
      ),
    );
  }

  /// Baja el acuse que el SAT firmo al aceptar la cancelacion.
  ///
  /// La API se niega con un mensaje claro si ese folio nunca se cancelo.
  Future<void> _descargarAcuse() async {
    if (!supportsDownload) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Las descargas solo funcionan en web.')),
      );
      return;
    }
    setState(() => _ocupado = true);
    try {
      final bytes = await _api.descargarAcuseCancelacion(widget.fila['IDFOL'].toString());
      await saveBytesFile(bytes, '${widget.fila['IDFOL']}_acuse.xml', 'application/xml');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Acuse descargado.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            apiErrorMessage(error, fallback: 'No se pudo bajar el acuse'),
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Widget _razonBloqueo(
    bool tieneCsd,
    bool yaTimbrado,
    bool esDeFacturify, {
    required bool enProduccion,
  }) {
    if (!enProduccion) {
      return const Padding(
        padding: EdgeInsets.only(top: 6),
        child: Text(
          'El PAC esta apuntando a PRUEBAS. Timbrar aqui marcaria el folio real '
          'con un UUID que el SAT no reconoce; usa Simular.',
          style: TextStyle(fontSize: 12),
        ),
      );
    }
    final razon = !tieneCsd
        ? 'Falta cargar el CSD de $_rfcEmisor en Facturación · Certificados.'
        : yaTimbrado
            ? 'El folio ya tiene UUID; para rehacerlo hay que cancelarlo primero.'
            : esDeFacturify
                ? 'El folio está marcado para $_pac, así que Quadrum no lo toca.'
                : null;
    if (razon == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(razon, style: const TextStyle(fontSize: 12)),
    );
  }
}

class _Resultado extends StatelessWidget {
  const _Resultado({required this.texto, required this.esError});

  final String texto;
  final bool esError;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 260),
      decoration: BoxDecoration(
        color: esError ? esquema.error.withValues(alpha: 0.06) : Colors.black12,
        border: Border.all(color: esError ? esquema.error : esquema.outline),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                esError ? Icons.error_outline : Icons.check_circle_outline,
                size: 16,
                color: esError ? esquema.error : Colors.green.shade700,
              ),
              const SizedBox(width: 6),
              Text(
                esError ? 'Error' : 'Respuesta',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: esError ? esquema.error : null,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Copiar',
                visualDensity: VisualDensity.compact,
                onPressed: () =>
                    Clipboard.setData(ClipboardData(text: texto)),
                icon: const Icon(Icons.copy, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: SingleChildScrollView(
              child: SelectableText(
                texto,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
