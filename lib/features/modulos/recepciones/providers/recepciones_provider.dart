import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/dio_provider.dart';
import '../data/recepciones_api.dart';

final recepcionesApiProvider = Provider<RecepcionesApi>((ref) {
  return RecepcionesApi(ref.read(dioProvider));
});
