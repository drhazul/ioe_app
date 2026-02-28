import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'dat_form_providers.dart';

class DatFormFormPage extends ConsumerStatefulWidget {
  const DatFormFormPage({super.key, this.idform});

  final int? idform;

  @override
  ConsumerState<DatFormFormPage> createState() => _DatFormFormPageState();
}

class _DatFormFormPageState extends ConsumerState<DatFormFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _aspelCtrl = TextEditingController();
  final _formCtrl = TextEditingController();
  final _nomCtrl = TextEditingController();
  bool _estado = true;
  bool _saving = false;
  late Future<void> _loader;

  @override
  void initState() {
    super.initState();
    _loader = _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (widget.idform == null) return;
    final data = await ref
        .read(datFormApiProvider)
        .fetchDatForm(widget.idform!);
    _aspelCtrl.text = data.aspel?.toString() ?? '';
    _formCtrl.text = data.form;
    _nomCtrl.text = data.nom;
    _estado = data.estado;
  }

  @override
  void dispose() {
    _aspelCtrl.dispose();
    _formCtrl.dispose();
    _nomCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final aspelText = _aspelCtrl.text.trim();
    final aspelValue = aspelText.isEmpty ? null : int.tryParse(aspelText);
    if (aspelText.isNotEmpty && aspelValue == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ASPEL debe ser un número entero')),
      );
      return;
    }

    setState(() => _saving = true);
    final payload = <String, dynamic>{
      'FORM': _formCtrl.text.trim().toUpperCase(),
      'NOM': _nomCtrl.text.trim().isEmpty ? null : _nomCtrl.text.trim(),
      'ESTADO': _estado,
      'ASPEL': aspelValue,
    };

    try {
      if (widget.idform == null) {
        await ref.read(datFormApiProvider).createDatForm(payload);
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Forma de pago creada')));
      } else {
        await ref
            .read(datFormApiProvider)
            .updateDatForm(widget.idform!, payload);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Forma de pago actualizada')),
        );
      }
      ref.invalidate(datFormListProvider);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.idform == null
              ? 'Nueva forma de pago'
              : 'Editar forma de pago',
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
                    controller: _aspelCtrl,
                    decoration: const InputDecoration(labelText: 'ASPEL'),
                    enabled: !_saving,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      final text = (value ?? '').trim();
                      if (text.isEmpty) return null;
                      final parsed = int.tryParse(text);
                      if (parsed == null || parsed < 0) {
                        return 'Debe ser entero mayor o igual a 0';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _formCtrl,
                    decoration: const InputDecoration(labelText: 'FORM'),
                    enabled: !_saving,
                    maxLength: 50,
                    validator: (value) {
                      final text = (value ?? '').trim();
                      if (text.isEmpty) return 'Requerido';
                      if (text.length > 50) return 'Máximo 50 caracteres';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nomCtrl,
                    decoration: const InputDecoration(labelText: 'NOM'),
                    enabled: !_saving,
                    maxLength: 50,
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Activo'),
                    value: _estado,
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _estado = value),
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
