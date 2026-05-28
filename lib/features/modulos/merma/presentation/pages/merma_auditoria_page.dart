import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../domain/merma_models.dart';
import '../../providers/merma_auditoria_provider.dart';
import '../../providers/merma_catalogs_provider.dart';
import '../../providers/merma_provider.dart';
import '../dialogs/merma_auditoria_dialog.dart';
import '../widgets/merma_status_chip.dart';

class MermaAuditoriaPage extends ConsumerStatefulWidget {
  const MermaAuditoriaPage({super.key});

  @override
  ConsumerState<MermaAuditoriaPage> createState() => _MermaAuditoriaPageState();
}

class _MermaAuditoriaPageState extends ConsumerState<MermaAuditoriaPage> {
  final _documentoCtrl = TextEditingController();
  final _usuarioCtrl = TextEditingController();
  final _fechaCtrl = TextEditingController();

  String _suc = '';
  bool _hasAppliedFilters = false;
  bool _scannerOpen = false;
  MermaAuditoriaFilters _filters = const MermaAuditoriaFilters(
    page: 1,
    limit: 50,
  );

  @override
  void dispose() {
    _documentoCtrl.dispose();
    _usuarioCtrl.dispose();
    _fechaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sucursales =
        ref.watch(mermaSucursalesProvider).valueOrNull ?? const <String>[];
    final asyncRows = _hasAppliedFilters
        ? ref.watch(mermaAuditoriaPendientesProvider(_filters))
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Auditoria de merma')),
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
            child: Text('Aplica al menos un filtro para visualizar documentos.'),
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
            child: Center(child: Text('Sin documentos para los filtros seleccionados')),
          )
        else
          ...items.map(_buildDocCard),
      ],
    );
  }

  Widget _buildFilters(List<String> sucursales) {
    const fieldWidth = 170.0;
    const dropWidth = 140.0;
    const dateWidth = 140.0;
    const fieldDecoration = InputDecoration(
      border: OutlineInputBorder(),
      isDense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );

    return Center(
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        runAlignment: WrapAlignment.center,
        children: [
        SizedBox(
          width: fieldWidth,
          child: TextField(
            controller: _documentoCtrl,
            decoration: fieldDecoration.copyWith(labelText: 'Documento'),
            onSubmitted: (_) => _applyFilters(),
          ),
        ),
        SizedBox(
          width: fieldWidth,
          child: TextField(
            controller: _usuarioCtrl,
            decoration: fieldDecoration.copyWith(labelText: 'Usuario'),
            onSubmitted: (_) => _applyFilters(),
          ),
        ),
        SizedBox(
          width: dropWidth,
          child: DropdownButtonFormField<String>(
            key: ValueKey('aud-suc-$_suc'),
            initialValue: _suc.trim().isEmpty ? null : _suc,
            isExpanded: true,
            hint: const Text('Seleccionar'),
            decoration: fieldDecoration.copyWith(labelText: 'Sucursal'),
            items: [
              ...sucursales.map(
                (item) => DropdownMenuItem(value: item, child: Text(item)),
              ),
            ],
            onChanged: (value) => setState(() => _suc = value ?? ''),
          ),
        ),
        SizedBox(
          width: dateWidth,
          child: TextField(
            controller: _fechaCtrl,
            readOnly: true,
            decoration: fieldDecoration.copyWith(
              labelText: 'Fecha',
              suffixIcon: IconButton(
                onPressed: () => _pickDate(_fechaCtrl),
                icon: const Icon(Icons.calendar_today),
              ),
            ),
            onTap: () => _pickDate(_fechaCtrl),
          ),
        ),
        ElevatedButton.icon(
          onPressed: _applyFilters,
          icon: const Icon(Icons.search),
          label: const Text('Filtrar'),
        ),
        OutlinedButton.icon(
          onPressed: _clearFilters,
          icon: const Icon(Icons.refresh),
          label: const Text('Limpiar'),
        ),
        OutlinedButton.icon(
          onPressed: _scanDocumentQr,
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Escanear QR'),
        ),
        ],
      ),
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
          'SUC ${doc.suc} | FCNC ${doc.fcnc?.toIso8601String() ?? '-'} | Total ${doc.total.toStringAsFixed(2)}',
        ),
        trailing: MermaStatusChip(estatus: doc.estatus),
        onTap: () => _auditar(doc.docmer),
      ),
    );
  }

  void _applyFilters() {
    final docmer = _documentoCtrl.text.trim();
    final usuario = _usuarioCtrl.text.trim();
    final suc = _suc.trim();
    final fecha = _fechaCtrl.text.trim();
    final hasAnyFilter = docmer.isNotEmpty ||
        usuario.isNotEmpty ||
        suc.isNotEmpty ||
        fecha.isNotEmpty;

    if (!hasAnyFilter) {
      setState(() => _hasAppliedFilters = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Captura al menos un filtro para consultar.')),
      );
      return;
    }

    setState(() {
      _hasAppliedFilters = true;
      _filters = MermaAuditoriaFilters(
        page: 1,
        limit: 50,
        docmer: docmer,
        usuario: usuario,
        suc: suc,
        estatus: 'CONTABILIZADO',
        from: fecha,
        to: fecha,
      );
    });
  }

  void _clearFilters() {
    setState(() {
      _documentoCtrl.clear();
      _usuarioCtrl.clear();
      _fechaCtrl.clear();
      _suc = '';
      _hasAppliedFilters = false;
      _filters = const MermaAuditoriaFilters(page: 1, limit: 50);
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

  Future<void> _scanDocumentQr() async {
    if (_scannerOpen) return;
    _scannerOpen = true;

    final controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      formats: const [
        BarcodeFormat.qrCode,
        BarcodeFormat.code128,
        BarcodeFormat.code39,
        BarcodeFormat.ean13,
        BarcodeFormat.upcA,
      ],
    );

    String? scanned;
    try {
      if (!mounted) return;
      scanned = await showDialog<String>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: const Text('Escanear QR documento'),
            actions: [
              IconButton(
                onPressed: () => Navigator.of(ctx).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          body: MobileScanner(
            controller: controller,
            onDetect: (capture) {
              for (final barcode in capture.barcodes) {
                final raw = (barcode.rawValue ?? '').trim();
                if (raw.isEmpty) continue;
                controller.stop();
                Navigator.of(ctx).pop(raw);
                return;
              }
            },
          ),
        ),
      );
    } finally {
      controller.dispose();
      _scannerOpen = false;
    }

    if (!mounted || scanned == null) return;
    final parsedDocmer = _extractDocmer(scanned);
    if (parsedDocmer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo leer DOCMER del codigo escaneado.')),
      );
      return;
    }

    setState(() => _documentoCtrl.text = parsedDocmer);
    _applyFilters();
  }

  String _extractDocmer(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return '';

    final fullKey = RegExp(
      r'DOCMER\s*=\s*([A-Za-z0-9_-]+)',
      caseSensitive: false,
    ).firstMatch(text);
    if (fullKey != null) {
      return (fullKey.group(1) ?? '').trim();
    }

    final uri = Uri.tryParse(text);
    if (uri != null) {
      final queryDoc =
          (uri.queryParameters['docmer'] ?? uri.queryParameters['DOCMER'] ?? '')
              .trim();
      if (queryDoc.isNotEmpty) return queryDoc;
    }

    final direct = RegExp(r'^\d{6,}$').firstMatch(text);
    if (direct != null) return (direct.group(0) ?? '').trim();
    return '';
  }

  Future<void> _auditar(String docmer) async {
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const MermaAuditoriaDialog(),
    );
    if (payload == null) return;
    try {
      await ref
          .read(mermaApiProvider)
          .auditar(
            docmer,
            obsAudit: (payload['obsAudit'] ?? '').toString(),
            confirmFisica: payload['confirmFisica'] == true,
          );
      ref.invalidate(mermaAuditoriaPendientesProvider(_filters));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Documento $docmer auditado')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(e))));
    }
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
