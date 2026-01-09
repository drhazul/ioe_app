import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ioe_app/core/dio_provider.dart';

import 'roles_api.dart';
import 'roles_models.dart';

final rolesApiProvider = Provider<RolesApi>((ref) => RolesApi(ref.read(dioProvider)));

final rolesListProvider = FutureProvider.autoDispose<List<RoleModel>>((ref) async {
  final api = ref.read(rolesApiProvider);
  return api.fetchRoles();
});

final roleProvider = FutureProvider.autoDispose.family<RoleModel, int>((ref, id) async {
  final api = ref.read(rolesApiProvider);
  return api.fetchRole(id);
});
