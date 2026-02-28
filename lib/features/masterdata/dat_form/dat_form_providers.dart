import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ioe_app/core/dio_provider.dart';

import 'dat_form_api.dart';
import 'dat_form_models.dart';

final datFormApiProvider = Provider<DatFormApi>(
  (ref) => DatFormApi(ref.read(dioProvider)),
);

final datFormListProvider = FutureProvider.autoDispose<List<DatFormModel>>((
  ref,
) async {
  final api = ref.read(datFormApiProvider);
  return api.fetchDatForms(includeInactive: true);
});

final datFormProvider = FutureProvider.autoDispose.family<DatFormModel, int>((
  ref,
  idform,
) async {
  final api = ref.read(datFormApiProvider);
  return api.fetchDatForm(idform);
});
