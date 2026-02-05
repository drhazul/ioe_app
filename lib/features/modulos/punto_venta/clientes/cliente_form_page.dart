import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ioe_app/core/api_error.dart';
import 'package:ioe_app/core/dio_provider.dart';
import 'package:ioe_app/features/masterdata/sucursales/sucursales_providers.dart';

import 'clientes_models.dart';
import 'clientes_providers.dart';
import 'datcatreg_providers.dart';
import 'datcatuso_providers.dart';

class ClienteFormPage extends ConsumerWidget {
  const ClienteFormPage({super.key, this.id});

  final String? id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(id == null ? 'Nuevo cliente' : 'Editar cliente')),
      body: ClienteFormBody(id: id),
    );
  }
}

class ClienteFormBody extends ConsumerStatefulWidget {
  const ClienteFormBody({super.key, this.id, this.onSaved});

  final String? id;
  final VoidCallback? onSaved;

  @override
  ConsumerState<ClienteFormBody> createState() => _ClienteFormBodyState();
}

class _ClienteFormBodyState extends ConsumerState<ClienteFormBody> {
  final _formKey = GlobalKey<FormState>();
  final _razonCtrl = TextEditingController();
  final _rfcCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _codigoPostalCtrl = TextEditingController();
  final _domiCtrl = TextEditingController();
  final _ncelCtrl = TextEditingController();
  final _aliasCtrl = TextEditingController();
  final _upperFormatter = UpperCaseTextFormatter();

  late Future<void> _loader;
  bool _saving = false;
  int? _roleId;
  String? _userSuc;
  String? _rfcEmisor;
  int? _regimenFiscal;
  String? _usoCfdi;
  String? _sucSelected;

  @override
  void initState() {
    super.initState();
    if (widget.id == null && _rfcCtrl.text.trim().isEmpty) {
      _rfcCtrl.text = 'XAXX010101000';
    }
    _loader = _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _loadUserContext();
    if (widget.id == null) return;
    final cliente = await ref.read(clientesApiProvider).fetchCliente(widget.id!);
    _apply(cliente);
  }

  void _apply(FactClientShpModel c) {
    _razonCtrl.text = c.razonSocialReceptor;
    _rfcCtrl.text = c.rfcReceptor;
    _emailCtrl.text = c.emailReceptor;
    _rfcEmisor = c.rfcEmisor;
    _usoCfdi = c.usoCfdi;
    _codigoPostalCtrl.text = c.codigoPostalReceptor;
    _regimenFiscal = c.regimenFiscalReceptor.toInt();
    _domiCtrl.text = c.domicilio ?? '';
    _ncelCtrl.text = c.ncel ?? '';
    _aliasCtrl.text = c.optica ?? '';
    _sucSelected = c.suc ?? _sucSelected;
  }

  Future<void> _loadUserContext() async {
    final storage = ref.read(storageProvider);
    final token = await storage.getAccessToken();
    if (token == null || token.isEmpty) return;
    final payload = _decodeJwt(token);
    _roleId = _asInt(payload['roleId']);
    _userSuc = payload['suc'] as String?;
    if ((_sucSelected ?? '').isEmpty && (_userSuc ?? '').isNotEmpty) {
      _sucSelected = _userSuc;
    }
  }

  Map<String, dynamic> _decodeJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return {};
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      return Map<String, dynamic>.from(json.decode(payload) as Map);
    } catch (_) {
      return {};
    }
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }

  DropdownMenuItem<T> _menuItem<T>(T value, String label, int index) {
    final bg = index.isEven ? Colors.grey.withValues(alpha: 0.08) : Colors.transparent;
    return DropdownMenuItem<T>(
      value: value,
      child: Container(
        width: double.infinity,
        color: bg,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }

  @override
  void dispose() {
    _razonCtrl.dispose();
    _rfcCtrl.dispose();
    _emailCtrl.dispose();
    _codigoPostalCtrl.dispose();
    _domiCtrl.dispose();
    _ncelCtrl.dispose();
    _aliasCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final payload = <String, dynamic>{
      'RAZONSOCIALRECEPTOR': _razonCtrl.text.trim().toUpperCase(),
      'RFCRECEPTOR': _rfcCtrl.text.trim().toUpperCase(),
      'EMAILRECEPTOR': _emailCtrl.text.trim(),
      'RFCEMISOR': _rfcEmisor,
      'USOCFDI': _usoCfdi,
      'CODIGOPOSTALRECEPTOR': _codigoPostalCtrl.text.trim().toUpperCase(),
      'REGIMENFISCALRECEPTOR': _regimenFiscal,
      'DOMI': _domiCtrl.text.trim().isEmpty ? null : _domiCtrl.text.trim(),
      'NCEL': _ncelCtrl.text.trim().isEmpty ? null : _ncelCtrl.text.trim(),
      'OPTICA': _aliasCtrl.text.trim().isEmpty ? null : _aliasCtrl.text.trim().toUpperCase(),
      'SUC': ((_roleId ?? 0) == 1) ? _sucSelected : _userSuc,
    };

    try {
      if (widget.id == null) {
        await ref.read(clientesApiProvider).createCliente(payload);
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Registro guardado correctamente')));
      } else {
        await ref.read(clientesApiProvider).updateCliente(widget.id!, payload);
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Registro guardado correctamente')));
      }
      ref.invalidate(clientesListProvider);
      widget.onSaved?.call();
      if (mounted) context.pop();
    } catch (e) {
      if (!mounted) return;
      final msg = apiErrorMessage(e, fallback: 'No se pudo guardar');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar: $msg')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _validateRfc(String? value) {
    final v = (value ?? '').trim().toUpperCase();
    if (v.isEmpty) return 'Requerido';
    if (v == 'XAXX010101000' || v == 'XEXX010101000') return null;
    final moral = RegExp(r'^[A-Z&Ñ]{3}\d{2}(0[1-9]|1[0-2])(0[1-9]|[12]\d|3[01])[A-Z0-9]{3}$');
    final fisica = RegExp(r'^[A-Z&Ñ]{4}\d{2}(0[1-9]|1[0-2])(0[1-9]|[12]\d|3[01])[A-Z0-9]{3}$');
    if (moral.hasMatch(v) || fisica.hasMatch(v)) return null;
    return 'RFC inválido';
  }

  String? _validateTelefono(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return null;
    if (v.length > 10) return 'Máximo 10 dígitos';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final regAsync = ref.watch(datCatRegListProvider);
    final usoAsync = ref.watch(datCatUsoListProvider);
    final sucAsync = ref.watch(sucursalesListProvider);
    final isAdmin = (_roleId ?? 0) == 1;

    return FutureBuilder<void>(
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.id == null ? 'Alta cliente nuevo' : 'Editar cliente',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    if (isAdmin)
                      _LabeledField(
                        label: 'Sucursal (SUC) *',
                        child: sucAsync.when(
                          data: (sucursales) {
                            final items = <DropdownMenuItem<String>>[];
                            for (var i = 0; i < sucursales.length; i++) {
                              final s = sucursales[i];
                              final label = (s.desc?.trim().isNotEmpty == true)
                                  ? '${s.suc} - ${s.desc}'
                                  : s.suc;
                              items.add(_menuItem<String>(s.suc, label, i));
                            }
                            final value = items.any((i) => i.value == _sucSelected) ? _sucSelected : null;
                            return DropdownButtonFormField<String>(
                              initialValue: value,
                              isExpanded: true,
                              items: items,
                              style: const TextStyle(fontSize: 12),
                              onChanged: _saving
                                  ? null
                                  : (v) => setState(() {
                                        _sucSelected = v;
                                      }),
                              decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                            );
                          },
                          loading: () => const _LoadingField(),
                          error: (e, _) => _ErrorField(message: 'Error'),
                        ),
                      ),
                    _LabeledField(
                      label: 'Alias',
                      child: TextFormField(
                        controller: _aliasCtrl,
                        enabled: !_saving,
                        inputFormatters: [_upperFormatter],
                        decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                      ),
                    ),
                    _LabeledField(
                      label: 'RazonSocialReceptor *',
                      child: TextFormField(
                        controller: _razonCtrl,
                        enabled: !_saving,
                        inputFormatters: [_upperFormatter],
                        decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                      ),
                    ),
                    _LabeledField(
                      label: 'RfcReceptor *',
                      child: TextFormField(
                        controller: _rfcCtrl,
                        enabled: !_saving,
                        inputFormatters: [_upperFormatter],
                        decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                        validator: _validateRfc,
                      ),
                    ),
                    _LabeledField(
                      label: 'Domicilio',
                      child: TextFormField(
                        controller: _domiCtrl,
                        enabled: !_saving,
                        decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                      ),
                    ),
                    _LabeledField(
                      label: 'EmailReceptor *',
                      child: TextFormField(
                        controller: _emailCtrl,
                        enabled: !_saving,
                        decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                      ),
                    ),
                    _LabeledField(
                      label: 'Tel o Cel',
                      child: TextFormField(
                        controller: _ncelCtrl,
                        enabled: !_saving,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                        validator: _validateTelefono,
                      ),
                    ),
                    _LabeledField(
                      label: 'RfcEmisor *',
                      child: sucAsync.when(
                        data: (sucursales) {
                          final filtered = isAdmin
                              ? sucursales
                              : sucursales.where((s) => s.suc == _userSuc).toList();

                          final byRfc = <String, String>{};
                          for (final s in filtered) {
                            final rfc = (s.rfc ?? '').trim();
                            if (rfc.isEmpty) continue;
                            if (byRfc.containsKey(rfc)) continue;
                            final baseLabel = (s.encar?.trim().isNotEmpty == true)
                                ? s.encar!
                                : (s.desc?.trim().isNotEmpty == true)
                                    ? s.desc!
                                    : s.suc;
                            byRfc[rfc] = '$baseLabel - $rfc';
                          }
                          final entries = byRfc.entries.toList();
                          final items = <DropdownMenuItem<String>>[];
                          for (var i = 0; i < entries.length; i++) {
                            items.add(_menuItem<String>(entries[i].key, entries[i].value, i));
                          }

                          final value = items.any((i) => i.value == _rfcEmisor) ? _rfcEmisor : null;

                          return DropdownButtonFormField<String>(
                            initialValue: value,
                            isExpanded: true,
                            items: items,
                            style: const TextStyle(fontSize: 12),
                            onChanged: _saving
                                ? null
                                : (v) => setState(() {
                                      _rfcEmisor = v;
                                    }),
                            decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                          );
                        },
                        loading: () => const _LoadingField(),
                        error: (e, _) => _ErrorField(message: 'Error'),
                      ),
                    ),
                    _LabeledField(
                      label: 'CodigoPostalReceptor *',
                      child: TextFormField(
                        controller: _codigoPostalCtrl,
                        enabled: !_saving,
                        inputFormatters: [_upperFormatter],
                        decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                      ),
                    ),
                    _LabeledField(
                      label: 'RegimenFiscalReceptor *',
                      child: regAsync.when(
                        data: (regs) {
                          final items = <DropdownMenuItem<int>>[];
                          for (var i = 0; i < regs.length; i++) {
                            final r = regs[i];
                            items.add(_menuItem<int>(r.codigo, '${r.codigo} - ${r.descripcion ?? ''}', i));
                          }
                          final value = items.any((i) => i.value == _regimenFiscal) ? _regimenFiscal : null;
                          return DropdownButtonFormField<int>(
                            initialValue: value,
                            isExpanded: true,
                            items: items,
                            style: const TextStyle(fontSize: 12),
                            onChanged: _saving
                                ? null
                                : (v) => setState(() {
                                      _regimenFiscal = v;
                                    }),
                            decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                            validator: (v) => v == null ? 'Requerido' : null,
                          );
                        },
                        loading: () => const _LoadingField(),
                        error: (e, _) => _ErrorField(message: 'Error'),
                      ),
                    ),
                    _LabeledField(
                      label: 'UsoCfdi *',
                      child: usoAsync.when(
                        data: (usos) {
                          final items = <DropdownMenuItem<String>>[];
                          for (var i = 0; i < usos.length; i++) {
                            final u = usos[i];
                            items.add(_menuItem<String>(u.usoCfdi, '${u.usoCfdi} - ${u.descripcion ?? ''}', i));
                          }
                          final value = items.any((i) => i.value == _usoCfdi) ? _usoCfdi : null;
                          return DropdownButtonFormField<String>(
                            initialValue: value,
                            isExpanded: true,
                            items: items,
                            style: const TextStyle(fontSize: 12),
                            onChanged: _saving
                                ? null
                                : (v) => setState(() {
                                      _usoCfdi = v;
                                    }),
                            decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                          );
                        },
                        loading: () => const _LoadingField(),
                        error: (e, _) => _ErrorField(message: 'Error'),
                      ),
                    ),
                    SizedBox(
                      width: 420,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton(
                          onPressed: _saving ? null : _submit,
                          child: Text(_saving ? 'Guardando...' : 'Guardar registro'),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 260,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '* Datos obligatorios',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 420,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 180,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _LoadingField extends StatelessWidget {
  const _LoadingField();

  @override
  Widget build(BuildContext context) {
    return const InputDecorator(
      decoration: InputDecoration(border: OutlineInputBorder(), isDense: true),
      child: SizedBox(height: 16, child: LinearProgressIndicator()),
    );
  }
}

class _ErrorField extends StatelessWidget {
  const _ErrorField({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
      child: Text(message),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final upper = newValue.text.toUpperCase();
    return newValue.copyWith(
      text: upper,
      selection: newValue.selection,
      composing: TextRange.empty,
    );
  }
}
