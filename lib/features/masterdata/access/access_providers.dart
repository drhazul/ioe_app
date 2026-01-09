import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ioe_app/core/dio_provider.dart';

import 'access_api.dart';
import 'access_models.dart';

final accessApiProvider = Provider<AccessApi>((ref) => AccessApi(ref.read(dioProvider)));

final backendModulosProvider = FutureProvider.autoDispose<List<AccessModulo>>((ref) async {
  final api = ref.read(accessApiProvider);
  return api.fetchBackendModulos(includeInactives: true);
});

final backendGruposProvider = FutureProvider.autoDispose<List<AccessGrupoModulo>>((ref) async {
  final api = ref.read(accessApiProvider);
  return api.fetchBackendGrupos(includeInactives: true);
});

final backendGroupModulesProvider = FutureProvider.autoDispose.family<List<BackendModuloRef>, int>((ref, id) async {
  final api = ref.read(accessApiProvider);
  return api.fetchBackendGroupModules(id);
});

final accessRolesProvider = FutureProvider.autoDispose<List<AccessRole>>((ref) async {
  final api = ref.read(accessApiProvider);
  return api.fetchRoles(includeInactives: true);
});

final backendPermsProvider = FutureProvider.autoDispose.family<List<BackendGroupPerm>, int>((ref, roleId) async {
  final api = ref.read(accessApiProvider);
  return api.fetchBackendPerms(roleId);
});

final frontModulosProvider = FutureProvider.autoDispose<List<AccessModuloFront>>((ref) async {
  final api = ref.read(accessApiProvider);
  return api.fetchFrontModulos(includeInactives: true);
});

final frontGruposProvider = FutureProvider.autoDispose<List<AccessGrupoFront>>((ref) async {
  final api = ref.read(accessApiProvider);
  return api.fetchFrontGrupos(includeInactives: true);
});

final frontGroupModulesProvider = FutureProvider.autoDispose.family<List<FrontModuloRef>, int>((ref, id) async {
  final api = ref.read(accessApiProvider);
  return api.fetchFrontGroupModules(id);
});

final frontEnrollmentsProvider = FutureProvider.autoDispose.family<List<FrontGroupEnrollment>, int>((ref, roleId) async {
  final api = ref.read(accessApiProvider);
  return api.fetchFrontEnrollments(roleId);
});
