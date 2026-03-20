import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ioe_app/core/dio_provider.dart';

import 'reimpresion_api.dart';
import 'reimpresion_models.dart';

final reimpresionApiProvider = Provider<ReimpresionApi>(
  (ref) => ReimpresionApi(ref.read(dioProvider)),
);

final reimpresionPanelQueryProvider =
    StateProvider.autoDispose<ReimpresionPanelQuery>(
  (ref) => const ReimpresionPanelQuery(),
);

final reimpresionAuthSessionProvider =
    StateProvider.autoDispose<ReimpresionAuthorizationSession?>(
  (ref) => null,
);

final reimpresionListProvider =
    FutureProvider.autoDispose<ReimpresionPageResult>((ref) async {
      final api = ref.read(reimpresionApiProvider);
      final authSession = ref.watch(reimpresionAuthSessionProvider);
      final query = ref.watch(reimpresionPanelQueryProvider);
      if (authSession == null) {
        return ReimpresionPageResult.empty(
          page: query.page,
          pageSize: query.pageSize,
        );
      }
      if (!query.hasCriteria) {
        return ReimpresionPageResult.empty(
          page: query.page,
          pageSize: query.pageSize,
        );
      }
      return api.fetchReimpresiones(
        suc: query.suc,
        opv: query.opv,
        search: query.search,
        fcnm: query.fcnm,
        page: query.page,
        pageSize: query.pageSize,
      );
    });
