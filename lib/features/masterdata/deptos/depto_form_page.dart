import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'deptos_providers.dart';

class DeptoFormPage extends ConsumerStatefulWidget {
  const DeptoFormPage({super.key, this.deptoId});

  final int? deptoId;

  @override
  ConsumerState<DeptoFormPage> createState() => _DeptoFormPageState();
}

class _DeptoFormPageState extends ConsumerState<DeptoFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  bool _activo = true;
  bool _saving = false;
  late Future<void> _loader;

  @override
  void initState() {
    super.initState();
    _loader = _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (widget.deptoId == null) return;
    final depto = await ref.read(deptosApiProvider).fetchDepto(widget.deptoId!);
    _nombreCtrl.text = depto.nombre;
    _activo = depto.activo;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final payload = {
      'NOMBRE': _nombreCtrl.text.trim(),
      'ACTIVO': _activo,
    };

    try {
      if (widget.deptoId == null) {
        await ref.read(deptosApiProvider).createDepto(payload);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Departamento creado')));
      } else {
        await ref.read(deptosApiProvider).updateDepto(widget.deptoId!, payload);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Departamento actualizado')));
      }
      ref.invalidate(deptosListProvider);
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
      appBar: AppBar(title: Text(widget.deptoId == null ? 'Nuevo departamento' : 'Editar departamento')),
      body: FutureBuilder<void>(
        future: _loader,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nombreCtrl,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                    enabled: !_saving,
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
                      icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save),
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
