import '../domain/merma_models.dart';
import 'merma_api.dart';

class MermaRepository {
  MermaRepository(this.api);

  final MermaApi api;

  Future<List<MermaGestionCabeceraModel>> fetchGestionCabecerasAbiertas({
    String? suc,
  }) {
    return api.fetchGestionCabecerasAbiertas(suc: suc);
  }

  Future<MermaPagedResult<MermaDocModel>> fetchGestion({
    int page = 1,
    int limit = 30,
    String? search,
    String? estatus,
    String? from,
    String? to,
  }) {
    return api.fetchMermas(
      consulta: false,
      page: page,
      limit: limit,
      search: search,
      estatus: estatus,
      from: from,
      to: to,
    );
  }

  Future<MermaPagedResult<MermaDocModel>> fetchConsulta({
    int page = 1,
    int limit = 30,
    String? docmer,
    String? usuario,
    String? suc,
    String? estatus,
    String? from,
    String? to,
  }) {
    return api.fetchMermas(
      consulta: true,
      page: page,
      limit: limit,
      docmer: docmer,
      usuario: usuario,
      suc: suc,
      estatus: estatus,
      from: from,
      to: to,
    );
  }
}
