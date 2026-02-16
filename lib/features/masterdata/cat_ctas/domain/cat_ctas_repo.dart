import 'cat_cta.dart';

abstract class CatCtasRepo {
  Future<CatCtasPage> list(CatCtasQuery query);

  Future<CatCta> getById(String cta);

  Future<CatCta> create(CatCta model);

  Future<CatCta> update(String cta, CatCta model);

  Future<void> delete(String cta);
}
