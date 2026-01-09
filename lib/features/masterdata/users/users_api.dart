import 'package:dio/dio.dart';

import 'users_models.dart';

class UsersApi {
  final Dio dio;
  UsersApi(this.dio);

  Future<List<UserModel>> fetchUsers() async {
    // cache-buster to avoid stale 304 responses on web
    final res = await dio.get('/users', queryParameters: {'_': DateTime.now().millisecondsSinceEpoch});
    final list = (res.data as List<dynamic>).map((e) => UserModel.fromJson(Map<String, dynamic>.from(e))).toList();
    return list;
  }

  Future<UserModel> fetchUser(int id) async {
    // cache-buster to avoid stale 304 responses on web
    final res = await dio.get('/users/$id', queryParameters: {'_': DateTime.now().millisecondsSinceEpoch});
    return UserModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<UserModel> createUser(Map<String, dynamic> payload) async {
    final body = _clean(payload);
    final res = await dio.post('/users', data: body);
    return UserModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<UserModel> updateUser(int id, Map<String, dynamic> payload) async {
    final body = _clean(payload);
    final res = await dio.patch('/users/$id', data: body);
    return UserModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<void> deleteUser(int id) async {
    await dio.delete('/users/$id');
  }

  Map<String, dynamic> _clean(Map<String, dynamic> payload) {
    return Map<String, dynamic>.from(payload);
  }
}
