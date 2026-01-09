import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../deptos/deptos_providers.dart';
import 'puestos_providers.dart';

class PuestoFormPage extends ConsumerStatefulWidget {
  const PuestoFormPage({super.key, this.puestoId});

  final int? puestoId;

  @override
  ConsumerState<PuestoFormPage> createState() => _PuestoFormPageState();
}

class _PuestoFormPageState extends ConsumerState<PuestoFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  int? _deptoId;
  bool _activo = true;
  bool _saving = false;
  late Future<void> _loader;

  @override
  void initState() {
    super.initState();
    _loader = _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (widget.puestoId == null) return;
    final puesto = await ref.read(puestosApiProvider).fetchPuesto(widget.puestoId!);
    _nombreCtrl.text = puesto.nombre;
    _deptoId = puesto.idDepto;
    _activo = puesto.activo;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_deptoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona un departamento')));
      return;
    }
    setState(() => _saving = true);

    final payload = {
      'IDDEPTO': _deptoId,
      'NOMBRE': _nombreCtrl.text.trim(),
      'ACTIVO': _activo,
    };

    try {
      if (widget.puestoId == null) {
        await ref.read(puestosApiProvider).createPuesto(payload);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Puesto creado')));
      } else {
        await ref.read(puestosApiProvider).updatePuesto(widget.puestoId!, payload);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Puesto actualizado')));
      }
      ref.invalidate(puestosListProvider);
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
    final deptosAsync = ref.watch(deptosListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(widget.puestoId == null ? 'Nuevo puesto' : 'Editar puesto')),
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
                  deptosAsync.when(
                    data: (deptos) {
                      final selected = _deptoId ?? (deptos.isNotEmpty ? deptos.first.id : null);
                      if (_deptoId == null && selected != null) _deptoId = selected;
                      return DropdownButtonFormField<int>(
                        initialValue: selected,
                        decoration: const InputDecoration(labelText: 'Departamento'),
                        items: deptos
                            .map((d) => DropdownMenuItem<int>(value: d.id, child: Text('${d.id} - ${d.nombre}')))
                            .toList(),
                        onChanged: _saving ? null : (v) => setState(() => _deptoId = v),
                        validator: (v) => v == null ? 'Requerido' : null,
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Error deptos: $e'),
                  ),
                  const SizedBox(height: 12),
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
