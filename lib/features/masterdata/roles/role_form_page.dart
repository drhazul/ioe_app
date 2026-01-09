import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'roles_providers.dart';

class RoleFormPage extends ConsumerStatefulWidget {
  const RoleFormPage({super.key, this.roleId});

  final int? roleId;

  @override
  ConsumerState<RoleFormPage> createState() => _RoleFormPageState();
}

class _RoleFormPageState extends ConsumerState<RoleFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _codigoCtrl = TextEditingController();
  final _nombreCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  late Future<void> _loader;
  bool _activo = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loader = _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (widget.roleId == null) return;
    final role = await ref.read(rolesApiProvider).fetchRole(widget.roleId!);
    _codigoCtrl.text = role.codigo;
    _nombreCtrl.text = role.nombre;
    _descCtrl.text = role.descripcion ?? '';
    _activo = role.activo;
  }

  @override
  void dispose() {
    _codigoCtrl.dispose();
    _nombreCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final payload = {
      'CODIGO': _codigoCtrl.text.trim(),
      'NOMBRE': _nombreCtrl.text.trim(),
      'DESCRIPCION': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      'ACTIVO': _activo,
    };

    try {
      if (widget.roleId == null) {
        await ref.read(rolesApiProvider).createRole(payload);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rol creado')));
      } else {
        await ref.read(rolesApiProvider).updateRole(widget.roleId!, payload);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rol actualizado')));
      }
      ref.invalidate(rolesListProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.roleId == null ? 'Nuevo rol' : 'Editar rol')),
      body: FutureBuilder<void>(
        future: _loader,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _codigoCtrl,
                    decoration: const InputDecoration(labelText: 'Código'),
                    enabled: !_saving,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nombreCtrl,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                    enabled: !_saving,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descCtrl,
                    decoration: const InputDecoration(labelText: 'Descripción'),
                    enabled: !_saving,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Activo'),
                    value: _activo,
                    onChanged: _saving ? null : (v) => setState(() => _activo = v),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: _saving ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save),
                      label: Text(_saving ? 'Guardando...' : 'Guardar'),
                      onPressed: _saving ? null : _submit,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
