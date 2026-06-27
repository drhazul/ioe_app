import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/auth/auth_controller.dart';
import '../../domain/transferencia_models.dart';
import '../../providers/transferencia_provider.dart';

class TransferenciasReportesPage extends ConsumerStatefulWidget {
  const TransferenciasReportesPage({super.key});

  @override
  ConsumerState<TransferenciasReportesPage> createState() =>
      _TransferenciasReportesPageState();
}

class _TransferenciasReportesPageState
    extends ConsumerState<TransferenciasReportesPage> {
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
    final filters = TransferenciaFilters(
      doc: _doc,
      usuario: _usuario,
      fecha: _fecha,
      estatus: _estatus,
      suc: _suc,
      limit: 100,
    );
    final asyncList = _hasAppliedFilters
        ? ref.watch(transferenciaReportesProvider(filters))
        : null;
    final asyncSucursales = ref.watch(transferenciaSucursalesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes traspaso entre sucursales'),
        actions: [
          IconButton(
            tooltip: 'Refrescar',
            icon: const Icon(Icons.refresh),
            onPressed: _hasAppliedFilters
                ? () => ref.invalidate(transferenciaReportesProvider(filters))
                : null,
          ),
        ],
      ),
      body: !isJefeInventarios
          ? const Center(
              child: Text('Modulo reservado para jefe de inventarios.'),
            )
          : Column(
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
                          items: _estatusItems(),
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
                                  (s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(s),
                                  ),
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
                      ? const Center(
                          child: Text('Capture un filtro para consultar.'),
                        )
                      : asyncList.when(
                          data: (data) {
                            if (data.items.isEmpty) {
                              return const Center(
                                child: Text(
                                  'Sin transferencias para los filtros.',
                                ),
                              );
                            }
                            return ListView.separated(
                              padding: const EdgeInsets.all(12),
                              itemCount: data.items.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) =>
                                  _ReporteTransferenciaCard(
                                    doc: data.items[index],
                                  ),
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

  List<DropdownMenuItem<String>> _estatusItems() {
    return const [
      DropdownMenuItem(value: '', child: Text('Todos')),
      DropdownMenuItem(value: 'BORRADOR', child: Text('Borrador')),
      DropdownMenuItem(value: 'PENDIENTE', child: Text('Pendiente')),
      DropdownMenuItem(value: 'LIBERADA', child: Text('Liberada')),
      DropdownMenuItem(value: 'PREPARACION', child: Text('Preparacion')),
      DropdownMenuItem(value: 'TRANSITO', child: Text('Transito')),
      DropdownMenuItem(value: 'REVISANDO', child: Text('Revisando')),
      DropdownMenuItem(value: 'CONTABILIZADO', child: Text('Contabilizado')),
      DropdownMenuItem(value: 'RECHAZADA', child: Text('Rechazada')),
    ];
  }

  void _applyFilters() {
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
}

class _ReporteTransferenciaCard extends StatelessWidget {
  const _ReporteTransferenciaCard({required this.doc});

  final TransferenciaDocModel doc;

  @override
  Widget build(BuildContext context) {
    final hasIncidencia = doc.hasIncidencia;
    final borderColor = hasIncidencia
        ? Colors.red.shade300
        : Colors.grey.shade300;
    final bgColor = hasIncidencia
        ? Colors.red.withValues(alpha: 0.06)
        : Colors.transparent;
    return Card(
      elevation: 0,
      color: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: borderColor, width: hasIncidencia ? 1.3 : 1),
      ),
      child: ListTile(
        leading: Icon(
          hasIncidencia ? Icons.report_problem_outlined : Icons.swap_horiz,
          color: hasIncidencia ? Colors.red.shade700 : null,
        ),
        title: Text('DOC ${doc.doc} | ${doc.sucSal} -> ${doc.sucEnt}'),
        subtitle: Text(
          '${_fmtDate(doc.fcnd)} | ${doc.estatus} | ${doc.detalleActivo} articulos | ${_money(doc.imp)}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.go('/modulos/transferencias-reportes/${doc.doc}'),
      ),
    );
  }
}

String _friendlyError(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['message'] != null) return '${data['message']}';
    return error.message ?? 'No fue posible completar la operacion.';
  }
  return error.toString();
}

String _fmtDate(DateTime? value) {
  if (value == null) return '-';
  return '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

String _money(double value) => '\$${value.toStringAsFixed(2)}';
