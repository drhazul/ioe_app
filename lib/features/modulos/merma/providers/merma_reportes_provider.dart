import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'merma_provider.dart';

final mermaReporteMensualProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, Map<String, dynamic>>((ref, query) async {
      final api = ref.read(mermaApiProvider);
      return api.reporte('mensual', query: query);
    });

final mermaReporteSucursalProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, Map<String, dynamic>>((ref, query) async {
      final api = ref.read(mermaApiProvider);
      return api.reporte('sucursal', query: query);
    });

final mermaReporteTallerProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, Map<String, dynamic>>((ref, query) async {
      final api = ref.read(mermaApiProvider);
      return api.reporte('taller', query: query);
    });

final mermaReporteProductoProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, Map<String, dynamic>>((ref, query) async {
      final api = ref.read(mermaApiProvider);
      return api.reporte('producto', query: query);
    });

final mermaReporteMotivosProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, Map<String, dynamic>>((ref, query) async {
      final api = ref.read(mermaApiProvider);
      return api.reporte('motivos', query: query);
    });

final mermaReporteComparativoProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, Map<String, dynamic>>((ref, query) async {
      final api = ref.read(mermaApiProvider);
      return api.reporte('comparativo', query: query);
    });

final mermaReporteAnualProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, Map<String, dynamic>>((ref, query) async {
      final api = ref.read(mermaApiProvider);
      return api.reporte('anual', query: query);
    });
