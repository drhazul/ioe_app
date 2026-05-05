import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ioe_app/core/dio_provider.dart';

import 'reloj_checador_app_api.dart';
import 'reloj_checador_app_models.dart';
import 'reloj_checador_realtime_client.dart';

final relojChecadorAppApiProvider = Provider<RelojChecadorAppApi>(
  (ref) => RelojChecadorAppApi(ref.read(dioProvider)),
);

final relojChecadorRealtimeClientProvider =
    Provider.autoDispose<RelojChecadorRealtimeClient>((ref) {
      final dio = ref.read(dioProvider);
      final client = RelojChecadorRealtimeClient(baseUrl: dio.options.baseUrl);
      client.connect();
      ref.onDispose(client.dispose);
      return client;
    });

final realtimePunchFeedProvider =
    StreamProvider.autoDispose<List<RelojRealtimePunchEvent>>((ref) async* {
      final client = ref.read(relojChecadorRealtimeClientProvider);
      final buffer = <RelojRealtimePunchEvent>[];
      yield const <RelojRealtimePunchEvent>[];

      await for (final event in client.punches) {
        buffer.insert(0, event);
        if (buffer.length > 120) {
          buffer.removeLast();
        }
        yield List<RelojRealtimePunchEvent>.unmodifiable(buffer);
      }
    });

final realtimeSocketConnectedProvider = StreamProvider.autoDispose<bool>((
  ref,
) async* {
  final client = ref.read(relojChecadorRealtimeClientProvider);
  await for (final connected in client.connected) {
    yield connected;
  }
});

final realtimeTemplateUpdatesProvider =
    StreamProvider.autoDispose<RelojRealtimeTemplateEvent>((ref) async* {
      final client = ref.read(relojChecadorRealtimeClientProvider);
      await for (final event in client.templateUpdates) {
        yield event;
      }
    });

final colaboradoresRealtimeBridgeProvider = Provider.autoDispose<void>((ref) {
  ref.listen<AsyncValue<RelojRealtimeTemplateEvent>>(
    realtimeTemplateUpdatesProvider,
    (previous, next) {
      if (next.hasValue) {
        ref.invalidate(colaboradoresLiveProvider);
      }
    },
  );
});

final relojChecadorContextProvider = FutureProvider.autoDispose
    .family<RelojChecadorContext, String?>((ref, suc) async {
      final api = ref.read(relojChecadorAppApiProvider);
      return api.getContext(suc: suc);
    });

final marcajesHistorialProvider = FutureProvider.autoDispose
    .family<List<MarcajeSqlModel>, int>((ref, idUsuario) async {
      final api = ref.read(relojChecadorAppApiProvider);
      return api.getMarcajesHistorialByUsuario(idUsuario);
    });

final sucursalesCatalogProvider =
    FutureProvider.autoDispose<List<SucursalOptionModel>>((ref) async {
      final api = ref.read(relojChecadorAppApiProvider);
      return api.getSucursalesCatalog();
    });

final horariosCatalogProvider = FutureProvider.autoDispose<List<HorarioModel>>((
  ref,
) async {
  final api = ref.read(relojChecadorAppApiProvider);
  return api.getHorarios();
});

final turnosCatalogProvider =
    FutureProvider.autoDispose<List<TurnoCatalogoModel>>((ref) async {
      final api = ref.read(relojChecadorAppApiProvider);
      return api.getTurnosCatalogo();
    });

final colaboradoresLiveProvider =
    StreamProvider.autoDispose<List<ColaboradorGestionModel>>((ref) async* {
      final api = ref.read(relojChecadorAppApiProvider);
      List<ColaboradorGestionModel> last = const [];

      while (true) {
        try {
          final sucursalId = ref.read(colabFilterSucursalIdProvider);
          final departamento = ref.read(colabFilterDepartamentoProvider);
          final cargo = ref.read(colabFilterCargoProvider);
          final search = ref.read(colabFilterSearchProvider);
          last = await api.getColaboradores(
            sucursalId: sucursalId,
            departamento: departamento,
            cargo: cargo,
            search: search.isNotEmpty ? search : null,
          );
          yield last;
        } catch (_) {
          if (last.isNotEmpty) {
            yield last;
          }
        }
        await Future<void>.delayed(const Duration(seconds: 4));
      }
    });

final colabFilterSucursalIdProvider = StateProvider<int?>((ref) => null);

final colabFilterDepartamentoProvider = StateProvider<String?>((ref) => null);

final colabFilterCargoProvider = StateProvider<String?>((ref) => null);

final colabFilterSearchProvider = StateProvider<String>((ref) => '');

final colabDepartamentosOptionsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final api = ref.read(relojChecadorAppApiProvider);
      return api.getDeptos();
    });

final colabCargosOptionsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String?>((ref, deptoNombre) async {
      final api = ref.read(relojChecadorAppApiProvider);
      if ((deptoNombre ?? '').trim().isEmpty) return [];
      final deptos = await ref.read(colabDepartamentosOptionsProvider.future);
      final match = deptos.cast<Map<String, dynamic>>().firstWhere(
        (d) => (d['NOMBRE'] as String? ?? '').toUpperCase() == deptoNombre!.trim().toUpperCase(),
        orElse: () => <String, dynamic>{},
      );
      final iddepto = match['IDDEPTO'] as int?;
      if (iddepto == null) return [];
      return api.getRoles(iddepto: iddepto);
    });

final colaboradorHorarioCalendarProvider = FutureProvider.autoDispose
    .family<ColaboradorHorarioCalendarModel, int>((ref, colaboradorId) async {
      final api = ref.read(relojChecadorAppApiProvider);
      return api.getColaboradorHorariosRotativos(colaboradorId);
    });

final reporteRangeProvider = StateProvider<DateTimeRange>((ref) {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, 1);
  final end = DateTime(now.year, now.month + 1, 0);
  return DateTimeRange(start: start, end: end);
});

final reporteSucursalIdProvider = StateProvider<int?>((ref) => null);

final reporteDepartamentoProvider = StateProvider<String?>((ref) => null);

final reporteDepartamentoIdProvider = StateProvider<int?>((ref) => null);

final reporteCargoProvider = StateProvider<String?>((ref) => null);

final reporteCargoIdProvider = StateProvider<int?>((ref) => null);

final reporteIdEmpleadoProvider = StateProvider<String>((ref) => '');

final reporteExpedienteEstatusProvider = StateProvider<String?>((ref) => null);

final reportePinProvider = StateProvider<String>((ref) => '');

final nominaColumnsProvider = StateProvider<List<String>>(
  (ref) => const [
    'fecha',
    'pin',
    'nombre',
    'sucursal',
    'entrada',
    'salida',
    'estatus',
  ],
);

final incidenciasRangeProvider = StateProvider<DateTimeRange>((ref) {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, 1);
  final end = DateTime(now.year, now.month + 1, 0);
  return DateTimeRange(start: start, end: end);
});

final incidenciasColaboradorProvider = StateProvider<int?>((ref) => null);

final permisosTiposProvider =
    FutureProvider.autoDispose<List<PermisoTipoModel>>((ref) async {
      final api = ref.read(relojChecadorAppApiProvider);
      return api.getPermisosTipos();
    });

final solicitudesIncidenciasProvider =
    FutureProvider.autoDispose<List<SolicitudIncidenciaModel>>((ref) async {
      final api = ref.read(relojChecadorAppApiProvider);
      final range = ref.watch(incidenciasRangeProvider);
      final colaboradorId = ref.watch(incidenciasColaboradorProvider);

      return api.getSolicitudesIncidencias(
        colaboradorId: colaboradorId,
        fechaInicio: range.start,
        fechaFin: range.end,
      );
    });

final ausenciasCalendarioProvider =
    FutureProvider.autoDispose<List<AusenciaCalendarioItem>>((ref) async {
      final api = ref.read(relojChecadorAppApiProvider);
      final range = ref.watch(incidenciasRangeProvider);
      final sucursalId = ref.watch(reporteSucursalIdProvider);

      return api.getAusenciasCalendario(
        fechaInicio: range.start,
        fechaFin: range.end,
        sucursalId: sucursalId,
      );
    });

final vacacionesDashboardProvider = FutureProvider.autoDispose
    .family<VacacionesDashboardModel, int>((ref, colaboradorId) async {
      final api = ref.read(relojChecadorAppApiProvider);
      return api.getVacacionesDashboard(colaboradorId);
    });

final asistenciaReporteQueryProvider = Provider<AsistenciaReporteQuery>((ref) {
  final range = ref.watch(reporteRangeProvider);
  final sucursalId = ref.watch(reporteSucursalIdProvider);
  final departamento = ref.watch(reporteDepartamentoProvider);
  final departamentoId = ref.watch(reporteDepartamentoIdProvider);
  final cargo = ref.watch(reporteCargoProvider);
  final cargoId = ref.watch(reporteCargoIdProvider);
  final idEmpleado = ref.watch(reporteIdEmpleadoProvider);
  final pin = ref.watch(reportePinProvider);

  return AsistenciaReporteQuery(
    fechaInicio: range.start,
    fechaFin: range.end,
    sucursalId: sucursalId,
    departamentoId: departamentoId,
    cargoId: cargoId,
    departamento: departamento,
    cargo: cargo,
    idEmpleado: idEmpleado,
    pin: pin,
  );
});

final asistenciaReporteProvider =
    FutureProvider.autoDispose<List<AsistenciaReporteRow>>((ref) async {
      final api = ref.read(relojChecadorAppApiProvider);
      final query = ref.watch(asistenciaReporteQueryProvider);

      return api.getAsistenciaReporte(query);
    });

final reporteSolicitudesProvider =
    FutureProvider.autoDispose<List<SolicitudIncidenciaModel>>((ref) async {
      final api = ref.read(relojChecadorAppApiProvider);
      final range = ref.watch(reporteRangeProvider);
      return api.getSolicitudesIncidencias(
        fechaInicio: range.start,
        fechaFin: range.end,
      );
    });
