import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ioe_app/core/api_error.dart';

import 'cotizaciones_models.dart';
import 'cotizaciones_providers.dart';

class CotizacionFormPage extends ConsumerWidget {
  const CotizacionFormPage({super.key, this.idfol});

  final String? idfol;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(idfol == null ? 'Nueva cotización' : 'Editar cotización')),
      body: CotizacionFormBody(idfol: idfol),
    );
  }
}

class CotizacionFormBody extends ConsumerStatefulWidget {
  const CotizacionFormBody({super.key, this.idfol, this.onSaved});

  final String? idfol;
  final VoidCallback? onSaved;

  @override
  ConsumerState<CotizacionFormBody> createState() => _CotizacionFormBodyState();
}

class _CotizacionFormBodyState extends ConsumerState<CotizacionFormBody> {
  final _formKey = GlobalKey<FormState>();
  final _idfolCtrl = TextEditingController();
  final _clienCtrl = TextEditingController();
  final _docCtrl = TextEditingController();
  final _fcnCtrl = TextEditingController();
  final _sucCtrl = TextEditingController();
  final _terCtrl = TextEditingController();
  final _traCtrl = TextEditingController();
  final _opvCtrl = TextEditingController();
  final _estaCtrl = TextEditingController();
  final _imptCtrl = TextEditingController();
  final _fpgoCtrl = TextEditingController();
  final _imppCtrl = TextEditingController();
  final _autCtrl = TextEditingController();
  final _reqfCtrl = TextEditingController();
  final _fcnmCtrl = TextEditingController();
  final _opvmCtrl = TextEditingController();
  final _modCtrl = TextEditingController();
  final _idfolorigCtrl = TextEditingController();

  late Future<void> _loader;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loader = _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (widget.idfol == null) return;
    final model = await ref.read(cotizacionesApiProvider).fetchCotizacion(widget.idfol!);
    _apply(model);
  }

  void _apply(PvCtrFolAsvrModel c) {
    _idfolCtrl.text = c.idfol;
    _clienCtrl.text = c.clien?.toString() ?? '';
    _docCtrl.text = c.doc ?? '';
    _fcnCtrl.text = c.fcn?.toIso8601String() ?? '';
    _sucCtrl.text = c.suc ?? '';
    _terCtrl.text = c.ter ?? '';
    _traCtrl.text = c.tra ?? '';
    _opvCtrl.text = c.opv ?? '';
    _estaCtrl.text = c.esta ?? '';
    _imptCtrl.text = c.impt?.toString() ?? '';
    _fpgoCtrl.text = c.fpgo ?? '';
    _imppCtrl.text = c.impp?.toString() ?? '';
    _autCtrl.text = c.aut ?? '';
    _reqfCtrl.text = c.reqf?.toString() ?? '';
    _fcnmCtrl.text = c.fcnm?.toIso8601String() ?? '';
    _opvmCtrl.text = c.opvm ?? '';
    _modCtrl.text = c.mod?.toString() ?? '';
    _idfolorigCtrl.text = c.idfolorig ?? '';
  }

  @override
  void dispose() {
    _idfolCtrl.dispose();
    _clienCtrl.dispose();
    _docCtrl.dispose();
    _fcnCtrl.dispose();
    _sucCtrl.dispose();
    _terCtrl.dispose();
    _traCtrl.dispose();
    _opvCtrl.dispose();
    _estaCtrl.dispose();
    _imptCtrl.dispose();
    _fpgoCtrl.dispose();
    _imppCtrl.dispose();
    _autCtrl.dispose();
    _reqfCtrl.dispose();
    _fcnmCtrl.dispose();
    _opvmCtrl.dispose();
    _modCtrl.dispose();
    _idfolorigCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final payload = <String, dynamic>{
      'IDFOL': _idfolCtrl.text.trim(),
      'CLIEN': _parseInt(_clienCtrl.text),
      'DOC': _docCtrl.text.trim().isEmpty ? null : _docCtrl.text.trim(),
      'FCN': _fcnCtrl.text.trim().isEmpty ? null : _fcnCtrl.text.trim(),
      'SUC': _sucCtrl.text.trim().isEmpty ? null : _sucCtrl.text.trim(),
      'TER': _terCtrl.text.trim().isEmpty ? null : _terCtrl.text.trim(),
      'TRA': _traCtrl.text.trim().isEmpty ? null : _traCtrl.text.trim(),
      'OPV': _opvCtrl.text.trim().isEmpty ? null : _opvCtrl.text.trim(),
      'ESTA': _estaCtrl.text.trim().isEmpty ? null : _estaCtrl.text.trim(),
      'IMPT': _parseDouble(_imptCtrl.text),
      'FPGO': _fpgoCtrl.text.trim().isEmpty ? null : _fpgoCtrl.text.trim(),
      'IMPP': _parseDouble(_imppCtrl.text),
      'AUT': _autCtrl.text.trim().isEmpty ? null : _autCtrl.text.trim(),
      'REQF': _parseInt(_reqfCtrl.text),
      'FCNM': _fcnmCtrl.text.trim().isEmpty ? null : _fcnmCtrl.text.trim(),
      'OPVM': _opvmCtrl.text.trim().isEmpty ? null : _opvmCtrl.text.trim(),
      'MOD': _parseInt(_modCtrl.text),
      'IDFOLORIG': _idfolorigCtrl.text.trim().isEmpty ? null : _idfolorigCtrl.text.trim(),
    };

    try {
      if (widget.idfol == null) {
        await ref.read(cotizacionesApiProvider).createCotizacion(payload);
      } else {
        await ref.read(cotizacionesApiProvider).updateCotizacion(widget.idfol!, payload);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Registro guardado correctamente')));
      ref.invalidate(cotizacionesListProvider);
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

  int? _parseInt(String value) {
    final v = value.trim();
    if (v.isEmpty) return null;
    return int.tryParse(v);
  }

  double? _parseDouble(String value) {
    final v = value.trim();
    if (v.isEmpty) return null;
    return double.tryParse(v.replaceAll(',', ''));
  }

  @override
  Widget build(BuildContext context) {
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
                  widget.idfol == null ? 'Alta de cotización' : 'Editar cotización',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    _LabeledField(
                      label: 'IDFOL *',
                      child: TextFormField(
                        controller: _idfolCtrl,
                        enabled: !_saving && widget.idfol == null,
                        decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                      ),
                    ),
                    _LabeledField(
                      label: 'N Cliente',
                      child: TextFormField(
                        controller: _clienCtrl,
                        enabled: !_saving,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                      ),
                    ),
                    _LabeledField(
                      label: 'DOC',
                      child: TextFormField(
                        controller: _docCtrl,
                        enabled: !_saving,
                        decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                      ),
                    ),
                    _LabeledField(
                      label: 'FCN (ISO)',
                      child: TextFormField(
                        controller: _fcnCtrl,
                        enabled: !_saving,
                        decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                      ),
                    ),
                    _LabeledField(
                      label: 'Sucursal',
                      child: TextFormField(
                        controller: _sucCtrl,
                        enabled: !_saving,
                        decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                      ),
                    ),
                    _LabeledField(
                      label: 'Terminal',
                      child: TextFormField(
                        controller: _terCtrl,
                        enabled: !_saving,
                        decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                      ),
                    ),
                    _LabeledField(
                      label: 'TRA',
                      child: TextFormField(
                        controller: _traCtrl,
                        enabled: !_saving,
                        decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                      ),
                    ),
                    _LabeledField(
                      label: 'OPV',
                      child: TextFormField(
                        controller: _opvCtrl,
                        enabled: !_saving,
                        decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                      ),
                    ),
                    _LabeledField(
                      label: 'Estado',
                      child: TextFormField(
                        controller: _estaCtrl,
                        enabled: !_saving,
                        decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                      ),
                    ),
                    _LabeledField(
                      label: 'Importe',
                      child: TextFormField(
                        controller: _imptCtrl,
                        enabled: !_saving,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                      ),
                    ),
                    _LabeledField(
                      label: 'FPGO',
                      child: TextFormField(
                        controller: _fpgoCtrl,
                        enabled: !_saving,
                        decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                      ),
                    ),
                    _LabeledField(
                      label: 'IMPP',
                      child: TextFormField(
                        controller: _imppCtrl,
                        enabled: !_saving,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                      ),
                    ),
                    _LabeledField(
                      label: 'AUT',
                      child: TextFormField(
                        controller: _autCtrl,
                        enabled: !_saving,
                        decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                      ),
                    ),
                    _LabeledField(
                      label: 'REQF',
                      child: TextFormField(
                        controller: _reqfCtrl,
                        enabled: !_saving,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                      ),
                    ),
                    _LabeledField(
                      label: 'FCNM (ISO)',
                      child: TextFormField(
                        controller: _fcnmCtrl,
                        enabled: !_saving,
                        decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                      ),
                    ),
                    _LabeledField(
                      label: 'OPVM',
                      child: TextFormField(
                        controller: _opvmCtrl,
                        enabled: !_saving,
                        decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                      ),
                    ),
                    _LabeledField(
                      label: 'MOD',
                      child: TextFormField(
                        controller: _modCtrl,
                        enabled: !_saving,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                      ),
                    ),
                    _LabeledField(
                      label: 'IDFOLORIG',
                      child: TextFormField(
                        controller: _idfolorigCtrl,
                        enabled: !_saving,
                        decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
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
