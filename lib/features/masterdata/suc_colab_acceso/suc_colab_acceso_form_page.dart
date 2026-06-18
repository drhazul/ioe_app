import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../sucursales/sucursales_models.dart';
import '../sucursales/sucursales_providers.dart';
import 'suc_colab_acceso_providers.dart';

class SucColabAccesoFormPage extends ConsumerStatefulWidget {
  const SucColabAccesoFormPage({super.key, this.id});

  final int? id;

  @override
  ConsumerState<SucColabAccesoFormPage> createState() =>
      _SucColabAccesoFormPageState();
}

class _SucColabAccesoFormPageState
    extends ConsumerState<SucColabAccesoFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _observacionCtrl = TextEditingController();
  String? _sucDestino;
  String? _sucOrigen;
  bool _activo = true;
  bool _saving = false;
  late final Future<void> _loader;

  @override
  void initState() {
    super.initState();
    _loader = _bootstrap();
  }

  Future<void> _bootstrap() async {
    final sucursales = await ref.read(sucursalesListProvider.future);
    if (sucursales.isEmpty) {
      throw StateError('No hay sucursales disponibles en DAT_SUC');
    }
    final options = _sortedSucursales(sucursales);
    final first = options.first;
    final second = options.length > 1 ? options[1] : first;
    _sucDestino = first.suc;
    _sucOrigen = second.suc;

    if (widget.id != null) {
      final data = await ref.read(sucColabAccesoProvider(widget.id!).future);
      _sucDestino = data.sucDestino;
      _sucOrigen = data.sucOrigen;
      _activo = data.activo;
      _observacionCtrl.text = data.observacion ?? '';
    }
  }

  @override
  void dispose() {
    _observacionCtrl.dispose();
    super.dispose();
  }

  List<SucursalModel> _sortedSucursales(List<SucursalModel> items) {
    final copy = [...items];
    copy.sort((a, b) => a.suc.compareTo(b.suc));
    return copy;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final destino = (_sucDestino ?? '').trim().toUpperCase();
    final origen = (_sucOrigen ?? '').trim().toUpperCase();
    if (destino.isEmpty || origen.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona sucursal destino y origen')),
      );
      return;
    }
    if (destino == origen) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Destino y origen no pueden ser iguales')),
      );
      return;
    }

    setState(() => _saving = true);
    final payload = <String, dynamic>{
      'SUC_DESTINO': destino,
      'SUC_ORIGEN': origen,
      'ACTIVO': _activo,
      'OBSERVACION': _observacionCtrl.text.trim().isEmpty
          ? null
          : _observacionCtrl.text.trim(),
    };

    try {
      if (widget.id == null) {
        await ref.read(sucColabAccesoApiProvider).create(payload);
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Relación creada')));
      } else {
        await ref.read(sucColabAccesoApiProvider).update(widget.id!, payload);
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Relación actualizada')));
      }
      final filters = ref.read(sucColabAccesoFiltersProvider);
      ref.invalidate(sucColabAccesoListProvider(filters));
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
    final sucursalesAsync = ref.watch(sucursalesListProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.id == null ? 'Nueva relación' : 'Editar relación'),
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

          return sucursalesAsync.when(
            data: (sucursales) {
              final options = _sortedSucursales(sucursales);
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        key: ValueKey('dest-$_sucDestino'),
                        initialValue: _sucDestino,
                        decoration: const InputDecoration(
                          labelText: 'Sucursal destino',
                          border: OutlineInputBorder(),
                        ),
                        items: options
                            .map(
                              (item) => DropdownMenuItem(
                                value: item.suc,
                                child: Text(
                                  item.desc == null || item.desc!.isEmpty
                                      ? item.suc
                                      : '${item.suc} - ${item.desc}',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: _saving
                            ? null
                            : (value) => setState(() => _sucDestino = value),
                        validator: (value) =>
                            (value ?? '').trim().isEmpty ? 'Requerido' : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        key: ValueKey('orig-$_sucOrigen'),
                        initialValue: _sucOrigen,
                        decoration: const InputDecoration(
                          labelText: 'Sucursal origen',
                          border: OutlineInputBorder(),
                        ),
                        items: options
                            .map(
                              (item) => DropdownMenuItem(
                                value: item.suc,
                                child: Text(
                                  item.desc == null || item.desc!.isEmpty
                                      ? item.suc
                                      : '${item.suc} - ${item.desc}',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: _saving
                            ? null
                            : (value) => setState(() => _sucOrigen = value),
                        validator: (value) =>
                            (value ?? '').trim().isEmpty ? 'Requerido' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _observacionCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Observación',
                          border: OutlineInputBorder(),
                        ),
                        enabled: !_saving,
                        maxLength: 250,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Activo'),
                        value: _activo,
                        onChanged: _saving
                            ? null
                            : (value) => setState(() => _activo = value),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: _saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
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
            error: (e, _) => Center(child: Text('Error: $e')),
            loading: () => const Center(child: CircularProgressIndicator()),
          );
        },
      ),
    );
  }
}
