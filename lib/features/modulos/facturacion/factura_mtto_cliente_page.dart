import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ioe_app/core/api_error.dart';
import 'package:ioe_app/features/masterdata/sucursales/sucursales_models.dart';
import 'package:ioe_app/features/masterdata/sucursales/sucursales_providers.dart';
import 'package:ioe_app/features/modulos/facturacion/facturacion_mtto_cliente_providers.dart';
import 'package:ioe_app/features/modulos/punto_venta/clientes/cliente_form_page.dart'
    show UpperCaseTextFormatter;
import 'package:ioe_app/features/modulos/punto_venta/clientes/clientes_models.dart';
import 'package:ioe_app/features/modulos/punto_venta/clientes/clientes_providers.dart';
import 'package:ioe_app/features/modulos/punto_venta/clientes/datcatreg_providers.dart';
import 'package:ioe_app/features/modulos/punto_venta/clientes/datcatuso_providers.dart';

class FacturaMttoClientePage extends ConsumerStatefulWidget {
  const FacturaMttoClientePage({super.key});

  @override
  ConsumerState<FacturaMttoClientePage> createState() =>
      _FacturaMttoClientePageState();
}

class _FacturaMttoClientePageState
    extends ConsumerState<FacturaMttoClientePage> {
  static const String _selectDefault = 'SELECCIONAR';
  static const int _regimenDefault = 0;

  final _searchCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _razonCtrl = TextEditingController();
  final _rfcCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _codigoPostalCtrl = TextEditingController();
  final _domiCtrl = TextEditingController();
  final _ncelCtrl = TextEditingController();
  final _aliasCtrl = TextEditingController();
  final _upperFormatter = UpperCaseTextFormatter();

  String _searchBy = 'NOMBRE';
  String? _sucFilter;
  FactClientShpModel? _selectedClient;
  bool _saving = false;
  String? _rfcEmisor;
  String? _usoCfdi;
  int? _regimenFiscal;

  @override
  void initState() {
    super.initState();
    _rfcEmisor = _selectDefault;
    _usoCfdi = _selectDefault;
    _regimenFiscal = _regimenDefault;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _razonCtrl.dispose();
    _rfcCtrl.dispose();
    _emailCtrl.dispose();
    _codigoPostalCtrl.dispose();
    _domiCtrl.dispose();
    _ncelCtrl.dispose();
    _aliasCtrl.dispose();
    super.dispose();
  }

  FacturaClientesFilter get _currentFilter =>
      FacturaClientesFilter(suc: _sucFilter);

  @override
  Widget build(BuildContext context) {
    final allowedSucsAsync = ref.watch(facturaMttoAllowedSucursalesProvider);
    final sucursalesAsync = ref.watch(sucursalesListProvider);
    final clientsAsync = ref.watch(facturaClientesProvider(_currentFilter));

    return Scaffold(
      appBar: AppBar(title: const Text('Facturación · Mantenimiento de clientes')),
      body: allowedSucsAsync.when(
        data: (allowedSucs) => sucursalesAsync.when(
          data: (sucursales) => clientsAsync.when(
            data: (clientes) =>
                _buildContent(clientes, allowedSucs, sucursales, context),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text('Error al cargar clientes: $e'),
            ),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text('Error al cargar sucursales: $e'),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Error al cargar sucursales autorizadas: $e'),
        ),
      ),
    );
  }

  Widget _buildContent(
    List<FactClientShpModel> clientes,
    List<String> allowedSucs,
    List<SucursalModel> sucursales,
    BuildContext context,
  ) {
    final filtered = _filter(clientes);

    if (_sucFilter == null && allowedSucs.length == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final normalized = allowedSucs.first.trim().toUpperCase();
        if (normalized.isEmpty) return;
        setState(() => _sucFilter = normalized);
      });
    }

    if (_selectedClient != null &&
        !filtered.any((c) => c.idc == _selectedClient!.idc)) {
      _selectedClient = null;
    }

    final listPanel = _FacturaClientesList(
      clientes: filtered,
      selected: _selectedClient,
      onSelect: (cliente) {
        setState(() {
          _selectedClient = cliente;
          _applyCliente(cliente);
        });
      },
    );

    final detailPanel = _buildEditor(filtered, allowedSucs, sucursales, context);

    final isNarrow = MediaQuery.of(context).size.width < 900;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          _SearchBar(
            controller: _searchCtrl,
            searchBy: _searchBy,
            onSearchByChanged: (value) => setState(() => _searchBy = value),
            onSearch: () => setState(() {}),
            onClear: () => setState(() {
              _searchCtrl.clear();
              _selectedClient = null;
            }),
            onRefresh: _refreshClients,
            branchDropdown: _buildBranchDropdown(allowedSucs, sucursales),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: isNarrow
                ? Column(
                    children: [
                      Expanded(child: listPanel),
                      const SizedBox(height: 10),
                      Expanded(child: detailPanel),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: listPanel),
                      const SizedBox(width: 12),
                      Expanded(child: detailPanel),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBranchDropdown(
    List<String> allowedSucs,
    List<SucursalModel> sucursales,
  ) {
    final normalizedAllowed = allowedSucs
        .map((code) => code.trim().toUpperCase())
        .where((code) => code.isNotEmpty)
        .toList();
    final options = normalizedAllowed.isEmpty
        ? sucursales
            .map((s) => s.suc.trim().toUpperCase())
            .where((code) => code.isNotEmpty)
            .toSet()
            .toList()
        : normalizedAllowed;

    final labels = <String, String>{
      for (final suc in sucursales)
        suc.suc.trim().toUpperCase(): suc.desc?.trim() ?? ''
    };

    final items = <DropdownMenuItem<String?>>[
      const DropdownMenuItem(
        value: null,
        child: Text('Todas las sucursales'),
      ),
      for (final code in options)
        DropdownMenuItem(
          value: code,
          child: Text(labels[code]?.isNotEmpty == true
              ? '$code - ${labels[code]}'
              : code),
        ),
    ];

    return DropdownButton<String?>(
      value: _sucFilter,
      items: items,
      onChanged: (value) {
        setState(() {
          _sucFilter = value;
          _selectedClient = null;
        });
      },
    );
  }

  Widget _buildEditor(
    List<FactClientShpModel> clients,
    List<String> allowedSucs,
    List<SucursalModel> sucursales,
    BuildContext context,
  ) {
    if (_selectedClient == null) {
      return const Card(
        elevation: 0,
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Center(
            child: Text('Selecciona un cliente para editar sus datos'),
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailRow(
                label: 'IDC',
                value: _selectedClient!.idc.toString(),
              ),
              _DetailRow(
                label: 'Sucursal',
                value: _selectedClient!.suc ?? '-',
              ),
              const SizedBox(height: 12),
              _LabeledField(
                label: 'Alias/Óptica',
                child: TextFormField(
                  controller: _aliasCtrl,
                  enabled: !_saving,
                  inputFormatters: [_upperFormatter],
                  decoration:
                      const InputDecoration(border: OutlineInputBorder(), isDense: true),
                ),
              ),
              _LabeledField(
                label: 'Razón social *',
                child: TextFormField(
                  controller: _razonCtrl,
                  enabled: !_saving,
                  inputFormatters: [_upperFormatter],
                  decoration:
                      const InputDecoration(border: OutlineInputBorder(), isDense: true),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Requerido' : null,
                ),
              ),
              _LabeledField(
                label: 'RFC receptor *',
                child: TextFormField(
                  controller: _rfcCtrl,
                  enabled: !_saving,
                  inputFormatters: [_upperFormatter],
                  decoration:
                      const InputDecoration(border: OutlineInputBorder(), isDense: true),
                  validator: _validateRfc,
                ),
              ),
              _LabeledField(
                label: 'RFC emisor *',
                child: _buildRfcEmisorDropdown(sucursales, allowedSucs),
              ),
              _LabeledField(
                label: 'Domicilio',
                child: TextFormField(
                  controller: _domiCtrl,
                  enabled: !_saving,
                  decoration:
                      const InputDecoration(border: OutlineInputBorder(), isDense: true),
                ),
              ),
              _LabeledField(
                label: 'Email receptor *',
                child: TextFormField(
                  controller: _emailCtrl,
                  enabled: !_saving,
                  decoration:
                      const InputDecoration(border: OutlineInputBorder(), isDense: true),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Requerido' : null,
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
                  decoration:
                      const InputDecoration(border: OutlineInputBorder(), isDense: true),
                  validator: _validateTelefono,
                ),
              ),
              _LabeledField(
                label: 'Código postal *',
                child: TextFormField(
                  controller: _codigoPostalCtrl,
                  enabled: !_saving,
                  inputFormatters: [_upperFormatter],
                  decoration:
                      const InputDecoration(border: OutlineInputBorder(), isDense: true),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Requerido' : null,
                ),
              ),
              _LabeledField(
                label: 'Regimen fiscal receptor *',
                child: _buildRegimenDropdown(),
              ),
              _LabeledField(
                label: 'Uso CFDI *',
                child: _buildUsoCfdiDropdown(),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _saving ? null : _clearSelection,
                    child: const Text('CANCELAR'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saving ? null : _submit,
                    child: Text(_saving ? 'Guardando...' : 'Guardar cambios'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRfcEmisorDropdown(
    List<SucursalModel> sucursales,
    List<String> allowedSucs,
  ) {
    final normalizedAllowed = allowedSucs
        .map((code) => code.trim().toUpperCase())
        .where((code) => code.isNotEmpty)
        .toList();
    final filtered = normalizedAllowed.isEmpty
        ? sucursales
        : sucursales
            .where((s) =>
                normalizedAllowed.contains(s.suc.trim().toUpperCase()))
            .toList();

    if (filtered.isEmpty) {
      return const InputDecorator(
        decoration: InputDecoration(border: OutlineInputBorder(), isDense: true),
        child: Text('No hay sucursales disponibles'),
      );
    }

    final byRfc = <String, String>{};
    for (var i = 0; i < filtered.length; i++) {
      final suc = filtered[i];
      final rfc = (suc.rfc ?? '').trim();
      if (rfc.isEmpty) continue;
      if (byRfc.containsKey(rfc)) continue;
      final label = suc.desc?.trim().isNotEmpty == true
          ? '${suc.desc} - $rfc'
          : '$rfc (${suc.suc})';
      byRfc[rfc] = label;
    }

    final items = <DropdownMenuItem<String>>[
      _menuItem<String>(_selectDefault, _selectDefault, 0),
      for (var i = 0; i < byRfc.length; i++)
        _menuItem<String>(byRfc.keys.elementAt(i), byRfc.values.elementAt(i), i + 1),
    ];

    final currentSelection =
        items.any((e) => e.value == _rfcEmisor) ? _rfcEmisor : _selectDefault;

    return DropdownButtonFormField<String>(
      key: ValueKey(currentSelection),
      initialValue: currentSelection,
      items: items,
      isExpanded: true,
      decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
      onChanged: _saving
          ? null
          : (value) => setState(() => _rfcEmisor = value ?? _selectDefault),
      validator: (value) =>
          _isSelectPlaceholder(value) ? 'Requerido' : null,
    );
  }

  Widget _buildRegimenDropdown() {
    final regAsync = ref.watch(datCatRegListProvider);
    return regAsync.when(
      data: (regs) {
        final items = <DropdownMenuItem<int>>[
          _menuItem<int>(_regimenDefault, _selectDefault, 0),
        ];
        for (var i = 0; i < regs.length; i++) {
          final r = regs[i];
          items.add(
            _menuItem<int>(
              r.codigo,
              '${r.codigo} - ${r.descripcion ?? ''}',
              i + 1,
            ),
          );
        }
        final currentSelection = items.any((item) => item.value == _regimenFiscal)
            ? _regimenFiscal
            : _regimenDefault;
        return DropdownButtonFormField<int>(
          key: ValueKey(currentSelection),
          isExpanded: true,
          initialValue: currentSelection,
          items: items,
          decoration:
              const InputDecoration(border: OutlineInputBorder(), isDense: true),
          onChanged: _saving
              ? null
              : (value) => setState(() => _regimenFiscal = value),
          validator: (value) =>
              value == null || value <= 0 ? 'Requerido' : null,
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Error: $e'),
    );
  }

  Widget _buildUsoCfdiDropdown() {
    final usoAsync = ref.watch(datCatUsoListProvider);
    return usoAsync.when(
      data: (usos) {
        final items = <DropdownMenuItem<String>>[
          _menuItem<String>(_selectDefault, _selectDefault, 0),
        ];
        for (var i = 0; i < usos.length; i++) {
          final uso = usos[i];
          items.add(
            _menuItem<String>(
              uso.usoCfdi,
              '${uso.usoCfdi} - ${uso.descripcion ?? ''}',
              i + 1,
            ),
          );
        }
        final currentSelection = items.any((item) => item.value == _usoCfdi)
            ? _usoCfdi
            : _selectDefault;
        return DropdownButtonFormField<String>(
          key: ValueKey(currentSelection),
          isExpanded: true,
          initialValue: currentSelection,
          items: items,
          decoration:
              const InputDecoration(border: OutlineInputBorder(), isDense: true),
          onChanged: _saving
              ? null
              : (value) => setState(() => _usoCfdi = value ?? _selectDefault),
          validator: (value) =>
              _isSelectPlaceholder(value) ? 'Requerido' : null,
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Error: $e'),
    );
  }

  void _showMessage(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  DropdownMenuItem<T> _menuItem<T>(T value, String label, int index) {
    final bg = index.isEven ? Colors.grey.shade50 : Colors.transparent;
    return DropdownMenuItem<T>(
      value: value,
      child: Container(
        width: double.infinity,
        color: bg,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Text(label, style: const TextStyle(fontSize: 11)),
      ),
    );
  }

  void _applyCliente(FactClientShpModel cliente) {
    _razonCtrl.text = cliente.razonSocialReceptor;
    _rfcCtrl.text = cliente.rfcReceptor;
    _emailCtrl.text = cliente.emailReceptor;
    _domiCtrl.text = cliente.domicilio ?? '';
    _ncelCtrl.text = cliente.ncel ?? '';
    _aliasCtrl.text = cliente.optica ?? '';
    _codigoPostalCtrl.text = cliente.codigoPostalReceptor;
    _rfcEmisor = cliente.rfcEmisor;
    _usoCfdi = cliente.usoCfdi;
    _regimenFiscal = cliente.regimenFiscalReceptor.toInt();
  }

  void _clearSelection() {
    if (_saving) return;
    setState(() {
      _selectedClient = null;
      _razonCtrl.clear();
      _rfcCtrl.clear();
      _emailCtrl.clear();
      _domiCtrl.clear();
      _ncelCtrl.clear();
      _aliasCtrl.clear();
      _codigoPostalCtrl.clear();
      _rfcEmisor = _selectDefault;
      _usoCfdi = _selectDefault;
      _regimenFiscal = _regimenDefault;
    });
  }

  Future<void> _submit() async {
    if (_selectedClient == null) return;
    if (!_formKey.currentState!.validate()) return;

    final rfcEmisor = (_rfcEmisor ?? _selectDefault).trim();
    final usoCfdi = (_usoCfdi ?? _selectDefault).trim();
    final regimenFiscal = _regimenFiscal ?? _regimenDefault;

    if (_isSelectPlaceholder(rfcEmisor) ||
        _isSelectPlaceholder(usoCfdi) ||
        regimenFiscal <= 0) {
      _showMessage(
          'Completa los campos fiscales obligatorios antes de guardar.');
      return;
    }

    setState(() => _saving = true);
    final payload = <String, dynamic>{
      'RAZONSOCIALRECEPTOR': _razonCtrl.text.trim().toUpperCase(),
      'RFCRECEPTOR': _rfcCtrl.text.trim().toUpperCase(),
      'EMAILRECEPTOR': _emailCtrl.text.trim(),
      'DOMI': _domiCtrl.text.trim().isEmpty ? null : _domiCtrl.text.trim(),
      'NCEL': _ncelCtrl.text.trim().isEmpty ? null : _ncelCtrl.text.trim(),
      'OPTICA': _aliasCtrl.text.trim().isEmpty ? null : _aliasCtrl.text.trim().toUpperCase(),
      'RFCEMISOR': rfcEmisor,
      'USOCFDI': usoCfdi,
      'CODIGOPOSTALRECEPTOR': _codigoPostalCtrl.text.trim().toUpperCase(),
      'REGIMENFISCALRECEPTOR': regimenFiscal,
    };

    try {
      final idc = _selectedClient!.idc.toInt().toString();
      final updated =
          await ref.read(clientesApiProvider).updateCliente(idc, payload);
      setState(() {
        _selectedClient = updated;
        _applyCliente(updated);
      });
      _refreshClients();
      _showMessage('Registro actualizado correctamente.');
    } catch (error) {
      final msg = apiErrorMessage(error, fallback: 'No se pudo guardar');
      _showMessage('Error al guardar: $msg');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _refreshClients() {
    ref.invalidate(facturaClientesProvider(_currentFilter));
  }

  List<FactClientShpModel> _filter(List<FactClientShpModel> clientes) {
    final term = _searchCtrl.text.trim().toLowerCase();
    if (term.isEmpty) return clientes;
    return clientes.where((cliente) {
      switch (_searchBy) {
        case 'RFC':
          return cliente.rfcReceptor.toLowerCase().contains(term);
        case 'IDC':
          return cliente.idc.toString().toLowerCase().contains(term);
        case 'NOMBRE':
        default:
          return cliente.razonSocialReceptor.toLowerCase().contains(term);
      }
    }).toList();
  }

  bool _isSelectPlaceholder(String? value) {
    final normalized = (value ?? '').trim().toUpperCase();
    return normalized.isEmpty || normalized == _selectDefault;
  }

  String? _validateRfc(String? value) {
    final v = (value ?? '').trim().toUpperCase();
    if (v.isEmpty) return 'Requerido';
    if (v == 'XAXX010101000' || v == 'XEXX010101000') return null;
    final moral = RegExp(r'^[A-Z&Ñ]{3}\\d{2}(0[1-9]|1[0-2])(0[1-9]|[12]\\d|3[01])[A-Z0-9]{3}$');
    final fisica = RegExp(r'^[A-Z&Ñ]{4}\\d{2}(0[1-9]|1[0-2])(0[1-9]|[12]\\d|3[01])[A-Z0-9]{3}$');
    if (moral.hasMatch(v) || fisica.hasMatch(v)) return null;
    return 'RFC inválido';
  }

  String? _validateTelefono(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return null;
    if (v.length > 10) return 'Máximo 10 dígitos';
    return null;
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.searchBy,
    required this.onSearchByChanged,
    required this.onSearch,
    required this.onClear,
    required this.onRefresh,
    required this.branchDropdown,
  });

  final TextEditingController controller;
  final String searchBy;
  final ValueChanged<String> onSearchByChanged;
  final VoidCallback onSearch;
  final VoidCallback onClear;
  final VoidCallback onRefresh;
  final Widget branchDropdown;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            branchDropdown,
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Buscar por:'),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: searchBy,
                  items: const [
                    DropdownMenuItem(value: 'NOMBRE', child: Text('NOMBRE')),
                    DropdownMenuItem(value: 'RFC', child: Text('RFC')),
                    DropdownMenuItem(value: 'IDC', child: Text('IDC')),
                  ],
                  onChanged: (value) => onSearchByChanged(value ?? 'NOMBRE'),
                ),
              ],
            ),
            SizedBox(
              width: 320,
              child: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'Digite búsqueda',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => onSearch(),
              ),
            ),
            IconButton(
              onPressed: onSearch,
              icon: const Icon(Icons.search),
              tooltip: 'Buscar',
            ),
            IconButton(
              onPressed: onClear,
              icon: const Icon(Icons.clear),
              tooltip: 'Limpiar',
            ),
            IconButton(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refrescar',
            ),
          ],
        ),
      ),
    );
  }
}

class _FacturaClientesList extends StatelessWidget {
  const _FacturaClientesList({
    required this.clientes,
    required this.selected,
    required this.onSelect,
  });

  final List<FactClientShpModel> clientes;
  final FactClientShpModel? selected;
  final ValueChanged<FactClientShpModel> onSelect;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            color: Colors.grey.shade200,
            child: const Row(
              children: [
                SizedBox(width: 70, child: Text('SUC', style: TextStyle(fontWeight: FontWeight.w600))),
                SizedBox(width: 8),
                SizedBox(width: 120, child: Text('IDC', style: TextStyle(fontWeight: FontWeight.w600))),
                SizedBox(width: 8),
                Expanded(child: Text('NOMBRE O RAZÓN SOCIAL', style: TextStyle(fontWeight: FontWeight.w600))),
                SizedBox(width: 140, child: Text('RFC', style: TextStyle(fontWeight: FontWeight.w600))),
                SizedBox(width: 120, child: Text('NCEL', style: TextStyle(fontWeight: FontWeight.w600))),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              itemCount: clientes.length,
              itemBuilder: (_, index) {
                final cliente = clientes[index];
                final selectedRow = selected?.idc == cliente.idc;
                return InkWell(
                  onTap: () => onSelect(cliente),
                  child: Container(
                    color: selectedRow ? Colors.blue.shade50 : null,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Row(
                      children: [
                        SizedBox(width: 70, child: Text(cliente.suc ?? '-')),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 120,
                          child: Text(cliente.idc.toString()),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(cliente.razonSocialReceptor)),
                        SizedBox(width: 140, child: Text(cliente.rfcReceptor)),
                        SizedBox(width: 120, child: Text(cliente.ncel ?? '-')),
                      ],
                    ),
                  ),
                );
              },
              separatorBuilder: (context, index) => const Divider(height: 1),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
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
