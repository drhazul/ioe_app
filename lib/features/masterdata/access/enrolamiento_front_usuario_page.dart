import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'access_models.dart';
import 'access_providers.dart';

class EnrolamientoFrontUsuarioPage extends ConsumerStatefulWidget {
  const EnrolamientoFrontUsuarioPage({super.key});

  @override
  ConsumerState<EnrolamientoFrontUsuarioPage> createState() =>
      _EnrolamientoFrontUsuarioPageState();
}

class _EnrolamientoFrontUsuarioPageState
    extends ConsumerState<EnrolamientoFrontUsuarioPage> {
  int? _userId;
  String _selectedSuc = 'TODAS';
  String _selectedDepto = 'TODOS';

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(accessUsersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Enrolamiento Usuario → Grupo Front')),
      body: usersAsync.when(
        data: (users) {
          if (users.isEmpty) {
            return const Center(child: Text('No hay usuarios disponibles.'));
          }

          final sucs = <String>{
            for (final user in users)
              if ((user.suc ?? '').trim().isNotEmpty) user.suc!.trim(),
          }.toList()..sort();
          final deptos = <String>{
            for (final user in users)
              if ((user.deptoNombre ?? '').trim().isNotEmpty)
                user.deptoNombre!.trim(),
          }.toList()..sort();

          final effectiveSuc =
              _selectedSuc == 'TODAS' || sucs.contains(_selectedSuc)
              ? _selectedSuc
              : 'TODAS';
          final effectiveDepto =
              _selectedDepto == 'TODOS' || deptos.contains(_selectedDepto)
              ? _selectedDepto
              : 'TODOS';

          final filteredUsers = users.where((user) {
            final userSuc = (user.suc ?? '').trim();
            final userDepto = (user.deptoNombre ?? '').trim();
            if (effectiveSuc != 'TODAS' && userSuc != effectiveSuc) {
              return false;
            }
            if (effectiveDepto != 'TODOS' && userDepto != effectiveDepto) {
              return false;
            }
            return true;
          }).toList();

          if (_userId == null && filteredUsers.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _userId = filteredUsers.first.id);
            });
          }

          AccessUser? selectedUser;
          for (final user in filteredUsers) {
            if (user.id == _userId) {
              selectedUser = user;
              break;
            }
          }
          if (selectedUser == null && filteredUsers.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _userId = filteredUsers.first.id);
            });
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            key: ValueKey('suc-$effectiveSuc'),
                            initialValue: effectiveSuc,
                            decoration: const InputDecoration(
                              labelText: 'Sucursal',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: 'TODAS',
                                child: Text('TODAS'),
                              ),
                              for (final suc in sucs)
                                DropdownMenuItem(
                                  value: suc,
                                  child: Text(_sucLabel(suc, users)),
                                ),
                            ],
                            onChanged: (value) =>
                                setState(() => _selectedSuc = value ?? 'TODAS'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            key: ValueKey('depto-$effectiveDepto'),
                            initialValue: effectiveDepto,
                            decoration: const InputDecoration(
                              labelText: 'Departamento',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: 'TODOS',
                                child: Text('TODOS'),
                              ),
                              for (final depto in deptos)
                                DropdownMenuItem(
                                  value: depto,
                                  child: Text(depto),
                                ),
                            ],
                            onChanged: (value) => setState(
                              () => _selectedDepto = value ?? 'TODOS',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      key: ValueKey(
                        'usr-${selectedUser?.id ?? 0}-$effectiveSuc-$effectiveDepto',
                      ),
                      initialValue: selectedUser?.id,
                      decoration: const InputDecoration(
                        labelText: 'Usuario',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final user in filteredUsers)
                          DropdownMenuItem(
                            value: user.id,
                            child: Text(_userLabel(user)),
                          ),
                      ],
                      onChanged: filteredUsers.isEmpty
                          ? null
                          : (value) => setState(() => _userId = value),
                    ),
                  ],
                ),
              ),
              if (filteredUsers.isEmpty)
                const Expanded(
                  child: Center(
                    child: Text(
                      'No hay usuarios para los filtros seleccionados.',
                    ),
                  ),
                ),
              if (filteredUsers.isNotEmpty)
                Expanded(
                  child: selectedUser == null
                      ? const Center(child: Text('Selecciona un usuario.'))
                      : _UserEnrollmentsList(userId: selectedUser.id),
                ),
            ],
          );
        },
        error: (e, _) => Center(child: Text('Error: $e')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  String _userLabel(AccessUser user) {
    final fullName = '${user.nombre ?? ''} ${user.apellidos ?? ''}'.trim();
    if (fullName.isEmpty) {
      return '${user.username} (${user.estatus})';
    }
    return '${user.username} - $fullName (${user.estatus})';
  }

  String _sucLabel(String suc, List<AccessUser> users) {
    String? desc;
    for (final user in users) {
      final userSuc = (user.suc ?? '').trim();
      final userDesc = (user.sucDesc ?? '').trim();
      if (userSuc == suc && userDesc.isNotEmpty) {
        desc = userDesc;
        break;
      }
    }
    final cleanDesc = (desc ?? '').trim();
    if (cleanDesc.isEmpty) return suc;
    return '$suc - $cleanDesc';
  }
}

class _UserEnrollmentsList extends ConsumerWidget {
  const _UserEnrollmentsList({required this.userId});

  final int userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enrollAsync = ref.watch(frontUserEnrollmentsProvider(userId));

    return enrollAsync.when(
      data: (items) => ListView(
        padding: const EdgeInsets.all(12),
        children: [
          for (final item in items)
            _UserEnrollmentCard(userId: userId, enrollment: item),
        ],
      ),
      error: (e, _) => Center(child: Text('Error: $e')),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}

class _UserEnrollmentCard extends ConsumerWidget {
  const _UserEnrollmentCard({required this.userId, required this.enrollment});

  final int userId;
  final FrontGroupEnrollment enrollment;

  Future<void> _update(
    WidgetRef ref,
    BuildContext context,
    FrontGroupEnrollment updated,
  ) async {
    try {
      await ref.read(accessApiProvider).setFrontUserEnrollment(userId, updated);
      ref.invalidate(frontUserEnrollmentsProvider(userId));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
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
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
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
