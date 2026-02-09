import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'datart_providers.dart';

class DatArtFormPage extends ConsumerStatefulWidget {
  const DatArtFormPage({super.key, this.suc, this.art, this.upc});

  final String? suc;
  final String? art;
  final String? upc;

  @override
  ConsumerState<DatArtFormPage> createState() => _DatArtFormPageState();
}

class _DatArtFormPageState extends ConsumerState<DatArtFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _sucCtrl = TextEditingController();
  final _tipoCtrl = TextEditingController();
  final _artCtrl = TextEditingController();
  final _upcCtrl = TextEditingController();
  final _clavesatCtrl = TextEditingController();
  final _unimedsatCtrl = TextEditingController();
  final _desCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();
  final _stockMinCtrl = TextEditingController();
  final _estatusCtrl = TextEditingController();
  final _diaReabastoCtrl = TextEditingController();
  final _pvtaCtrl = TextEditingController();
  final _ctopCtrl = TextEditingController();
  final _unCompCtrl = TextEditingController();
  final _factCompCtrl = TextEditingController();
  final _unVtaCtrl = TextEditingController();
  final _factVtaCtrl = TextEditingController();

  final _prov1Ctrl = TextEditingController();
  final _ctoProv1Ctrl = TextEditingController();
  final _prov2Ctrl = TextEditingController();
  final _ctoProv2Ctrl = TextEditingController();
  final _prov3Ctrl = TextEditingController();
  final _ctoProv3Ctrl = TextEditingController();
  final _baseCtrl = TextEditingController();
  final _sphCtrl = TextEditingController();
  final _cylCtrl = TextEditingController();
  final _adicCtrl = TextEditingController();
  final _depaCtrl = TextEditingController();
  final _subdCtrl = TextEditingController();
  final _clasCtrl = TextEditingController();
  final _sclaCtrl = TextEditingController();
  final _scla2Ctrl = TextEditingController();
  final _umueCtrl = TextEditingController();
  final _utraCtrl = TextEditingController();
  final _univCtrl = TextEditingController();

  final _bloqCtrl = TextEditingController();
  final _marcaCtrl = TextEditingController();
  final _modeloCtrl = TextEditingController();

  bool _saving = false;
  late Future<void> _loader;

  bool get _isNew => widget.suc == null || widget.art == null || widget.upc == null;

  @override
  void initState() {
    super.initState();
    _loader = _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (_isNew) return;
    final data = await ref.read(datArtApiProvider).fetchArticulo(widget.suc!, widget.art!, widget.upc!);
    _sucCtrl.text = data.suc;
    _tipoCtrl.text = data.tipo ?? '';
    _artCtrl.text = data.art;
    _upcCtrl.text = data.upc;
    _clavesatCtrl.text = _fmtNum(data.clavesat);
    _unimedsatCtrl.text = data.unimedsat ?? '';
    _desCtrl.text = data.des ?? '';
    _stockCtrl.text = _fmtNum(data.stock);
    _stockMinCtrl.text = _fmtNum(data.stockMin);
    _estatusCtrl.text = data.estatus ?? '';
    _diaReabastoCtrl.text = _fmtNum(data.diaReabasto);
    _pvtaCtrl.text = _fmtNum(data.pvta);
    _ctopCtrl.text = _fmtNum(data.ctop);
    _unCompCtrl.text = data.unComp ?? '';
    _factCompCtrl.text = _fmtNum(data.factComp);
    _unVtaCtrl.text = data.unVta ?? '';
    _factVtaCtrl.text = _fmtNum(data.factVta);

    _prov1Ctrl.text = _fmtNum(data.prov1);
    _ctoProv1Ctrl.text = _fmtNum(data.ctoProv1);
    _prov2Ctrl.text = _fmtNum(data.prov2);
    _ctoProv2Ctrl.text = _fmtNum(data.ctoProv2);
    _prov3Ctrl.text = _fmtNum(data.prov3);
    _ctoProv3Ctrl.text = _fmtNum(data.ctoProv3);
    _baseCtrl.text = data.base ?? '';
    _sphCtrl.text = _fmtNum(data.sph);
    _cylCtrl.text = _fmtNum(data.cyl);
    _adicCtrl.text = _fmtNum(data.adic);
    _depaCtrl.text = _fmtNum(data.depa);
    _subdCtrl.text = _fmtNum(data.subd);
    _clasCtrl.text = _fmtNum(data.clas);
    _sclaCtrl.text = _fmtNum(data.scla);
    _scla2Ctrl.text = _fmtNum(data.scla2);
    _umueCtrl.text = _fmtNum(data.umue);
    _utraCtrl.text = _fmtNum(data.utra);
    _univCtrl.text = _fmtNum(data.univ);

    _bloqCtrl.text = data.bloq?.toString() ?? '';
    _marcaCtrl.text = data.marca ?? '';
    _modeloCtrl.text = data.modelo ?? '';
  }

  @override
  void dispose() {
    _sucCtrl.dispose();
    _tipoCtrl.dispose();
    _artCtrl.dispose();
    _upcCtrl.dispose();
    _clavesatCtrl.dispose();
    _unimedsatCtrl.dispose();
    _desCtrl.dispose();
    _stockCtrl.dispose();
    _stockMinCtrl.dispose();
    _estatusCtrl.dispose();
    _diaReabastoCtrl.dispose();
    _pvtaCtrl.dispose();
    _ctopCtrl.dispose();
    _unCompCtrl.dispose();
    _factCompCtrl.dispose();
    _unVtaCtrl.dispose();
    _factVtaCtrl.dispose();
    _prov1Ctrl.dispose();
    _ctoProv1Ctrl.dispose();
    _prov2Ctrl.dispose();
    _ctoProv2Ctrl.dispose();
    _prov3Ctrl.dispose();
    _ctoProv3Ctrl.dispose();
    _baseCtrl.dispose();
    _sphCtrl.dispose();
    _cylCtrl.dispose();
    _adicCtrl.dispose();
    _depaCtrl.dispose();
    _subdCtrl.dispose();
    _clasCtrl.dispose();
    _sclaCtrl.dispose();
    _scla2Ctrl.dispose();
    _umueCtrl.dispose();
    _utraCtrl.dispose();
    _univCtrl.dispose();
    _bloqCtrl.dispose();
    _marcaCtrl.dispose();
    _modeloCtrl.dispose();
    super.dispose();
  }

  String _fmtNum(double? value) => value?.toString() ?? '';

  double? _parseDouble(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    final normalized = trimmed.replaceAll(',', '.');
    return double.tryParse(normalized);
  }

  int? _parseInt(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    return int.tryParse(trimmed);
  }

  String? _parseString(String text) {
    final trimmed = text.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final payload = <String, dynamic>{
      if (_isNew) 'SUC': _sucCtrl.text.trim(),
      if (_isNew) 'ART': _artCtrl.text.trim(),
      if (_isNew) 'UPC': _upcCtrl.text.trim(),
      'TIPO': _parseString(_tipoCtrl.text),
      'CLAVESAT': _parseDouble(_clavesatCtrl.text),
      'UNIMEDSAT': _parseString(_unimedsatCtrl.text),
      'DES': _parseString(_desCtrl.text),
      'STOCK': _parseDouble(_stockCtrl.text),
      'STOCK_MIN': _parseDouble(_stockMinCtrl.text),
      'ESTATUS': _parseString(_estatusCtrl.text),
      'DIA_REABASTO': _parseDouble(_diaReabastoCtrl.text),
      'PVTA': _parseDouble(_pvtaCtrl.text),
      'CTOP': _parseDouble(_ctopCtrl.text),
      'UN_COMP': _parseString(_unCompCtrl.text),
      'FACT_COMP': _parseDouble(_factCompCtrl.text),
      'UN_VTA': _parseString(_unVtaCtrl.text),
      'FACT_VTA': _parseDouble(_factVtaCtrl.text),
      'PROV_1': _parseDouble(_prov1Ctrl.text),
      'CTO_PROV1': _parseDouble(_ctoProv1Ctrl.text),
      'PROV_2': _parseDouble(_prov2Ctrl.text),
      'CTO_PROV2': _parseDouble(_ctoProv2Ctrl.text),
      'PROV_3': _parseDouble(_prov3Ctrl.text),
      'CTO_PROV3': _parseDouble(_ctoProv3Ctrl.text),
      'BASE': _parseString(_baseCtrl.text),
      'SPH': _parseDouble(_sphCtrl.text),
      'CYL': _parseDouble(_cylCtrl.text),
      'ADIC': _parseDouble(_adicCtrl.text),
      'DEPA': _parseDouble(_depaCtrl.text),
      'SUBD': _parseDouble(_subdCtrl.text),
      'CLAS': _parseDouble(_clasCtrl.text),
      'SCLA': _parseDouble(_sclaCtrl.text),
      'SCLA2': _parseDouble(_scla2Ctrl.text),
      'UMUE': _parseDouble(_umueCtrl.text),
      'UTRA': _parseDouble(_utraCtrl.text),
      'UNIV': _parseDouble(_univCtrl.text),
      'BLOQ': _parseInt(_bloqCtrl.text),
      'MARCA': _parseString(_marcaCtrl.text),
      'MODELO': _parseString(_modeloCtrl.text),
    };

    try {
      if (_isNew) {
        await ref.read(datArtApiProvider).createArticulo(payload);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Artículo creado')));
        }
      } else {
        await ref.read(datArtApiProvider).updateArticulo(widget.suc!, widget.art!, widget.upc!, payload);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Artículo actualizado')));
        }
      }
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
    final numberInputType = const TextInputType.numberWithOptions(decimal: true, signed: true);
    final numberFormatters = [FilteringTextInputFormatter.allow(RegExp(r'[0-9,.-]'))];
    final intFormatters = [FilteringTextInputFormatter.digitsOnly];
    final upperFormatter = _UpperCaseTextFormatter();
    const denseDecoration = InputDecoration(border: OutlineInputBorder(), isDense: true);

    return Scaffold(
      appBar: AppBar(title: Text(_isNew ? 'Nuevo artículo' : 'Editar artículo')),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _FieldBox(
                        label: 'SUC',
                        width: 90,
                        child: TextFormField(
                          controller: _sucCtrl,
                          enabled: !_saving && _isNew,
                          decoration: denseDecoration,
                          inputFormatters: [upperFormatter, LengthLimitingTextInputFormatter(5)],
                          validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                        ),
                      ),
                      _FieldBox(
                        label: 'TIPO',
                        width: 110,
                        child: TextFormField(
                          controller: _tipoCtrl,
                          enabled: !_saving,
                          decoration: denseDecoration,
                          inputFormatters: [upperFormatter],
                        ),
                      ),
                      _FieldBox(
                        label: 'ART',
                        width: 110,
                        child: TextFormField(
                          controller: _artCtrl,
                          enabled: !_saving && _isNew,
                          decoration: denseDecoration,
                          inputFormatters: [upperFormatter, LengthLimitingTextInputFormatter(10)],
                          validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                        ),
                      ),
                      _FieldBox(
                        label: 'UPC',
                        width: 140,
                        child: TextFormField(
                          controller: _upcCtrl,
                          enabled: !_saving && _isNew,
                          decoration: denseDecoration,
                          inputFormatters: [upperFormatter, LengthLimitingTextInputFormatter(15)],
                          validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                        ),
                      ),
                      _FieldBox(
                        label: 'CLAVESAT',
                        width: 120,
                        child: TextFormField(
                          controller: _clavesatCtrl,
                          enabled: !_saving,
                          keyboardType: numberInputType,
                          inputFormatters: numberFormatters,
                          decoration: denseDecoration,
                        ),
                      ),
                      _FieldBox(
                        label: 'UNIMEDSAT',
                        width: 140,
                        child: TextFormField(
                          controller: _unimedsatCtrl,
                          enabled: !_saving,
                          inputFormatters: [upperFormatter],
                          decoration: denseDecoration,
                        ),
                      ),
                      _FieldBox(
                        label: 'DES',
                        width: 260,
                        child: TextFormField(
                          controller: _desCtrl,
                          enabled: !_saving,
                          decoration: denseDecoration,
                        ),
                      ),
                      _FieldBox(
                        label: 'STOCK',
                        width: 110,
                        child: TextFormField(
                          controller: _stockCtrl,
                          enabled: !_saving,
                          keyboardType: numberInputType,
                          inputFormatters: numberFormatters,
                          decoration: denseDecoration,
                        ),
                      ),
                      _FieldBox(
                        label: 'STOCK_MIN',
                        width: 120,
                        child: TextFormField(
                          controller: _stockMinCtrl,
                          enabled: !_saving,
                          keyboardType: numberInputType,
                          inputFormatters: numberFormatters,
                          decoration: denseDecoration,
                        ),
                      ),
                      _FieldBox(
                        label: 'ESTATUS',
                        width: 130,
                        child: TextFormField(
                          controller: _estatusCtrl,
                          enabled: !_saving,
                          inputFormatters: [upperFormatter],
                          decoration: denseDecoration,
                        ),
                      ),
                      _FieldBox(
                        label: 'DIA_REABASTO',
                        width: 130,
                        child: TextFormField(
                          controller: _diaReabastoCtrl,
                          enabled: !_saving,
                          keyboardType: numberInputType,
                          inputFormatters: numberFormatters,
                          decoration: denseDecoration,
                        ),
                      ),
                      _FieldBox(
                        label: 'PVTA',
                        width: 110,
                        child: TextFormField(
                          controller: _pvtaCtrl,
                          enabled: !_saving,
                          keyboardType: numberInputType,
                          inputFormatters: numberFormatters,
                          decoration: denseDecoration,
                        ),
                      ),
                      _FieldBox(
                        label: 'CTOP',
                        width: 110,
                        child: TextFormField(
                          controller: _ctopCtrl,
                          enabled: !_saving,
                          keyboardType: numberInputType,
                          inputFormatters: numberFormatters,
                          decoration: denseDecoration,
                        ),
                      ),
                      _FieldBox(
                        label: 'UN_COMP',
                        width: 120,
                        child: TextFormField(
                          controller: _unCompCtrl,
                          enabled: !_saving,
                          inputFormatters: [upperFormatter],
                          decoration: denseDecoration,
                        ),
                      ),
                      _FieldBox(
                        label: 'FACT_COMP',
                        width: 120,
                        child: TextFormField(
                          controller: _factCompCtrl,
                          enabled: !_saving,
                          keyboardType: numberInputType,
                          inputFormatters: numberFormatters,
                          decoration: denseDecoration,
                        ),
                      ),
                      _FieldBox(
                        label: 'UN_VTA',
                        width: 120,
                        child: TextFormField(
                          controller: _unVtaCtrl,
                          enabled: !_saving,
                          inputFormatters: [upperFormatter],
                          decoration: denseDecoration,
                        ),
                      ),
                      _FieldBox(
                        label: 'FACT_VTA',
                        width: 120,
                        child: TextFormField(
                          controller: _factVtaCtrl,
                          enabled: !_saving,
                          keyboardType: numberInputType,
                          inputFormatters: numberFormatters,
                          decoration: denseDecoration,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _FieldBox(
                        label: 'PROV_1',
                        width: 110,
                        child: TextFormField(
                          controller: _prov1Ctrl,
                          enabled: !_saving,
                          keyboardType: numberInputType,
                          inputFormatters: numberFormatters,
                          decoration: denseDecoration,
                        ),
                      ),
                      _FieldBox(
                        label: 'CTO_PROV1',
                        width: 120,
                        child: TextFormField(
                          controller: _ctoProv1Ctrl,
                          enabled: !_saving,
                          keyboardType: numberInputType,
                          inputFormatters: numberFormatters,
                          decoration: denseDecoration,
                        ),
                      ),
                      _FieldBox(
                        label: 'PROV_2',
                        width: 110,
                        child: TextFormField(
                          controller: _prov2Ctrl,
                          enabled: !_saving,
                          keyboardType: numberInputType,
                          inputFormatters: numberFormatters,
                          decoration: denseDecoration,
                        ),
                      ),
                      _FieldBox(
                        label: 'CTO_PROV2',
                        width: 120,
                        child: TextFormField(
                          controller: _ctoProv2Ctrl,
                          enabled: !_saving,
                          keyboardType: numberInputType,
                          inputFormatters: numberFormatters,
                          decoration: denseDecoration,
                        ),
                      ),
                      _FieldBox(
                        label: 'PROV_3',
                        width: 110,
                        child: TextFormField(
                          controller: _prov3Ctrl,
                          enabled: !_saving,
                          keyboardType: numberInputType,
                          inputFormatters: numberFormatters,
                          decoration: denseDecoration,
                        ),
                      ),
                      _FieldBox(
                        label: 'CTO_PROV3',
                        width: 120,
                        child: TextFormField(
                          controller: _ctoProv3Ctrl,
                          enabled: !_saving,
                          keyboardType: numberInputType,
                          inputFormatters: numberFormatters,
                          decoration: denseDecoration,
                        ),
                      ),
                      _FieldBox(
                        label: 'BASE',
                        width: 120,
                        child: TextFormField(
                          controller: _baseCtrl,
                          enabled: !_saving,
                          inputFormatters: [upperFormatter],
                          decoration: denseDecoration,
                        ),
                      ),
                      _FieldBox(
                        label: 'SPH',
                        width: 90,
                        child: TextFormField(
                          controller: _sphCtrl,
                          enabled: !_saving,
                          keyboardType: numberInputType,
                          inputFormatters: numberFormatters,
                          decoration: denseDecoration,
                        ),
                      ),
                      _FieldBox(
                        label: 'CYL',
                        width: 90,
                        child: TextFormField(
                          controller: _cylCtrl,
                          enabled: !_saving,
                          keyboardType: numberInputType,
                          inputFormatters: numberFormatters,
                          decoration: denseDecoration,
                        ),
                      ),
                      _FieldBox(
                        label: 'ADIC',
                        width: 90,
                        child: TextFormField(
                          controller: _adicCtrl,
                          enabled: !_saving,
                          keyboardType: numberInputType,
                          inputFormatters: numberFormatters,
                          decoration: denseDecoration,
                        ),
                      ),
                      _FieldBox(
                        label: 'DEPA',
                        width: 90,
                        child: TextFormField(
                          controller: _depaCtrl,
                          enabled: !_saving,
                          keyboardType: numberInputType,
                          inputFormatters: numberFormatters,
                          decoration: denseDecoration,
                        ),
                      ),
                      _FieldBox(
                        label: 'SUBD',
                        width: 90,
                        child: TextFormField(
                          controller: _subdCtrl,
                          enabled: !_saving,
                          keyboardType: numberInputType,
                          inputFormatters: numberFormatters,
                          decoration: denseDecoration,
                        ),
                      ),
                      _FieldBox(
                        label: 'CLAS',
                        width: 90,
                        child: TextFormField(
                          controller: _clasCtrl,
                          enabled: !_saving,
                          keyboardType: numberInputType,
                          inputFormatters: numberFormatters,
                          decoration: denseDecoration,
                        ),
                      ),
                      _FieldBox(
                        label: 'SCLA',
                        width: 90,
                        child: TextFormField(
                          controller: _sclaCtrl,
                          enabled: !_saving,
                          keyboardType: numberInputType,
                          inputFormatters: numberFormatters,
                          decoration: denseDecoration,
                        ),
                      ),
                      _FieldBox(
                        label: 'SCLA2',
                        width: 90,
                        child: TextFormField(
                          controller: _scla2Ctrl,
                          enabled: !_saving,
                          keyboardType: numberInputType,
                          inputFormatters: numberFormatters,
                          decoration: denseDecoration,
                        ),
                      ),
                      _FieldBox(
                        label: 'UMUE',
                        width: 90,
                        child: TextFormField(
                          controller: _umueCtrl,
                          enabled: !_saving,
                          keyboardType: numberInputType,
                          inputFormatters: numberFormatters,
                          decoration: denseDecoration,
                        ),
                      ),
                      _FieldBox(
                        label: 'UTRA',
                        width: 90,
                        child: TextFormField(
                          controller: _utraCtrl,
                          enabled: !_saving,
                          keyboardType: numberInputType,
                          inputFormatters: numberFormatters,
                          decoration: denseDecoration,
                        ),
                      ),
                      _FieldBox(
                        label: 'UNIV',
                        width: 90,
                        child: TextFormField(
                          controller: _univCtrl,
                          enabled: !_saving,
                          keyboardType: numberInputType,
                          inputFormatters: numberFormatters,
                          decoration: denseDecoration,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _FieldBox(
                        label: 'BLOQ',
                        width: 90,
                        child: TextFormField(
                          controller: _bloqCtrl,
                          enabled: !_saving,
                          keyboardType: TextInputType.number,
                          inputFormatters: intFormatters,
                          decoration: denseDecoration,
                        ),
                      ),
                      _FieldBox(
                        label: 'MARCA',
                        width: 180,
                        child: TextFormField(
                          controller: _marcaCtrl,
                          enabled: !_saving,
                          inputFormatters: [upperFormatter],
                          decoration: denseDecoration,
                        ),
                      ),
                      _FieldBox(
                        label: 'MODELO',
                        width: 260,
                        child: TextFormField(
                          controller: _modeloCtrl,
                          enabled: !_saving,
                          decoration: denseDecoration,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _submit,
                      icon: _saving
                          ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
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

class _FieldBox extends StatelessWidget {
  const _FieldBox({required this.label, required this.width, required this.child});

  final String label;
  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}

class _UpperCaseTextFormatter extends TextInputFormatter {
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
