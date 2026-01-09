import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'access_models.dart';
import 'access_providers.dart';

class EnrolamientoFrontPage extends ConsumerStatefulWidget {
  const EnrolamientoFrontPage({super.key});

  @override
  ConsumerState<EnrolamientoFrontPage> createState() => _EnrolamientoFrontPageState();
}

class _EnrolamientoFrontPageState extends ConsumerState<EnrolamientoFrontPage> {
  int? _roleId;

  @override
  Widget build(BuildContext context) {
    final rolesAsync = ref.watch(accessRolesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Enrolamiento Rol → Grupo Front')),
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
                    : _EnrollmentsList(roleId: _roleId!),
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

class _EnrollmentsList extends ConsumerWidget {
  const _EnrollmentsList({required this.roleId});

  final int roleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enrollAsync = ref.watch(frontEnrollmentsProvider(roleId));

    return enrollAsync.when(
      data: (items) => ListView(
        padding: const EdgeInsets.all(12),
        children: [
          for (final item in items)
            _EnrollmentCard(
              roleId: roleId,
              enrollment: item,
            ),
        ],
      ),
      error: (e, _) => Center(child: Text('Error: $e')),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}

class _EnrollmentCard extends ConsumerWidget {
  const _EnrollmentCard({required this.roleId, required this.enrollment});

  final int roleId;
  final FrontGroupEnrollment enrollment;

  Future<void> _update(WidgetRef ref, BuildContext context, FrontGroupEnrollment updated) async {
    try {
      await ref.read(accessApiProvider).setFrontEnrollment(roleId, updated);
      ref.invalidate(frontEnrollmentsProvider(roleId));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mods = enrollment.mods.isEmpty
        ? 'Sin módulos'
        : enrollment.mods.map((m) => m.codigo).join(', ');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              enrollment.grupoNombre,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(mods),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text('Activo'),
                const SizedBox(width: 8),
                Switch(
                  value: enrollment.activo,
                  onChanged: (v) => _update(
                    ref,
                    context,
                    FrontGroupEnrollment(
                      idGrupmodFront: enrollment.idGrupmodFront,
                      grupoNombre: enrollment.grupoNombre,
                      activo: v,
                      mods: enrollment.mods,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
