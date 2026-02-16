import 'package:dio/dio.dart';

import '../domain/cat_cta.dart';
import '../domain/cat_ctas_repo.dart';
import 'cat_ctas_dto.dart';

class CatCtasRemoteRepo implements CatCtasRepo {
  final Dio dio;

  CatCtasRemoteRepo(this.dio);

  @override
  Future<CatCtasPage> list(CatCtasQuery query) async {
    final res = await dio.get(
      '/cat-ctas',
      queryParameters: query.toQueryParams(),
    );
    return CatCtasPageDto.fromResponse(res.data, query: query).toDomain();
  }

  @override
  Future<CatCta> getById(String cta) async {
    final res = await dio.get('/cat-ctas/${Uri.encodeComponent(cta)}');
    final dto = CatCtaDto.fromJson(Map<String, dynamic>.from(res.data as Map));
    return dto.toDomain();
  }

  @override
  Future<CatCta> create(CatCta model) async {
    final dto = CatCtaDto.fromDomain(model);
    final res = await dio.post('/cat-ctas', data: dto.toPayload(includeCta: true));
    return CatCtaDto.fromJson(Map<String, dynamic>.from(res.data as Map)).toDomain();
  }

  @override
  Future<CatCta> update(String cta, CatCta model) async {
    final dto = CatCtaDto.fromDomain(model);
    final res = await dio.put(
      '/cat-ctas/${Uri.encodeComponent(cta)}',
      data: dto.toPayload(includeCta: false),
    );
    return CatCtaDto.fromJson(Map<String, dynamic>.from(res.data as Map)).toDomain();
  }

  @override
  Future<void> delete(String cta) async {
    await dio.delete('/cat-ctas/${Uri.encodeComponent(cta)}');
  }
}
