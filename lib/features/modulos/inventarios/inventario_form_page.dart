import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ioe_app/core/auth/auth_controller.dart';
import 'package:ioe_app/features/masterdata/sucursales/sucursales_providers.dart';

import 'inventarios_providers.dart';

class InventarioFormPage extends ConsumerStatefulWidget {
  const InventarioFormPage({super.key, this.tokenreg});

  final String? tokenreg;

  @override
  ConsumerState<InventarioFormPage> createState() => _InventarioFormPageState();
}

class _InventarioFormPageState extends ConsumerState<InventarioFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _tokenCtrl = TextEditingController();
  final _contCtrl = TextEditingController();
  final _fcncCtrl = TextEditingController();
  final _estaCtrl = TextEditingController();
  final _fcnajCtrl = TextEditingController();
  final _artajCtrl = TextEditingController();
  final _artcontCtrl = TextEditingController();
  final _creadoCtrl = TextEditingController();
  final _creadoPorCtrl = TextEditingController();
  final _modificadoPorCtrl = TextEditingController();

  String? _selectedSuc;
  String? _tipoConteo;
  static const List<String> _tipoConteoOptions = ['ARTICULO', 'JERARQUIA'];

  bool _saving = false;
  late Future<void> _loader;

  bool get _isNew => widget.tokenreg == null;

  @override
  void initState() {
    super.initState();
    if (_isNew) {
      _estaCtrl.text = 'ABIERTO';
      _tipoConteo = 'ARTICULO';
    }
    _loader = _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (_isNew) return;
    final data = await ref.read(inventariosApiProvider).fetchOne(widget.tokenreg!);
    _tokenCtrl.text = data.tokenreg;
    _contCtrl.text = data.cont ?? '';
    _fcncCtrl.text = data.fcnc?.toIso8601String() ?? '';
    _estaCtrl.text = data.esta ?? '';
    _selectedSuc = data.suc;
    _fcnajCtrl.text = data.fcnaj?.toIso8601String() ?? '';
    _artajCtrl.text = data.artaj?.toString() ?? '';
    _artcontCtrl.text = data.artcont?.toString() ?? '';
    _tipoConteo = data.tipocont;
    _creadoCtrl.text = data.creado?.toIso8601String() ?? '';
    _creadoPorCtrl.text = data.creadoPor ?? '';
    _modificadoPorCtrl.text = data.modificadoPor ?? '';
  }

  @override
  void dispose() {
    _tokenCtrl.dispose();
    _contCtrl.dispose();
    _fcncCtrl.dispose();
    _estaCtrl.dispose();
    _fcnajCtrl.dispose();
    _artajCtrl.dispose();
    _artcontCtrl.dispose();
    _creadoCtrl.dispose();
    _creadoPorCtrl.dispose();
    _modificadoPorCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    double? parseDouble(String text) => text.trim().isEmpty ? null : double.tryParse(text.trim());
    String? parseStr(String? text) => text == null || text.trim().isEmpty ? null : text.trim();
    String? parseDate(String? text) => text == null || text.trim().isEmpty ? null : text.trim();

    final nowIso = DateTime.now().toIso8601String();
    final username = ref.read(authControllerProvider).username ?? '';

    final payload = {
      'TOKENREG': _isNew ? _ensureToken() : _tokenCtrl.text.trim(),
      'CONT': parseStr(_sanitizeCont(_contCtrl.text)),
      'FCNC': _isNew ? nowIso : parseDate(_fcncCtrl.text),
      'ESTA': _isNew ? 'ABIERTO' : (parseStr(_estaCtrl.text) ?? 'ABIERTO'),
      'SUC': _selectedSuc,
      'FCNAJ': _isNew ? null : parseDate(_fcnajCtrl.text),
      'ARTAJ': _isNew ? null : parseDouble(_artajCtrl.text),
      'ARTCONT': _isNew ? null : parseDouble(_artcontCtrl.text),
      'TIPOCONT': _tipoConteo,
      'CREADO': _isNew ? nowIso : parseDate(_creadoCtrl.text),
      'CREADO_POR': _isNew ? username : (parseStr(_creadoPorCtrl.text) ?? username),
      'MODIFICADO_POR': _isNew ? null : (username.isNotEmpty ? username : parseStr(_modificadoPorCtrl.text)),
    };

    try {
      if (widget.tokenreg == null) {
        await ref.read(inventariosApiProvider).create(payload);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registro creado')));
      } else {
        await ref.read(inventariosApiProvider).update(widget.tokenreg!, payload);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registro actualizado')));
      }
      ref.invalidate(inventariosListProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _sanitizeCont(String value) {
    return value.replaceAll(RegExp(r'\s+'), '').toUpperCase();
  }

  String _ensureToken() {
    final existing = _tokenCtrl.text.trim();
    if (existing.isNotEmpty) return existing;
    final random = Random();
    final token =
        'INV-${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}-${random.nextInt(0xFFFFFFFF).toRadixString(16).padLeft(8, '0')}';
    _tokenCtrl.text = token;
    return token;
  }

  void _applyContFormatting(String value) {
    final sanitized = _sanitizeCont(value);
    if (sanitized == _contCtrl.text) return;
    _contCtrl.value = TextEditingValue(
      text: sanitized,
      selection: TextSelection.collapsed(offset: sanitized.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.tokenreg == null ? 'Nuevo registro' : 'Editar registro')),
      body: FutureBuilder<void>(
        future: _loader,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  if (!_isNew) ...[
                    TextFormField(
                      controller: _tokenCtrl,
                      decoration: const InputDecoration(labelText: 'TOKENREG'),
                      enabled: false,
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: _contCtrl,
                    decoration: const InputDecoration(labelText: 'CONT'),
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
                    onChanged: _applyContFormatting,
                    enabled: !_saving && _isNew,
                    validator: (v) {
                      final value = _sanitizeCont(v ?? '');
                      if (value.isEmpty) return 'Requerido';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _estaCtrl.text.isEmpty ? null : _estaCtrl.text,
                    decoration: const InputDecoration(labelText: 'ESTA'),
                    items: const [
                      DropdownMenuItem(value: 'ABIERTO', child: Text('ABIERTO')),
                      DropdownMenuItem(value: 'CERRADO', child: Text('CERRADO')),
                    ],
                    onChanged: (_saving || _isNew)
                        ? null
                        : (v) => setState(() => _estaCtrl.text = (v ?? '').toUpperCase()),
                  ),
                  const SizedBox(height: 12),
                  ref.watch(sucursalesListProvider).when(
                        data: (sucs) {
                          final selectedSuc = sucs.any((s) => s.suc == _selectedSuc) ? _selectedSuc : null;
                          return DropdownButtonFormField<String>(
                            initialValue: selectedSuc,
                            decoration: const InputDecoration(labelText: 'SUC'),
                            items: sucs
                                .map(
                                  (s) => DropdownMenuItem<String>(
                                    value: s.suc,
                                    child: Text(s.desc != null && s.desc!.isNotEmpty ? '${s.suc} - ${s.desc}' : s.suc),
                                  ),
                                )
                                .toList(),
                            onChanged: (_saving || !_isNew) ? null : (v) => setState(() => _selectedSuc = v),
                            validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (e, _) => Text('Error sucursales: $e'),
                      ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _tipoConteo,
                    decoration: const InputDecoration(labelText: 'TIPOCONT'),
                    items: _tipoConteoOptions
                        .map((opt) => DropdownMenuItem<String>(value: opt, child: Text(opt)))
                        .toList(),
                    onChanged: _saving ? null : (v) => setState(() => _tipoConteo = v),
                    validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  if (!_isNew) ...[
                    TextFormField(
                      controller: _fcncCtrl,
                      decoration: const InputDecoration(labelText: 'FCNC (ISO 8601)'),
                      enabled: false,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _fcnajCtrl,
                      decoration: const InputDecoration(labelText: 'FCNAJ (ISO 8601)'),
                      enabled: false,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _artajCtrl,
                      decoration: const InputDecoration(labelText: 'ARTAJ'),
                      enabled: false,
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v != null && v.trim().isNotEmpty && double.tryParse(v.trim()) == null) {
                          return 'Número inválido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _artcontCtrl,
                      decoration: const InputDecoration(labelText: 'ARTCONT'),
                      enabled: false,
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v != null && v.trim().isNotEmpty && double.tryParse(v.trim()) == null) {
                          return 'Número inválido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _creadoCtrl,
                      decoration: const InputDecoration(labelText: 'CREADO (ISO 8601)'),
                      enabled: false,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _creadoPorCtrl,
                      decoration: const InputDecoration(labelText: 'CREADO_POR'),
                      enabled: false,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _modificadoPorCtrl,
                      decoration: const InputDecoration(labelText: 'MODIFICADO_POR'),
                      enabled: false,
                    ),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 12),
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
