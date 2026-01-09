import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'datmodulos_providers.dart';

class DatModuloFormPage extends ConsumerStatefulWidget {
  const DatModuloFormPage({super.key, this.modulo});

  final String? modulo;

  @override
  ConsumerState<DatModuloFormPage> createState() => _DatModuloFormPageState();
}

class _DatModuloFormPageState extends ConsumerState<DatModuloFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _codigoCtrl = TextEditingController();
  final _nombreCtrl = TextEditingController();
  final _deptoCtrl = TextEditingController();
  bool _activo = true;
  bool _saving = false;
  late Future<void> _loader;

  @override
  void initState() {
    super.initState();
    _loader = _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (widget.modulo == null) return;
    final data = await ref.read(datmodulosApiProvider).fetchModulo(widget.modulo!);
    _codigoCtrl.text = data.codigo;
    _nombreCtrl.text = data.nombre;
    _deptoCtrl.text = data.depto ?? '';
    _activo = data.activo;
  }

  @override
  void dispose() {
    _codigoCtrl.dispose();
    _nombreCtrl.dispose();
    _deptoCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final payload = {
      'CODIGO': _codigoCtrl.text.trim(),
      'NOMBRE': _nombreCtrl.text.trim(),
      'DEPTO': _deptoCtrl.text.trim().isEmpty ? null : _deptoCtrl.text.trim(),
      'ACTIVO': _activo,
    };

    try {
      if (widget.modulo == null) {
        await ref.read(datmodulosApiProvider).createModulo(payload);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Módulo creado')));
      } else {
        await ref.read(datmodulosApiProvider).updateModulo(widget.modulo!, payload..remove('CODIGO'));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Módulo actualizado')));
      }
      ref.invalidate(datmodulosListProvider);
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
      appBar: AppBar(title: Text(widget.modulo == null ? 'Nuevo módulo' : 'Editar módulo')),
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
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    TextFormField(
                      controller: _codigoCtrl,
                      decoration: const InputDecoration(labelText: 'Código'),
                      enabled: !_saving && widget.modulo == null,
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
                      controller: _deptoCtrl,
                      decoration: const InputDecoration(labelText: 'Departamento'),
                      enabled: !_saving,
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      value: _activo,
                      onChanged: _saving ? null : (value) => setState(() => _activo = value),
                      title: const Text('Activo'),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: _saving
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.save),
                        label: Text(_saving ? 'Guardando...' : 'Guardar'),
                        onPressed: _saving ? null : _submit,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
