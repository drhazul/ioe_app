import '../cotizaciones/cotizaciones_models.dart';

class ReimpresionPanelQuery {
  const ReimpresionPanelQuery({
    this.suc = '',
    this.opv = '',
    this.search = '',
    this.fcnm = '',
    this.page = 1,
    this.pageSize = 20,
  });

  final String suc;
  final String opv;
  final String search;
  final String fcnm;
  final int page;
  final int pageSize;

  bool get hasCriteria {
    return fcnm.trim().isNotEmpty ||
        search.trim().isNotEmpty ||
        opv.trim().isNotEmpty;
  }

  ReimpresionPanelQuery copyWith({
    String? suc,
    String? opv,
    String? search,
    String? fcnm,
    int? page,
    int? pageSize,
  }) {
    return ReimpresionPanelQuery(
      suc: suc ?? this.suc,
      opv: opv ?? this.opv,
      search: search ?? this.search,
      fcnm: fcnm ?? this.fcnm,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ReimpresionPanelQuery &&
        other.suc == suc &&
        other.opv == opv &&
        other.search == search &&
        other.fcnm == fcnm &&
        other.page == page &&
        other.pageSize == pageSize;
  }

  @override
  int get hashCode => Object.hash(suc, opv, search, fcnm, page, pageSize);
}

class ReimpresionAuthorizationSession {
  const ReimpresionAuthorizationSession({
    required this.authorizationToken,
    required this.supervisorUserId,
  });

  final String authorizationToken;
  final String supervisorUserId;

  factory ReimpresionAuthorizationSession.fromJson(Map<String, dynamic> json) {
    return ReimpresionAuthorizationSession(
      authorizationToken: (json['authorizationToken'] ?? '').toString().trim(),
      supervisorUserId: (json['supervisorUserId'] ?? '').toString().trim(),
    );
  }
}

class ReimpresionPageResult {
  const ReimpresionPageResult({
    required this.data,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  final List<PvCtrFolAsvrModel> data;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;

  factory ReimpresionPageResult.empty({
    required int page,
    required int pageSize,
  }) {
    return ReimpresionPageResult(
      data: const [],
      total: 0,
      page: page,
      pageSize: pageSize,
      totalPages: 0,
    );
  }
}
