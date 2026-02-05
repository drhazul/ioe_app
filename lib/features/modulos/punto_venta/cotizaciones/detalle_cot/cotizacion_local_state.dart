import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SyncStatus { pending, synced, error }

class CotizacionLocalItem {
  CotizacionLocalItem({
    required this.id,
    required this.idfol,
    this.upc,
    this.art,
    this.des,
    required this.ctd,
    this.pvta,
    required this.pvtat,
    this.ord,
    this.iddev,
    this.ctdd,
    this.ctddf,
    required this.updatedAt,
    this.syncStatus = SyncStatus.pending,
    this.syncError,
  });

  final String id;
  final String idfol;
  final String? upc;
  final String? art;
  final String? des;
  final double ctd;
  final double? pvta;
  final double pvtat;
  final int? ord;
  final String? iddev;
  final double? ctdd;
  final double? ctddf;
  final DateTime updatedAt;
  final SyncStatus syncStatus;
  final String? syncError;

  CotizacionLocalItem copyWith({
    String? id,
    String? idfol,
    String? upc,
    String? art,
    String? des,
    double? ctd,
    double? pvta,
    double? pvtat,
    int? ord,
    String? iddev,
    double? ctdd,
    double? ctddf,
    DateTime? updatedAt,
    SyncStatus? syncStatus,
    String? syncError,
  }) {
    return CotizacionLocalItem(
      id: id ?? this.id,
      idfol: idfol ?? this.idfol,
      upc: upc ?? this.upc,
      art: art ?? this.art,
      des: des ?? this.des,
      ctd: ctd ?? this.ctd,
      pvta: pvta ?? this.pvta,
      pvtat: pvtat ?? this.pvtat,
      ord: ord ?? this.ord,
      iddev: iddev ?? this.iddev,
      ctdd: ctdd ?? this.ctdd,
      ctddf: ctddf ?? this.ctddf,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      syncError: syncError ?? this.syncError,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'idfol': idfol,
        'upc': upc,
        'art': art,
        'des': des,
        'ctd': ctd,
        'pvta': pvta,
        'pvtat': pvtat,
        'ord': ord,
        'iddev': iddev,
        'ctdd': ctdd,
        'ctddf': ctddf,
        'updatedAt': updatedAt.toIso8601String(),
        'syncStatus': _syncStatusToString(syncStatus),
        'syncError': syncError,
      };

  static CotizacionLocalItem fromJson(Map<String, dynamic> json) {
    return CotizacionLocalItem(
      id: json['id']?.toString() ?? '',
      idfol: json['idfol']?.toString() ?? '',
      upc: json['upc']?.toString(),
      art: json['art']?.toString(),
      des: json['des']?.toString(),
      ctd: (json['ctd'] as num?)?.toDouble() ?? 0,
      pvta: (json['pvta'] as num?)?.toDouble(),
      pvtat: (json['pvtat'] as num?)?.toDouble() ?? 0,
      ord: (json['ord'] as num?)?.toInt(),
      iddev: json['iddev']?.toString(),
      ctdd: (json['ctdd'] as num?)?.toDouble(),
      ctddf: (json['ctddf'] as num?)?.toDouble(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? DateTime.now(),
      syncStatus: _syncStatusFromString(json['syncStatus']?.toString()),
      syncError: json['syncError']?.toString(),
    );
  }

  static String _syncStatusToString(SyncStatus status) {
    switch (status) {
      case SyncStatus.synced:
        return 'synced';
      case SyncStatus.error:
        return 'error';
      case SyncStatus.pending:
        return 'pending';
    }
  }

  static SyncStatus _syncStatusFromString(String? raw) {
    switch ((raw ?? '').toLowerCase()) {
      case 'synced':
        return SyncStatus.synced;
      case 'error':
        return SyncStatus.error;
      case 'pending':
      default:
        return SyncStatus.pending;
    }
  }
}

class CotizacionLocalState {
  const CotizacionLocalState({
    required this.idfol,
    required this.items,
    required this.loading,
    required this.error,
  });

  final String idfol;
  final List<CotizacionLocalItem> items;
  final bool loading;
  final String? error;

  factory CotizacionLocalState.initial(String idfol) => CotizacionLocalState(
        idfol: idfol,
        items: const [],
        loading: true,
        error: null,
      );

  CotizacionLocalState copyWith({
    String? idfol,
    List<CotizacionLocalItem>? items,
    bool? loading,
    String? error,
  }) {
    return CotizacionLocalState(
      idfol: idfol ?? this.idfol,
      items: items ?? this.items,
      loading: loading ?? this.loading,
      error: error,
    );
  }

  double get total => items.fold(0, (sum, item) => sum + item.pvtat);

  double get totalPiezas => items.fold(0, (sum, item) => sum + item.ctd);
}

class CotizacionLocalStore {
  static const _prefix = 'cot_local_items_';

  Future<List<CotizacionLocalItem>> load(String idfol) async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString('$_prefix$idfol');
    if (raw == null || raw.isEmpty) return [];
    final decoded = json.decode(raw);
    if (decoded is! List) return [];
    return decoded
        .map((e) => CotizacionLocalItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> save(String idfol, List<CotizacionLocalItem> items) async {
    final sp = await SharedPreferences.getInstance();
    final pendingOnly = items.where((e) => e.syncStatus != SyncStatus.synced).toList();
    final raw = json.encode(pendingOnly.map((e) => e.toJson()).toList());
    await sp.setString('$_prefix$idfol', raw);
  }

  Future<void> clear(String idfol) async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove('$_prefix$idfol');
  }
}

final cotizacionLocalStoreProvider = Provider<CotizacionLocalStore>((ref) => CotizacionLocalStore());

final cotizacionLocalProvider = StateNotifierProvider.family<CotizacionLocalController, CotizacionLocalState, String>(
  (ref, idfol) => CotizacionLocalController(ref.read(cotizacionLocalStoreProvider), idfol),
);

class CotizacionLocalController extends StateNotifier<CotizacionLocalState> {
  CotizacionLocalController(this._store, this._idfol) : super(CotizacionLocalState.initial(_idfol)) {
    _load();
  }

  final CotizacionLocalStore _store;
  final String _idfol;

  Future<void> _load() async {
    try {
      final items = await _store.load(_idfol);
      state = state.copyWith(items: items, loading: false, error: null);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> addItem(CotizacionLocalItem item) async {
    final next = [...state.items, item];
    state = state.copyWith(items: next, error: null);
    await _store.save(_idfol, next);
  }

  Future<void> updateItem(String id, {double? ctd, double? pvta, String? des}) async {
    final next = state.items.map((item) {
      if (item.id != id) return item;
      final nextCtd = ctd ?? item.ctd;
      final nextPvta = pvta ?? item.pvta;
      final nextTotal = nextPvta == null ? item.pvtat : nextCtd * nextPvta;
      return item.copyWith(
        ctd: nextCtd,
        pvta: nextPvta,
        pvtat: nextTotal,
        des: des ?? item.des,
        updatedAt: DateTime.now(),
      );
    }).toList();
    state = state.copyWith(items: next, error: null);
    await _store.save(_idfol, next);
  }

  Future<void> setSyncStatus(String id, SyncStatus status, {String? error}) async {
    final next = state.items.map((item) {
      if (item.id != id) return item;
      return item.copyWith(syncStatus: status, syncError: error);
    }).toList();
    state = state.copyWith(items: next, error: null);
    await _store.save(_idfol, next);
  }

  Future<void> mergeRemote(List<CotizacionLocalItem> remoteItems) async {
    final map = {for (final item in state.items) item.id: item};
    for (final remote in remoteItems) {
      map[remote.id] = remote.copyWith(syncStatus: SyncStatus.synced, syncError: null);
    }
    final merged = map.values.toList()
      ..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
    state = state.copyWith(items: merged, error: null);
    await _store.save(_idfol, merged);
  }

  Future<void> removeItem(String id) async {
    final next = state.items.where((item) => item.id != id).toList();
    state = state.copyWith(items: next, error: null);
    await _store.save(_idfol, next);
  }

  Future<void> clearAll() async {
    state = state.copyWith(items: const [], error: null);
    await _store.clear(_idfol);
  }
}
