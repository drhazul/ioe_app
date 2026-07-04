import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/auth/auth_controller.dart';
import '../../domain/transferencia_models.dart';
import '../../providers/transferencia_provider.dart';

class TransferenciasPage extends ConsumerStatefulWidget {
  const TransferenciasPage({super.key});

  @override
  ConsumerState<TransferenciasPage> createState() => _TransferenciasPageState();
}

class _TransferenciasPageState extends ConsumerState<TransferenciasPage> {
  static const _filterSucursales = {'DF01', 'DF02', 'DF04', 'DF05', 'DF06'};

  final _docCtrl = TextEditingController();
  final _usuarioCtrl = TextEditingController();
  final _fechaCtrl = TextEditingController();
  String _doc = '';
  String _usuario = '';
  String _fecha = '';
  String _estatus = '';
  String _suc = '';
  bool _hasAppliedFilters = false;

  @override
  void dispose() {
    _docCtrl.dispose();
    _usuarioCtrl.dispose();
    _fechaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final isJefeInventarios = auth.roleId == 2;
    final isLimitedEstatusRole = auth.roleId == 13008 || auth.roleId == 14008;
    final effectiveEstatus = isJefeInventarios ? 'PENDIENTE' : _estatus;
    final filters = TransferenciaFilters(
      doc: _doc,
      usuario: _usuario,
      fecha: _fecha,
      estatus: effectiveEstatus,
      suc: _suc,
    );
    final asyncList = _hasAppliedFilters
        ? ref.watch(transferenciasProvider(filters))
        : null;
    final asyncSucursales = ref.watch(transferenciaSucursalesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transferencias entre sucursales'),
        actions: [
          if (!isJefeInventarios)
            IconButton(
              tooltip: 'Nueva solicitud',
              icon: const Icon(Icons.add_circle_outline),
              onPressed: _openCreateDialog,
            ),
          IconButton(
            tooltip: 'Notificaciones',
            icon: const Icon(Icons.notifications_none),
            onPressed: _openNotifications,
          ),
          IconButton(
            tooltip: 'Refrescar',
            icon: const Icon(Icons.refresh),
            onPressed: _hasAppliedFilters
                ? () => ref.invalidate(transferenciasProvider(filters))
                : null,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 190,
                  child: TextField(
                    controller: _docCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Documento',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _applyFilters(),
                  ),
                ),
                SizedBox(
                  width: 190,
                  child: TextField(
                    controller: _usuarioCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Usuario',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _applyFilters(),
                  ),
                ),
                SizedBox(
                  width: 170,
                  child: TextField(
                    controller: _fechaCtrl,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Fecha',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      suffixIcon: IconButton(
                        tooltip: 'Seleccionar fecha',
                        icon: const Icon(Icons.calendar_month),
                        onPressed: _pickFecha,
                      ),
                    ),
                    onTap: _pickFecha,
                  ),
                ),
                if (!isJefeInventarios)
                  SizedBox(
                    width: 170,
                    child: DropdownButtonFormField<String>(
                      initialValue: _estatus,
                      isDense: true,
                      decoration: const InputDecoration(
                        labelText: 'Estatus',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: _estatusItems(isLimitedEstatusRole),
                      onChanged: (value) =>
                          setState(() => _estatus = value ?? ''),
                    ),
                  ),
                SizedBox(
                  width: 150,
                  child: asyncSucursales.when(
                    data: (sucs) {
                      final filterSucs =
                          sucs
                              .map((s) => s.trim().toUpperCase())
                              .where(_filterSucursales.contains)
                              .toSet()
                              .toList()
                            ..sort();
                      return DropdownButtonFormField<String>(
                        initialValue: _suc,
                        isDense: true,
                        decoration: const InputDecoration(
                          labelText: 'Sucursal',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: '',
                            child: Text('Todas'),
                          ),
                          ...filterSucs.map(
                            (s) => DropdownMenuItem(value: s, child: Text(s)),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => _suc = value ?? ''),
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (_, _) => const Text('Sin sucursales'),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _applyFilters,
                  icon: const Icon(Icons.search),
                  label: const Text('Filtrar'),
                ),
                OutlinedButton.icon(
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Limpiar'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: asyncList == null
                ? const Center(child: Text('Capture un filtro para consultar.'))
                : asyncList.when(
                    data: (data) {
                      if (data.items.isEmpty) {
                        return const Center(
                          child: Text('Sin transferencias para los filtros.'),
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: data.items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) =>
                            _TransferenciaCard(doc: data.items[index]),
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, _) =>
                        Center(child: Text(_friendlyError(error))),
                  ),
          ),
        ],
      ),
    );
  }

  List<DropdownMenuItem<String>> _estatusItems(bool limited) {
    const allItems = [
      DropdownMenuItem(value: '', child: Text('Todos')),
      DropdownMenuItem(value: 'BORRADOR', child: Text('Borrador')),
      DropdownMenuItem(value: 'PENDIENTE', child: Text('Pendiente')),
      DropdownMenuItem(value: 'LIBERADA', child: Text('Liberada')),
      DropdownMenuItem(value: 'PREPARACION', child: Text('Preparación')),
      DropdownMenuItem(value: 'TRANSITO', child: Text('Tránsito')),
      DropdownMenuItem(value: 'REVISANDO', child: Text('Revisando')),
      DropdownMenuItem(value: 'INCIDENCIA', child: Text('Incidencia')),
      DropdownMenuItem(value: 'CONTABILIZADO', child: Text('Contabilizado')),
      DropdownMenuItem(value: 'RECHAZADA', child: Text('Rechazada')),
    ];
    if (!limited) return allItems;
    const allowed = {'', 'BORRADOR', 'PREPARACION', 'TRANSITO', 'REVISANDO'};
    return allItems
        .where((item) => allowed.contains(item.value ?? ''))
        .toList();
  }

  void _applyFilters() {
    final hasVisibleFilter =
        _docCtrl.text.trim().isNotEmpty ||
        _usuarioCtrl.text.trim().isNotEmpty ||
        _fechaCtrl.text.trim().isNotEmpty ||
        _suc.trim().isNotEmpty ||
        _estatus.trim().isNotEmpty;
    if (!hasVisibleFilter) {
      setState(() => _hasAppliedFilters = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Capture al menos un filtro.')),
      );
      return;
    }
    setState(() {
      _doc = _docCtrl.text.trim();
      _usuario = _usuarioCtrl.text.trim();
      _fecha = _fechaCtrl.text.trim();
      _hasAppliedFilters = true;
    });
  }

  void _clearFilters() {
    setState(() {
      _docCtrl.clear();
      _usuarioCtrl.clear();
      _fechaCtrl.clear();
      _doc = '';
      _usuario = '';
      _fecha = '';
      _estatus = '';
      _suc = '';
      _hasAppliedFilters = false;
    });
  }

  Future<void> _pickFecha() async {
    final now = DateTime.now();
    final current = DateTime.tryParse(_fechaCtrl.text);
    final selected = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _fechaCtrl.text = _fmtDate(selected);
      _fecha = _fechaCtrl.text;
    });
  }

  Future<void> _openCreateDialog() async {
    final created = await showDialog<TransferenciaDocModel>(
      context: context,
      builder: (_) => const _CreateTransferenciaDialog(),
    );
    if (created == null || !mounted) return;
    context.go('/modulos/transferencias/${created.doc}');
  }

  Future<void> _openNotifications() async {
    final selectedDoc = await showDialog<String>(
      context: context,
      builder: (_) => const _TransferNotificationsDialog(),
    );
    if (selectedDoc == null || !mounted) return;
    context.go('/modulos/transferencias/$selectedDoc');
  }
}

class _TransferNotificationsDialog extends ConsumerWidget {
  const _TransferNotificationsDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AlertDialog(
      title: const Text('Notificaciones'),
      content: SizedBox(
        width: 560,
        height: 420,
        child: FutureBuilder<List<TransferenciaDocModel>>(
          future: ref.read(transferenciaApiProvider).notificaciones(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text(_friendlyError(snapshot.error!)));
            }
            final items = snapshot.data ?? const <TransferenciaDocModel>[];
            if (items.isEmpty) {
              return const Center(
                child: Text('Sin transferencias pendientes de seguimiento.'),
              );
            }
            return ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = items[index];
                return ListTile(
                  leading: Icon(
                    _notificationIcon(item.estatus),
                    color: _notificationColor(item.estatus),
                  ),
                  title: Text('DOC ${item.doc} | ${item.estatus}'),
                  subtitle: Text(
                    '${item.sucSal} -> ${item.sucEnt} | ${_fmtDate(item.fcnd)} | ${item.detalleActivo} artículos',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).pop(item.doc),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }

  IconData _notificationIcon(String estatus) {
    switch (estatus.trim().toUpperCase()) {
      case 'INCIDENCIA':
        return Icons.report_problem_outlined;
      case 'PENDIENTE':
        return Icons.rule;
      case 'TRANSITO':
        return Icons.local_shipping;
      default:
        return Icons.notifications_none;
    }
  }

  Color _notificationColor(String estatus) {
    switch (estatus.trim().toUpperCase()) {
      case 'INCIDENCIA':
        return Colors.red.shade700;
      case 'PENDIENTE':
        return Colors.orange.shade700;
      case 'TRANSITO':
        return Colors.blue.shade700;
      default:
        return Colors.teal.shade700;
    }
  }
}

class _TransferenciaCard extends StatelessWidget {
  const _TransferenciaCard({required this.doc});

  final TransferenciaDocModel doc;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: ListTile(
        leading: const Icon(Icons.swap_horiz),
        title: Text('DOC ${doc.doc} | ${doc.sucSal} -> ${doc.sucEnt}'),
        subtitle: Text(
          '${_fmtDate(doc.fcnd)} | ${doc.estatus} | ${doc.detalleActivo} artículos | ${_money(doc.imp)}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.go('/modulos/transferencias/${doc.doc}'),
      ),
    );
  }
}

class _CreateTransferenciaDialog extends ConsumerStatefulWidget {
  const _CreateTransferenciaDialog();

  @override
  ConsumerState<_CreateTransferenciaDialog> createState() =>
      _CreateTransferenciaDialogState();
}

class _CreateTransferenciaDialogState
    extends ConsumerState<_CreateTransferenciaDialog> {
  static const _transferSucursales = {'DF01', 'DF02', 'DF04', 'DF05', 'DF06'};

  final _txtCtrl = TextEditingController();
  String _sucEnt = '';
  String _sucSal = '';
  String _mtv = '';
  String _prio = 'NORMAL';
  bool _saving = false;

  @override
  void dispose() {
    _txtCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final sucsAsync = ref.watch(transferenciaSucursalesProvider);
    final motivosAsync = ref.watch(transferenciaMotivosProvider);
    final priosAsync = ref.watch(transferenciaPrioridadesProvider);
    if (_sucEnt.isEmpty) _sucEnt = (auth.suc ?? '').trim().toUpperCase();
    return AlertDialog(
      title: const Text('Nueva solicitud'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            sucsAsync.when(
              data: (_) {
                final allTransferSucs = _transferSucursales.toList()..sort();
                final userSuc = (auth.suc ?? '').trim().toUpperCase();
                final allowedSucs = _transferSucursales.contains(userSuc)
                    ? <String>[userSuc]
                    : allTransferSucs;
                if (_sucEnt.isNotEmpty && !allowedSucs.contains(_sucEnt)) {
                  _sucEnt = allowedSucs.isNotEmpty
                      ? allowedSucs.first
                      : allTransferSucs.first;
                }
                final validOrigenSucs = allTransferSucs
                    .where((s) => s != _sucEnt.trim().toUpperCase())
                    .toList();
                if (_sucSal.isNotEmpty && !validOrigenSucs.contains(_sucSal)) {
                  _sucSal = '';
                }
                return Row(
                  children: [
                    Expanded(
                      child: _combo(
                        label: 'Sucursal solicita',
                        value: _sucEnt,
                        values: allowedSucs,
                        onChanged: (v) => setState(() {
                          _sucEnt = v ?? '';
                          if (_sucSal == _sucEnt) _sucSal = '';
                        }),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _combo(
                        label: 'Sucursal origen',
                        value: _sucSal,
                        values: validOrigenSucs,
                        onChanged: (v) => setState(() => _sucSal = v ?? ''),
                      ),
                    ),
                  ],
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error sucursales: $e'),
            ),
            const SizedBox(height: 10),
            motivosAsync.when(
              data: (motivos) {
                if (_mtv.isEmpty && motivos.isNotEmpty) {
                  _mtv = motivos.first.value;
                }
                return _optionCombo(
                  label: 'Motivo',
                  value: _mtv,
                  values: motivos,
                  onChanged: (v) => setState(() => _mtv = v ?? ''),
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error motivos: $e'),
            ),
            const SizedBox(height: 10),
            priosAsync.when(
              data: (prios) => _optionCombo(
                label: 'Prioridad',
                value: _prio,
                values: prios,
                onChanged: (v) => setState(() => _prio = v ?? 'NORMAL'),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _txtCtrl,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Observaciones',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _create,
          child: _saving ? const Text('Creando...') : const Text('Crear'),
        ),
      ],
    );
  }

  Widget _combo({
    required String label,
    required String value,
    required List<String> values,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value.isEmpty ? '' : value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem(value: '', child: Text('Seleccionar')),
        ...values.map((s) => DropdownMenuItem(value: s, child: Text(s))),
      ],
      onChanged: onChanged,
    );
  }

  Widget _optionCombo({
    required String label,
    required String value,
    required List<TransferenciaCatalogOptionModel> values,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value.isEmpty ? null : value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: values
          .map(
            (x) => DropdownMenuItem(
              value: x.value,
              child: Text('${x.value} - ${x.label}'),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }

  Future<void> _create() async {
    if (_sucEnt.isEmpty || _sucSal.isEmpty || _mtv.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Sucursal solicitante, origen y motivo son requeridos.',
          ),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final created = await ref
          .read(transferenciaApiProvider)
          .create(
            sucEnt: _sucEnt,
            sucSal: _sucSal,
            mtv: _mtv,
            prio: _prio,
            txt: _txtCtrl.text,
          );
      if (mounted) Navigator.of(context).pop(created);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(e))));
    }
  }
}

String _friendlyError(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['message'] != null) return '${data['message']}';
    return error.message ?? 'No fue posible completar la operación.';
  }
  return error.toString();
}

String _fmtDate(DateTime? value) {
  if (value == null) return '-';
  return '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

String _money(double value) => '\$${value.toStringAsFixed(2)}';
