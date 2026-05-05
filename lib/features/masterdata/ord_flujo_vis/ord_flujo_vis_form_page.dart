import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'ord_flujo_vis_models.dart';
import 'ord_flujo_vis_providers.dart';

class OrdFlujoVisFormPage extends ConsumerStatefulWidget {
  const OrdFlujoVisFormPage({super.key, this.id});

  final int? id;

  @override
  ConsumerState<OrdFlujoVisFormPage> createState() => _OrdFlujoVisFormPageState();
}

class _OrdFlujoVisFormPageState extends ConsumerState<OrdFlujoVisFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _moduloCtrl = TextEditingController(text: 'DAT_JAO_ORD');
  final _ordenCtrl = TextEditingController();

  List<OrdFlujoVisRoleOption> _roles = const [];
  List<OrdFlujoVisEstadoOption> _estados = const [];
  String _modulo = 'DAT_JAO_ORD';
  String _panelMode = 'operativo';
  String? _roleCode;
  String? _estaKey;
  bool _soloExterno = false;
  bool _activo = true;
  bool _saving = false;
  late Future<void> _loader;

  @override
  void initState() {
    super.initState();
    _loader = _bootstrap();
  }

  Future<void> _bootstrap() async {
    final api = ref.read(ordFlujoVisApiProvider);
    final catalogos = await api.fetchCatalogos();
    _modulo = catalogos.modulo.trim().isEmpty ? 'DAT_JAO_ORD' : catalogos.modulo;
    _moduloCtrl.text = _modulo;
    _roles = [...catalogos.roles]..sort((a, b) => a.roleCode.compareTo(b.roleCode));
    _estados = [...catalogos.estados]
      ..sort((a, b) => a.esta.compareTo(b.esta));

    if (widget.id != null) {
      final row = await api.fetchById(widget.id!);
      _modulo = row.modulo;
      _moduloCtrl.text = row.modulo;
      _panelMode = row.panelMode;
      _soloExterno = row.soloExterno;
      _activo = row.activo;
      _roleCode = row.roleCode;
      _estaKey = _formatEstaKey(row.esta);
      _ensureRoleOption(_roleCode!);
      _ensureEstadoOption(row.esta);
    }

    _roleCode ??= _roles.isNotEmpty ? _roles.first.roleCode : null;
    _estaKey ??= _estados.isNotEmpty ? _formatEstaKey(_estados.first.esta) : null;
    _syncOrdenAuto();
  }

  @override
  void dispose() {
    _moduloCtrl.dispose();
    _ordenCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_roleCode == null || _roleCode!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ROLE_CODE es requerido')),
      );
      return;
    }
    if (_estaKey == null || _estaKey!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ESTA es requerido')),
      );
      return;
    }

    final esta = double.tryParse(_estaKey!);
    if (esta == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ESTA inválido')),
      );
      return;
    }

    final payload = <String, dynamic>{
      'MODULO': _modulo,
      'PANEL_MODE': _panelMode,
      'ROLE_CODE': _roleCode,
      'ESTA': esta,
      'SOLO_EXTERNO': _soloExterno,
      'ACTIVO': _activo,
    };

    setState(() => _saving = true);
    try {
      if (widget.id == null) {
        await ref.read(ordFlujoVisApiProvider).create(payload);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configuración creada')),
        );
      } else {
        await ref.read(ordFlujoVisApiProvider).update(widget.id!, payload);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configuración actualizada')),
        );
      }
      ref.invalidate(ordFlujoVisListProvider);
      ref.invalidate(ordFlujoVisCatalogosProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.id == null
              ? 'Nueva visualización por ROLL'
              : 'Editar visualización por ROLL',
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
                    controller: _moduloCtrl,
                    readOnly: true,
                    enabled: false,
                    decoration: const InputDecoration(labelText: 'MODULO'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey('panelMode-$_panelMode'),
                    initialValue: _panelMode,
                    decoration: const InputDecoration(
                      labelText: 'PANEL_MODE',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'operativo',
                        child: Text('operativo'),
                      ),
                      DropdownMenuItem(value: 'estado', child: Text('estado')),
                      DropdownMenuItem(
                        value: 'anulados',
                        child: Text('anulados'),
                      ),
                      DropdownMenuItem(
                        value: 'entregadas',
                        child: Text('entregadas'),
                      ),
                    ],
                    onChanged: _saving
                        ? null
                        : (v) => setState(() => _panelMode = v ?? 'operativo'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey('role-${_roleCode ?? ''}'),
                    initialValue: _roleCode,
                    decoration: const InputDecoration(
                      labelText: 'ROLE_CODE',
                      border: OutlineInputBorder(),
                    ),
                    items: _roles
                        .map(
                          (role) => DropdownMenuItem(
                            value: role.roleCode,
                            child: Text(_roleLabel(role)),
                          ),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (v) => setState(() => _roleCode = v),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey('esta-${_estaKey ?? ''}'),
                    initialValue: _estaKey,
                    decoration: const InputDecoration(
                      labelText: 'ESTA',
                      border: OutlineInputBorder(),
                    ),
                    items: _estados
                        .map(
                          (estado) => DropdownMenuItem(
                            value: _formatEstaKey(estado.esta),
                            child: Text(_estadoLabel(estado)),
                          ),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (v) => setState(() {
                            _estaKey = v;
                            _syncOrdenAuto();
                          }),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _ordenCtrl,
                    readOnly: true,
                    enabled: false,
                    decoration: const InputDecoration(
                      labelText: 'ORDEN (automático)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('SOLO_EXTERNO'),
                    subtitle: const Text(
                      'Si activo, solo muestra flujo cuando laboratorio es externo',
                    ),
                    value: _soloExterno,
                    onChanged:
                        _saving ? null : (v) => setState(() => _soloExterno = v),
                  ),
                  const SizedBox(height: 4),
                  SwitchListTile(
                    title: const Text('ACTIVO'),
                    value: _activo,
                    onChanged: _saving ? null : (v) => setState(() => _activo = v),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
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

  void _syncOrdenAuto() {
    final esta = double.tryParse(_estaKey ?? '');
    if (esta == null) {
      _ordenCtrl.text = '';
      return;
    }
    _ordenCtrl.text = (esta * 10).round().toString();
  }

  void _ensureRoleOption(String roleCode) {
    final already = _roles.any((role) => role.roleCode == roleCode);
    if (already) return;
    _roles = [
      ..._roles,
      OrdFlujoVisRoleOption(roleCode: roleCode, roleName: roleCode),
    ]..sort((a, b) => a.roleCode.compareTo(b.roleCode));
  }

  void _ensureEstadoOption(double esta) {
    final key = _formatEstaKey(esta);
    final already = _estados.any((row) => _formatEstaKey(row.esta) == key);
    if (already) return;
    _estados = [
      ..._estados,
      OrdFlujoVisEstadoOption(
        esta: esta,
        tipo: 'ESTA $key',
        ordenSugerido: (esta * 10).round(),
      ),
    ]..sort((a, b) => a.esta.compareTo(b.esta));
  }

  String _roleLabel(OrdFlujoVisRoleOption role) {
    if (role.roleName.trim().isEmpty ||
        role.roleName.trim().toUpperCase() == role.roleCode) {
      return role.roleCode;
    }
    return '${role.roleCode} - ${role.roleName}';
  }

  String _estadoLabel(OrdFlujoVisEstadoOption estado) {
    final key = _formatEstaKey(estado.esta);
    final tipo = estado.tipo.trim();
    if (tipo.isEmpty) return '$key (ORDEN ${estado.ordenSugerido})';
    return '$key - $tipo (ORDEN ${estado.ordenSugerido})';
  }

  String _formatEstaKey(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toString();
  }
}
