import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ioe_app/core/dio_provider.dart';

import 'retiros_api.dart';
import 'retiros_models.dart';

final retirosApiProvider = Provider<RetirosApi>(
  (ref) => RetirosApi(ref.read(dioProvider)),
);

final retirosTodayProvider =
    FutureProvider.autoDispose<List<RetiroPanelItem>>((ref) async {
      final api = ref.read(retirosApiProvider);
      return api.fetchToday();
    });

final retiroDetailProvider =
    FutureProvider.autoDispose.family<RetiroDetailResponse, String>((
      ref,
      idret,
    ) async {
      final api = ref.read(retirosApiProvider);
      return api.fetchRetiro(idret.trim());
    });

final retirosFormasCatalogProvider =
    FutureProvider.autoDispose<List<RetiroFormaCatalogItem>>((ref) async {
      final api = ref.read(retirosApiProvider);
      return api.fetchFormasCatalog();
    });

