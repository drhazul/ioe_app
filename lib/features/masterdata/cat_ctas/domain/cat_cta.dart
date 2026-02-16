class CatCta {
  final String cta;
  final String? dcta;
  final String? relacion;
  final String? suc;

  const CatCta({
    required this.cta,
    this.dcta,
    this.relacion,
    this.suc,
  });

  Map<String, dynamic> toPayload() {
    final payload = <String, dynamic>{'CTA': cta};
    if (dcta != null) payload['DCTA'] = dcta;
    if (relacion != null) payload['RELACION'] = relacion;
    if (suc != null) payload['SUC'] = suc;
    return payload;
  }
}

class CatCtasPage {
  final List<CatCta> items;
  final int total;
  final int page;
  final int limit;

  const CatCtasPage({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
  });
}

class CatCtasQuery {
  final String? search;
  final String? suc;
  final int page;
  final int limit;

  const CatCtasQuery({
    this.search,
    this.suc,
    this.page = 1,
    this.limit = 50,
  });

  CatCtasQuery copyWith({
    String? search,
    String? suc,
    int? page,
    int? limit,
  }) {
    return CatCtasQuery(
      search: search ?? this.search,
      suc: suc ?? this.suc,
      page: page ?? this.page,
      limit: limit ?? this.limit,
    );
  }

  Map<String, dynamic> toQueryParams() {
    final params = <String, dynamic>{
      'page': page,
      'limit': limit,
    };
    final searchValue = (search ?? '').trim();
    final sucValue = (suc ?? '').trim();
    if (searchValue.isNotEmpty) params['search'] = searchValue;
    if (sucValue.isNotEmpty) params['suc'] = sucValue;
    return params;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CatCtasQuery &&
        other.search == search &&
        other.suc == suc &&
        other.page == page &&
        other.limit == limit;
  }

  @override
  int get hashCode => Object.hash(search, suc, page, limit);
}
