import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ioe_app/core/dio_provider.dart';

import 'cfdi_correo_api.dart';

final cfdiCorreoApiProvider = Provider<CfdiCorreoApi>(
  (ref) => CfdiCorreoApi(ref.read(dioProvider)),
);

final cfdiCorreoConfigProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>(
      (ref) => ref.read(cfdiCorreoApiProvider).configuracion(),
    );

final cfdiCorreoEnviosProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>(
      (ref) => ref.read(cfdiCorreoApiProvider).envios(),
    );
