import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ioe_app/core/api_error.dart';

import '../roles/roles_providers.dart';
import '../deptos/deptos_providers.dart';
import '../puestos/puestos_providers.dart';
import '../sucursales/sucursales_providers.dart';
import 'users_providers.dart';

class UserFormPage extends ConsumerStatefulWidget {
  const UserFormPage({super.key, this.userId});

  final int? userId;

  @override
  ConsumerState<UserFormPage> createState() => _UserFormPageState();
}

class _UserFormPageState extends ConsumerState<UserFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nombreCtrl = TextEditingController();
  final _apellidosCtrl = TextEditingController();
  final _mailCtrl = TextEditingController();
  final _nivelCtrl = TextEditingController(text: '1');

  late Future<void> _loader;
  bool _saving = false;
  String _estatus = 'ACTIVO';
  int? _roleId;
  int? _deptoId;
  int? _puestoId;
  String? _suc;

  @override
  void initState() {
    super.initState();
    _loader = _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (widget.userId == null) return;
    final user = await ref.read(usersApiProvider).fetchUser(widget.userId!);
    _usernameCtrl.text = user.username;
    _nombreCtrl.text = user.nombre ?? '';
    _apellidosCtrl.text = user.apellidos ?? '';
    _mailCtrl.text = user.mail;
    _nivelCtrl.text = user.nivel.toString();
    _estatus = user.estatus;
    _roleId = user.idRol;
    _deptoId = user.idDepto;
    _puestoId = user.idPuesto;
    _suc = (user.suc?.trim().isEmpty ?? true) ? null : user.suc;
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _nombreCtrl.dispose();
    _apellidosCtrl.dispose();
    _mailCtrl.dispose();
    _nivelCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_roleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona un rol')));
      return;
    }
    setState(() => _saving = true);

    final nivel = int.tryParse(_nivelCtrl.text.trim()) ?? 0;
    final suc = _suc?.trim();

    final payload = <String, dynamic>{
      'USERNAME': _usernameCtrl.text.trim(),
      'MAIL': _mailCtrl.text.trim(),
      'ESTATUS': _estatus,
      'NIVEL': nivel,
      'IDROL': _roleId,
      'NOMBRE': _nombreCtrl.text.trim().isEmpty ? null : _nombreCtrl.text.trim(),
      'APELLIDOS': _apellidosCtrl.text.trim().isEmpty ? null : _apellidosCtrl.text.trim(),
      'IDDEPTO': _deptoId,
      'IDPUESTO': _puestoId,
      'SUC': (suc == null || suc.isEmpty) ? null : suc,
    };

    if (_passwordCtrl.text.trim().isNotEmpty) {
      payload['PASSWORD'] = _passwordCtrl.text.trim();
    } else if (widget.userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contraseña requerida para crear')));
      if (mounted) setState(() => _saving = false);
      return;
    }

    try {
      if (widget.userId == null) {
        await ref.read(usersApiProvider).createUser(payload);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usuario creado')));
      } else {
        await ref.read(usersApiProvider).updateUser(widget.userId!, payload);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usuario actualizado')));
      }
      ref.invalidate(usersListProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        final msg = apiErrorMessage(e, fallback: 'No se pudo guardar');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar: $msg')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rolesAsync = ref.watch(rolesListProvider);
    final deptosAsync = ref.watch(deptosListProvider);
    final puestosAsync = ref.watch(puestosListProvider);
    final sucursalesAsync = ref.watch(sucursalesListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(widget.userId == null ? 'Nuevo usuario' : 'Editar usuario')),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _usernameCtrl,
                    decoration: const InputDecoration(labelText: 'Usuario'),
                    enabled: !_saving,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordCtrl,
                    decoration: InputDecoration(labelText: widget.userId == null ? 'Contraseña' : 'Contraseña (dejar vacío para mantener)'),
                    obscureText: true,
                    enabled: !_saving,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _mailCtrl,
                    decoration: const InputDecoration(labelText: 'Correo'),
                    enabled: !_saving,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _estatus,
                    items: const [
                      DropdownMenuItem(value: 'ACTIVO', child: Text('ACTIVO')),
                      DropdownMenuItem(value: 'INACTIVO', child: Text('INACTIVO')),
                    ],
                    onChanged: _saving ? null : (v) => setState(() => _estatus = v ?? 'ACTIVO'),
                    decoration: const InputDecoration(labelText: 'Estatus'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nivelCtrl,
                    decoration: const InputDecoration(labelText: 'Nivel'),
                    enabled: !_saving,
                    keyboardType: TextInputType.number,
                    validator: (v) => v == null || int.tryParse(v) == null ? 'Nivel numérico' : null,
                  ),
                  const SizedBox(height: 12),
                  rolesAsync.when(
                    data: (roles) {
                      final selected = _roleId ?? (roles.isNotEmpty ? roles.first.id : null);
                      if (_roleId == null && selected != null) _roleId = selected;
                      return DropdownButtonFormField<int>(
                        initialValue: selected,
                        decoration: const InputDecoration(labelText: 'Rol'),
                        items: roles.map((r) => DropdownMenuItem(value: r.id, child: Text('${r.codigo} - ${r.nombre}'))).toList(),
                        onChanged: _saving ? null : (v) => setState(() => _roleId = v),
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Error roles: $e'),
                  ),
                  const SizedBox(height: 12),
                  deptosAsync.when(
                    data: (deptos) => DropdownButtonFormField<int?>(
                      initialValue: _deptoId,
                      decoration: const InputDecoration(labelText: 'Departamento'),
                      items: [
                        const DropdownMenuItem<int?>(value: null, child: Text('Sin departamento')),
                        ...deptos.map((d) => DropdownMenuItem<int?>(value: d.id, child: Text(d.nombre))),
                      ],
                      onChanged: _saving ? null : (v) => setState(() => _deptoId = v),
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Error deptos: $e'),
                  ),
                  const SizedBox(height: 12),
                  puestosAsync.when(
                    data: (puestos) {
                      final selectedPuesto = puestos.any((p) => p.id == _puestoId) ? _puestoId : null;
                      return DropdownButtonFormField<int?>(
                        initialValue: selectedPuesto,
                        decoration: const InputDecoration(labelText: 'Puesto'),
                        items: [
                          const DropdownMenuItem<int?>(value: null, child: Text('Sin puesto')),
                          ...puestos.map(
                            (p) => DropdownMenuItem<int?>(
                              value: p.id,
                              child: Text(p.deptoNombre != null ? '${p.nombre} (${p.deptoNombre})' : p.nombre),
                            ),
                          ),
                        ],
                        onChanged: _saving ? null : (v) => setState(() => _puestoId = v),
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Error puestos: $e'),
                  ),
                  const SizedBox(height: 12),
                  sucursalesAsync.when(
                    data: (sucs) {
                      final selectedSuc = sucs.any((s) => s.suc == _suc) ? _suc : null;
                      return DropdownButtonFormField<String?>(
                        initialValue: selectedSuc,
                        decoration: const InputDecoration(labelText: 'Sucursal'),
                        items: [
                          const DropdownMenuItem<String?>(value: null, child: Text('Sin sucursal')),
                          ...sucs.map(
                            (s) => DropdownMenuItem<String?>(
                              value: s.suc,
                              child: Text(s.desc != null && s.desc!.isNotEmpty ? '${s.suc} - ${s.desc}' : s.suc),
                            ),
                          ),
                        ],
                        onChanged: _saving ? null : (v) => setState(() => _suc = v),
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Error sucursales: $e'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nombreCtrl,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                    enabled: !_saving,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _apellidosCtrl,
                    decoration: const InputDecoration(labelText: 'Apellidos'),
                    enabled: !_saving,
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
