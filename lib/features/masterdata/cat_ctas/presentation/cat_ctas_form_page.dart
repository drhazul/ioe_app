import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/cat_ctas_providers.dart';
import '../domain/cat_cta.dart';

class CatCtasFormPage extends ConsumerStatefulWidget {
  const CatCtasFormPage({super.key, this.cta});

  final String? cta;

  @override
  ConsumerState<CatCtasFormPage> createState() => _CatCtasFormPageState();
}

class _CatCtasFormPageState extends ConsumerState<CatCtasFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _ctaCtrl = TextEditingController();
  final _dctaCtrl = TextEditingController();
  final _relacionCtrl = TextEditingController();
  final _sucCtrl = TextEditingController();

  bool _saving = false;
  late Future<void> _loader;

  bool get _editing => widget.cta != null && widget.cta!.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loader = _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (!_editing) return;
    final item = await ref.read(catCtasRepoProvider).getById(widget.cta!);
    _ctaCtrl.text = item.cta;
    _dctaCtrl.text = item.dcta ?? '';
    _relacionCtrl.text = item.relacion ?? '';
    _sucCtrl.text = item.suc ?? '';
  }

  @override
  void dispose() {
    _ctaCtrl.dispose();
    _dctaCtrl.dispose();
    _relacionCtrl.dispose();
    _sucCtrl.dispose();
    super.dispose();
  }

  String? _normalize(String value) {
    final text = value.trim();
    return text.isEmpty ? null : text;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final model = CatCta(
      cta: _ctaCtrl.text.trim(),
      dcta: _normalize(_dctaCtrl.text),
      relacion: _normalize(_relacionCtrl.text),
      suc: _normalize(_sucCtrl.text),
    );

    try {
      if (_editing) {
        await ref.read(catCtasRepoProvider).update(widget.cta!, model);
      } else {
        await ref.read(catCtasRepoProvider).create(model);
      }

      ref.invalidate(catCtasListProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_editing ? 'Cuenta actualizada' : 'Cuenta creada')),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Editar Cuenta' : 'Nueva Cuenta')),
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
                    controller: _ctaCtrl,
                    enabled: !_saving && !_editing,
                    decoration: const InputDecoration(
                      labelText: 'CTA',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final text = (value ?? '').trim();
                      if (text.isEmpty) return 'CTA es requerida';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _dctaCtrl,
                    enabled: !_saving,
                    decoration: const InputDecoration(
                      labelText: 'Descripcion (DCTA)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _relacionCtrl,
                    enabled: !_saving,
                    decoration: const InputDecoration(
                      labelText: 'Relacion',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _sucCtrl,
                    enabled: !_saving,
                    decoration: const InputDecoration(
                      labelText: 'SUC (opcional para admin)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _submit,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: Text(_saving ? 'Guardando...' : 'Guardar'),
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
