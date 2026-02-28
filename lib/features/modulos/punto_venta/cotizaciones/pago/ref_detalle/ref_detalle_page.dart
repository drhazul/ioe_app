import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ioe_app/core/api_error.dart';

import 'ref_detalle_models.dart';
import 'ref_detalle_providers.dart';

class RefDetallePage extends ConsumerStatefulWidget {
  const RefDetallePage({
    super.key,
    required this.args,
  });

  final RefDetallePageArgs args;

  @override
  ConsumerState<RefDetallePage> createState() => _RefDetallePageState();
}

class _RefDetallePageState extends ConsumerState<RefDetallePage> {
  late final TextEditingController _imptCtrl;
  late final TextEditingController _idrefCtrl;
  late final TextEditingController _searchCtrl;
  late DateTime _fcnd;

  List<RefDetalleItem> _items = const [];
  RefDetalleItem? _selected;

  bool _loading = false;
  bool _creating = false;
  bool _assigning = false;
  bool _deleting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _imptCtrl = TextEditingController(
      text: widget.args.impt.toStringAsFixed(2),
    );
    _idrefCtrl = TextEditingController();
    _searchCtrl = TextEditingController();
    _fcnd = DateTime.now();
    _loadItems();
  }

  @override
  void dispose() {
    _imptCtrl.dispose();
    _idrefCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filter(_items, _searchCtrl.text);
    final canWork = !_loading && !_creating && !_assigning && !_deleting;

    return Scaffold(
      appBar: AppBar(
        title: const Text('REF_DETALLE'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ContextCard(
            idfol: widget.args.idfol,
            suc: widget.args.suc,
            idc: widget.args.idc,
            opv: widget.args.opv,
            tipo: widget.args.tipo,
            rfcEmisor: widget.args.rfcEmisor,
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _imptCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'IMPT',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _DateField(
                          value: _fcnd,
                          onPick: canWork ? _pickFcnd : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _idrefCtrl,
                    enabled: canWork,
                    decoration: const InputDecoration(
                      labelText: 'IDREF (opcional)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Restante permitido para referencia: ${_money(widget.args.maxImpt)}',
                    style: TextStyle(color: Theme.of(context).colorScheme.primary),
                  ),
                  if ((_error ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: canWork ? _crearRef : null,
                        icon: _creating
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.add_card_outlined),
                        label: const Text('Crear Ref.'),
                      ),
                      OutlinedButton.icon(
                        onPressed: canWork && _selected != null
                            ? _eliminarSeleccionada
                            : null,
                        icon: _deleting
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.delete_outline),
                        label: const Text('Eliminar seleccionada'),
                      ),
                      FilledButton.icon(
                        onPressed: canWork && _selected != null
                            ? _seleccionarGuardar
                            : null,
                        icon: _assigning
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.check_circle_outline),
                        label: const Text('Seleccionar / Guardar'),
                      ),
                      TextButton(
                        onPressed: canWork ? () => Navigator.of(context).pop() : null,
                        child: const Text('Cancelar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _searchCtrl,
                    enabled: canWork,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Buscar referencia (IDREF)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (filtered.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('Sin referencias para este folio/tipo'),
                    )
                  else
                    RadioGroup<String>(
                      groupValue: _selected?.idref,
                      onChanged: (value) {
                        if (value == null) return;
                        for (final item in filtered) {
                          if (item.idref == value) {
                            setState(() => _selected = item);
                            return;
                          }
                        }
                      },
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 360),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (_, index) {
                            final item = filtered[index];
                            final selected = _selected?.idref == item.idref;
                            return ListTile(
                              dense: true,
                              selected: selected,
                              onTap: () => setState(() => _selected = item),
                              leading: Radio<String>(
                                value: item.idref,
                              ),
                              title: Text(item.idref),
                              subtitle: Text(
                                'Estatus: ${item.estatus ?? '-'} | IMPT: ${_money(item.impt ?? 0)} | FCND: ${_date(item.fcnd)}',
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadItems() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(refDetalleApiProvider);
      final rows = await api.fetchByFolio(
        idfol: widget.args.idfol,
        tipo: widget.args.tipo,
      );
      RefDetalleItem? selected = _selected;
      final initialIdref = (widget.args.initialIdref ?? '').trim();
      if (initialIdref.isNotEmpty) {
        selected = rows.firstWhere(
          (item) => item.idref.trim().toUpperCase() == initialIdref.toUpperCase(),
          orElse: () => selected ?? const RefDetalleItem(
            idref: '',
            suc: null,
            fcnr: null,
            fcnd: null,
            opv: null,
            idfol: null,
            idc: null,
            rfcEmisor: null,
            tipo: null,
            impt: null,
            estatus: null,
          ),
        );
        if (selected.idref.isEmpty) {
          selected = null;
        }
      }
      if (selected != null) {
        final exists = rows.any((e) => e.idref == selected!.idref);
        if (!exists) selected = null;
      }

      if (!mounted) return;
      setState(() {
        _items = rows;
        _selected = selected;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = apiErrorMessage(e, fallback: 'No se pudieron cargar referencias');
      });
    }
  }

  Future<void> _crearRef() async {
    final validation = _validateCrear();
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }

    final impt = _parseAmount(_imptCtrl.text) ?? 0;
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      final api = ref.read(refDetalleApiProvider);
      final result = await api.crear(
        suc: widget.args.suc,
        idfol: widget.args.idfol,
        idc: widget.args.idc,
        opv: widget.args.opv,
        rfcEmisor: widget.args.rfcEmisor,
        tipo: widget.args.tipo,
        impt: impt,
        fcnd: _fcnd,
        idref: _idrefCtrl.text.trim().isEmpty ? null : _idrefCtrl.text.trim(),
      );

      await _loadItems();
      if (!mounted) return;
      RefDetalleItem? selected;
      for (final item in _items) {
        if (item.idref.trim().toUpperCase() == result.idref.toUpperCase()) {
          selected = item;
          break;
        }
      }
      selected ??= _items.isNotEmpty ? _items.first : null;
      setState(() {
        _creating = false;
        _selected = selected;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Referencia creada: ${result.idref}')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _creating = false;
        _error = apiErrorMessage(e, fallback: 'No se pudo crear referencia');
      });
    }
  }

  Future<void> _seleccionarGuardar() async {
    final selected = _selected;
    if (selected == null) {
      setState(() => _error = 'Selecciona una referencia');
      return;
    }
    setState(() {
      _assigning = true;
      _error = null;
    });
    try {
      final api = ref.read(refDetalleApiProvider);
      await api.asignar(idref: selected.idref, idfol: widget.args.idfol);

      if (!mounted) return;
      Navigator.of(context).pop(
        RefDetalleSelectionResult(
          idref: selected.idref,
          impt: selected.impt ?? (_parseAmount(_imptCtrl.text) ?? widget.args.impt),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _assigning = false;
        _error = apiErrorMessage(e, fallback: 'No se pudo asignar referencia');
      });
    }
  }

  Future<void> _eliminarSeleccionada() async {
    final selected = _selected;
    if (selected == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar referencia'),
        content: Text('¿Deseas eliminar la referencia ${selected.idref}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      final api = ref.read(refDetalleApiProvider);
      await api.eliminar(idref: selected.idref, idfol: widget.args.idfol);
      await _loadItems();
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _selected = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Referencia eliminada')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _error = apiErrorMessage(e, fallback: 'No se pudo eliminar referencia');
      });
    }
  }

  Future<void> _pickFcnd() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _fcnd,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;
    setState(() => _fcnd = picked);
  }

  String? _validateCrear() {
    final tipo = widget.args.tipo.trim().toUpperCase();
    final idc = widget.args.idc;
    final rfc = widget.args.rfcEmisor.trim();
    final impt = _parseAmount(_imptCtrl.text);

    if (rfc.isEmpty) {
      return 'RFC emisor requerido';
    }
    if (impt == null || impt <= 0) {
      return 'IMPT inválido';
    }
    if (impt - widget.args.maxImpt > 0.0001) {
      return 'El importe de referencia no puede ser mayor al restante por pagar';
    }
    if ((widget.args.rqfac || tipo != 'EFECTIVO') && idc == 1) {
      return 'Para formas no efectivo o con factura, el cliente no puede ser 1';
    }
    return null;
  }

  List<RefDetalleItem> _filter(List<RefDetalleItem> data, String raw) {
    final term = raw.trim().toLowerCase();
    if (term.isEmpty) return data;
    return data.where((item) {
      return item.idref.toLowerCase().contains(term);
    }).toList();
  }

  double? _parseAmount(String raw) {
    final text = raw.trim().replaceAll(',', '.');
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }
}

class _ContextCard extends StatelessWidget {
  const _ContextCard({
    required this.idfol,
    required this.suc,
    required this.idc,
    required this.opv,
    required this.tipo,
    required this.rfcEmisor,
  });

  final String idfol;
  final String suc;
  final int idc;
  final String opv;
  final String tipo;
  final String rfcEmisor;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 12,
          runSpacing: 10,
          children: [
            _ReadOnlyField(label: 'IDFOL', value: idfol),
            _ReadOnlyField(label: 'SUC', value: suc),
            _ReadOnlyField(label: 'IDC', value: idc.toString()),
            _ReadOnlyField(label: 'OPV', value: opv),
            _ReadOnlyField(label: 'TIPO', value: tipo),
            _ReadOnlyField(label: 'RfcEmisor', value: rfcEmisor),
          ],
        ),
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        child: Text(value.trim().isEmpty ? '-' : value),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.value,
    required this.onPick,
  });

  final DateTime value;
  final VoidCallback? onPick;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPick,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'FCND',
          border: const OutlineInputBorder(),
          isDense: true,
          suffixIcon: IconButton(
            onPressed: onPick,
            icon: const Icon(Icons.calendar_today),
          ),
        ),
        child: Text(_date(value)),
      ),
    );
  }
}

String _date(DateTime? value) {
  if (value == null) return '-';
  final dd = value.day.toString().padLeft(2, '0');
  final mm = value.month.toString().padLeft(2, '0');
  final yyyy = value.year.toString().padLeft(4, '0');
  return '$dd/$mm/$yyyy';
}

String _money(double value) => '\$${value.toStringAsFixed(2)}';
