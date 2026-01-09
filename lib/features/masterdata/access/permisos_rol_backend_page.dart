import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'access_models.dart';
import 'access_providers.dart';

class PermisosRolBackendPage extends ConsumerStatefulWidget {
  const PermisosRolBackendPage({super.key});

  @override
  ConsumerState<PermisosRolBackendPage> createState() => _PermisosRolBackendPageState();
}

class _PermisosRolBackendPageState extends ConsumerState<PermisosRolBackendPage> {
  int? _roleId;

  @override
  Widget build(BuildContext context) {
    final rolesAsync = ref.watch(accessRolesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Permisos por Rol (Backend)')),
      body: rolesAsync.when(
        data: (roles) {
          if (roles.isEmpty) {
            return const Center(child: Text('No hay roles disponibles.'));
          }

          if (_roleId == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _roleId = roles.first.id);
            });
          }

          final selectedRole = roles.firstWhere((r) => r.id == _roleId, orElse: () => roles.first);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: DropdownButtonFormField<int>(
                  key: ValueKey(selectedRole.id),
                  initialValue: selectedRole.id,
                  decoration: const InputDecoration(
                    labelText: 'Rol',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final role in roles)
                      DropdownMenuItem(
                        value: role.id,
                        child: Text('${role.codigo} - ${role.nombre}'),
                      ),
                  ],
                  onChanged: (value) => setState(() => _roleId = value),
                ),
              ),
              Expanded(
                child: _roleId == null
                    ? const Center(child: Text('Selecciona un rol.'))
                    : _PermsList(roleId: _roleId!),
              ),
            ],
          );
        },
        error: (e, _) => Center(child: Text('Error: $e')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _PermsList extends ConsumerWidget {
  const _PermsList({required this.roleId});

  final int roleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permsAsync = ref.watch(backendPermsProvider(roleId));

    return permsAsync.when(
      data: (items) => ListView(
        padding: const EdgeInsets.all(12),
        children: [
          for (final perm in items)
            _PermCard(
              roleId: roleId,
              perm: perm,
            ),
        ],
      ),
      error: (e, _) => Center(child: Text('Error: $e')),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}

class _PermCard extends ConsumerWidget {
  const _PermCard({required this.roleId, required this.perm});

  final int roleId;
  final BackendGroupPerm perm;

  Future<void> _updatePerm(WidgetRef ref, BuildContext context, BackendGroupPerm updated) async {
    try {
      await ref.read(accessApiProvider).setBackendPerm(roleId, updated);
      ref.invalidate(backendPermsProvider(roleId));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mods = perm.modulos.isEmpty
        ? 'Sin módulos'
        : perm.modulos.map((m) => m.codigo).join(', ');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              perm.grupoNombre,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(mods),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Activo'),
                const SizedBox(width: 8),
                Switch(
                  value: perm.activo,
                  onChanged: (v) => _updatePerm(ref, context, perm.copyWith(activo: v)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _PermSwitch(
                  label: 'R',
                  value: perm.canRead,
                  onChanged: (v) => _updatePerm(ref, context, perm.copyWith(canRead: v)),
                ),
                _PermSwitch(
                  label: 'C',
                  value: perm.canCreate,
                  onChanged: (v) => _updatePerm(ref, context, perm.copyWith(canCreate: v)),
                ),
                _PermSwitch(
                  label: 'U',
                  value: perm.canUpdate,
                  onChanged: (v) => _updatePerm(ref, context, perm.copyWith(canUpdate: v)),
                ),
                _PermSwitch(
                  label: 'D',
                  value: perm.canDelete,
                  onChanged: (v) => _updatePerm(ref, context, perm.copyWith(canDelete: v)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PermSwitch extends StatelessWidget {
  const _PermSwitch({required this.label, required this.value, required this.onChanged});

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}
