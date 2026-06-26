import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'empresas_providers.dart';

class EmpresaFormPage extends ConsumerStatefulWidget {
  const EmpresaFormPage({super.key, this.idempresa});

  final int? idempresa;

  @override
  ConsumerState<EmpresaFormPage> createState() => _EmpresaFormPageState();
}

class _EmpresaFormPageState extends ConsumerState<EmpresaFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _razonCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _correoCtrl = TextEditingController(text: '@');
  final _cpCtrl = TextEditingController();
  final _rfcCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();

  late Future<void> _loader;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loader = _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (widget.idempresa == null) return;
    final data = await ref
        .read(empresasApiProvider)
        .fetchEmpresa(widget.idempresa!);
    _razonCtrl.text = data.razonSocial;
    _direccionCtrl.text = data.direccion ?? '';
    _correoCtrl.text = data.correo;
    _cpCtrl.text = data.cp ?? '';
    _rfcCtrl.text = data.rfc ?? '';
    _telefonoCtrl.text = data.telefono ?? '';
  }

  @override
  void dispose() {
    _razonCtrl.dispose();
    _direccionCtrl.dispose();
    _correoCtrl.dispose();
    _cpCtrl.dispose();
    _rfcCtrl.dispose();
    _telefonoCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final payload = <String, dynamic>{
      'razon_social': _razonCtrl.text.trim(),
      'direccion': _emptyToNull(_direccionCtrl.text),
      'correo': _correoCtrl.text.trim().toLowerCase(),
      'cp': _emptyToNull(_cpCtrl.text),
      'rfc': _emptyToNull(_rfcCtrl.text)?.toUpperCase(),
      'telefono': _emptyToNull(_telefonoCtrl.text),
    };

    try {
      if (widget.idempresa == null) {
        await ref.read(empresasApiProvider).createEmpresa(payload);
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Empresa creada')));
      } else {
        await ref
            .read(empresasApiProvider)
            .updateEmpresa(widget.idempresa!, payload);
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Empresa actualizada')));
      }
      ref.invalidate(empresasListProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _emptyToNull(String value) {
    final text = value.trim();
    return text.isEmpty ? null : text;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.idempresa == null ? 'Nueva empresa' : 'Editar empresa',
        ),
      ),
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
                    controller: _razonCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Razón social',
                    ),
                    enabled: !_saving,
                    maxLength: 200,
                    validator: (value) =>
                        (value ?? '').trim().isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _correoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Prefijo correo',
                      helperText: 'Usar formato @dominio.com',
                    ),
                    enabled: !_saving,
                    maxLength: 120,
                    validator: (value) {
                      final text = (value ?? '').trim();
                      if (!RegExp(
                        r'^@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
                      ).hasMatch(text)) {
                        return 'Formato requerido: @dominio.com';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _direccionCtrl,
                    decoration: const InputDecoration(labelText: 'Dirección'),
                    enabled: !_saving,
                    maxLength: 300,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _cpCtrl,
                    decoration: const InputDecoration(labelText: 'CP'),
                    enabled: !_saving,
                    maxLength: 10,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _rfcCtrl,
                    decoration: const InputDecoration(labelText: 'RFC'),
                    enabled: !_saving,
                    maxLength: 20,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _telefonoCtrl,
                    decoration: const InputDecoration(labelText: 'Teléfono'),
                    enabled: !_saving,
                    maxLength: 30,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
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
