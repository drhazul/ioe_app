import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ioe_app/core/dio_provider.dart';

import 'reloj_checador_app_api.dart';
import 'reloj_checador_app_models.dart';

final relojChecadorAppApiProvider = Provider<RelojChecadorAppApi>(
  (ref) => RelojChecadorAppApi(ref.read(dioProvider)),
);

final relojChecadorContextProvider = FutureProvider.autoDispose
    .family<RelojChecadorContext, String?>((ref, suc) async {
      final api = ref.read(relojChecadorAppApiProvider);
      return api.getContext(suc: suc);
    });
