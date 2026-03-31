import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ioe_app/features/masterdata/users/users_models.dart';
import 'package:ioe_app/features/masterdata/users/users_providers.dart';

class AdminOpvSelector extends ConsumerWidget {
  const AdminOpvSelector({
    super.key,
    required this.suc,
    required this.selectedOpv,
    required this.onOpvChanged,
    this.label = 'Usuario (OPV / Supervisor)',
  });

  final String suc;
  final String selectedOpv;
  final ValueChanged<String?> onOpvChanged;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final normalizedSuc = suc.trim().toUpperCase();
    final usersAsync = ref.watch(usersListProvider);
    return SizedBox(
      width: 220,
      child: usersAsync.when(
        data: (users) {
          final filtered = _filterUsers(users, normalizedSuc);
          final selectedValue = filtered.any((user) => user.username == selectedOpv)
              ? selectedOpv
              : null;
          final hasSuc = normalizedSuc.isNotEmpty;
          final helperText = hasSuc
              ? (filtered.isEmpty ? 'No hay operadores para esta sucursal' : null)
              : 'Selecciona una sucursal primero';
          return DropdownButtonFormField<String>(
            key: ValueKey(selectedValue),
            initialValue: selectedValue,
            isExpanded: true,
            items: filtered
                .map(
                  (user) => DropdownMenuItem<String>(
                    value: user.username,
                    child: Text(
                      _buildLabel(user),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: hasSuc && filtered.isNotEmpty
                ? (value) => onOpvChanged(value?.trim())
                : null,
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
              isDense: true,
              helperText: helperText,
            ),
          );
        },
        loading: () => _buildLoading(),
        error: (error, stack) => _buildError(),
      ),
    );
  }

  Widget _buildLoading() {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      child: const SizedBox(
        height: 24,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
    );
  }

  Widget _buildError() {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      child: const Text('No se pudo cargar la lista de usuarios'),
    );
  }

  List<UserModel> _filterUsers(List<UserModel> users, String suc) {
    final normalizedSuc = suc.trim().toUpperCase();
    return users
        .where((user) {
          final userSuc = (user.suc ?? '').trim().toUpperCase();
          if (normalizedSuc.isNotEmpty && userSuc != normalizedSuc) return false;
          final roleCode = (user.rolCodigo ?? '').trim().toUpperCase();
          final roleName = (user.rolNombre ?? '').trim().toUpperCase();
          return _isAllowedRole(roleCode) || _isAllowedRole(roleName);
        })
        .toList()
      ..sort((a, b) => a.username.compareTo(b.username));
  }

  bool _isAllowedRole(String value) {
    const keywords = ['OPV', 'SUPERV'];
    if (value.isEmpty) return false;
    return keywords.any((keyword) => value.contains(keyword));
  }

  String _buildLabel(UserModel user) {
    final roleLabel = (user.rolNombre ?? user.rolCodigo ?? '').trim();
    final displayName = user.displayName;
    if (roleLabel.isEmpty) {
      return '$displayName (${user.username})';
    }
    return '$displayName (${user.username}) · $roleLabel';
  }
}
