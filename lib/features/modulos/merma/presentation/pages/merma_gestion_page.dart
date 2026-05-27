import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';

import '../../../../../core/auth/auth_controller.dart';
import '../../domain/merma_models.dart';
import '../../providers/merma_catalogs_provider.dart';
import '../../providers/merma_provider.dart';
import '../dialogs/merma_anular_dialog.dart';
import '../dialogs/merma_etiqueta_dialog.dart';
import '../dialogs/merma_revision_dialog.dart';
import '../widgets/merma_item_table.dart';
import '../widgets/merma_status_chip.dart';
import '../widgets/merma_totals_card.dart';

class MermaGestionPage extends ConsumerStatefulWidget {
  const MermaGestionPage({super.key});

  @override
  ConsumerState<MermaGestionPage> createState() => _MermaGestionPageState();
}

class _MermaGestionPageState extends ConsumerState<MermaGestionPage> {
  String? _selectedDocmer;
  String _selectedSucursalFilter = '';
  String _selectedFechaFilter = '';
  bool _encargadoFiltroAplicado = false;

  @override
  Widget build(BuildContext context) {
    final roleName = ref.watch(mermaCurrentRoleNameProvider).valueOrNull ?? '';
    final isInventarios = _isInventariosReviewer(roleName);
    final isEncargadoSucursal = _isEncargadoSucursalRole(roleName);
    final isEncargadoMerma = _isEncargadoMerma(roleName);
    final canCreateNewFile = _isEncargadoSucursalRole(roleName);
    final auth = ref.watch(authControllerProvider);
    final loggedSuc = _normalizeSuc(auth.suc);
    final selectedFilterSuc = _normalizeSuc(_selectedSucursalFilter);
    final effectiveSuc = isInventarios
        ? selectedFilterSuc
        : (selectedFilterSuc ?? loggedSuc);

    final asyncSucursales = ref.watch(mermaSucursalesProvider);
    final asyncCabeceras = ref.watch(mermaGestionCabecerasProvider(effectiveSuc));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de merma'),
        actions: [
          if (canCreateNewFile)
            IconButton(
              tooltip: 'Nuevo archivo',
              onPressed: _create,
              icon: const Icon(Icons.add_circle_outline),
            ),
          IconButton(
            tooltip: 'Refrescar',
            onPressed: _refreshAll,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: asyncCabeceras.when(
        data: (cabeceras) {
          final roleFilteredCabeceras = _filterCabecerasByRole(
            cabeceras,
            roleName,
          );
          final visibleCabeceras = _applyFiltersForRole(
            cabeceras: roleFilteredCabeceras,
            isEncargadoSucursal: isEncargadoSucursal,
            isInventarios: isInventarios,
          );
          final sucursales = asyncSucursales.valueOrNull ?? const <String>[];
          _ensureSelection(visibleCabeceras);
          return LayoutBuilder(
            builder: (context, constraints) {
              final useWideLayout = constraints.maxWidth >= 1100;
              if (!useWideLayout) {
                return Column(
                  children: [
                    SizedBox(
                      height: 320,
                      child: _CabecerasPanel(
                        cabeceras: visibleCabeceras,
                        selectedDocmer: _selectedDocmer,
                        onSelect: _selectDoc,
                        sucLabel: loggedSuc,
                        sucursales: sucursales,
                        selectedSuc: selectedFilterSuc,
                        onChangeSuc: _changeSucursalFilter,
                        requireSucursalSelection: isInventarios,
                        showSucursalFilter: isInventarios,
                        showFechaCalendarFilter:
                            isEncargadoSucursal || isInventarios,
                        showFechaActionButtons: isEncargadoMerma,
                        selectedFecha: _selectedFechaFilter,
                        onPickFecha: _pickFechaFilter,
                        onApplyFecha: _applyEncargadoFechaFilter,
                        onClearFecha: _clearEncargadoFechaFilter,
                        needApplyBeforeResults:
                            isEncargadoSucursal && !_encargadoFiltroAplicado,
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(child: _buildDetailPanel()),
                  ],
                );
              }

              return Row(
                children: [
                  SizedBox(
                    width: 360,
                    child: _CabecerasPanel(
                      cabeceras: visibleCabeceras,
                      selectedDocmer: _selectedDocmer,
                      onSelect: _selectDoc,
                      sucLabel: loggedSuc,
                      sucursales: sucursales,
                      selectedSuc: selectedFilterSuc,
                      onChangeSuc: _changeSucursalFilter,
                      requireSucursalSelection: isInventarios,
                      showSucursalFilter: isInventarios,
                      showFechaCalendarFilter:
                          isEncargadoSucursal || isInventarios,
                      showFechaActionButtons: isEncargadoMerma,
                      selectedFecha: _selectedFechaFilter,
                      onPickFecha: _pickFechaFilter,
                      onApplyFecha: _applyEncargadoFechaFilter,
                      onClearFecha: _clearEncargadoFechaFilter,
                      needApplyBeforeResults:
                          isEncargadoSucursal && !_encargadoFiltroAplicado,
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: _buildDetailPanel()),
                ],
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildDetailPanel() {
    final selected = _selectedDocmer;
    final roleName = ref.watch(mermaCurrentRoleNameProvider).valueOrNull ?? '';
    final auth = ref.watch(authControllerProvider);
    final roleId = auth.roleId ?? 0;
    final username = (auth.username ?? '').trim().toUpperCase();
    if (selected == null || selected.trim().isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.inventory_2_outlined, size: 44, color: Colors.grey),
            SizedBox(height: 8),
            Text('Selecciona una cabecera para ver el detalle'),
          ],
        ),
      );
    }

    final asyncDoc = ref.watch(mermaDetalleProvider(selected));
    return asyncDoc.when(
      data: (doc) => ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.25)),
            ),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                Text(
                  'DOCMER: ${doc.docmer}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('Sucursal: ${doc.suc}'),
                Text('Usuario: ${doc.user}'),
                MermaStatusChip(estatus: doc.estatus),
              ],
            ),
          ),
          const SizedBox(height: 10),
          MermaTotalsCard(narts: doc.narts, total: doc.total),
          const SizedBox(height: 10),
          if (_isInventariosReviewer(roleName))
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (doc.idEstatus == 2)
                  OutlinedButton.icon(
                    onPressed: () => _revisarEnGestion(doc),
                    icon: const Icon(Icons.rule),
                    label: const Text('Revisar'),
                  ),
                if (doc.idEstatus == 2)
                  FilledButton.icon(
                    onPressed: () => _contabilizarEnGestion(doc),
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Contabilizar'),
                  ),
                if (doc.idEstatus == 1 || doc.idEstatus == 2 || doc.idEstatus == 4)
                  OutlinedButton.icon(
                    onPressed: () => _anularEnGestion(doc),
                    icon: const Icon(Icons.cancel),
                    label: const Text('Anular'),
                  ),
                OutlinedButton.icon(
                  onPressed: () =>
                      context.go('/modulos/merma/consulta/${doc.docmer}'),
                  icon: const Icon(Icons.visibility),
                  label: const Text('Ver en consulta'),
                ),
              ],
            )
          else
            Row(
              children: [
                if (doc.idEstatus == 5 &&
                    _canPrintEtiquetaInGestion(
                      roleName: roleName,
                      roleId: roleId,
                      username: username,
                    ))
                  FilledButton.icon(
                    onPressed: () => _openEtiqueta(doc.docmer),
                    icon: const Icon(Icons.print),
                    label: const Text('Imprimir etiqueta'),
                  )
                else
                  FilledButton.icon(
                    onPressed: () =>
                        context.go('/modulos/merma/gestion/${doc.docmer}'),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Abrir documento completo'),
                  ),
              ],
            ),
          const SizedBox(height: 10),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: MermaItemTable(
                items: doc.detalle,
                documentArea: doc.areaM,
                readOnly: true,
                showEvidenceColumn: true,
                showDescriptionColumn: true,
                showObservacionesColumn: true,
              ),
            ),
          ),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) {
        if (error is DioException && error.response?.statusCode == 404) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _selectedDocmer = null);
            _refreshAll();
          });
          return const Center(
            child: Text('El documento ya no existe. La lista fue actualizada.'),
          );
        }
        return Center(child: Text('Error: ${_friendlyError(error)}'));
      },
    );
  }

  void _ensureSelection(List<MermaGestionCabeceraModel> cabeceras) {
    if (cabeceras.isEmpty) {
      if (_selectedDocmer != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() => _selectedDocmer = null);
        });
      }
      return;
    }

    final hasSelected = cabeceras.any((x) => x.docmer == _selectedDocmer);
    if (hasSelected || _selectedDocmer == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _selectedDocmer = null);
    });
  }

  void _selectDoc(String docmer) {
    if (_selectedDocmer == docmer) return;
    setState(() => _selectedDocmer = docmer);
  }

  void _changeSucursalFilter(String? suc) {
    final next = _normalizeSuc(suc) ?? '';
    if (_selectedSucursalFilter == next) return;
    setState(() {
      _selectedSucursalFilter = next;
      _selectedDocmer = null;
    });
  }

  Future<void> _pickFechaFilter() async {
    final now = DateTime.now();
    final parsed = _parseDate(_selectedFechaFilter);
    final picked = await showDatePicker(
      context: context,
      initialDate: parsed ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 2),
    );
    if (picked == null || !mounted) return;
    final y = picked.year.toString().padLeft(4, '0');
    final m = picked.month.toString().padLeft(2, '0');
    final d = picked.day.toString().padLeft(2, '0');
    setState(() {
      _selectedFechaFilter = '$y-$m-$d';
      _encargadoFiltroAplicado = true;
      _selectedDocmer = null;
    });
  }

  void _applyEncargadoFechaFilter() {
    final fecha = _selectedFechaFilter.trim();
    if (fecha.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una fecha para filtrar.')),
      );
      return;
    }
    setState(() {
      _encargadoFiltroAplicado = true;
      _selectedDocmer = null;
    });
  }

  void _clearEncargadoFechaFilter() {
    setState(() {
      _selectedFechaFilter = '';
      _encargadoFiltroAplicado = false;
      _selectedDocmer = null;
    });
  }

  void _refreshAll() {
    final roleName = ref.read(mermaCurrentRoleNameProvider).valueOrNull ?? '';
    final isInventarios = _isInventariosReviewer(roleName);
    final loggedSuc = _normalizeSuc(ref.read(authControllerProvider).suc);
    final selectedFilterSuc = _normalizeSuc(_selectedSucursalFilter);
    final effectiveSuc = isInventarios
        ? selectedFilterSuc
        : (selectedFilterSuc ?? loggedSuc);
    ref.invalidate(mermaGestionCabecerasProvider(effectiveSuc));
    final selected = _selectedDocmer;
    if (selected != null && selected.trim().isNotEmpty) {
      ref.invalidate(mermaDetalleProvider(selected));
    }
  }

  List<MermaGestionCabeceraModel> _filterCabecerasByRole(
    List<MermaGestionCabeceraModel> cabeceras,
    String roleName,
  ) {
    if (_isEncargadoMerma(roleName)) {
      // Encargado de sucursal/merma no debe ver documentos pendientes.
      // Mantener visibles abiertos/revisión/contabilizados como en gestión.
      const allowed = {'ABIERTO', 'REVISAR', 'CONTABILIZADO'};
      return cabeceras
          .where((row) => allowed.contains(row.estats.trim().toUpperCase()))
          .toList();
    }
    if (_isInventariosReviewer(roleName)) {
      // Inventarios en gestión filtra solo documentos pendientes.
      const allowed = {'PENDIENTE'};
      return cabeceras
          .where((row) => allowed.contains(row.estats.trim().toUpperCase()))
          .toList();
    }
    return cabeceras;
  }

  List<MermaGestionCabeceraModel> _applyFechaFilter(
    List<MermaGestionCabeceraModel> cabeceras,
  ) {
    final selected = _selectedFechaFilter.trim();
    if (selected.isEmpty) return cabeceras;
    return cabeceras.where((row) => _fmtDate(row.fcnd) == selected).toList();
  }

  List<MermaGestionCabeceraModel> _applyFiltersForRole({
    required List<MermaGestionCabeceraModel> cabeceras,
    required bool isEncargadoSucursal,
    required bool isInventarios,
  }) {
    if (isEncargadoSucursal) {
      if (!_encargadoFiltroAplicado) return const <MermaGestionCabeceraModel>[];
      return _applyFechaFilter(cabeceras);
    }
    if (isInventarios) {
      return _applyFechaFilter(cabeceras);
    }
    return cabeceras;
  }

  DateTime? _parseDate(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  bool _isEncargadoMerma(String roleName) {
    final role = roleName.trim().toUpperCase();
    if (role.isEmpty) return false;
    return role.contains('ENCARGADO DE MERMA') ||
        (role.contains('ENCARGADO') &&
            (role.contains('SUCURSAL') || role.contains('MERMA')));
  }

  bool _isInventariosReviewer(String roleName) {
    final role = roleName.trim().toUpperCase();
    if (role.isEmpty) return false;
    final isJefeInventarios =
        role.contains('JEFE') &&
        (role.contains('INVENTARIOS') || role.contains('INVENTARIO'));
    final isAnalistaInventarios =
        role.contains('ANALISTA') &&
        (role.contains('INVENTARIOS') || role.contains('INVENTARIO'));
    return isJefeInventarios || isAnalistaInventarios;
  }

  bool _isEncargadoSucursalRole(String roleName) {
    final role = roleName.trim().toUpperCase();
    if (role.isEmpty) return false;
    return role.contains('ENCARGADO') && role.contains('SUCURSAL');
  }

  Future<void> _create() async {
    final suc = _normalizeSuc(ref.read(authControllerProvider).suc);
    final sucLabel = suc == null ? '' : ' para la sucursal $suc';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Crear documento de merma'),
        content: Text(
          'Se creará un nuevo documento en estatus ABIERTO$sucLabel. ¿Deseas continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    try {
      final api = ref.read(mermaApiProvider);
      final created = await api.createMerma(suc: suc);
      if (!mounted) return;
      setState(() => _selectedDocmer = created.docmer);
      _refreshAll();
      context.go('/modulos/merma/gestion/${created.docmer}?nuevo=1');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo crear merma: $e')));
    }
  }

  bool _canPrintEtiquetaInGestion({
    required String roleName,
    required int roleId,
    required String username,
  }) {
    if (roleId == 0 || roleId == 1 || username == 'ADMIN') {
      return true;
    }
    final role = roleName.trim().toUpperCase();
    if (role.contains('ADMIN')) return true;
    if (role.contains('ENCARGADO') && role.contains('SUCURSAL')) return true;
    return false;
  }

  Future<void> _openEtiqueta(String docmer) async {
    try {
      final data = await ref.read(mermaApiProvider).etiqueta(docmer);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => MermaEtiquetaDialog(data: data),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(e))));
    }
  }

  Future<void> _revisarEnGestion(MermaDocModel doc) async {
    final obs = await showDialog<String>(
      context: context,
      builder: (_) => const MermaRevisionDialog(),
    );
    if (obs == null) return;
    try {
      await ref.read(mermaApiProvider).revisar(doc.docmer, obs);
      ref.invalidate(mermaDetalleProvider(doc.docmer));
      _refreshAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(e))));
    }
  }

  Future<void> _contabilizarEnGestion(MermaDocModel doc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar contabilización'),
        content: Text(
          'Se contabilizará el documento ${doc.docmer}. ¿Deseas continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final api = ref.read(mermaApiProvider);
      await api.contabilizar(doc.docmer);
      ref.invalidate(mermaDetalleProvider(doc.docmer));
      _refreshAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(e))));
    }
  }

  Future<void> _anularEnGestion(MermaDocModel doc) async {
    final obs = await showDialog<String>(
      context: context,
      builder: (_) => const MermaAnularDialog(),
    );
    if (obs == null) return;
    try {
      await ref.read(mermaApiProvider).anular(doc.docmer, obs);
      ref.invalidate(mermaDetalleProvider(doc.docmer));
      _refreshAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(e))));
    }
  }

  String _friendlyError(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        final msg = (data['message'] ?? '').toString().trim();
        if (msg.isNotEmpty) return msg;
      }
      return error.message ?? 'No fue posible completar la accion.';
    }
    return error.toString();
  }

  String? _normalizeSuc(String? value) {
    final suc = (value ?? '').trim().toUpperCase();
    return suc.isEmpty ? null : suc;
  }
}

class _CabecerasPanel extends StatelessWidget {
  const _CabecerasPanel({
    required this.cabeceras,
    required this.selectedDocmer,
    required this.onSelect,
    required this.sucLabel,
    required this.sucursales,
    required this.selectedSuc,
    required this.onChangeSuc,
    required this.requireSucursalSelection,
    required this.showSucursalFilter,
    required this.showFechaCalendarFilter,
    required this.showFechaActionButtons,
    required this.selectedFecha,
    required this.onPickFecha,
    required this.onApplyFecha,
    required this.onClearFecha,
    required this.needApplyBeforeResults,
  });

  final List<MermaGestionCabeceraModel> cabeceras;
  final String? selectedDocmer;
  final ValueChanged<String> onSelect;
  final String? sucLabel;
  final List<String> sucursales;
  final String? selectedSuc;
  final ValueChanged<String?> onChangeSuc;
  final bool requireSucursalSelection;
  final bool showSucursalFilter;
  final bool showFechaCalendarFilter;
  final bool showFechaActionButtons;
  final String selectedFecha;
  final VoidCallback onPickFecha;
  final VoidCallback onApplyFecha;
  final VoidCallback onClearFecha;
  final bool needApplyBeforeResults;

  @override
  Widget build(BuildContext context) {
    final currentSuc = (selectedSuc ?? '').trim();
    final mustPickSucursal = requireSucursalSelection && currentSuc.isEmpty;
    final label = currentSuc.isNotEmpty ? currentSuc : (sucLabel ?? '').trim();

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.25)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.list_alt, color: Colors.teal),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Documentos de gestion',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              if (showSucursalFilter || showFechaCalendarFilter) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (showSucursalFilter)
                      SizedBox(
                        width: 145,
                        child: DropdownButtonFormField<String>(
                          key: ValueKey(currentSuc),
                          initialValue: currentSuc.isEmpty ? '' : currentSuc,
                          isDense: true,
                          decoration: const InputDecoration(
                            isDense: true,
                            labelText: 'Sucursal',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem<String>(
                              value: '',
                              child: Text('Seleccionar'),
                            ),
                            ...sucursales.map(
                              (suc) => DropdownMenuItem<String>(
                                value: suc,
                                child: Text(suc),
                              ),
                            ),
                          ],
                          onChanged: onChangeSuc,
                        ),
                      ),
                    if (showFechaCalendarFilter)
                      SizedBox(
                        width: 160,
                        child: OutlinedButton.icon(
                          onPressed: onPickFecha,
                          icon: const Icon(Icons.calendar_today),
                          label: Text(
                            selectedFecha.trim().isEmpty
                                ? 'Fecha'
                                : selectedFecha.trim(),
                          ),
                        ),
                      ),
                    if (showFechaCalendarFilter && showFechaActionButtons)
                      FilledButton(
                        onPressed: onApplyFecha,
                        child: const Text('Filtrar'),
                      ),
                    if (showFechaCalendarFilter && showFechaActionButtons)
                      TextButton(
                        onPressed: onClearFecha,
                        child: const Text('Limpiar'),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (mustPickSucursal)
          const Expanded(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Selecciona una sucursal para ver documentos.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          )
        else if (needApplyBeforeResults)
          const Expanded(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Primero aplica el filtro de fecha para visualizar documentos.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          )
        else if (cabeceras.isEmpty)
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  label.isEmpty
                      ? 'Sin documentos para los estatus permitidos'
                      : 'Sin documentos para los estatus permitidos en $label',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(10),
              itemCount: cabeceras.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = cabeceras[index];
                final selected = item.docmer == selectedDocmer;
                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: selected
                          ? Colors.deepPurple.shade200
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => onSelect(item.docmer),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'DOCMER ${item.docmer}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: selected
                                        ? Colors.deepPurple.shade700
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                              Text(
                                item.estats,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${item.suc} | ${_fmtDate(item.fcnd)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

String _fmtDate(DateTime? value) {
  if (value == null) return '-';
  final y = value.year.toString().padLeft(4, '0');
  final m = value.month.toString().padLeft(2, '0');
  final d = value.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
