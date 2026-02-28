import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ioe_app/core/dio_provider.dart';

import 'reloj_checador_consultas_api.dart';

final relojChecadorConsultasApiProvider = Provider<RelojChecadorConsultasApi>(
  (ref) => RelojChecadorConsultasApi(ref.read(dioProvider)),
);

final relojChecadorConsultasReloadProvider = StateProvider<int>((ref) => 0);

final relojChecadorCanManageOverridesProvider =
    FutureProvider.autoDispose<bool>((ref) async {
      final api = ref.read(relojChecadorConsultasApiProvider);
      return api.canManageOverrides();
    });
