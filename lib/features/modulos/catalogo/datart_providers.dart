import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ioe_app/core/dio_provider.dart';

import 'datart_api.dart';

final datArtApiProvider = Provider<DatArtApi>(
  (ref) => DatArtApi(ref.read(dioProvider)),
);
