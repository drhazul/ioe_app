import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ioe_app/core/dio_provider.dart';

import '../data/cat_ctas_remote_ds.dart';
import '../domain/cat_cta.dart';
import '../domain/cat_ctas_repo.dart';

final catCtasRepoProvider = Provider<CatCtasRepo>((ref) {
  return CatCtasRemoteRepo(ref.read(dioProvider));
});

final catCtasQueryProvider = StateProvider<CatCtasQuery>((ref) {
  return const CatCtasQuery();
});

final catCtasListProvider = FutureProvider.autoDispose<CatCtasPage>((ref) async {
  final repo = ref.read(catCtasRepoProvider);
  final query = ref.watch(catCtasQueryProvider);
  return repo.list(query);
});

final catCtaProvider = FutureProvider.autoDispose.family<CatCta, String>((ref, cta) async {
  final repo = ref.read(catCtasRepoProvider);
  return repo.getById(cta);
});
