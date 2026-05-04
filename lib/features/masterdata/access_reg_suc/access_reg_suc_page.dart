import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../access/access_models.dart';
import '../access/access_providers.dart';
import '../sucursales/sucursales_models.dart';
import '../sucursales/sucursales_providers.dart';
import '../users/users_models.dart';
import '../users/users_providers.dart';
import 'access_reg_suc_models.dart';
import 'access_reg_suc_providers.dart';

class AccessRegSucPage extends ConsumerStatefulWidget {
  const AccessRegSucPage({super.key});

  @override
  ConsumerState<AccessRegSucPage> createState() => _AccessRegSucPageState();
}

class _AccessRegSucPageState extends ConsumerState<AccessRegSucPage> {
  AccessRegSucFilters _appliedFilters = const AccessRegSucFilters();

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(accessRegSucListProvider(_appliedFilters));
    final usersAsync = ref.watch(accessUsersProvider);
    final modulosAsync = ref.watch(frontModulosProvider);

    final sucUsuarioOptions = usersAsync.maybeWhen(
      data: (users) => _buildSucUsuarioOptions(users),
      orElse: () => const <String>[],
    );

    final deptoOptions = usersAsync.maybeWhen(
      data: (users) => modulosAsync.maybeWhen(
        data: (modulos) => _buildDeptoOptions(users, modulos),
        orElse: () => const <String>[],
      ),
      orElse: () => const <String>[],
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Acceso por sucursal'),
        actions: [
          IconButton(
            onPressed: () =>
                ref.invalidate(accessRegSucListProvider(_appliedFilters)),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refrescar',
          ),
        ],
      ),
      body: dataAsync.when(
        data: (rows) => _AccessRegSucList(
          rows: rows,
          ref: ref,
          appliedFilters: _appliedFilters,
          sucUsuarioOptions: sucUsuarioOptions,
          deptoOptions: deptoOptions,
          onApplyFilters: (nextFilters) =>
              setState(() => _appliedFilters = nextFilters),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

List<String> _buildSucUsuarioOptions(List<AccessUser> users) {
  final sucs = <String>{
    for (final user in users)
      if ((user.suc ?? '').trim().isNotEmpty) user.suc!.trim(),
  }.toList()..sort();
  return sucs;
}

List<String> _buildDeptoOptions(
  List<AccessUser> users,
  List<AccessModuloFront> modulos,
) {
  final deptosUsuario = <String>{
    for (final user in users)
      if ((user.deptoNombre ?? '').trim().isNotEmpty)
        user.deptoNombre!.trim().toUpperCase(),
  };
  final deptosModulo = <String>{
    for (final modulo in modulos)
      if ((modulo.depto ?? '').trim().isNotEmpty)
        modulo.depto!.trim().toUpperCase(),
  };

  final intersection = deptosUsuario.intersection(deptosModulo).toList()
    ..sort();
  return intersection;
}

class _AccessRegSucList extends StatefulWidget {
  const _AccessRegSucList({
    required this.rows,
    required this.ref,
    required this.appliedFilters,
    required this.sucUsuarioOptions,
    required this.deptoOptions,
    required this.onApplyFilters,
  });

  final List<AccessRegSucModel> rows;
  final WidgetRef ref;
  final AccessRegSucFilters appliedFilters;
  final List<String> sucUsuarioOptions;
  final List<String> deptoOptions;
  final ValueChanged<AccessRegSucFilters> onApplyFilters;

  @override
  State<_AccessRegSucList> createState() => _AccessRegSucListState();
}

class _AccessRegSucListState extends State<_AccessRegSucList> {
  final _searchCtrl = TextEditingController();
  String _searchApplied = '';
  String _selectedSucUsuario = 'TODAS';
  String _selectedDepto = 'TODOS';

  @override
  void initState() {
    super.initState();
    _hydrateLocalFilters();
  }

  @override
  void didUpdateWidget(covariant _AccessRegSucList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.appliedFilters != widget.appliedFilters) {
      _hydrateLocalFilters();
    }
  }

  void _hydrateLocalFilters() {
    _selectedSucUsuario =
        (widget.appliedFilters.sucUsuario ?? '').trim().isEmpty
        ? 'TODAS'
        : widget.appliedFilters.sucUsuario!.trim();
    _selectedDepto = (widget.appliedFilters.depto ?? '').trim().isEmpty
        ? 'TODOS'
        : widget.appliedFilters.depto!.trim().toUpperCase();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _refreshList() async {
    widget.ref.invalidate(accessRegSucListProvider(widget.appliedFilters));
    await widget.ref.read(
      accessRegSucListProvider(widget.appliedFilters).future,
    );
  }

  void _applyFilters() {
    widget.onApplyFilters(
      AccessRegSucFilters(
        sucUsuario: _selectedSucUsuario == 'TODAS' ? null : _selectedSucUsuario,
        depto: _selectedDepto == 'TODOS' ? null : _selectedDepto,
      ),
    );
    setState(() => _searchApplied = _searchCtrl.text);
  }

  void _clearFilters() {
    _searchCtrl.clear();
    setState(() {
      _searchApplied = '';
      _selectedSucUsuario = 'TODAS';
      _selectedDepto = 'TODOS';
    });
    widget.onApplyFilters(const AccessRegSucFilters());
  }

  Future<void> _createGroup() async {
    final catalogs = await _loadCatalogs();
    if (catalogs == null) return;
    if (!mounted) return;

    final created = await _AccessRegSucEditorDialog.show(
      context,
      sucursales: catalogs.sucursales,
      modulos: catalogs.modulos,
      usuarios: catalogs.usuarios,
      title: 'Vincular sucursales',
    );

    if (!mounted) return;
    if (created == null) return;
    if (created.selectedSucursales.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona al menos una sucursal.')),
      );
      return;
    }
    final previousBySucursal = <String, AccessRegSucModel>{};
    for (final row in widget.rows) {
      if (row.modulo == created.modulo && row.usuario == created.usuario) {
        previousBySucursal[row.suc] = row;
      }
    }

    await _saveAssignments(
      modulo: created.modulo,
      usuario: created.usuario,
      previousBySucursal: previousBySucursal,
      selectedSucursales: created.selectedSucursales,
      successMessage: previousBySucursal.isEmpty
          ? 'Sucursales vinculadas.'
          : 'Asignación actualizada.',
    );
  }

  Future<void> _assignSucursales(_AccessRegSucGroup group) async {
    final catalogs = await _loadCatalogs();
    if (catalogs == null) return;
    if (!mounted) return;

    final updated = await _AccessRegSucEditorDialog.show(
      context,
      sucursales: catalogs.sucursales,
      modulos: catalogs.modulos,
      usuarios: catalogs.usuarios,
      title: 'Asignar sucursales a ${group.modulo}',
      initialModulo: group.modulo,
      initialUsuario: group.usuario,
      initialSelectedSucursales: group.activeSucursales,
      lockIdentityFields: true,
    );

    if (updated == null) return;
    await _saveAssignments(
      modulo: group.modulo,
      usuario: group.usuario,
      previousBySucursal: group.bySucursal,
      selectedSucursales: updated.selectedSucursales,
      successMessage: 'Asignación actualizada.',
    );
  }

  Future<void> _saveAssignments({
    required String modulo,
    required String usuario,
    required Map<String, AccessRegSucModel> previousBySucursal,
    required Set<String> selectedSucursales,
    required String successMessage,
  }) async {
    try {
      final api = widget.ref.read(accessRegSucApiProvider);
      var hasChanges = false;

      for (final suc in selectedSucursales) {
        final existing = previousBySucursal[suc];
        if (existing == null) {
          await api.create({
            'MODULO': modulo,
            'USUARIO': usuario,
            'SUC': suc,
            'ACTIVO': true,
          });
          hasChanges = true;
        } else if (!existing.activo) {
          await api.update(modulo, usuario, suc, {'ACTIVO': true});
          hasChanges = true;
        }
      }

      for (final entry in previousBySucursal.entries) {
        final suc = entry.key;
        final existing = entry.value;
        if (selectedSucursales.contains(suc) || !existing.activo) continue;
        await api.update(modulo, usuario, suc, {'ACTIVO': false});
        hasChanges = true;
      }

      if (!mounted) return;
      if (!hasChanges) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Sin cambios.')));
        return;
      }

      widget.ref.invalidate(accessRegSucListProvider(widget.appliedFilters));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
    }
  }

  Future<void> _deleteGroup(_AccessRegSucGroup group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar vínculos'),
        content: Text(
          '¿Eliminar todos los vínculos de ${group.modulo} para ${group.usuario}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final api = widget.ref.read(accessRegSucApiProvider);
      for (final row in group.bySucursal.values) {
        await api.delete(group.modulo, group.usuario, row.suc);
      }
      if (!mounted) return;
      widget.ref.invalidate(accessRegSucListProvider(widget.appliedFilters));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Vínculos eliminados.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
    }
  }

  Future<_AccessRegSucCatalogs?> _loadCatalogs() async {
    try {
      final sucursalesFuture = widget.ref.read(sucursalesListProvider.future);
      final modulosFuture = widget.ref.read(frontModulosProvider.future);
      final usuariosFuture = widget.ref.read(usersListProvider.future);

      final sucursales = await sucursalesFuture;
      final modulosFront = await modulosFuture;
      final usuariosRaw = await usuariosFuture;

      final modulos =
          modulosFront.map(_ModuloOption.fromAccessModuloFront).toList()..sort(
            (a, b) => a.codigo.toLowerCase().compareTo(b.codigo.toLowerCase()),
          );

      final usuarios = usuariosRaw.map(_UsuarioOption.fromUser).toList()
        ..sort(
          (a, b) =>
              a.username.toLowerCase().compareTo(b.username.toLowerCase()),
        );

      return _AccessRegSucCatalogs(
        sucursales: sucursales,
        modulos: modulos,
        usuarios: usuarios,
      );
    } catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error cargando catálogos: $e')));
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = _buildGroups(widget.rows);
    final term = _searchApplied.trim().toLowerCase();
    final filtered =
        groups.where((group) {
          if (term.isEmpty) return true;
          return group.modulo.toLowerCase().contains(term) ||
              group.usuario.toLowerCase().contains(term);
        }).toList()..sort((a, b) {
          final byUser = a.usuario.toLowerCase().compareTo(
            b.usuario.toLowerCase(),
          );
          if (byUser != 0) return byUser;
          return a.modulo.toLowerCase().compareTo(b.modulo.toLowerCase());
        });

    return RefreshIndicator(
      onRefresh: _refreshList,
      child: ListView(
        padding: const EdgeInsets.all(12),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _FiltersBar(
            searchController: _searchCtrl,
            selectedSucUsuario: _selectedSucUsuario,
            selectedDepto: _selectedDepto,
            sucUsuarioOptions: widget.sucUsuarioOptions,
            deptoOptions: widget.deptoOptions,
            onChangedSucUsuario: (value) =>
                setState(() => _selectedSucUsuario = value ?? 'TODAS'),
            onChangedDepto: (value) =>
                setState(() => _selectedDepto = value ?? 'TODOS'),
            onApplySearch: _applyFilters,
            onClearSearch: _clearFilters,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _createGroup,
              icon: const Icon(Icons.add),
              label: const Text('Vincular'),
            ),
          ),
          const SizedBox(height: 8),
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No hay accesos para los filtros aplicados.'),
              ),
            )
          else
            for (final group in filtered)
              _AccessRegSucRow(
                group: group,
                onAssign: () => _assignSucursales(group),
                onDelete: () => _deleteGroup(group),
              ),
        ],
      ),
    );
  }
}

class _FiltersBar extends StatelessWidget {
  const _FiltersBar({
    required this.searchController,
    required this.selectedSucUsuario,
    required this.selectedDepto,
    required this.sucUsuarioOptions,
    required this.deptoOptions,
    required this.onChangedSucUsuario,
    required this.onChangedDepto,
    required this.onApplySearch,
    required this.onClearSearch,
  });

  final TextEditingController searchController;
  final String selectedSucUsuario;
  final String selectedDepto;
  final List<String> sucUsuarioOptions;
  final List<String> deptoOptions;
  final ValueChanged<String?> onChangedSucUsuario;
  final ValueChanged<String?> onChangedDepto;
  final VoidCallback onApplySearch;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;

        if (compact) {
          return Column(
            children: [
              DropdownButtonFormField<String>(
                key: ValueKey('suc-main-$selectedSucUsuario'),
                initialValue: selectedSucUsuario,
                decoration: const InputDecoration(
                  labelText: 'Sucursal (usuario)',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(value: 'TODAS', child: Text('TODAS')),
                  for (final suc in sucUsuarioOptions)
                    DropdownMenuItem(value: suc, child: Text(suc)),
                ],
                onChanged: onChangedSucUsuario,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                key: ValueKey('depto-main-$selectedDepto'),
                initialValue: selectedDepto,
                decoration: const InputDecoration(
                  labelText: 'Departamento',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(value: 'TODOS', child: Text('TODOS')),
                  for (final depto in deptoOptions)
                    DropdownMenuItem(value: depto, child: Text(depto)),
                ],
                onChanged: onChangedDepto,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: searchController,
                decoration: const InputDecoration(
                  labelText: 'Buscar por módulo o usuario',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => onApplySearch(),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onApplySearch,
                      icon: const Icon(Icons.search),
                      label: const Text('Filtrar'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onClearSearch,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Limpiar'),
                    ),
                  ),
                ],
              ),
            ],
          );
        }

        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('suc-main-dk-$selectedSucUsuario'),
                    initialValue: selectedSucUsuario,
                    decoration: const InputDecoration(
                      labelText: 'Sucursal (usuario)',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: 'TODAS',
                        child: Text('TODAS'),
                      ),
                      for (final suc in sucUsuarioOptions)
                        DropdownMenuItem(value: suc, child: Text(suc)),
                    ],
                    onChanged: onChangedSucUsuario,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('depto-main-dk-$selectedDepto'),
                    initialValue: selectedDepto,
                    decoration: const InputDecoration(
                      labelText: 'Departamento',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: 'TODOS',
                        child: Text('TODOS'),
                      ),
                      for (final depto in deptoOptions)
                        DropdownMenuItem(value: depto, child: Text(depto)),
                    ],
                    onChanged: onChangedDepto,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: searchController,
                    decoration: const InputDecoration(
                      labelText: 'Buscar por módulo o usuario',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => onApplySearch(),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: onApplySearch,
                  icon: const Icon(Icons.search),
                  label: const Text('Filtrar'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: onClearSearch,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Limpiar'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _AccessRegSucRow extends StatelessWidget {
  const _AccessRegSucRow({
    required this.group,
    required this.onAssign,
    required this.onDelete,
  });

  final _AccessRegSucGroup group;
  final VoidCallback onAssign;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final preview = group.activeSucursales.toList()..sort();
    final previewText = preview.isEmpty
        ? 'Sin sucursales activas'
        : preview.take(3).join(', ') + (preview.length > 3 ? ' ...' : '');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: Icon(
          group.activeSucursales.isEmpty ? Icons.cancel : Icons.check_circle,
          color: group.activeSucursales.isEmpty ? Colors.red : Colors.green,
        ),
        title: Text(group.modulo),
        subtitle: Text(
          'Usuario: ${group.usuario}\n'
          'Sucursales activas: ${group.activeSucursales.length} · $previewText',
        ),
        trailing: Wrap(
          spacing: 8,
          children: [
            IconButton(
              onPressed: onAssign,
              icon: const Icon(Icons.link),
              tooltip: 'Vincular sucursales',
            ),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete, color: Colors.red),
              tooltip: 'Eliminar vínculos',
            ),
          ],
        ),
      ),
    );
  }
}

class _AccessRegSucGroup {
  const _AccessRegSucGroup({
    required this.modulo,
    required this.usuario,
    required this.bySucursal,
  });

  final String modulo;
  final String usuario;
  final Map<String, AccessRegSucModel> bySucursal;

  Set<String> get activeSucursales => bySucursal.values
      .where((row) => row.activo)
      .map((row) => row.suc)
      .toSet();
}

List<_AccessRegSucGroup> _buildGroups(List<AccessRegSucModel> rows) {
  final grouped = <String, Map<String, AccessRegSucModel>>{};

  for (final row in rows) {
    final groupKey = '${row.modulo}::${row.usuario}';
    final bySuc = grouped.putIfAbsent(
      groupKey,
      () => <String, AccessRegSucModel>{},
    );
    bySuc[row.suc] = row;
  }

  return grouped.entries.map((entry) {
    final separator = entry.key.indexOf('::');
    final modulo = separator == -1
        ? entry.key
        : entry.key.substring(0, separator);
    final usuario = separator == -1 ? '' : entry.key.substring(separator + 2);
    return _AccessRegSucGroup(
      modulo: modulo,
      usuario: usuario,
      bySucursal: entry.value,
    );
  }).toList();
}

class _AccessRegSucEditorResult {
  const _AccessRegSucEditorResult({
    required this.modulo,
    required this.usuario,
    required this.selectedSucursales,
  });

  final String modulo;
  final String usuario;
  final Set<String> selectedSucursales;
}

class _AccessRegSucEditorDialog extends StatefulWidget {
  const _AccessRegSucEditorDialog({
    required this.sucursales,
    required this.modulos,
    required this.usuarios,
    required this.title,
    this.initialModulo,
    this.initialUsuario,
    this.initialSelectedSucursales = const <String>{},
    this.lockIdentityFields = false,
  });

  final List<SucursalModel> sucursales;
  final List<_ModuloOption> modulos;
  final List<_UsuarioOption> usuarios;
  final String title;
  final String? initialModulo;
  final String? initialUsuario;
  final Set<String> initialSelectedSucursales;
  final bool lockIdentityFields;

  static Future<_AccessRegSucEditorResult?> show(
    BuildContext context, {
    required List<SucursalModel> sucursales,
    required List<_ModuloOption> modulos,
    required List<_UsuarioOption> usuarios,
    required String title,
    String? initialModulo,
    String? initialUsuario,
    Set<String> initialSelectedSucursales = const <String>{},
    bool lockIdentityFields = false,
  }) {
    return showDialog<_AccessRegSucEditorResult>(
      context: context,
      builder: (_) => _AccessRegSucEditorDialog(
        sucursales: sucursales,
        modulos: modulos,
        usuarios: usuarios,
        title: title,
        initialModulo: initialModulo,
        initialUsuario: initialUsuario,
        initialSelectedSucursales: initialSelectedSucursales,
        lockIdentityFields: lockIdentityFields,
      ),
    );
  }

  @override
  State<_AccessRegSucEditorDialog> createState() =>
      _AccessRegSucEditorDialogState();
}

class _AccessRegSucEditorDialogState extends State<_AccessRegSucEditorDialog> {
  late final List<_ModuloOption> _modulos;
  late final List<_UsuarioOption> _usuarios;
  late final Set<String> _selectedSucursales;
  String? _selectedModulo;
  String? _selectedUsuario;
  String _selectedSucUsuario = 'TODAS';
  String _selectedDepto = 'TODOS';

  @override
  void initState() {
    super.initState();
    _modulos = [...widget.modulos];
    _usuarios = [...widget.usuarios];

    _selectedModulo = widget.initialModulo?.trim();
    _selectedUsuario = widget.initialUsuario?.trim();

    if ((_selectedModulo ?? '').isNotEmpty &&
        !_modulos.any((m) => m.codigo == _selectedModulo)) {
      _modulos.insert(
        0,
        _ModuloOption(
          codigo: _selectedModulo!,
          nombre: '(No disponible)',
          depto: null,
          activo: false,
        ),
      );
    }
    if ((_selectedUsuario ?? '').isNotEmpty &&
        !_usuarios.any((u) => u.username == _selectedUsuario)) {
      _usuarios.insert(
        0,
        _UsuarioOption(
          username: _selectedUsuario!,
          nombreCompleto: '(No disponible)',
          estatus: 'DESCONOCIDO',
          suc: null,
          sucDesc: null,
          deptoNombre: null,
        ),
      );
    }

    _selectedSucursales = {...widget.initialSelectedSucursales};
  }

  List<_ModuloOption> _ensureSelectedModuloVisible(
    List<_ModuloOption> filtered,
  ) {
    final selected = _selectedModulo?.trim();
    if (selected == null || selected.isEmpty) return filtered;
    if (filtered.any((item) => item.codigo == selected)) return filtered;
    final found = _modulos.where((item) => item.codigo == selected).toList();
    if (found.isEmpty) return filtered;
    return [...found, ...filtered];
  }

  List<_UsuarioOption> _ensureSelectedUsuarioVisible(
    List<_UsuarioOption> filtered,
  ) {
    final selected = _selectedUsuario?.trim();
    if (selected == null || selected.isEmpty) return filtered;
    if (filtered.any((item) => item.username == selected)) return filtered;
    final found = _usuarios.where((item) => item.username == selected).toList();
    if (found.isEmpty) return filtered;
    return [...found, ...filtered];
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final dialogWidth = (screenSize.width * 0.92)
        .clamp(320.0, 760.0)
        .toDouble();
    final dialogHeight = (screenSize.height * 0.72)
        .clamp(320.0, 560.0)
        .toDouble();
    final orderedSucursales = [...widget.sucursales]
      ..sort((a, b) => a.suc.toLowerCase().compareTo(b.suc.toLowerCase()));
    final sucOptions = <String>{
      for (final user in _usuarios)
        if ((user.suc ?? '').trim().isNotEmpty) user.suc!.trim(),
    }.toList()..sort();
    final deptosUsuario = <String>{
      for (final user in _usuarios)
        if ((user.deptoNombre ?? '').trim().isNotEmpty)
          user.deptoNombre!.trim().toUpperCase(),
    };
    final deptosModulo = <String>{
      for (final modulo in _modulos)
        if ((modulo.depto ?? '').trim().isNotEmpty)
          modulo.depto!.trim().toUpperCase(),
    };
    final deptoOptions = deptosUsuario.intersection(deptosModulo).toList()
      ..sort();

    final effectiveSuc =
        _selectedSucUsuario == 'TODAS' ||
            sucOptions.contains(_selectedSucUsuario)
        ? _selectedSucUsuario
        : 'TODAS';
    final effectiveDepto =
        _selectedDepto == 'TODOS' || deptoOptions.contains(_selectedDepto)
        ? _selectedDepto
        : 'TODOS';

    final filteredModulos = _modulos.where((modulo) {
      if (effectiveDepto == 'TODOS') return true;
      return (modulo.depto ?? '').trim().toUpperCase() == effectiveDepto;
    }).toList();

    final filteredUsuarios = _usuarios.where((usuario) {
      final matchesSuc =
          effectiveSuc == 'TODAS' || (usuario.suc ?? '').trim() == effectiveSuc;
      if (!matchesSuc) return false;
      if (effectiveDepto == 'TODOS') return true;
      return (usuario.deptoNombre ?? '').trim().toUpperCase() == effectiveDepto;
    }).toList();

    final moduloItems = _ensureSelectedModuloVisible(filteredModulos);
    final usuarioItems = _ensureSelectedUsuarioVisible(filteredUsuarios);

    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('f-suc-$effectiveSuc'),
                    initialValue: effectiveSuc,
                    decoration: const InputDecoration(
                      labelText: 'Sucursal (usuario)',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: 'TODAS',
                        child: Text('TODAS'),
                      ),
                      for (final suc in sucOptions)
                        DropdownMenuItem(value: suc, child: Text(suc)),
                    ],
                    onChanged: (value) =>
                        setState(() => _selectedSucUsuario = value ?? 'TODAS'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('f-depto-$effectiveDepto'),
                    initialValue: effectiveDepto,
                    decoration: const InputDecoration(
                      labelText: 'Departamento',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: 'TODOS',
                        child: Text('TODOS'),
                      ),
                      for (final depto in deptoOptions)
                        DropdownMenuItem(value: depto, child: Text(depto)),
                    ],
                    onChanged: (value) =>
                        setState(() => _selectedDepto = value ?? 'TODOS'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              key: ValueKey(
                'modulo-${_selectedModulo ?? ''}-${widget.lockIdentityFields}',
              ),
              initialValue: _selectedModulo,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Módulo Front'),
              items: moduloItems
                  .map(
                    (modulo) => DropdownMenuItem<String>(
                      value: modulo.codigo,
                      child: Text(
                        modulo.label,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: widget.lockIdentityFields
                  ? null
                  : (value) => setState(() => _selectedModulo = value),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              key: ValueKey(
                'usuario-${_selectedUsuario ?? ''}-${widget.lockIdentityFields}',
              ),
              initialValue: _selectedUsuario,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Usuario'),
              items: usuarioItems
                  .map(
                    (usuario) => DropdownMenuItem<String>(
                      value: usuario.username,
                      child: Text(
                        usuario.label,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: widget.lockIdentityFields
                  ? null
                  : (value) => setState(() => _selectedUsuario = value),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Sucursales seleccionadas: ${_selectedSucursales.length}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: ListView(
                children: [
                  for (final sucursal in orderedSucursales)
                    CheckboxListTile(
                      value: _selectedSucursales.contains(sucursal.suc),
                      title: Text(
                        '${sucursal.suc} - ${sucursal.desc ?? 'Sin descripción'}',
                      ),
                      subtitle: Text(
                        sucursal.zona?.isEmpty == false
                            ? sucursal.zona!
                            : 'Sin zona',
                      ),
                      onChanged: (selected) {
                        setState(() {
                          if (selected == true) {
                            _selectedSucursales.add(sucursal.suc);
                          } else {
                            _selectedSucursales.remove(sucursal.suc);
                          }
                        });
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final modulo = _selectedModulo?.trim() ?? '';
            final usuario = _selectedUsuario?.trim() ?? '';
            if (modulo.isEmpty || usuario.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Selecciona un módulo y un usuario.'),
                ),
              );
              return;
            }
            Navigator.pop(
              context,
              _AccessRegSucEditorResult(
                modulo: modulo,
                usuario: usuario,
                selectedSucursales: _selectedSucursales,
              ),
            );
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _AccessRegSucCatalogs {
  const _AccessRegSucCatalogs({
    required this.sucursales,
    required this.modulos,
    required this.usuarios,
  });

  final List<SucursalModel> sucursales;
  final List<_ModuloOption> modulos;
  final List<_UsuarioOption> usuarios;
}

class _ModuloOption {
  const _ModuloOption({
    required this.codigo,
    required this.nombre,
    required this.depto,
    required this.activo,
  });

  final String codigo;
  final String nombre;
  final String? depto;
  final bool activo;

  factory _ModuloOption.fromAccessModuloFront(AccessModuloFront model) {
    return _ModuloOption(
      codigo: model.codigo,
      nombre: model.nombre,
      depto: model.depto,
      activo: model.activo,
    );
  }

  String get label {
    final deptoTxt = (depto == null || depto!.trim().isEmpty)
        ? 'SIN DEPTO'
        : depto!;
    final statusTxt = activo ? 'Activo' : 'Inactivo';
    return '$codigo - $nombre · $deptoTxt · $statusTxt';
  }
}

class _UsuarioOption {
  const _UsuarioOption({
    required this.username,
    required this.nombreCompleto,
    required this.estatus,
    required this.suc,
    required this.sucDesc,
    required this.deptoNombre,
  });

  final String username;
  final String nombreCompleto;
  final String estatus;
  final String? suc;
  final String? sucDesc;
  final String? deptoNombre;

  factory _UsuarioOption.fromUser(UserModel model) {
    return _UsuarioOption(
      username: model.username,
      nombreCompleto: model.displayName,
      estatus: model.estatus,
      suc: model.suc,
      sucDesc: model.sucDesc,
      deptoNombre: model.deptoNombre,
    );
  }

  String get label {
    final sucTxt = (suc ?? '').trim();
    final deptoTxt = (deptoNombre ?? '').trim();
    final sucDescTxt = (sucDesc ?? '').trim();
    final sucLabel = sucTxt.isEmpty
        ? 'SIN SUC'
        : (sucDescTxt.isEmpty ? sucTxt : '$sucTxt - $sucDescTxt');
    final deptoLabel = deptoTxt.isEmpty ? 'SIN DEPTO' : deptoTxt.toUpperCase();
    return '$username - $nombreCompleto · $estatus · $sucLabel · $deptoLabel';
  }
}
