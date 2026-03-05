import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ioe_app/core/dio_provider.dart';

import 'estado_cajon_api.dart';
import 'estado_cajon_models.dart';

final estadoCajonApiProvider = Provider<EstadoCajonApi>(
  (ref) => EstadoCajonApi(ref.read(dioProvider)),
);

class EstadoCajonAuthSessionNotifier
    extends StateNotifier<EstadoCajonAuthorizationSession?> {
  EstadoCajonAuthSessionNotifier() : super(null);

  void setSession(EstadoCajonAuthorizationSession session) {
    state = session;
  }

  void clear() {
    state = null;
  }
}

final estadoCajonAuthSessionProvider = StateNotifierProvider<
    EstadoCajonAuthSessionNotifier, EstadoCajonAuthorizationSession?>(
  (ref) => EstadoCajonAuthSessionNotifier(),
);

final estadoCajonFechaProvider = StateProvider<DateTime>(
  (ref) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  },
);

final estadoCajonResumenProvider =
    FutureProvider.autoDispose<List<EstadoCajonResumenRow>>((ref) async {
      final session = ref.watch(estadoCajonAuthSessionProvider);
      if (session == null) {
        throw StateError('Se requiere autorización de supervisor.');
      }

      final fecha = ref.watch(estadoCajonFechaProvider);
      final api = ref.read(estadoCajonApiProvider);
      return api.fetchResumen(
        fecha: fecha,
        authorizationToken: session.authorizationToken,
      );
    });
