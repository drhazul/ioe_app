import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ioe_app/core/dio_provider.dart';

import 'datart_api.dart';
import 'datart_models.dart';

class DatArtQuery {
  const DatArtQuery({
    required this.suc,
    required this.by,
    required this.term,
    this.depa,
    this.subd,
    this.clas,
    this.scla,
    this.scla2,
    this.sph,
    this.cyl,
    this.adic,
  });

  final String suc;
  final String by;
  final String term;
  final double? depa;
  final double? subd;
  final double? clas;
  final double? scla;
  final double? scla2;
  final double? sph;
  final double? cyl;
  final double? adic;

  @override
  bool operator ==(Object other) {
    return other is DatArtQuery &&
        other.suc == suc &&
        other.by == by &&
        other.term == term &&
        other.depa == depa &&
        other.subd == subd &&
        other.clas == clas &&
        other.scla == scla &&
        other.scla2 == scla2 &&
        other.sph == sph &&
        other.cyl == cyl &&
        other.adic == adic;
  }

  @override
  int get hashCode => Object.hash(
        suc,
        by,
        term,
        depa,
        subd,
        clas,
        scla,
        scla2,
        sph,
        cyl,
        adic,
      );
}

final datArtApiProvider = Provider<DatArtApi>((ref) => DatArtApi(ref.read(dioProvider)));
const int _datArtLimit = 200;

final datArtListProvider = FutureProvider.autoDispose.family<List<DatArtModel>, DatArtQuery>((ref, query) async {
  final suc = query.suc.trim();
  if (suc.isEmpty) return [];
  final term = query.term.trim();
  final api = ref.read(datArtApiProvider);
  final hasFilters = term.isNotEmpty ||
      query.depa != null ||
      query.subd != null ||
      query.clas != null ||
      query.scla != null ||
      query.scla2 != null ||
      query.sph != null ||
      query.cyl != null ||
      query.adic != null;
  if (!hasFilters) return [];
  switch (query.by) {
    case 'ART':
      return api.fetchArticulos(
        suc: suc,
        art: term.isEmpty ? null : term,
        depa: query.depa,
        subd: query.subd,
        clas: query.clas,
        scla: query.scla,
        scla2: query.scla2,
        sph: query.sph,
        cyl: query.cyl,
        adic: query.adic,
        limit: _datArtLimit,
        view: 'lite',
      );
    case 'MODELO':
      return api.fetchArticulos(
        suc: suc,
        modelo: term.isEmpty ? null : term,
        depa: query.depa,
        subd: query.subd,
        clas: query.clas,
        scla: query.scla,
        scla2: query.scla2,
        sph: query.sph,
        cyl: query.cyl,
        adic: query.adic,
        limit: _datArtLimit,
        view: 'lite',
      );
    case 'DES':
      return api.fetchArticulos(
        suc: suc,
        des: term.isEmpty ? null : term,
        depa: query.depa,
        subd: query.subd,
        clas: query.clas,
        scla: query.scla,
        scla2: query.scla2,
        sph: query.sph,
        cyl: query.cyl,
        adic: query.adic,
        limit: _datArtLimit,
        view: 'lite',
      );
    default:
      return api.fetchArticulos(
        suc: suc,
        upc: term.isEmpty ? null : term,
        depa: query.depa,
        subd: query.subd,
        clas: query.clas,
        scla: query.scla,
        scla2: query.scla2,
        sph: query.sph,
        cyl: query.cyl,
        adic: query.adic,
        limit: _datArtLimit,
        view: 'lite',
      );
  }
});
