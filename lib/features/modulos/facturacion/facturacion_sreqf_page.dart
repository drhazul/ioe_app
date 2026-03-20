import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ioe_app/core/dio_provider.dart';
import 'package:ioe_app/features/masterdata/sucursales/sucursales_providers.dart';
import 'package:ioe_app/features/modulos/punto_venta/cotizaciones/cotizaciones_models.dart';

class FacturacionSreqfPageData {
  const FacturacionSreqfPageData({
    this.data = const [],
    this.total = 0,
    this.page = 1,
    this.pageSize = 20,
    this.totalPages = 0,
    this.hasPrevPage = false,
    this.hasNextPage = false,
  });

  final List<PvCtrFolAsvrModel> data;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;
  final bool hasPrevPage;
  final bool hasNextPage;

  factory FacturacionSreqfPageData.empty({
    int page = 1,
    int pageSize = 20,
  }) {
    return FacturacionSreqfPageData(
      data: const [],
      total: 0,
      page: page,
      pageSize: pageSize,
      totalPages: 0,
      hasPrevPage: false,
      hasNextPage: false,
    );
  }
}

class FacturacionSreqfQuery {
  const FacturacionSreqfQuery({
    this.suc = '',
    this.fcnm = '',
    this.search = '',
    this.page = 1,
  });

  final String suc;
  final String fcnm;
  final String search;
  final int page;

  bool get hasCriteria =>
      fcnm.trim().isNotEmpty || search.trim().isNotEmpty;

  FacturacionSreqfQuery copyWith({
    String? suc,
    String? fcnm,
    String? search,
    int? page,
  }) {
    return FacturacionSreqfQuery(
      suc: suc ?? this.suc,
      fcnm: fcnm ?? this.fcnm,
      search: search ?? this.search,
      page: page ?? this.page,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is FacturacionSreqfQuery &&
        other.suc == suc &&
        other.fcnm == fcnm &&
        other.search == search &&
        other.page == page;
  }

  @override
  int get hashCode => Object.hash(suc, fcnm, search, page);
}

class FacturacionSreqfApi {
  FacturacionSreqfApi(this.dio);

  final Dio dio;

  Future<FacturacionSreqfPageData> fetchFoliosReqf({
    String? suc,
    String? fcnm,
    String? search,
    int page = 1,
  }) async {
    final normalizedSuc = (suc ?? '').trim().toUpperCase();
    final normalizedFcnm = (fcnm ?? '').trim().toUpperCase();
    final normalizedSearch = (search ?? '').trim().toUpperCase();
    final normalizedPage = page < 1 ? 1 : page;

    final query = <String, dynamic>{
      if (normalizedSuc.isNotEmpty) 'suc': normalizedSuc,
      if (normalizedFcnm.isNotEmpty) 'fcnm': normalizedFcnm,
      if (normalizedSearch.isNotEmpty) 'search': normalizedSearch,
      if (normalizedPage > 1) 'page': normalizedPage,
    };

    final res = await dio.get(
      '/facturacion/reqf/folios',
      queryParameters: query,
    );

    final raw = res.data;
    final List rows;
    if (raw is Map) {
      rows = (raw['data'] as List?) ?? (raw['items'] as List?) ?? const [];
    } else if (raw is List) {
      rows = raw;
    } else {
      rows = const [];
    }

    final parsed = rows
        .map(
          (row) => PvCtrFolAsvrModel.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();

    if (raw is! Map) {
      final total = parsed.length;
      return FacturacionSreqfPageData(
        data: parsed,
        total: total,
        page: 1,
        pageSize: total == 0 ? 20 : total,
        totalPages: total == 0 ? 0 : 1,
        hasPrevPage: false,
        hasNextPage: false,
      );
    }

    final total = _asInt(raw['total']) ?? parsed.length;
    final responsePage = _asInt(raw['page']) ?? normalizedPage;
    final pageSize = _asInt(raw['pageSize']) ?? 20;
    final totalPages =
        _asInt(raw['totalPages']) ??
        (total == 0 || pageSize <= 0 ? 0 : (total / pageSize).ceil());
    final hasPrevPage =
        _asBool(raw['hasPrevPage']) ?? (responsePage > 1 && totalPages > 0);
    final hasNextPage = _asBool(raw['hasNextPage']) ??
        (totalPages > 0 && responsePage < totalPages);

    return FacturacionSreqfPageData(
      data: parsed,
      total: total,
      page: responsePage,
      pageSize: pageSize,
      totalPages: totalPages,
      hasPrevPage: hasPrevPage,
      hasNextPage: hasNextPage,
    );
  }

  Future<String> markReqf(String idFol) async {
    final normalizedIdFol = idFol.trim();
    if (normalizedIdFol.isEmpty) {
      throw ArgumentError('IDFOL es requerido');
    }

    final res = await dio.post(
      '/facturacion/reqf/folios/${Uri.encodeComponent(normalizedIdFol)}/marcar',
    );

    final raw = res.data;
    if (raw is Map) {
      final message = (raw['message'] ?? raw['mensaje'] ?? '').toString().trim();
      if (message.isNotEmpty) return message;
    }
    return 'REQF marcado correctamente';
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  bool? _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final raw = (value ?? '').toString().trim().toLowerCase();
    if (raw == 'true' || raw == '1') return true;
    if (raw == 'false' || raw == '0') return false;
    return null;
  }
}

final facturacionSreqfApiProvider = Provider<FacturacionSreqfApi>(
  (ref) => FacturacionSreqfApi(ref.read(dioProvider)),
);

final facturacionSreqfPanelQueryProvider =
    StateProvider<FacturacionSreqfQuery>(
  (ref) => const FacturacionSreqfQuery(),
);

final facturacionSreqfListProvider =
    FutureProvider.autoDispose<FacturacionSreqfPageData>((ref) async {
  final api = ref.read(facturacionSreqfApiProvider);
  final query = ref.watch(facturacionSreqfPanelQueryProvider);
  if (!query.hasCriteria) {
    return FacturacionSreqfPageData.empty(page: query.page);
  }
  return api.fetchFoliosReqf(
    suc: query.suc,
    fcnm: query.fcnm,
    search: query.search,
    page: query.page,
  );
});

class FacturacionSREQFPage extends ConsumerStatefulWidget {
  const FacturacionSREQFPage({super.key});

  @override
  ConsumerState<FacturacionSREQFPage> createState() =>
      _FacturacionSREQFPageState();
}

class _FacturacionSREQFPageState extends ConsumerState<FacturacionSREQFPage> {
  final _searchCtrl = TextEditingController();
  final _fcnmCtrl = TextEditingController();
  final _sucCtrl = TextEditingController();

  PvCtrFolAsvrModel? _selected;
  bool _contextReady = false;
  bool _markingReqf = false;
  FacturacionSreqfQuery _query = const FacturacionSreqfQuery();

  @override
  void initState() {
    super.initState();
    _loadUserContext();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _fcnmCtrl.dispose();
    _sucCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_contextReady) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final foliosAsync = ref.watch(facturacionSreqfListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Procesamiento de folios REQF'),
        actions: [
          IconButton(
            onPressed: () {
              if (!_query.hasCriteria) return;
              ref.invalidate(facturacionSreqfListProvider);
            },
            icon: const Icon(Icons.refresh),
            tooltip: 'Refrescar',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF6F2EB), Color(0xFFEFE7DB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: foliosAsync.when(
          data: (pageData) => RefreshIndicator(
            onRefresh: () async {
              if (!_query.hasCriteria) return;
              ref.invalidate(facturacionSreqfListProvider);
              await ref.read(facturacionSreqfListProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _TopFilters(
                  sucCtrl: _sucCtrl,
                  fcnmCtrl: _fcnmCtrl,
                  searchCtrl: _searchCtrl,
                  onMarkReqf: _markSelectedReqf,
                  canMarkReqf: _canMarkReqf,
                  markReqfLoading: _markingReqf,
                  onSucChanged: (value) =>
                      setState(() => _sucCtrl.text = value?.trim() ?? ''),
                  onPickFcnmDate: _pickFcnmDate,
                  onSearch: _applyFilters,
                  onClear: _clearFilters,
                ),
                const SizedBox(height: 12),
                if (!_query.hasCriteria) const _EmptyCriteriaHint(),
                _FoliosReqfTable(
                  folios: pageData.data,
                  selected: _selected,
                  onSelect: (folio) {
                    setState(() => _selected = folio);
                  },
                ),
                const SizedBox(height: 10),
                _PaginationBar(
                  enabled: _query.hasCriteria,
                  page: pageData.page,
                  pageSize: pageData.pageSize,
                  total: pageData.total,
                  totalPages: pageData.totalPages,
                  onPrev: pageData.hasPrevPage
                      ? () => _goToPage(pageData.page - 1)
                      : null,
                  onNext: pageData.hasNextPage
                      ? () => _goToPage(pageData.page + 1)
                      : null,
                ),
              ],
            ),
          ),
          error: (e, _) => Center(child: Text('Error: $e')),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }

  void _applyFilters() {
    final next = FacturacionSreqfQuery(
      suc: _sucCtrl.text.trim(),
      fcnm: _fcnmCtrl.text.trim(),
      search: _searchCtrl.text.trim(),
      page: 1,
    );
    setState(() {
      _selected = null;
      _query = next;
    });
    ref.read(facturacionSreqfPanelQueryProvider.notifier).state = next;
  }

  void _clearFilters() {
    setState(() {
      _searchCtrl.clear();
      _fcnmCtrl.clear();
      _sucCtrl.clear();
      _selected = null;
      _query = const FacturacionSreqfQuery();
    });
    ref.read(facturacionSreqfPanelQueryProvider.notifier).state = _query;
  }

  void _goToPage(int nextPage) {
    if (!_query.hasCriteria) return;
    if (nextPage < 1 || nextPage == _query.page) return;

    final next = _query.copyWith(page: nextPage);
    setState(() {
      _selected = null;
      _query = next;
    });
    ref.read(facturacionSreqfPanelQueryProvider.notifier).state = next;
  }

  bool get _canMarkReqf {
    if (_markingReqf) return false;
    final folio = _selected;
    if (folio == null) return false;
    return _markReqfValidationMessage(folio) == null;
  }

  Future<void> _markSelectedReqf() async {
    final selected = _selected;
    if (selected == null) {
      _showMessage('Seleccione un folio para marcar REQF', isError: true);
      return;
    }

    final validationMessage = _markReqfValidationMessage(selected);
    if (validationMessage != null) {
      _showMessage(validationMessage, isError: true);
      return;
    }

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Confirmar accion'),
            content: Text(
              'Se marcara REQF=1 para el folio ${selected.idfol} y se sincronizara en facturacion. Desea continuar?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Confirmar'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;

    setState(() => _markingReqf = true);
    try {
      final message = await ref
          .read(facturacionSreqfApiProvider)
          .markReqf(selected.idfol);
      ref.invalidate(facturacionSreqfListProvider);
      await ref.read(facturacionSreqfListProvider.future);
      if (!mounted) return;
      setState(() => _selected = null);
      _showMessage(message);
    } catch (error) {
      if (!mounted) return;
      _showMessage(_buildReqfErrorMessage(error), isError: true);
    } finally {
      if (mounted) {
        setState(() => _markingReqf = false);
      }
    }
  }

  String? _markReqfValidationMessage(PvCtrFolAsvrModel folio) {
    final aut = (folio.aut ?? '').trim().toUpperCase();
    final esta = (folio.esta ?? '').trim().toUpperCase();
    final reqf = folio.reqf ?? 0;

    if (reqf == 1) {
      return 'El folio ${folio.idfol} ya esta marcado como REQF';
    }
    if (aut != 'VF' || esta != 'MB51PROCES') {
      return 'Solo se permite marcar folios con AUT=VF y ESTA=MB51PROCES';
    }
    return null;
  }

  String _buildReqfErrorMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        final message = (data['message'] ?? data['mensaje'] ?? '')
            .toString()
            .trim();
        if (message.isNotEmpty) return message;
      } else if (data is String && data.trim().isNotEmpty) {
        return data.trim();
      }
    }
    return 'No se pudo marcar REQF: $error';
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : null,
      ),
    );
  }

  Future<void> _loadUserContext() async {
    final storage = ref.read(storageProvider);
    final token = await storage.getAccessToken();
    if (!mounted) return;

    // No forzar SUC por JWT: backend resuelve alcance por USR_MOD_SUC
    // (con fallback legado a user.suc cuando no hay filas).
    final query = const FacturacionSreqfQuery();
    if (token == null || token.isEmpty) {
      ref.read(facturacionSreqfPanelQueryProvider.notifier).state = query;
      setState(() {
        _query = query;
        _contextReady = true;
      });
      return;
    }

    ref.read(facturacionSreqfPanelQueryProvider.notifier).state = query;
    setState(() {
      _query = query;
      _contextReady = true;
    });
  }

  Future<void> _pickFcnmDate() async {
    final now = DateTime.now();
    final selectedDate = _tryParseYmd(_fcnmCtrl.text.trim());
    final firstDate = DateTime(2000, 1, 1);
    final lastDate = DateTime(now.year + 5, 12, 31);
    var initialDate = selectedDate ?? now;
    if (initialDate.isBefore(firstDate)) {
      initialDate = firstDate;
    } else if (initialDate.isAfter(lastDate)) {
      initialDate = lastDate;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Seleccionar fecha FCNM',
    );

    if (picked == null || !mounted) return;

    final formatted = _formatYmd(picked);
    setState(() {
      _fcnmCtrl.text = formatted;
    });
  }

  DateTime? _tryParseYmd(String raw) {
    final parts = raw.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    if (m < 1 || m > 12 || d < 1 || d > 31) return null;
    return DateTime(y, m, d);
  }

  String _formatYmd(DateTime value) {
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

class _TopFilters extends ConsumerWidget {
  const _TopFilters({
    required this.sucCtrl,
    required this.fcnmCtrl,
    required this.searchCtrl,
    required this.onMarkReqf,
    required this.canMarkReqf,
    required this.markReqfLoading,
    required this.onPickFcnmDate,
    required this.onSearch,
    required this.onClear,
    required this.onSucChanged,
  });

  final TextEditingController sucCtrl;
  final TextEditingController fcnmCtrl;
  final TextEditingController searchCtrl;
  final VoidCallback onMarkReqf;
  final bool canMarkReqf;
  final bool markReqfLoading;
  final VoidCallback onPickFcnmDate;
  final VoidCallback onSearch;
  final VoidCallback onClear;
  final ValueChanged<String?> onSucChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sucAsync = ref.watch(sucursalesListProvider);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 16,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              height: 40,
              child: FilledButton.icon(
                onPressed: canMarkReqf ? onMarkReqf : null,
                icon: markReqfLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.playlist_add_check_rounded),
                label: const Text('Marcar REQF'),
              ),
            ),
            SizedBox(
              width: 230,
              child: sucAsync.when(
                data: (sucursales) {
                  final items = <DropdownMenuItem<String>>[
                    const DropdownMenuItem(
                      value: '',
                      child: Text('TODAS (AUTORIZADAS)'),
                    ),
                  ];
                  for (final s in sucursales) {
                    final label = (s.desc?.trim().isNotEmpty == true)
                        ? '${s.suc} - ${s.desc}'
                        : s.suc;
                    items.add(
                      DropdownMenuItem(
                        value: s.suc,
                        child: Text(label),
                      ),
                    );
                  }

                  final selected = sucCtrl.text.trim();
                  final value = items.any((item) => item.value == selected)
                      ? selected
                      : null;

                  return DropdownButtonFormField<String>(
                    initialValue: value,
                    isExpanded: true,
                    items: items,
                    onChanged: onSucChanged,
                    decoration: const InputDecoration(
                      labelText: 'Sucursal',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  );
                },
                loading: () => _SmallField(
                  label: 'Sucursal',
                  controller: sucCtrl,
                  enabled: false,
                ),
                error: (_, _) => _SmallField(
                  label: 'Sucursal',
                  controller: sucCtrl,
                  enabled: false,
                ),
              ),
            ),
            SizedBox(
              width: 190,
              child: TextField(
                controller: fcnmCtrl,
                readOnly: true,
                onTap: onPickFcnmDate,
                decoration: InputDecoration(
                  labelText: 'FCNM (YYYY-MM-DD)',
                  isDense: true,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: 'Seleccionar fecha',
                    onPressed: onPickFcnmDate,
                    icon: const Icon(Icons.calendar_today),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 500,
              child: TextField(
                controller: searchCtrl,
                decoration: const InputDecoration(
                  labelText: 'Buscar folio / CLIEN / razon social / OPV',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => onSearch(),
              ),
            ),
            IconButton(
              tooltip: 'Buscar',
              onPressed: onSearch,
              icon: const Icon(Icons.search),
            ),
            IconButton(
              tooltip: 'Limpiar',
              onPressed: onClear,
              icon: const Icon(Icons.clear),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCriteriaHint extends StatelessWidget {
  const _EmptyCriteriaHint();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          'Capture FCNM o una busqueda general (IDFOL, CLIEN, razon social u OPV) para consultar registros.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.enabled,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.totalPages,
    required this.onPrev,
    required this.onNext,
  });

  final bool enabled;
  final int page;
  final int pageSize;
  final int total;
  final int totalPages;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final pageText = totalPages == 0
        ? 'Pagina 0 de 0'
        : 'Pagina $page de $totalPages';

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Text(
              'Registros: $total',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(width: 14),
            Text(
              'Maximo por pagina: $pageSize',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Anterior',
              onPressed: enabled ? onPrev : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Text(
              pageText,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            IconButton(
              tooltip: 'Siguiente',
              onPressed: enabled ? onNext : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallField extends StatelessWidget {
  const _SmallField({
    required this.label,
    required this.controller,
    this.enabled = true,
  });

  final String label;
  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: TextField(
        controller: controller,
        enabled: enabled,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

class _FoliosReqfTable extends StatelessWidget {
  const _FoliosReqfTable({
    required this.folios,
    required this.selected,
    required this.onSelect,
  });

  final List<PvCtrFolAsvrModel> folios;
  final PvCtrFolAsvrModel? selected;
  final ValueChanged<PvCtrFolAsvrModel> onSelect;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: SizedBox(
        height: 420,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            child: DataTable(
              showCheckboxColumn: false,
              headingRowHeight: 40,
              dataRowMinHeight: 42,
              dataRowMaxHeight: 48,
              horizontalMargin: 12,
              columnSpacing: 20,
              columns: const [
                DataColumn(
                  label: Text('SUC', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                DataColumn(
                  label: Text('OPV', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                DataColumn(
                  label: Text('IDFOL', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                DataColumn(
                  label: Text(
                    'ORIGEN_AUT',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                DataColumn(
                  label: Text('FCN', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                DataColumn(
                  label: Text('TRA', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                DataColumn(
                  label: Text('CLIEN', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                DataColumn(
                  label: Text(
                    'Razon social receptor',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                DataColumn(
                  label: Text('REQF', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                DataColumn(
                  label: Text('Estado', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                DataColumn(
                  label: Text('Importe', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
              rows: folios.map((folio) {
                final selectedRow = selected?.idfol == folio.idfol;
                final razonSocial = (folio.razonSocialReceptor ?? '').trim();
                return DataRow(
                  selected: selectedRow,
                  onSelectChanged: (_) => onSelect(folio),
                  cells: [
                    DataCell(_cellText(folio.suc ?? '-')),
                    DataCell(_cellText(folio.opv ?? '-')),
                    DataCell(_cellText(folio.idfol)),
                    DataCell(_cellText((folio.origenAut ?? '-').toUpperCase())),
                    DataCell(_cellText(_formatDate(folio.fcn))),
                    DataCell(_cellText(folio.tra ?? '-')),
                    DataCell(_cellText(folio.clien?.toString() ?? '-')),
                    DataCell(_cellText(razonSocial.isEmpty ? '-' : razonSocial)),
                    DataCell(_cellText(_formatReqf(folio.reqf))),
                    DataCell(_cellText(folio.esta ?? '-')),
                    DataCell(
                      _cellText(_formatMoney(folio.impt), align: TextAlign.right),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _cellText(String value, {TextAlign align = TextAlign.left}) {
    return Text(
      value,
      textAlign: align,
      softWrap: false,
      overflow: TextOverflow.visible,
    );
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '-';
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$d/$m/$y';
  }

  String _formatMoney(double? value) {
    if (value == null) return '-';
    return '\$${value.toStringAsFixed(2)}';
  }

  String _formatReqf(int? value) {
    if (value == null) return '-';
    return value.toString();
  }
}
