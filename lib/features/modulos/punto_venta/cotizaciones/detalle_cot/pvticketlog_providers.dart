import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ioe_app/core/dio_provider.dart';

import 'pvticketlog_api.dart';
import 'pvticketlog_models.dart';

final pvTicketLogApiProvider = Provider<PvTicketLogApi>((ref) => PvTicketLogApi(ref.read(dioProvider)));

final pvTicketLogListProvider = FutureProvider.autoDispose.family<List<PvTicketLogItem>, String>((ref, idfol) async {
  final trimmed = idfol.trim();
  if (trimmed.isEmpty) return [];
  final api = ref.read(pvTicketLogApiProvider);
  return api.fetchByIdfol(trimmed);
});
