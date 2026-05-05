import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_controller.dart';
import '../../../masterdata/datos_maestros/datos_maestros_screen.dart';
import '../../../masterdata/sucursales/sucursales_page.dart';
import 'reloj_checador_auto_servicio_tab.dart';
import 'reloj_checador_colaboradores_tab.dart';
import 'reloj_checador_horarios_tab.dart';
import 'reloj_checador_incidencias_vacaciones_tab.dart';
import 'reloj_checador_app_models.dart';
import 'reloj_checador_app_providers.dart';
import 'reloj_checador_reporte_tab.dart';

class RelojChecadorAppPage extends ConsumerStatefulWidget {
  const RelojChecadorAppPage({super.key, required this.initialSection});

  final String initialSection;

  @override
  ConsumerState<RelojChecadorAppPage> createState() =>
      _RelojChecadorAppPageState();
}

class _RelojChecadorAppPageState extends ConsumerState<RelojChecadorAppPage> {
  static const List<String> _sections = <String>[
    'marcaje',
    'sucursales',
    'colaboradores',
    'horarios',
    'incidencias',
    'reporte',
    'auto-servicio',
    'datos-maestros',
  ];

  final String _authMethod = 'PIN';
  final bool _livenessOk = true;
  String? _submittingTipo;
  final TextEditingController _pinCtrl = TextEditingController();

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(relojChecadorContextProvider(null));
    await ref.read(relojChecadorContextProvider(null).future);
  }

  Future<void> _submit(RelojChecadorContext contextData, String tipo) async {
    if (_submittingTipo != null) return;

    setState(() => _submittingTipo = tipo);

    try {
      final api = ref.read(relojChecadorAppApiProvider);
      final auth = ref.read(authControllerProvider);
      final idUsuario = contextData.idUsuario ?? auth.userId ?? 0;
      final pin = _pinCtrl.text.trim().isNotEmpty
          ? _pinCtrl.text.trim()
          : (auth.username ?? '').trim();
      if (idUsuario <= 0 || pin.isEmpty) {
        throw Exception('Faltan datos de usuario para generar marcaje');
      }
      final now = DateTime.now();
      final result = await api.createTimelog(
        TimelogCreateRequest(
          id_usuario: idUsuario,
          pin: pin,
          suc: contextData.suc,
          tipo: tipo,
          authMethod: _authMethod,
          livenessOk: _livenessOk,
          lat: null,
          lon: null,
          gpsAccuracyM: null,
          deviceId: kIsWeb ? 'flutter-web' : 'flutter-mobile',
          clientIdUnico:
              '${kIsWeb ? 'flutter-web' : 'flutter-mobile'}-${now.millisecondsSinceEpoch}',
          fechaHoraLocal: now.toIso8601String(),
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

  int _initialIndexFromSection() {
    final section = widget.initialSection.trim().toLowerCase();
    final idx = _sections.indexOf(section);
    return idx < 0 ? 0 : idx;
  }

  @override
  Widget build(BuildContext context) {
    final contextAsync = ref.watch(relojChecadorContextProvider(null));
    final initialIndex = _initialIndexFromSection();

    return DefaultTabController(
      initialIndex: initialIndex,
      length: _sections.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Reloj checador - App'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.fingerprint), text: 'Marcaje'),
              Tab(icon: Icon(Icons.store), text: 'Gestión de Sucursales'),
              Tab(icon: Icon(Icons.people), text: 'Gestión de Colaboradores'),
              Tab(icon: Icon(Icons.schedule), text: 'Horarios'),
              Tab(
                icon: Icon(Icons.event_note),
                text: 'Incidencias y Vacaciones',
              ),
              Tab(icon: Icon(Icons.bar_chart), text: 'Reporte Mensual'),
              Tab(icon: Icon(Icons.qr_code_scanner), text: 'Auto-Servicio'),
              Tab(icon: Icon(Icons.dataset_linked), text: 'Datos Maestros'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildMarcajeTab(contextAsync),
            const SucursalesPage(embedded: true, allowConfiguration: true),
            const RelojChecadorColaboradoresTab(),
            const RelojChecadorHorariosTab(),
            const RelojChecadorIncidenciasVacacionesTab(),
            const RelojChecadorReporteTab(),
            const RelojChecadorAutoServicioTab(),
            const DatosMaestrosScreen(embedded: true),
          ],
        ),
      ),
    );
  }

  Widget _buildMarcajeTab(AsyncValue<RelojChecadorContext> contextAsync) {
    final auth = ref.watch(authControllerProvider);
    final nombre = (auth.username ?? 'Sin identificar').trim();
    final iniciales = nombre
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .take(2)
        .map((e) => e.substring(0, 1).toUpperCase())
        .join();

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () {
                final tab = DefaultTabController.of(context);
                tab.animateTo(2);
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF6350A9),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                shape: const StadiumBorder(),
              ),
              icon: const Icon(Icons.settings),
              label: const Text('Mantenimiento de Datos'),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 42,
                    backgroundColor: const Color(0xFFD9CEEE),
                    child: Text(
                      iniciales.isEmpty ? '--' : iniciales,
                      style: const TextStyle(
                        color: Color(0xFF5A4AA3),
                        fontWeight: FontWeight.w700,
                        fontSize: 28,
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: contextAsync.when(
                      data: (ctx) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nombre,
                            style: const TextStyle(
                              fontSize: 46 / 2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(ctx.message.isEmpty ? 'Auxiliar' : ctx.message),
                          Text(ctx.suc.isEmpty ? '-' : ctx.suc),
                        ],
                      ),
                      loading: () => const Text('Cargando colaborador...'),
                      error: (_, _) => const Text('Sin identificar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: TextField(
                controller: _pinCtrl,
                obscureText: true,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '••••',
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: contextAsync.when(
                data: (ctx) => Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    _MarcajeBtn(
                      color: const Color(0xFF2E7D32),
                      label: 'ENTRA',
                      busy: _submittingTipo == 'ENTRADA',
                      enabled: _submittingTipo == null && _canPress(ctx, 'ENTRADA'),
                      onTap: () => _submit(ctx, 'ENTRADA'),
                    ),
                    _MarcajeBtn(
                      color: const Color(0xFF1E64B7),
                      label: 'SALIDA COMER',
                      busy: _submittingTipo == 'SALIDA_COMER',
                      enabled:
                          _submittingTipo == null && _canPress(ctx, 'SALIDA_COMER'),
                      onTap: () => _submit(ctx, 'SALIDA_COMER'),
                    ),
                    _MarcajeBtn(
                      color: const Color(0xFF6A1B9A),
                      label: 'REGRESO COMER',
                      busy: _submittingTipo == 'REGRESO_COMER',
                      enabled:
                          _submittingTipo == null && _canPress(ctx, 'REGRESO_COMER'),
                      onTap: () => _submit(ctx, 'REGRESO_COMER'),
                    ),
                    _MarcajeBtn(
                      color: const Color(0xFFC62828),
                      label: 'SALIDA',
                      busy: _submittingTipo == 'SALIDA',
                      enabled: _submittingTipo == null && _canPress(ctx, 'SALIDA'),
                      onTap: () => _submit(ctx, 'SALIDA'),
                    ),
                  ],
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => const Text('Sin conexión de contexto'),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: contextAsync.when(
                data: (ctx) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Historial de Marcajes',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      ctx.message.isEmpty
                          ? 'Compañero, no pudimos conectar con el servidor'
                          : ctx.message,
                    ),
                  ],
                ),
                loading: () => const Text('Cargando historial...'),
                error: (_, _) =>
                    const Text('Compañero, no pudimos conectar con el servidor'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MarcajeBtn extends StatelessWidget {
  const _MarcajeBtn({
    required this.color,
    required this.label,
    required this.busy,
    required this.enabled,
    required this.onTap,
  });

  final Color color;
  final String label;
  final bool busy;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      height: 130,
      child: ElevatedButton(
        onPressed: enabled ? onTap : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        ),
        child: busy
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(
                label,
                style: const TextStyle(fontSize: 40 / 2, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
      ),
    );
  }
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

