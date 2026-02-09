import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'access_reg_suc_providers.dart';

class AccessRegSucFormPage extends ConsumerStatefulWidget {
  const AccessRegSucFormPage({super.key, this.modulo, this.usuario, this.suc});

  final String? modulo;
  final String? usuario;
  final String? suc;

  @override
  ConsumerState<AccessRegSucFormPage> createState() => _AccessRegSucFormPageState();
}

class _AccessRegSucFormPageState extends ConsumerState<AccessRegSucFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _moduloCtrl = TextEditingController();
  final _usuarioCtrl = TextEditingController();
  final _sucCtrl = TextEditingController();
  bool _activo = true;
  bool _saving = false;
  late Future<void> _loader;

  bool get _isNew => widget.modulo == null || widget.usuario == null || widget.suc == null;

  @override
  void initState() {
    super.initState();
    _loader = _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (_isNew) return;
    final row = await ref.read(accessRegSucApiProvider).fetchOne(widget.modulo!, widget.usuario!, widget.suc!);
    _moduloCtrl.text = row.modulo;
    _usuarioCtrl.text = row.usuario;
    _sucCtrl.text = row.suc;
    _activo = row.activo;
  }

  @override
  void dispose() {
    _moduloCtrl.dispose();
    _usuarioCtrl.dispose();
    _sucCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      if (_isNew) {
        final payload = {
          'MODULO': _moduloCtrl.text.trim(),
          'USUARIO': _usuarioCtrl.text.trim(),
          'SUC': _sucCtrl.text.trim(),
          'ACTIVO': _activo,
        };
        await ref.read(accessRegSucApiProvider).create(payload);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Acceso creado')));
        }
      } else {
        final payload = {
          'ACTIVO': _activo,
        };
        await ref.read(accessRegSucApiProvider).update(widget.modulo!, widget.usuario!, widget.suc!, payload);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Acceso actualizado')));
        }
      }
      ref.invalidate(accessRegSucListProvider);
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
      appBar: AppBar(title: Text(_isNew ? 'Nuevo acceso' : 'Editar acceso')),
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
                    controller: _moduloCtrl,
                    decoration: const InputDecoration(labelText: 'Módulo'),
                    enabled: !_saving && _isNew,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _usuarioCtrl,
                    decoration: const InputDecoration(labelText: 'Usuario'),
                    enabled: !_saving && _isNew,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _sucCtrl,
                    decoration: const InputDecoration(labelText: 'Sucursal'),
                    enabled: !_saving && _isNew,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
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
                      icon: _saving
                          ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.save),
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
