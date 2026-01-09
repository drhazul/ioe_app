import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ioe_app/core/dio_provider.dart';

import 'users_api.dart';
import 'users_models.dart';

final usersApiProvider = Provider<UsersApi>((ref) => UsersApi(ref.read(dioProvider)));

final usersListProvider = FutureProvider.autoDispose<List<UserModel>>((ref) async {
  final api = ref.read(usersApiProvider);
  return api.fetchUsers();
});

final userProvider = FutureProvider.autoDispose.family<UserModel, int>((ref, id) async {
  final api = ref.read(usersApiProvider);
  return api.fetchUser(id);
});
