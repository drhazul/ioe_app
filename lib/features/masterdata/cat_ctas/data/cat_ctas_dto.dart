import '../domain/cat_cta.dart';

class CatCtaDto {
  final String cta;
  final String? dcta;
  final String? relacion;
  final String? suc;

  const CatCtaDto({
    required this.cta,
    this.dcta,
    this.relacion,
    this.suc,
  });

  factory CatCtaDto.fromJson(Map<String, dynamic> json) {
    return CatCtaDto(
      cta: _asString(json['CTA']) ?? '',
      dcta: _asString(json['DCTA']),
      relacion: _asString(json['RELACION']),
      suc: _asString(json['SUC']),
    );
  }

  CatCta toDomain() {
    return CatCta(
      cta: cta,
      dcta: dcta,
      relacion: relacion,
      suc: suc,
    );
  }

  static CatCtaDto fromDomain(CatCta model) {
    return CatCtaDto(
      cta: model.cta,
      dcta: model.dcta,
      relacion: model.relacion,
      suc: model.suc,
    );
  }

  Map<String, dynamic> toPayload({bool includeCta = true}) {
    final payload = <String, dynamic>{};
    if (includeCta) payload['CTA'] = cta;
    if (dcta != null) payload['DCTA'] = dcta;
    if (relacion != null) payload['RELACION'] = relacion;
    if (suc != null) payload['SUC'] = suc;
    return payload;
  }
}

class CatCtasPageDto {
  final List<CatCtaDto> items;
  final int total;
  final int page;
  final int limit;

  const CatCtasPageDto({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
  });

  factory CatCtasPageDto.fromResponse(dynamic data, {required CatCtasQuery query}) {
    if (data is List) {
      final list = data
          .map((raw) => CatCtaDto.fromJson(Map<String, dynamic>.from(raw as Map)))
          .toList();
      return CatCtasPageDto(
        items: list,
        total: list.length,
        page: query.page,
        limit: query.limit,
      );
    }

    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      final rawItems = map['items'];
      final list = rawItems is List
          ? rawItems
              .map((raw) => CatCtaDto.fromJson(Map<String, dynamic>.from(raw as Map)))
              .toList()
          : <CatCtaDto>[];
      return CatCtasPageDto(
        items: list,
        total: _asInt(map['total']) ?? list.length,
        page: _asInt(map['page']) ?? query.page,
        limit: _asInt(map['limit']) ?? query.limit,
      );
    }

    return CatCtasPageDto(
      items: const [],
      total: 0,
      page: query.page,
      limit: query.limit,
    );
  }

  CatCtasPage toDomain() {
    return CatCtasPage(
      items: items.map((item) => item.toDomain()).toList(),
      total: total,
      page: page,
      limit: limit,
    );
  }
}

String? _asString(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}
