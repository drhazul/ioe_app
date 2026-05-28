import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/merma_models.dart';
import '../../providers/merma_catalogs_provider.dart';
import '../../providers/merma_consulta_provider.dart';
import '../widgets/merma_filters.dart';
import '../widgets/merma_status_chip.dart';

class MermaConsultaPage extends ConsumerStatefulWidget {
  const MermaConsultaPage({super.key});

  @override
  ConsumerState<MermaConsultaPage> createState() => _MermaConsultaPageState();
}

class _MermaConsultaPageState extends ConsumerState<MermaConsultaPage> {
  final _folioCtrl = TextEditingController();
  final _usuarioCtrl = TextEditingController();
  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();

  String _suc = '';
  String? _estatus;
  bool _hasAppliedFilters = false;
  MermaConsultaFilters _filters = const MermaConsultaFilters(
    page: 1,
    limit: 50,
  );

  @override
  void dispose() {
    _folioCtrl.dispose();
    _usuarioCtrl.dispose();
    _fromCtrl.dispose();
    _toCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sucursales =
        ref.watch(mermaSucursalesProvider).valueOrNull ?? const <String>[];
    final asyncRows = _hasAppliedFilters
        ? ref.watch(mermaConsultaProvider(_filters))
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Consulta de documentos merma')),
      body: !_hasAppliedFilters
          ? _buildInitialBody(sucursales)
          : asyncRows!.when(
              data: (data) => _buildResultBody(sucursales, data.items),
              loading: () => _buildLoadingBody(sucursales),
              error: (error, _) => _buildErrorBody(sucursales, error),
            ),
    );
  }

  Widget _buildInitialBody(List<String> sucursales) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _buildFilters(sucursales),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Aplica al menos un filtro para visualizar documentos.',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingBody(List<String> sucursales) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _buildFilters(sucursales),
        const SizedBox(height: 24),
        const Center(child: CircularProgressIndicator()),
      ],
    );
  }

  Widget _buildErrorBody(List<String> sucursales, Object error) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _buildFilters(sucursales),
        const SizedBox(height: 12),
        Text('Error: ${_friendlyError(error)}'),
      ],
    );
  }

  Widget _buildResultBody(List<String> sucursales, List<MermaDocModel> items) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _buildFilters(sucursales),
        const SizedBox(height: 12),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: Text('Sin documentos')),
          )
        else
          ...items.map(_buildDocCard),
      ],
    );
  }

  Widget _buildFilters(List<String> sucursales) {
    return MermaFilters(
      folioCtrl: _folioCtrl,
      usuarioCtrl: _usuarioCtrl,
      sucursales: sucursales,
      suc: _suc,
      fromCtrl: _fromCtrl,
      toCtrl: _toCtrl,
      estatus: _estatus,
      estatusOptions: const [
        'ABIERTO',
        'PENDIENTE',
        'REVISAR',
        'ANULADO',
        'CONTABILIZADO',
        'AUDITADO',
      ],
      onSucChanged: (value) => setState(() => _suc = value ?? ''),
      onStatusChanged: (value) => setState(() => _estatus = value),
      onPickFrom: () => _pickDate(_fromCtrl),
      onPickTo: () => _pickDate(_toCtrl),
      onApply: _applyFilters,
      onClear: _clearFilters,
    );
  }

  Widget _buildDocCard(MermaDocModel doc) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: ListTile(
        title: Text('DOCMER ${doc.docmer}'),
        subtitle: Text(
          'SUC ${doc.suc} | Usuario ${doc.user} | Total ${doc.total.toStringAsFixed(2)}',
        ),
        trailing: Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            MermaStatusChip(estatus: doc.estatus),
            PopupMenuButton<_MermaMenuAction>(
              tooltip: 'Opciones',
              onSelected: (action) => _runMenuAction(doc, action),
              itemBuilder: (_) => _buildMenuItems(doc),
              icon: const Icon(Icons.more_vert),
            ),
          ],
        ),
        onTap: () => context.go('/modulos/merma/consulta/${doc.docmer}'),
      ),
    );
  }

  List<PopupMenuEntry<_MermaMenuAction>> _buildMenuItems(MermaDocModel doc) {
    return <PopupMenuEntry<_MermaMenuAction>>[
      const PopupMenuItem(
        value: _MermaMenuAction.abrirDetalle,
        child: Text('Abrir detalle'),
      ),
    ];
  }

  Future<void> _runMenuAction(
    MermaDocModel doc,
    _MermaMenuAction action,
  ) async {
    switch (action) {
      case _MermaMenuAction.abrirDetalle:
        context.go('/modulos/merma/consulta/${doc.docmer}');
        return;
    }
  }

  void _applyFilters() {
    final docmer = _folioCtrl.text.trim();
    final usuario = _usuarioCtrl.text.trim();
    final from = _fromCtrl.text.trim();
    final to = _toCtrl.text.trim();
    final estatus = (_estatus ?? '').trim();
    final suc = _suc.trim();
    final hasAnyFilter =
        docmer.isNotEmpty ||
        usuario.isNotEmpty ||
        from.isNotEmpty ||
        to.isNotEmpty ||
        estatus.isNotEmpty ||
        suc.isNotEmpty;

    if (!hasAnyFilter) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Captura al menos un filtro para consultar.'),
        ),
      );
      return;
    }

    setState(() {
      _hasAppliedFilters = true;
      _filters = MermaConsultaFilters(
        page: 1,
        limit: 50,
        docmer: docmer,
        usuario: usuario,
        estatus: estatus,
        suc: suc,
        from: from,
        to: to,
      );
    });
  }

  void _clearFilters() {
    setState(() {
      _folioCtrl.clear();
      _usuarioCtrl.clear();
      _fromCtrl.clear();
      _toCtrl.clear();
      _suc = '';
      _estatus = null;
      _hasAppliedFilters = false;
      _filters = const MermaConsultaFilters(page: 1, limit: 50);
    });
  }

  Future<void> _pickDate(TextEditingController target) async {
    final now = DateTime.now();
    final initial = _parseDate(target.text) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 2),
    );
    if (picked == null || !mounted) return;
    final y = picked.year.toString().padLeft(4, '0');
    final m = picked.month.toString().padLeft(2, '0');
    final d = picked.day.toString().padLeft(2, '0');
    setState(() => target.text = '$y-$m-$d');
  }

  DateTime? _parseDate(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  String _friendlyError(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        final msg = (data['message'] ?? '').toString().trim();
        if (msg.isNotEmpty) return msg;
      }
      return error.message ?? 'No fue posible completar la accion.';
    }
    return error.toString();
  }
}

enum _MermaMenuAction { abrirDetalle }
