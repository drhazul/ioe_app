import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dio_provider.dart';
import 'fys_report_api.dart';

class FysReportPage extends ConsumerStatefulWidget {
  const FysReportPage({super.key});

  @override
  ConsumerState<FysReportPage> createState() => _FysReportPageState();
}

class _FysReportPageState extends ConsumerState<FysReportPage> {
  List<Map<String, dynamic>> _sucursales = const [];
  List<Map<String, dynamic>> _periodos = const [];
  int? _suc;
  String? _qna;
  Map<String, dynamic>? _ajuste;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadCatalogos);
  }

  FysReportApi get _api => FysReportApi(ref.read(dioProvider));

  Future<void> _loadCatalogos() async {
    setState(() => _busy = true);
    try {
      final data = await _api.catalogos();
      if (!mounted) return;
      setState(() {
        _sucursales = ((data['sucursales'] as List?) ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _periodos = ((data['periodos'] as List?) ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadAjustes() async {
    if (_suc == null || _qna == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final row = await _api.ajustes(suc: _suc!, qna: _qna!);
      if (mounted) setState(() => _ajuste = row);
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final periods = _periodos.where((p) => _int(p['suc']) == _suc).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Reporte de Faltantes')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 320,
                  child: DropdownButtonFormField<int>(
                    initialValue: _suc,
                    decoration: const InputDecoration(labelText: 'Sucursal'),
                    items: _sucursales.map((row) {
                      final suc = _int(row['suc'])!;
                      final nombre = '${row['nombre'] ?? ''}'.trim();
                      return DropdownMenuItem(
                        value: suc,
                        child: Text(nombre.isEmpty ? '$suc' : '$suc - $nombre'),
                      );
                    }).toList(),
                    onChanged: _busy
                        ? null
                        : (value) => setState(() {
                            _suc = value;
                            _qna = null;
                            _ajuste = null;
                          }),
                  ),
                ),
                SizedBox(
                  width: 300,
                  child: DropdownButtonFormField<String>(
                    initialValue: _qna,
                    decoration: const InputDecoration(labelText: 'QNA'),
                    items: periods
                        .map(
                          (row) => DropdownMenuItem(
                            value: '${row['qna']}',
                            child: Text(
                              'QNA ${row['qna']} | ${row['vigente']}',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _busy
                        ? null
                        : (value) => setState(() => _qna = value),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _busy || _suc == null || _qna == null
                      ? null
                      : _loadAjustes,
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('Reporte de ajustes'),
                ),
              ],
            ),
            if (_busy) const LinearProgressIndicator(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 20),
            Expanded(
              child: _AdjustmentReport(row: _ajuste, suc: _suc, qna: _qna),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdjustmentReport extends StatelessWidget {
  const _AdjustmentReport({
    required this.row,
    required this.suc,
    required this.qna,
  });
  final Map<String, dynamic>? row;
  final int? suc;
  final String? qna;

  @override
  Widget build(BuildContext context) {
    if (row == null) {
      return const Text(
        'Selecciona sucursal y QNA, luego genera reporte de ajustes.',
      );
    }
    final lines = <({String cuenta, String texto, double cargo, double abono})>[
      (
        cuenta: '110001070',
        texto: 'Sobrante total',
        cargo: -_num(row!['TSOBRREAL']),
        abono: 0,
      ),
      (
        cuenta: '704010003',
        texto: 'Sobrante total',
        cargo: 0,
        abono: _num(row!['TSOBRREAL']),
      ),
      (
        cuenta: '110001070',
        texto: 'Descuentos Faltantes',
        cargo: _num(row!['TFALTREAL']),
        abono: 0,
      ),
      (
        cuenta: '110001070',
        texto: 'Descuentos Faltantes',
        cargo: 0,
        abono: -_num(row!['TFALTREAL']),
      ),
      (
        cuenta: '110001020',
        texto: 'Pago de Faltantes',
        cargo: _num(row!['TPGOFALTREAL']),
        abono: 0,
      ),
      (
        cuenta: '110001070',
        texto: 'Pago de Faltantes',
        cargo: 0,
        abono: -_num(row!['TPGOFALTREAL']),
      ),
    ];
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Reporte para ajuste en SAP, CeBe Local',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 24,
            children: [
              Text('CeBe local: $suc'),
              Text('QNA: $qna'),
              Text('Status: ${row!['STATUS']}'),
              Text('TVTA: ${_money(_num(row!['TVTA']))}'),
              Text('TSOBRREAL: ${_money(_num(row!['TSOBRREAL']))}'),
              Text('TFALTREAL: ${_money(_num(row!['TFALTREAL']))}'),
              Text('TPGOFALTREAL: ${_money(_num(row!['TPGOFALTREAL']))}'),
            ],
          ),
          const SizedBox(height: 18),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('CEBE')),
                DataColumn(label: Text('CUENTA')),
                DataColumn(label: Text('TEXTO')),
                DataColumn(label: Text('DOC SAP')),
                DataColumn(label: Text('CARGO')),
                DataColumn(label: Text('ABONO')),
              ],
              rows: lines
                  .map(
                    (line) => DataRow(
                      cells: [
                        DataCell(Text('T${suc.toString().padLeft(3, '0')}')),
                        DataCell(Text(line.cuenta)),
                        DataCell(
                          Text(
                            '${line.texto} del ___ al ___ de ______ del ______',
                          ),
                        ),
                        const DataCell(Text('')),
                        DataCell(
                          Text(line.cargo == 0 ? '' : _money(line.cargo)),
                        ),
                        DataCell(
                          Text(line.abono == 0 ? '' : _money(line.abono)),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

int? _int(Object? value) => int.tryParse('$value');
double _num(Object? value) => double.tryParse('$value') ?? 0;
String _money(double value) => '\$${value.toStringAsFixed(2)}';
String _message(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['message'] != null) return '${data['message']}';
  }
  return '$error';
}
