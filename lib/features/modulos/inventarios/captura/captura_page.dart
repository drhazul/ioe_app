import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:uuid/uuid.dart';

import 'package:ioe_app/core/api_error.dart';

import 'captura_models.dart';
import 'captura_providers.dart';

class CapturaInventarioPage extends ConsumerStatefulWidget {
  const CapturaInventarioPage({super.key});

  @override
  ConsumerState<CapturaInventarioPage> createState() => _CapturaInventarioPageState();
}

class _CapturaInventarioPageState extends ConsumerState<CapturaInventarioPage> {
  final _upcCtrl = TextEditingController();
  final _cantidadCtrl = TextEditingController();
  final _upcFocus = FocusNode();
  final _cantidadFocus = FocusNode();
  ProviderSubscription<String?>? _correctionUpcSub;
  ProviderSubscription<String?>? _selectedContSub;

  String? _selectedCont;
  String _selectedAlmacen = '001';
  bool _sending = false;
  bool _scannerOpen = false;

  CapturaResult? _lastResult;

  @override
  void initState() {
    super.initState();
    _upcCtrl.addListener(_onFieldsChange);
    _cantidadCtrl.addListener(_onFieldsChange);
    final savedCont = ref.read(capturaSelectedContProvider);
    if (savedCont != null && savedCont.trim().isNotEmpty) {
      _selectedCont = savedCont.trim();
    }
    _correctionUpcSub = ref.listenManual<String?>(capturaCorrectionUpcProvider, (prev, next) {
      _applyCorrectionUpc(next);
    });
    _applyCorrectionUpc(ref.read(capturaCorrectionUpcProvider));
    _selectedContSub = ref.listenManual<String?>(capturaSelectedContProvider, (prev, next) {
      final value = next?.trim() ?? '';
      if (value.isEmpty || value == _selectedCont) return;
      if (!mounted) return;
      setState(() => _selectedCont = value);
    });
  }

  @override
  void dispose() {
    _correctionUpcSub?.close();
    _selectedContSub?.close();
    _upcCtrl.removeListener(_onFieldsChange);
    _cantidadCtrl.removeListener(_onFieldsChange);
    _upcCtrl.dispose();
    _cantidadCtrl.dispose();
    _upcFocus.dispose();
    _cantidadFocus.dispose();
    super.dispose();
  }

  void _onFieldsChange() {
    if (mounted) setState(() {});
  }

  void _applyCorrectionUpc(String? next) {
    final value = next?.trim() ?? '';
    if (value.isEmpty) return;
    _upcCtrl.text = value;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _cantidadFocus.requestFocus();
      // Clear after build to avoid provider mutation during lifecycle.
      ref.read(capturaCorrectionUpcProvider.notifier).state = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final conteosAsync = ref.watch(conteosDisponiblesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Captura Inventario'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: [
          IconButton(
            onPressed: (_selectedCont == null || _selectedCont!.isEmpty) ? null : () => _goToDetalle(context),
            icon: const Icon(Icons.list_alt),
            tooltip: 'Detalle captura',
          ),
          IconButton(
            onPressed: () => ref.invalidate(conteosDisponiblesProvider),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refrescar conteos',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(conteosDisponiblesProvider);
          await ref.read(conteosDisponiblesProvider.future);
        },
        child: conteosAsync.when(
          data: (conteos) {
            _syncSelection(conteos);

            if (conteos.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: const [Text('No hay conteos en estado CAPTURA/LISTO')],
              );
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildConteoDropdown(conteos),
                const SizedBox(height: 16),
                _buildAlmacenChips(),
                const SizedBox(height: 16),
                _buildUpcInput(),
                const SizedBox(height: 12),
                _buildCantidadInput(),
                const SizedBox(height: 20),
                _buildSubmitButton(),
                if (_lastResult != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _lastResult!.idempotent ? 'Última captura idempotente (ya existía).' : 'Última captura registrada.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 80),
              ],
            );
          },
          loading: () => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(height: 180),
              Center(child: CircularProgressIndicator()),
            ],
          ),
          error: (e, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Text('Error al cargar conteos: $e'),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(conteosDisponiblesProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConteoDropdown(List<ConteoDisponible> conteos) {
    final items = conteos
        .map(
          (c) => DropdownMenuItem<String>(
            value: c.cont ?? c.tokenreg,
            child: Text('${c.cont ?? c.tokenreg} · ${c.suc ?? '-'} · ${c.estado ?? ''}'),
          ),
        )
        .toList();

    return DropdownButtonFormField<String>(
      initialValue: _selectedCont,
      decoration: const InputDecoration(
        labelText: 'Conteo disponible',
        border: OutlineInputBorder(),
      ),
      items: items,
      onChanged: _sending
          ? null
          : (v) {
              setState(() {
                _selectedCont = v;
              });
              ref.read(capturaSelectedContProvider.notifier).state = v;
            },
    );
  }

  Widget _buildAlmacenChips() {
    const almacenes = ['001', '002', 'M001', 'T001'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Almacén', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: almacenes
              .map(
                (alm) => ChoiceChip(
                  label: Text(alm),
                  selected: _selectedAlmacen == alm,
                  onSelected: _sending ? null : (v) => v ? setState(() => _selectedAlmacen = alm) : null,
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildUpcInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _upcCtrl,
          focusNode: _upcFocus,
          decoration: const InputDecoration(
            labelText: 'UPC / EAN13',
            border: OutlineInputBorder(),
            helperText: 'Puedes capturar manualmente o escanear.',
          ),
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          enabled: !_sending,
          onSubmitted: (_) => _cantidadFocus.requestFocus(),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _sending ? null : _openScanner,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Escanear código'),
          ),
        ),
      ],
    );
  }

  Widget _buildCantidadInput() {
    return TextField(
      controller: _cantidadCtrl,
      focusNode: _cantidadFocus,
      decoration: const InputDecoration(
        labelText: 'Cantidad',
        border: OutlineInputBorder(),
        helperText: 'Admite valores negativos para correcciones.',
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
      enabled: !_sending,
      onSubmitted: (_) => _submit(),
    );
  }

  Widget _buildSubmitButton() {
    final canSubmit = !_sending &&
        (_selectedCont != null && _selectedCont!.isNotEmpty) &&
        _upcCtrl.text.trim().isNotEmpty &&
        _cantidadCtrl.text.trim().isNotEmpty;

    return ElevatedButton.icon(
      onPressed: canSubmit ? _submit : null,
      icon: _sending
          ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.check),
      label: Text(_sending ? 'Enviando...' : 'Confirmar'),
    );
  }

  void _goToDetalle(BuildContext context) {
    final cont = _selectedCont;
    if (cont == null || cont.isEmpty) {
      _showMessage('Selecciona un conteo');
      return;
    }
    context.go('/inventarios/${Uri.encodeComponent(cont)}/captura/detalle');
  }

  Future<void> _submit() async {
    if (_sending) return;
    final cont = _selectedCont;
    final upc = _upcCtrl.text.trim();
    final cantidadStr = _cantidadCtrl.text.trim().replaceAll(',', '.');

    if (cont == null || cont.isEmpty) {
      _showMessage('Selecciona un conteo');
      return;
    }
    if (upc.isEmpty || cantidadStr.isEmpty) {
      _showMessage('UPC y cantidad son requeridos');
      return;
    }
    final cantidad = double.tryParse(cantidadStr);
    if (cantidad == null) {
      _showMessage('Cantidad inválida');
      return;
    }

    setState(() => _sending = true);
    final capturaUuid = const Uuid().v4();

    try {
      final api = ref.read(capturaApiProvider);
      final res = await api.registrarCaptura(
        cont: cont,
        almacen: _selectedAlmacen,
        upc: upc,
        cantidad: cantidad,
        capturaUuid: capturaUuid,
      );

      if (!mounted) return;

      setState(() {
        _lastResult = res;
        _upcCtrl.clear();
        _cantidadCtrl.clear();
      });

      HapticFeedback.mediumImpact();
      _showMessage(res.idempotent ? 'Captura ya existía (idempotente)' : 'Captura registrada');

      // Listo para la siguiente captura
      _upcFocus.requestFocus();
    } catch (e) {
      if (mounted) _showMessage('Error al capturar: ${apiErrorMessage(e)}');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _openScanner() async {
    if (_scannerOpen) return;
    _scannerOpen = true;

    final controller = MobileScannerController(
      formats: const [BarcodeFormat.ean13, BarcodeFormat.upcA],
      detectionSpeed: DetectionSpeed.normal,
    );

    String? scanned;
    bool reportedInvalid = false;

    try {
      if (!mounted) return;
      scanned = await showDialog<String>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) {
          return Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              title: const Text('Escanear código'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            body: MobileScanner(
              controller: controller,
              onDetect: (capture) {
                for (final barcode in capture.barcodes) {
                  final raw = barcode.rawValue;
                  if (raw == null || raw.isEmpty) continue;

                  final format = barcode.format;
                  final allowed = format == BarcodeFormat.ean13 || format == BarcodeFormat.upcA;
                  if (!allowed) {
                    if (!reportedInvalid) {
                      reportedInvalid = true;
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Código no válido')));
                    }
                    continue;
                  }

                  controller.stop();
                  HapticFeedback.mediumImpact();
                  SystemSound.play(SystemSoundType.click);
                  Navigator.of(ctx).pop(raw);
                  return;
                }
              },
            ),
          );
        },
      );
    } finally {
      controller.dispose();
      _scannerOpen = false;
    }

    if (!mounted || scanned == null) return;

    final normalized = _stripCheckDigit(scanned);
    setState(() => _upcCtrl.text = normalized);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    _cantidadFocus.requestFocus();
  }

  void _syncSelection(List<ConteoDisponible> conteos) {
    if (conteos.isEmpty) {
      if (_selectedCont != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _selectedCont = null);
          ref.read(capturaSelectedContProvider.notifier).state = null;
        });
      }
      return;
    }

    final exists = _selectedCont != null && conteos.any((c) => (c.cont ?? c.tokenreg) == _selectedCont);

    if (_selectedCont == null || !exists) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final first = conteos.first;
        final next = first.cont ?? first.tokenreg;
        setState(() => _selectedCont = next);
        ref.read(capturaSelectedContProvider.notifier).state = next;
      });
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _stripCheckDigit(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 12 || digits.length == 13) {
      return digits.substring(0, digits.length - 1);
    }
    return digits;
  }
}
