import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ioe_app/core/dio_provider.dart';

import 'new_ord_api.dart';

final newOrdApiProvider = Provider<NewOrdApi>((ref) => NewOrdApi(ref.read(dioProvider)));
