import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'sucursales_providers.dart';

class SucursalFormPage extends ConsumerStatefulWidget {
  const SucursalFormPage({super.key, this.suc});

  final String? suc;

  @override
  ConsumerState<SucursalFormPage> createState() => _SucursalFormPageState();
}

class _SucursalFormPageState extends ConsumerState<SucursalFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _sucCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _encarCtrl = TextEditingController();
  final _zonaCtrl = TextEditingController();
  final _rfcCtrl = TextEditingController();
  final _dirCtrl = TextEditingController();
  final _contactoCtrl = TextEditingController();
  bool _ivaIntegrado = false;
  bool _saving = false;
  late Future<void> _loader;

  @override
  void initState() {
    super.initState();
    _loader = _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (widget.suc == null) return;
    final data = await ref.read(sucursalesApiProvider).fetchSucursal(widget.suc!);
    _sucCtrl.text = data.suc;
    _descCtrl.text = data.desc ?? '';
    _encarCtrl.text = data.encar ?? '';
    _zonaCtrl.text = data.zona ?? '';
    _rfcCtrl.text = data.rfc ?? '';
    _dirCtrl.text = data.direccion ?? '';
    _contactoCtrl.text = data.contacto ?? '';
    _ivaIntegrado = (data.ivaIntegrado ?? 0) == 1;
  }

  @override
  void dispose() {
    _sucCtrl.dispose();
    _descCtrl.dispose();
    _encarCtrl.dispose();
    _zonaCtrl.dispose();
    _rfcCtrl.dispose();
    _dirCtrl.dispose();
    _contactoCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final payload = {
      'SUC': _sucCtrl.text.trim(),
      'DESC': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      'ENCAR': _encarCtrl.text.trim().isEmpty ? null : _encarCtrl.text.trim(),
      'ZONA': _zonaCtrl.text.trim().isEmpty ? null : _zonaCtrl.text.trim(),
      'RFC': _rfcCtrl.text.trim().isEmpty ? null : _rfcCtrl.text.trim(),
      'DIRECCION': _dirCtrl.text.trim().isEmpty ? null : _dirCtrl.text.trim(),
      'CONTACTO': _contactoCtrl.text.trim().isEmpty ? null : _contactoCtrl.text.trim(),
      'IVA_INTEGRADO': _ivaIntegrado ? 1 : 0,
    };

    try {
      if (widget.suc == null) {
        await ref.read(sucursalesApiProvider).createSucursal(payload);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sucursal creada')));
      } else {
        await ref.read(sucursalesApiProvider).updateSucursal(widget.suc!, payload);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sucursal actualizada')));
      }
      ref.invalidate(sucursalesListProvider);
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
      appBar: AppBar(title: Text(widget.suc == null ? 'Nueva sucursal' : 'Editar sucursal')),
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
                    controller: _sucCtrl,
                    decoration: const InputDecoration(labelText: 'SUC'),
                    enabled: !_saving && widget.suc == null,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descCtrl,
                    decoration: const InputDecoration(labelText: 'Descripción'),
                    enabled: !_saving,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _encarCtrl,
                    decoration: const InputDecoration(labelText: 'Encargado'),
                    enabled: !_saving,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _zonaCtrl,
                    decoration: const InputDecoration(labelText: 'Zona'),
                    enabled: !_saving,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _rfcCtrl,
                    decoration: const InputDecoration(labelText: 'RFC'),
                    enabled: !_saving,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _dirCtrl,
                    decoration: const InputDecoration(labelText: 'Dirección'),
                    enabled: !_saving,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _contactoCtrl,
                    decoration: const InputDecoration(labelText: 'Contacto'),
                    enabled: !_saving,
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('IVA integrado'),
                    value: _ivaIntegrado,
                    onChanged: _saving ? null : (v) => setState(() => _ivaIntegrado = v),
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
