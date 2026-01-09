import 'package:dio/dio.dart';

import 'home_models.dart';

class HomeApi {
  final Dio dio;
  HomeApi(this.dio);

  Future<HomeModulesResponse> fetchHomeModules() async {
    final res = await dio.get(
      '/access/me/front-menu',
      queryParameters: {'_': DateTime.now().millisecondsSinceEpoch},
    );
    final data = Map<String, dynamic>.from(res.data as Map);
    final list = (data['data'] as List<dynamic>);
    return HomeModulesResponse.fromMenu(list);
  }
}
