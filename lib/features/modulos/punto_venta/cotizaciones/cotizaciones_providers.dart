import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ioe_app/core/dio_provider.dart';

import 'cotizaciones_api.dart';
import 'cotizaciones_models.dart';

final cotizacionesApiProvider = Provider<CotizacionesApi>((ref) => CotizacionesApi(ref.read(dioProvider)));

final cotizacionesListProvider = FutureProvider.autoDispose<List<PvCtrFolAsvrModel>>((ref) async {
  final api = ref.read(cotizacionesApiProvider);
  return api.fetchCotizaciones();
});

final cotizacionProvider = FutureProvider.autoDispose.family<PvCtrFolAsvrModel, String>((ref, idfol) async {
  final api = ref.read(cotizacionesApiProvider);
  return api.fetchCotizacion(idfol);
});
