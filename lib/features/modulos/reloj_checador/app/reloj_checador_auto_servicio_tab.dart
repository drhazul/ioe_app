import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:uuid/uuid.dart';

import 'reloj_checador_app_models.dart';
import 'reloj_checador_app_providers.dart';

class RelojChecadorAutoServicioTab extends ConsumerStatefulWidget {
  const RelojChecadorAutoServicioTab({super.key});

  @override
  ConsumerState<RelojChecadorAutoServicioTab> createState() =>
      _RelojChecadorAutoServicioTabState();
}

class _RelojChecadorAutoServicioTabState
    extends ConsumerState<RelojChecadorAutoServicioTab> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  SelfServiceSession? _session;
  String? _token;
  bool _scanning = true;
  bool _marking = false;
  String _tipo = 'ENTRADA';
  // ignore: unused_field
  bool _essLoading = false;
  final Map<int, String> _nom035ShownByDay = <int, String>{};
  late LocalAuthentication _localAuth;

  @override
  void initState() {
    super.initState();
    _localAuth = LocalAuthentication();
    Future.microtask(_hydrateCachedSession);
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _hydrateCachedSession() async {
    final api = ref.read(relojChecadorAppApiProvider);
    final cached = await api.restoreCachedSession();
    if (!mounted || cached == null) return;

    setState(() {
      _session = cached;
      _token = cached.token;
      _scanning = false;
    });

    try {
      await _loadEssData(token: cached.token);
    } catch (_) {
      // Si no hay red, dejamos tablero local.
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (!_scanning) return;
    final token = capture.barcodes
        .map((b) => b.rawValue?.trim() ?? '')
        .firstWhere((v) => v.isNotEmpty, orElse: () => '');
    if (token.isEmpty) return;

    setState(() => _scanning = false);

    try {
      final api = ref.read(relojChecadorAppApiProvider);
      final session = await api.qrLogin(token);

      _token = token;
      _session = session;
      await _loadEssData(token: token);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Bienvenido ${session.nombre}')));
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_dioMessage(e))));
      _resumeScan();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error QR: $e')));
      _resumeScan();
    }
  }

  Future<void> _loadEssData({required String token}) async {
    setState(() {
      _essLoading = true;
    });

    try {
      final api = ref.read(relojChecadorAppApiProvider);
      final now = DateTime.now();
      final rangeStart = DateTime(now.year, now.month, 1);
      final rangeEnd = DateTime(now.year, now.month + 1, 0);

      await api.getEssVacacionesDashboard(
        token: token,
        anio: now.year,
      );
      await api.getEssSolicitudes(
        token: token,
        fechaInicio: rangeStart,
        fechaFin: rangeEnd,
      );

      if (!mounted) return;
      setState(() {
        _essLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _essLoading = false;
      });
    }
  }


  Future<void> _markAttendance() async {
    if (_session == null || _token == null) return;

    setState(() => _marking = true);
    try {
      // Authenticate with biometry (Face ID or Fingerprint)
      final isAuthenticated = await _localAuth.authenticate(
        localizedReason: 'Escanea tu rostro o huella para marcar ${_tipo.toLowerCase()}',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (!isAuthenticated) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Autenticación biométrica cancelada')),
        );
        setState(() => _marking = false);
        return;
      }

      // Biometry successful, now create timelog with FACE/FINGER auth
      final api = ref.read(relojChecadorAppApiProvider);
      final deviceIdFuture = api.getSecurityService().resolveDeviceId();
      final deviceId = await deviceIdFuture;
      final now = DateTime.now();
      final clientIdUnico = '${deviceId}_${const Uuid().v4()}'.toUpperCase();

      final response = await api.createTimelog(
        TimelogCreateRequest(
          id_usuario: _session!.colaboradorId,
          pin: _session!.pin,
          suc: _session!.sucursalCodigo,
          tipo: _tipo,
          authMethod: 'FACE',
          livenessOk: true,
          lat: null,
          lon: null,
          gpsAccuracyM: null,
          deviceId: deviceId,
          clientIdUnico: clientIdUnico,
          fechaHoraLocal: now.toIso8601String(),
          notes: 'Self-service biometric attendance',
        ),
      );

      if (!mounted) return;
      final message = response.message.isNotEmpty
          ? response.message
          : 'Asistencia registrada correctamente';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );

      if (_tipo == 'SALIDA') {
        await _maybeShowNom035Modal(_session!);
      }
    } on DioException catch (e) {
      if (!mounted) return;
      final isNetwork =
          e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          (e.response == null &&
              (e.type == DioExceptionType.unknown ||
                  e.type == DioExceptionType.badCertificate));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isNetwork
                ? 'Sin conexión. Reintente en un momento.'
                : _dioMessage(e),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _marking = false);
    }
  }

  Future<void> _maybeShowNom035Modal(SelfServiceSession session) async {
    if (!mounted) return;

    final today = _dateIso(DateTime.now());
    final lastShown = _nom035ShownByDay[session.colaboradorId];
    if (lastShown == today) return;

    final randomGate = math.Random().nextInt(100) < 40;
    if (!randomGate) return;

    int p1 = 3;
    int p2 = 3;
    int p3 = 3;
    final comentarioCtrl = TextEditingController();
    var saving = false;

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: !saving,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              Widget likert({
                required String title,
                required int value,
                required ValueChanged<int> onChanged,
              }) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title),
                    const SizedBox(height: 4),
                    Slider(
                      value: value.toDouble(),
                      min: 1,
                      max: 5,
                      divisions: 4,
                      label: '$value',
                      onChanged: saving
                          ? null
                          : (v) => onChanged(v.round().clamp(1, 5)),
                    ),
                  ],
                );
              }

              return AlertDialog(
                title: const Text('Encuesta NOM-035 (Salida)'),
                content: SizedBox(
                  width: 480,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Responde de 1 (muy bajo) a 5 (muy alto).',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 10),
                        likert(
                          title: '1) Carga laboral del día',
                          value: p1,
                          onChanged: (v) => setDialogState(() => p1 = v),
                        ),
                        likert(
                          title: '2) Nivel de estrés percibido',
                          value: p2,
                          onChanged: (v) => setDialogState(() => p2 = v),
                        ),
                        likert(
                          title: '3) Apoyo del equipo/supervisión',
                          value: p3,
                          onChanged: (v) => setDialogState(() => p3 = v),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: comentarioCtrl,
                          maxLines: 3,
                          enabled: !saving,
                          decoration: const InputDecoration(
                            labelText: 'Comentario (opcional)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: saving
                        ? null
                        : () => Navigator.of(dialogContext).pop(),
                    child: const Text('Omitir'),
                  ),
                  FilledButton.icon(
                    onPressed: saving
                        ? null
                        : () async {
                            setDialogState(() => saving = true);
                            try {
                              final api = ref.read(relojChecadorAppApiProvider);
                              await api.saveNom035RespuestasSelfService(
                                token: _token ?? '',
                                payload: SaveNom035Request(
                                  p1: p1,
                                  p2: p2,
                                  p3: p3,
                                  comentario: comentarioCtrl.text.trim().isEmpty
                                      ? null
                                      : comentarioCtrl.text.trim(),
                                ),
                              );
                              _nom035ShownByDay[session.colaboradorId] = today;
                              if (!dialogContext.mounted) return;
                              Navigator.of(dialogContext).pop();
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Respuesta NOM-035 registrada'),
                                ),
                              );
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'No se pudo guardar NOM-035: $e',
                                  ),
                                ),
                              );
                              setDialogState(() => saving = false);
                            }
                          },
                    icon: saving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text('Guardar'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      comentarioCtrl.dispose();
    }
  }

  void _resumeScan() {
    final api = ref.read(relojChecadorAppApiProvider);
    Future.microtask(api.clearCachedSession);
    setState(() {
      _scanning = true;
      _session = null;
      _token = null;
     
      _essLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: session == null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: MobileScanner(
                      controller: _scannerController,
                      onDetect: _onDetect,
                    ),
                  )
                : Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session.nombre,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text('PIN: ${session.pin}'),
                          Text(
                            'Sucursal: ${session.sucursalCodigo ?? '-'}',
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _tipo,
                            decoration: const InputDecoration(
                              labelText: 'Tipo de marcaje',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'ENTRADA',
                                child: Text('ENTRADA'),
                              ),
                              DropdownMenuItem(
                                value: 'SALIDA_COMER',
                                child: Text('SALIDA_COMER'),
                              ),
                              DropdownMenuItem(
                                value: 'REGRESO_COMER',
                                child: Text('REGRESO_COMER'),
                              ),
                              DropdownMenuItem(
                                value: 'SALIDA',
                                child: Text('SALIDA'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() => _tipo = value);
                            },
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Preparado para autenticación biométrica',
                            style: TextStyle(
                              color: Color(0xFF2E7D32),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Cuando toques "MARCAR ASISTENCIA", se abrirá el lector de biometría de tu dispositivo (FaceID o Huella Digital).',
                            style: TextStyle(fontSize: 12),
                          ),
                          const Spacer(),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _marking ? null : _resumeScan,
                                icon: const Icon(Icons.qr_code_scanner),
                                label: const Text('Escanear otro QR'),
                              ),
                              FilledButton.icon(
                                onPressed: _marking ? null : _markAttendance,
                                icon: _marking
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.how_to_reg),
                                label: const Text('Marcar Asistencia'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

String _dioMessage(DioException e) {
  final data = e.response?.data;
  if (data is Map) {
    final map = Map<String, dynamic>.from(data);
    final message = map['message'];
    if (message is String && message.trim().isNotEmpty) {
      return message.trim();
    }
  }
  if ((e.message ?? '').trim().isNotEmpty) {
    return e.message!.trim();
  }
  return 'Error de red';
}

String _dateIso(DateTime value) {
  final y = value.year.toString().padLeft(4, '0');
  final m = value.month.toString().padLeft(2, '0');
  final d = value.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
