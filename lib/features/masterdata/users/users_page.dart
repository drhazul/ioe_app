import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'users_models.dart';
import 'users_providers.dart';

const _allFilter = '__ALL__';
const _noneFilter = '__NONE__';

enum _UsersViewMode {
  lista,
  sucursal,
  departamento,
}

class UsersPage extends ConsumerStatefulWidget {
  const UsersPage({super.key});

  @override
  ConsumerState<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends ConsumerState<UsersPage> {
  _UsersViewMode _viewMode = _UsersViewMode.sucursal;
  String _selectedSuc = _allFilter;
  String _selectedDepto = _allFilter;

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(usersListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Usuarios'),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(usersListProvider),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refrescar',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/masterdata/users/new'),
        child: const Icon(Icons.add),
      ),
      body: usersAsync.when(
        data: (users) => _UsersContent(
          users: users,
          ref: ref,
          viewMode: _viewMode,
          selectedSuc: _selectedSuc,
          selectedDepto: _selectedDepto,
          onModeChanged: (value) => setState(() => _viewMode = value),
          onSucChanged: (value) => setState(() => _selectedSuc = value),
          onDeptoChanged: (value) => setState(() => _selectedDepto = value),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _UsersContent extends StatelessWidget {
  const _UsersContent({
    required this.users,
    required this.ref,
    required this.viewMode,
    required this.selectedSuc,
    required this.selectedDepto,
    required this.onModeChanged,
    required this.onSucChanged,
    required this.onDeptoChanged,
  });

  final List<UserModel> users;
  final WidgetRef ref;
  final _UsersViewMode viewMode;
  final String selectedSuc;
  final String selectedDepto;
  final ValueChanged<_UsersViewMode> onModeChanged;
  final ValueChanged<String> onSucChanged;
  final ValueChanged<String> onDeptoChanged;

  @override
  Widget build(BuildContext context) {
    final sucOptions = _buildSucursalOptions(users);
    final deptoOptions = _buildDeptoOptions(users);

    final effectiveSuc = sucOptions.any((o) => o.value == selectedSuc)
        ? selectedSuc
        : _allFilter;
    final effectiveDepto = deptoOptions.any((o) => o.value == selectedDepto)
        ? selectedDepto
        : _allFilter;

    final filtered = _filterUsers(users, effectiveSuc, effectiveDepto);
    final rows = _buildRows(filtered, viewMode, ref);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 260,
                child: DropdownButtonFormField<_UsersViewMode>(
                  initialValue: viewMode,
                  decoration: const InputDecoration(labelText: 'Visualización'),
                  items: const [
                    DropdownMenuItem(
                      value: _UsersViewMode.lista,
                      child: Text('Lista general'),
                    ),
                    DropdownMenuItem(
                      value: _UsersViewMode.sucursal,
                      child: Text('Agrupar por sucursal'),
                    ),
                    DropdownMenuItem(
                      value: _UsersViewMode.departamento,
                      child: Text('Agrupar por departamento'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) onModeChanged(value);
                  },
                ),
              ),
              SizedBox(
                width: 260,
                child: DropdownButtonFormField<String>(
                  initialValue: effectiveSuc,
                  decoration: const InputDecoration(labelText: 'Filtro sucursal'),
                  items: sucOptions
                      .map(
                        (option) => DropdownMenuItem<String>(
                          value: option.value,
                          child: Text(option.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) onSucChanged(value);
                  },
                ),
              ),
              SizedBox(
                width: 280,
                child: DropdownButtonFormField<String>(
                  initialValue: effectiveDepto,
                  decoration: const InputDecoration(
                    labelText: 'Filtro departamento',
                  ),
                  items: deptoOptions
                      .map(
                        (option) => DropdownMenuItem<String>(
                          value: option.value,
                          child: Text(option.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) onDeptoChanged(value);
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(usersListProvider);
              await ref.read(usersListProvider.future);
            },
            child: rows.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 96),
                      Center(child: Text('No hay usuarios para los filtros seleccionados')),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: rows.length,
                    itemBuilder: (_, index) => rows[index],
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                  ),
          ),
        ),
      ],
    );
  }

  List<_FilterOption> _buildSucursalOptions(List<UserModel> users) {
    final map = <String, String>{};
    for (final user in users) {
      final suc = (user.suc ?? '').trim();
      if (suc.isEmpty) {
        map[_noneFilter] = 'Sin sucursal';
        continue;
      }
      final desc = (user.sucDesc ?? '').trim();
      map[suc] = desc.isEmpty ? suc : '$suc - $desc';
    }

    final options = map.entries
        .map((entry) => _FilterOption(value: entry.key, label: entry.value))
        .toList()
      ..sort((a, b) => a.label.compareTo(b.label));

    return [
      const _FilterOption(value: _allFilter, label: 'Todas'),
      ...options,
    ];
  }

  List<_FilterOption> _buildDeptoOptions(List<UserModel> users) {
    final map = <String, String>{};
    for (final user in users) {
      final key = user.idDepto?.toString() ?? _noneFilter;
      final label = (user.deptoNombre ?? '').trim();
      map[key] = label.isEmpty ? 'Sin departamento' : label;
    }

    final options = map.entries
        .map((entry) => _FilterOption(value: entry.key, label: entry.value))
        .toList()
      ..sort((a, b) => a.label.compareTo(b.label));

    return [
      const _FilterOption(value: _allFilter, label: 'Todos'),
      ...options,
    ];
  }

  List<UserModel> _filterUsers(
    List<UserModel> users,
    String sucFilter,
    String deptoFilter,
  ) {
    return users.where((user) {
      if (sucFilter != _allFilter) {
        final suc = (user.suc ?? '').trim();
        if (sucFilter == _noneFilter) {
          if (suc.isNotEmpty) return false;
        } else if (suc != sucFilter) {
          return false;
        }
      }

      if (deptoFilter != _allFilter) {
        final deptoKey = user.idDepto?.toString() ?? _noneFilter;
        if (deptoKey != deptoFilter) return false;
      }

      return true;
    }).toList();
  }

  List<Widget> _buildRows(
    List<UserModel> users,
    _UsersViewMode mode,
    WidgetRef ref,
  ) {
    final sortedUsers = [...users]
      ..sort(
        (a, b) => a.displayName.toUpperCase().compareTo(
              b.displayName.toUpperCase(),
            ),
      );

    if (mode == _UsersViewMode.lista) {
      return sortedUsers
          .map((user) => _UserTile(user: user, ref: ref))
          .toList();
    }

    final groups = <String, List<UserModel>>{};
    for (final user in sortedUsers) {
      final key = mode == _UsersViewMode.sucursal
          ? _sucursalLabel(user)
          : _deptoLabel(user);
      groups.putIfAbsent(key, () => []).add(user);
    }

    final groupKeys = groups.keys.toList()..sort();
    final rows = <Widget>[];

    for (final key in groupKeys) {
      final groupUsers = groups[key]!;
      rows.add(_GroupHeader(title: key, total: groupUsers.length));
      for (final user in groupUsers) {
        rows.add(_UserTile(user: user, ref: ref));
      }
    }

    return rows;
  }

  String _sucursalLabel(UserModel user) {
    final suc = (user.suc ?? '').trim();
    if (suc.isEmpty) return 'Sucursal: Sin sucursal';
    final desc = (user.sucDesc ?? '').trim();
    return desc.isEmpty ? 'Sucursal: $suc' : 'Sucursal: $suc - $desc';
  }

  String _deptoLabel(UserModel user) {
    final depto = (user.deptoNombre ?? '').trim();
    return depto.isEmpty
        ? 'Departamento: Sin departamento'
        : 'Departamento: $depto';
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.title, required this.total});

  final String title;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Text('$total usuario(s)'),
        ],
      ),
    );
  }
}

class _FilterOption {
  const _FilterOption({required this.value, required this.label});

  final String value;
  final String label;
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user, required this.ref});

  final UserModel user;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final role = user.rolNombre ?? 'Rol ${user.idRol}';
    final depto = user.deptoNombre != null ? 'Depto: ${user.deptoNombre}' : null;
    final puesto = user.puestoNombre != null ? 'Puesto: ${user.puestoNombre}' : null;
    final suc = user.suc != null
        ? user.sucDesc != null && user.sucDesc!.trim().isNotEmpty
              ? 'Suc: ${user.suc} - ${user.sucDesc}'
              : 'Suc: ${user.suc}'
        : null;

    return Card(
      child: ListTile(
        title: Text('${user.displayName} (${user.username})'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${user.mail} · $role · Estatus: ${user.estatus}'),
            if (depto != null || puesto != null || suc != null)
              Text([depto, puesto, suc].where((v) => v != null).join(' · ')),
            if (user.forzarCambioPass)
              const Text(
                'Cambio de contraseña pendiente en próximo acceso',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => context.go('/masterdata/users/${user.id}'),
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _confirmDelete(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar usuario'),
        content: Text('¿Eliminar a ${user.username}?'),
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
    if (!context.mounted) return;

    try {
      await ref.read(usersApiProvider).deleteUser(user.id);
      ref.invalidate(usersListProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Usuario eliminado')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
    }
  }
}
