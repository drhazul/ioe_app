import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'reloj_checador_app_models.dart';
import 'reloj_checador_app_providers.dart';

class RelojChecadorAppPage extends ConsumerStatefulWidget {
  const RelojChecadorAppPage({super.key});

  @override
  ConsumerState<RelojChecadorAppPage> createState() =>
      _RelojChecadorAppPageState();
}

class _RelojChecadorAppPageState extends ConsumerState<RelojChecadorAppPage> {
  final _latCtrl = TextEditingController();
  final _lonCtrl = TextEditingController();
  final _accCtrl = TextEditingController();

  String _authMethod = 'PIN';
  bool _livenessOk = true;
  String? _submittingTipo;

  @override
  void dispose() {
    _latCtrl.dispose();
    _lonCtrl.dispose();
    _accCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(relojChecadorContextProvider(null));
    await ref.read(relojChecadorContextProvider(null).future);
  }

  Future<void> _submit(RelojChecadorContext contextData, String tipo) async {
    if (_submittingTipo != null) return;

    final lat = _parseDouble(_latCtrl.text);
    final lon = _parseDouble(_lonCtrl.text);
    final acc = _parseInt(_accCtrl.text);

    if (contextData.requireGps && (lat == null || lon == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este marcaje requiere GPS: captura LAT y LON.'),
        ),
      );
      return;
    }

    setState(() => _submittingTipo = tipo);

    try {
      final api = ref.read(relojChecadorAppApiProvider);
      final result = await api.createTimelog(
        TimelogCreateRequest(
          suc: contextData.suc,
          tipo: tipo,
          authMethod: _authMethod,
          livenessOk: _livenessOk,
          lat: contextData.requireGps ? lat : null,
          lon: contextData.requireGps ? lon : null,
          gpsAccuracyM: contextData.requireGps ? acc : null,
          deviceId: kIsWeb ? 'flutter-web' : 'flutter-mobile',
          notes: null,
        ),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.message.isEmpty
                ? 'Marcaje registrado correctamente'
                : result.message,
          ),
          backgroundColor: result.ok ? Colors.green : Colors.orange,
        ),
      );
      await _refresh();
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = _readDioMessage(
        e,
        fallback: 'No se pudo registrar el marcaje',
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
    } finally {
      if (mounted) {
        setState(() => _submittingTipo = null);
      }
    }
  }

  bool _canPress(RelojChecadorContext c, String tipo) {
    final last = (c.lastTipo ?? '').toUpperCase();
    final next = c.nextAllowedTipo.toUpperCase();

    if (last.isEmpty) return tipo == 'ENTRADA';
    if (last == 'ENTRADA') return tipo == 'SALIDA_COMER' || tipo == 'SALIDA';
    if (last == 'SALIDA_COMER') return tipo == 'REGRESO_COMER';
    if (last == 'REGRESO_COMER') return tipo == 'SALIDA';
    if (last == 'SALIDA') return false;

    if (next == 'NINGUNO') return false;
    if (next == tipo) return true;
    if (next == 'SALIDA_COMER' && tipo == 'SALIDA') return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final contextAsync = ref.watch(relojChecadorContextProvider(null));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reloj checador - App'),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
          IconButton(
            onPressed: () => context.go('/reloj-checador/consultas'),
            icon: const Icon(Icons.manage_search),
            tooltip: 'Ir a consultas',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            contextAsync.when(
              data: (data) => _ContextCard(data: data),
              loading: () => const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (e, _) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('No se pudo cargar contexto: $e'),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Autenticacion',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _authMethod,
                      decoration: const InputDecoration(
                        labelText: 'Metodo',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'FACE', child: Text('FACE')),
                        DropdownMenuItem(
                          value: 'FINGER',
                          child: Text('FINGER'),
                        ),
                        DropdownMenuItem(value: 'PIN', child: Text('PIN')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _authMethod = value);
                      },
                    ),
                    if (kDebugMode) ...[
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Liveness OK (debug)'),
                        value: _livenessOk,
                        onChanged: (value) =>
                            setState(() => _livenessOk = value),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            contextAsync.maybeWhen(
              data: (data) => data.requireGps
                  ? Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'GPS requerido por policy',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _latCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                    signed: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'LAT',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _lonCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                    signed: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'LON',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _accCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText:
                                    'Precision GPS (m) - max ${data.gpsMaxAccuracyM}',
                                border: const OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
              orElse: () => const SizedBox.shrink(),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: contextAsync.when(
                  data: (data) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Checkpoints',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final tipo in const [
                            'ENTRADA',
                            'SALIDA_COMER',
                            'REGRESO_COMER',
                            'SALIDA',
                          ])
                            ElevatedButton.icon(
                              onPressed:
                                  _submittingTipo != null ||
                                      !_canPress(data, tipo)
                                  ? null
                                  : () => _submit(data, tipo),
                              icon: _submittingTipo == tipo
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.fingerprint, size: 16),
                              label: Text(tipo),
                            ),
                        ],
                      ),
                    ],
                  ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) =>
                      const Text('No se puede marcar sin contexto.'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContextCard extends StatelessWidget {
  const _ContextCard({required this.data});

  final RelojChecadorContext data;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Contexto de marcaje',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Sucursal: ${data.suc}'),
            Text('Ultimo marcaje: ${data.lastTipo ?? '-'}'),
            Text('Fecha ultimo marcaje: ${_fmt(data.lastFcnr)}'),
            Text('Siguiente permitido: ${data.nextAllowedTipo}'),
            Text('Requiere GPS: ${data.requireGps ? 'SI' : 'NO'}'),
            Text('Requiere liveness: ${data.requireLiveness ? 'SI' : 'NO'}'),
            Text('Valida ventanas: ${data.enforceWindows ? 'SI' : 'NO'}'),
            if (data.requireGps)
              Text(
                'Geocerca: ${data.geofenceLat ?? '-'}, ${data.geofenceLon ?? '-'} '
                'radio ${data.geofenceRadiusM ?? '-'}m',
              ),
            if (data.message.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                data.message,
                style: const TextStyle(color: Colors.blueGrey),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _fmt(DateTime? value) {
  if (value == null) return '-';
  final local = value.toLocal();
  final y = local.year.toString().padLeft(4, '0');
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '$d/$m/$y $hh:$mm';
}

String _readDioMessage(DioException e, {required String fallback}) {
  final data = e.response?.data;
  if (data is Map) {
    final map = Map<String, dynamic>.from(data);
    final message = map['message'];
    if (message is String && message.trim().isNotEmpty) {
      return message.trim();
    }
  }
  if ((e.message ?? '').trim().isNotEmpty) return e.message!.trim();
  return fallback;
}

double? _parseDouble(String input) {
  final text = input.trim();
  if (text.isEmpty) return null;
  return double.tryParse(text);
}

int? _parseInt(String input) {
  final text = input.trim();
  if (text.isEmpty) return null;
  return int.tryParse(text);
}
