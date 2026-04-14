import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ioe_app/core/api_error.dart';
import 'package:ioe_app/core/storage.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'ordenes_trabajo_models.dart';
import 'ordenes_trabajo_providers.dart';

class OrdenesTrabajoActionPage extends ConsumerStatefulWidget {
  const OrdenesTrabajoActionPage({super.key, required this.action});

  final OrdenesTrabajoInitialAction action;

  @override
  ConsumerState<OrdenesTrabajoActionPage> createState() =>
      _OrdenesTrabajoActionPageState();
}

class _OrdenesTrabajoActionPageState
    extends ConsumerState<OrdenesTrabajoActionPage> {
  final _ordCtrl = TextEditingController();
  final _observacionesCtrl = TextEditingController();
  final _signatureKey = GlobalKey();

  List<OrdenTrabajoEnviarRelacionItem> _relaciones =
      const <OrdenTrabajoEnviarRelacionItem>[];
  List<OrdenTrabajoColaboradorOption> _colaboradores =
      const <OrdenTrabajoColaboradorOption>[];
  List<Offset?> _signaturePoints = <Offset?>[];

  bool _processing = false;
  bool _loadingCollaborators = false;
  String _userSuc = '';
  String? _colaboradorId;

  bool get _requiresColaborador =>
      widget.action == OrdenesTrabajoInitialAction.asignar;
  bool get _requiresFirma =>
      widget.action == OrdenesTrabajoInitialAction.entregar;
  bool get _hasFirma => _signaturePoints.any((point) => point != null);

  @override
  void initState() {
    super.initState();
    if (_requiresColaborador) {
      unawaited(_loadUserContext());
    }
  }

  @override
  void dispose() {
    _ordCtrl.dispose();
    _observacionesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Regresar',
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(widget.action.pageTitle),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF7F3EC), Color(0xFFEFE6DA)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.action.pageTitle,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            Text(widget.action.helperText),
                            const SizedBox(height: 16),
                            _buildCaptureRow(),
                            if (_requiresColaborador) ...[
                              const SizedBox(height: 12),
                              _buildColaboradorField(),
                            ],
                            if (_requiresFirma) ...[
                              const SizedBox(height: 12),
                              _buildEntregaFields(),
                            ],
                            if (_processing || _loadingCollaborators) ...[
                              const SizedBox(height: 12),
                              const LinearProgressIndicator(),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 420,
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ORDs relacionadas (no editables)',
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              if (_requiresFirma) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'La firma y observaciones se aplicarán a todas las ORDs relacionadas.',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                              const SizedBox(height: 12),
                              Expanded(child: _buildRelacionTable()),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _processing ? null : _resetForm,
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: _processing ? null : () => context.go('/'),
                          child: const Text('Cerrar'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _processing ? null : _submit,
                          icon: Icon(widget.action.submitIcon),
                          label: Text(widget.action.submitLabel),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCaptureRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final field = TextField(
          controller: _ordCtrl,
          enabled: !_processing,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'ORD',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _addOrd(),
        );
        final button = OutlinedButton.icon(
          onPressed: _processing ? null : _scanOrd,
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Escanear'),
        );
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [field, const SizedBox(height: 8), button],
          );
        }
        return Row(
          children: [
            Expanded(child: field),
            const SizedBox(width: 8),
            button,
          ],
        );
      },
    );
  }

  Widget _buildColaboradorField() {
    final colaboradorSuc = _userSuc.trim().toUpperCase();
    final safeColaboradorId = _coerceColaboradorValue();
    return DropdownButtonFormField<String>(
      key: ValueKey('ord-colaborador-${safeColaboradorId ?? 'NONE'}'),
      initialValue: safeColaboradorId,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: colaboradorSuc.isEmpty
            ? 'Colaborador a asignar'
            : 'Colaborador a asignar ($colaboradorSuc)',
        border: const OutlineInputBorder(),
      ),
      items: _colaboradores
          .map(
            (item) => DropdownMenuItem<String>(
              value: item.idopv,
              child: Text(
                '${item.idopv} - ${item.label}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(growable: false),
      onChanged: _processing || _loadingCollaborators
          ? null
          : (value) => setState(() => _colaboradorId = value),
    );
  }

  String? _coerceColaboradorValue() {
    final selected = _colaboradorId;
    if (selected == null) return null;
    for (final item in _colaboradores) {
      if (item.idopv == selected) {
        return selected;
      }
    }
    return null;
  }

  Widget _buildEntregaFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _observacionesCtrl,
          enabled: !_processing,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Observaciones para entrega (opcional)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Firma digital del cliente',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            TextButton.icon(
              onPressed: _processing ? null : _clearSignature,
              icon: const Icon(Icons.cleaning_services_outlined),
              label: const Text('Limpiar firma'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: RepaintBoundary(
            key: _signatureKey,
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(12),
              ),
              child: GestureDetector(
                onPanStart: _processing
                    ? null
                    : (details) => _addSignaturePoint(details.localPosition),
                onPanUpdate: _processing
                    ? null
                    : (details) => _addSignaturePoint(details.localPosition),
                onPanEnd: _processing ? null : (_) => _endSignatureStroke(),
                child: CustomPaint(
                  painter: _SignaturePainter(_signaturePoints),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _hasFirma
              ? 'Firma capturada.'
              : 'Dibuja la firma del cliente antes de confirmar la entrega.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildRelacionTable() {
    if (_relaciones.isEmpty) {
      return const Center(child: Text('Sin ORDs relacionadas.'));
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          columns: const [
            DataColumn(label: Text('ORD')),
            DataColumn(label: Text('Cliente')),
            DataColumn(label: Text('Nombre cliente')),
            DataColumn(label: Text('Articulo')),
            DataColumn(label: Text('Descripcion')),
            DataColumn(label: Text('Cantidad')),
            DataColumn(label: Text('Acciones')),
          ],
          rows: _relaciones
              .map(
                (row) => DataRow(
                  cells: [
                    DataCell(Text(row.iord)),
                    DataCell(Text(row.clien)),
                    DataCell(SizedBox(width: 220, child: Text(row.ncliente))),
                    DataCell(Text(row.art)),
                    DataCell(SizedBox(width: 280, child: Text(row.descArt))),
                    DataCell(Text(_money(row.ctd))),
                    DataCell(
                      IconButton(
                        tooltip: 'Eliminar ORD',
                        onPressed: _processing
                            ? null
                            : () => _removeRelacion(row),
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }

  Future<void> _scanOrd() async {
    final scanned = await _captureCodeWithCamera();
    if (!mounted || (scanned ?? '').trim().isEmpty) return;
    await _addOrd(codeOverride: scanned);
  }

  Future<void> _addOrd({String? codeOverride}) async {
    if (_processing) return;
    final code = (codeOverride ?? _ordCtrl.text).trim();
    if (code.isEmpty) {
      _showError('Digita o escanea una ORD para continuar.');
      return;
    }

    setState(() => _processing = true);
    try {
      final item = await _validateOrd(code);
      if (_relaciones.any(
        (row) => _normalizeOrd(row.iord) == _normalizeOrd(item.iord),
      )) {
        throw _PageActionException('La ORD ${item.iord} ya está relacionada.');
      }
      if (!mounted) return;
      setState(
        () => _relaciones = <OrdenTrabajoEnviarRelacionItem>[
          ..._relaciones,
          item,
        ],
      );
      _ordCtrl.clear();
    } catch (e) {
      _showError(_errorMessage(e, widget.action.validateFallbackError));
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
  }

  Future<OrdenTrabajoEnviarRelacionItem> _validateOrd(String code) {
    final api = ref.read(ordenesTrabajoApiProvider);
    switch (widget.action) {
      case OrdenesTrabajoInitialAction.enviar:
        return api.validarOrdEnviar(code);
      case OrdenesTrabajoInitialAction.asignar:
        return api.validarOrdAsignar(code);
      case OrdenesTrabajoInitialAction.regresarTienda:
        return api.validarOrdRegresarTienda(code);
      case OrdenesTrabajoInitialAction.recibir:
        return api.validarOrdRecibir(code);
      case OrdenesTrabajoInitialAction.entregar:
        return api.validarOrdEntregar(code);
    }
  }

  Future<void> _loadCollaborators(String suc) async {
    final normalizedSuc = suc.trim().toUpperCase();
    if (normalizedSuc.isEmpty) return;
    if (_loadingCollaborators) return;
    setState(() => _loadingCollaborators = true);
    try {
      final items = await ref
          .read(ordenesTrabajoApiProvider)
          .fetchAsignarColaboradores(normalizedSuc);
      if (!mounted) return;
      setState(() {
        _colaboradores = items;
        if (!_colaboradores.any((item) => item.idopv == _colaboradorId)) {
          _colaboradorId = _colaboradores.isEmpty
              ? null
              : _colaboradores.first.idopv;
        }
      });
    } catch (e) {
      _showError(_errorMessage(e, 'No se pudo cargar colaboradores.'));
    } finally {
      if (mounted) {
        setState(() => _loadingCollaborators = false);
      }
    }
  }

  void _removeRelacion(OrdenTrabajoEnviarRelacionItem row) {
    final remaining = _relaciones
        .where((item) => _normalizeOrd(item.iord) != _normalizeOrd(row.iord))
        .toList(growable: false);
    setState(() {
      _relaciones = remaining;
    });
  }

  Future<void> _submit() async {
    if (_processing) return;
    if (_relaciones.isEmpty) {
      _showError(widget.action.emptySubmitError);
      return;
    }
    if (_requiresColaborador && (_colaboradorId ?? '').trim().isEmpty) {
      _showError('Selecciona un colaborador para continuar.');
      return;
    }
    if (_requiresFirma && !_hasFirma) {
      _showError('Captura la firma digital del cliente para continuar.');
      return;
    }

    final confirm = await _confirmSubmit();
    if (confirm != true) return;

    setState(() => _processing = true);
    try {
      final message = await _executeSubmit();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      _showError(_errorMessage(e, widget.action.executeFallbackError));
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
  }

  Future<String> _executeSubmit() async {
    final api = ref.read(ordenesTrabajoApiProvider);
    final iords = _relaciones
        .map((item) => item.iord.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);

    switch (widget.action) {
      case OrdenesTrabajoInitialAction.enviar:
        final result = await api.enviarLote(iords);
        _resetAfterSuccess();
        return _resolveSuccessMessage(
          result.message,
          fallback:
              '${iords.length} ORD${iords.length == 1 ? '' : 's'} enviada${iords.length == 1 ? '' : 's'} correctamente.',
        );
      case OrdenesTrabajoInitialAction.asignar:
        final result = await api.asignarLote(
          iords,
          idopv: _colaboradorId!.trim(),
        );
        _resetAfterSuccess(keepColaboradorState: true);
        return _resolveSuccessMessage(
          result.message,
          fallback:
              '${iords.length} ORD${iords.length == 1 ? '' : 's'} asignada${iords.length == 1 ? '' : 's'} correctamente.',
        );
      case OrdenesTrabajoInitialAction.regresarTienda:
        final result = await api.regresarTiendaLote(iords);
        _resetAfterSuccess();
        return _resolveSuccessMessage(
          result.message,
          fallback:
              '${iords.length} ORD${iords.length == 1 ? '' : 's'} regresada${iords.length == 1 ? '' : 's'} a tienda correctamente.',
        );
      case OrdenesTrabajoInitialAction.recibir:
        final result = await api.recibirLote(iords);
        _resetAfterSuccess();
        return _resolveSuccessMessage(
          result.message,
          fallback:
              '${iords.length} ORD${iords.length == 1 ? '' : 's'} recibida${iords.length == 1 ? '' : 's'} correctamente.',
        );
      case OrdenesTrabajoInitialAction.entregar:
        return _executeEntregaIndividual();
    }
  }

  Future<String> _executeEntregaIndividual() async {
    final api = ref.read(ordenesTrabajoApiProvider);
    final total = _relaciones.length;
    final observaciones = _observacionesCtrl.text.trim();
    final firmaCliente = await _exportSignatureBase64();
    var processed = 0;
    String lastMessage = '';

    while (_relaciones.isNotEmpty) {
      final current = _relaciones.first;
      try {
        final result = await api.entregar(
          current.iord,
          observaciones: observaciones.isEmpty ? null : observaciones,
          firmaCliente: firmaCliente,
        );
        processed++;
        lastMessage = result.message;
        if (!mounted) break;
        setState(() {
          _relaciones = _relaciones
              .where(
                (item) =>
                    _normalizeOrd(item.iord) != _normalizeOrd(current.iord),
              )
              .toList(growable: false);
        });
      } catch (e) {
        final fallback = apiErrorMessage(
          e,
          fallback: widget.action.executeFallbackError,
        );
        if (processed > 0) {
          throw _PageActionException(
            'Se entregaron $processed de $total ORDs antes del error. $fallback',
          );
        }
        throw _PageActionException(fallback);
      }
    }

    _observacionesCtrl.clear();
    _clearSignature();
    return _resolveSuccessMessage(
      lastMessage,
      fallback:
          '$total ORD${total == 1 ? '' : 's'} entregada${total == 1 ? '' : 's'} correctamente.',
    );
  }

  Future<bool?> _confirmSubmit() {
    final extraMessage = switch (widget.action) {
      OrdenesTrabajoInitialAction.asignar =>
        _selectedColaboradorLabel == null
            ? null
            : 'Colaborador: $_selectedColaboradorLabel',
      OrdenesTrabajoInitialAction.entregar =>
        _hasFirma ? 'Se adjuntará firma digital del cliente.' : null,
      _ => null,
    };
    final total = _relaciones.length;
    final suffix = total == 1 ? '' : 's';
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(widget.action.confirmTitle),
        content: Text(
          [
            'Se cambiará ESTSEGU a ${widget.action.targetStatus} para $total ORD$suffix.',
            if ((extraMessage ?? '').trim().isNotEmpty) extraMessage!.trim(),
            '¿Deseas continuar?',
          ].join('\n'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  void _resetForm() {
    _ordCtrl.clear();
    _observacionesCtrl.clear();
    _clearSignature();
    setState(() {
      _relaciones = const <OrdenTrabajoEnviarRelacionItem>[];
      if (!_requiresColaborador) {
        _colaboradores = const <OrdenTrabajoColaboradorOption>[];
        _colaboradorId = null;
      }
    });
  }

  void _resetAfterSuccess({bool keepColaboradorState = false}) {
    _ordCtrl.clear();
    if (_requiresFirma) {
      _observacionesCtrl.clear();
      _clearSignature();
    }
    setState(() {
      _relaciones = const <OrdenTrabajoEnviarRelacionItem>[];
      if (!keepColaboradorState) {
        if (!_requiresColaborador) {
          _colaboradores = const <OrdenTrabajoColaboradorOption>[];
          _colaboradorId = null;
        }
      }
    });
  }

  String? get _selectedColaboradorLabel {
    if ((_colaboradorId ?? '').trim().isEmpty) return null;
    final matches = _colaboradores.where(
      (item) => item.idopv == _colaboradorId,
    );
    return matches.isEmpty ? _colaboradorId?.trim() : matches.first.label;
  }

  Future<void> _loadUserContext() async {
    final storage = ref.read(storageProvider);
    final token = await storage.getAccessToken();
    if (token == null || token.isEmpty) return;

    final payload = _decodeJwt(token);
    final suc = (payload['suc'] ?? '').toString().trim().toUpperCase();
    if (!mounted || suc.isEmpty) return;

    setState(() => _userSuc = suc);
    await _loadCollaborators(suc);
  }

  Map<String, dynamic> _decodeJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return {};
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      return Map<String, dynamic>.from(json.decode(payload) as Map);
    } catch (_) {
      return {};
    }
  }

  void _addSignaturePoint(Offset point) {
    setState(() => _signaturePoints = <Offset?>[..._signaturePoints, point]);
  }

  void _endSignatureStroke() {
    if (_signaturePoints.isEmpty || _signaturePoints.last == null) return;
    setState(() => _signaturePoints = <Offset?>[..._signaturePoints, null]);
  }

  void _clearSignature() {
    if (!mounted) return;
    setState(() => _signaturePoints = <Offset?>[]);
  }

  Future<String> _exportSignatureBase64() async {
    final boundary = _signatureKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) {
      throw const _PageActionException(
        'No se pudo capturar la firma digital. Intenta nuevamente.',
      );
    }
    final image = await boundary.toImage(pixelRatio: 3);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw const _PageActionException(
        'No se pudo convertir la firma digital a imagen.',
      );
    }
    return base64Encode(byteData.buffer.asUint8List());
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _resolveSuccessMessage(String rawMessage, {required String fallback}) {
    final message = rawMessage.trim();
    return message.isEmpty ? fallback : message;
  }

  String _errorMessage(Object error, String fallback) {
    if (error is _PageActionException) return error.message;
    return apiErrorMessage(error, fallback: fallback);
  }

  String _money(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2);
  }

  String _normalizeOrd(String value) => value.trim().toUpperCase();

  Future<String?> _captureCodeWithCamera() async {
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        var locked = false;
        return AlertDialog(
          title: const Text('Escanear por camara'),
          content: SizedBox(
            width: 420,
            height: 420,
            child: MobileScanner(
              controller: MobileScannerController(
                detectionSpeed: DetectionSpeed.noDuplicates,
              ),
              onDetect: (capture) {
                if (locked) return;
                final barcode = capture.barcodes.isNotEmpty
                    ? capture.barcodes.first
                    : null;
                final code = barcode?.rawValue?.trim() ?? '';
                if (code.isEmpty) return;
                locked = true;
                Navigator.of(ctx).pop(code);
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    );
  }
}

extension on OrdenesTrabajoInitialAction {
  static const String _recibirRolHint =
      'Los encargados de maquila solo pueden recibir ORDs TALLADO y los encargados de bisel solo ORDs BISELADO. Admin y jefe de taller pueden recibir ambas.';

  String get pageTitle {
    switch (this) {
      case OrdenesTrabajoInitialAction.enviar:
        return 'ORDs: Enviar a taller';
      case OrdenesTrabajoInitialAction.asignar:
        return 'ORDs: Asignar a colaborador';
      case OrdenesTrabajoInitialAction.regresarTienda:
        return 'ORDs: Recibir en tienda';
      case OrdenesTrabajoInitialAction.recibir:
        return 'ORDs: Recibir en taller';
      case OrdenesTrabajoInitialAction.entregar:
        return 'ORDs: Entregar a cliente';
    }
  }

  String get helperText {
    switch (this) {
      case OrdenesTrabajoInitialAction.enviar:
        return 'Captura o escanea una ORD para validarla en estatus 3 (NUEVA AUTORIZADA) y relacionarla para envío. La ORD debe tener laboratorio asignado.';
      case OrdenesTrabajoInitialAction.asignar:
        return 'Captura o escanea una ORD para validarla en estatus 7 (RECIBIDA A TALLER) y asignar colaborador.';
      case OrdenesTrabajoInitialAction.regresarTienda:
        return 'Captura o escanea una ORD para validarla en estatus 9 (TRABAJO TERMINADO) y recibirla en tienda. Mapeo: TIPOM=1 -> 9.1, TIPOM=2 -> 9.2.';
      case OrdenesTrabajoInitialAction.recibir:
        return 'Captura o escanea una ORD para validarla en estatus 5 (ENTREGADA A MAQ O BISEL) y recibirla en taller.\n\n$_recibirRolHint';
      case OrdenesTrabajoInitialAction.entregar:
        return 'Captura o escanea una ORD para validarla en estatus 10 (REGRESADO A TIENDA) y entregarla al cliente con firma digital.';
    }
  }

  String get submitLabel {
    switch (this) {
      case OrdenesTrabajoInitialAction.enviar:
        return 'Enviar a taller';
      case OrdenesTrabajoInitialAction.asignar:
        return 'Asignar a colaborador';
      case OrdenesTrabajoInitialAction.regresarTienda:
        return 'Recibir en tienda';
      case OrdenesTrabajoInitialAction.recibir:
        return 'Recibir en taller';
      case OrdenesTrabajoInitialAction.entregar:
        return 'Entregar a cliente';
    }
  }

  IconData get submitIcon {
    switch (this) {
      case OrdenesTrabajoInitialAction.enviar:
        return Icons.outbound;
      case OrdenesTrabajoInitialAction.asignar:
        return Icons.assignment_ind;
      case OrdenesTrabajoInitialAction.regresarTienda:
        return Icons.storefront_outlined;
      case OrdenesTrabajoInitialAction.recibir:
        return Icons.qr_code_scanner;
      case OrdenesTrabajoInitialAction.entregar:
        return Icons.handshake_outlined;
    }
  }

  String get emptySubmitError {
    switch (this) {
      case OrdenesTrabajoInitialAction.enviar:
        return 'No hay ORDs relacionadas para enviar.';
      case OrdenesTrabajoInitialAction.asignar:
        return 'No hay ORDs relacionadas para asignar.';
      case OrdenesTrabajoInitialAction.regresarTienda:
        return 'No hay ORDs relacionadas para recibir en tienda.';
      case OrdenesTrabajoInitialAction.recibir:
        return 'No hay ORDs relacionadas para recibir en taller.';
      case OrdenesTrabajoInitialAction.entregar:
        return 'No hay ORDs relacionadas para entregar a cliente.';
    }
  }

  String get validateFallbackError {
    switch (this) {
      case OrdenesTrabajoInitialAction.enviar:
        return 'No se pudo validar la ORD. Debe estar en estatus 3 y tener laboratorio asignado.';
      case OrdenesTrabajoInitialAction.asignar:
        return 'No se pudo validar la ORD. Debe estar en estatus 7 (RECIBIDA A TALLER).';
      case OrdenesTrabajoInitialAction.regresarTienda:
        return 'No se pudo validar la ORD. Debe estar en estatus 9.';
      case OrdenesTrabajoInitialAction.recibir:
        return 'No se pudo validar la ORD. Debe estar en estatus 5.';
      case OrdenesTrabajoInitialAction.entregar:
        return 'No se pudo validar la ORD. Debe estar en estatus 10.';
    }
  }

  String get executeFallbackError {
    switch (this) {
      case OrdenesTrabajoInitialAction.enviar:
        return 'No se pudieron enviar las ORDs seleccionadas.';
      case OrdenesTrabajoInitialAction.asignar:
        return 'No se pudieron asignar las ORDs seleccionadas.';
      case OrdenesTrabajoInitialAction.regresarTienda:
        return 'No se pudieron recibir en tienda las ORDs seleccionadas.';
      case OrdenesTrabajoInitialAction.recibir:
        return 'No se pudieron recibir en taller las ORDs seleccionadas.';
      case OrdenesTrabajoInitialAction.entregar:
        return 'No se pudieron entregar a cliente las ORDs seleccionadas.';
    }
  }

  String get confirmTitle {
    switch (this) {
      case OrdenesTrabajoInitialAction.enviar:
        return 'Confirmar envío';
      case OrdenesTrabajoInitialAction.asignar:
        return 'Confirmar asignación';
      case OrdenesTrabajoInitialAction.regresarTienda:
        return 'Confirmar recepción en tienda';
      case OrdenesTrabajoInitialAction.recibir:
        return 'Confirmar recepción en taller';
      case OrdenesTrabajoInitialAction.entregar:
        return 'Confirmar entrega a cliente';
    }
  }

  String get targetStatus {
    switch (this) {
      case OrdenesTrabajoInitialAction.enviar:
        return '5';
      case OrdenesTrabajoInitialAction.asignar:
        return '8';
      case OrdenesTrabajoInitialAction.regresarTienda:
        return 'TIPOM=1 -> 9.1, TIPOM=2 -> 9.2, o 10';
      case OrdenesTrabajoInitialAction.recibir:
        return '7';
      case OrdenesTrabajoInitialAction.entregar:
        return '11';
    }
  }
}

class _SignaturePainter extends CustomPainter {
  const _SignaturePainter(this.points);

  final List<Offset?> points;

  @override
  void paint(Canvas canvas, Size size) {
    final borderPaint = Paint()
      ..color = const Color(0xFFD7D0C5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRect(Offset.zero & size, borderPaint);

    final paint = Paint()
      ..color = const Color(0xFF2F2A26)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 2.6
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < points.length - 1; i++) {
      final current = points[i];
      final next = points[i + 1];
      if (current == null || next == null) continue;
      canvas.drawLine(current, next, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

class _PageActionException implements Exception {
  const _PageActionException(this.message);

  final String message;

  @override
  String toString() => message;
}
