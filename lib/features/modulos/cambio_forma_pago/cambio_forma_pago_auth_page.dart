import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ioe_app/core/api_error.dart';

import 'cambio_forma_pago_providers.dart';

class CambioFormaPagoAuthPage extends ConsumerStatefulWidget {
  const CambioFormaPagoAuthPage({super.key});

  @override
  ConsumerState<CambioFormaPagoAuthPage> createState() =>
      _CambioFormaPagoAuthPageState();
}

class _CambioFormaPagoAuthPageState
    extends ConsumerState<CambioFormaPagoAuthPage> {
  final _pinCtrl = TextEditingController();
  bool _submitting = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    // Evita modificar providers durante build; limpia sesión al finalizar el frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(cambioFormaPagoSessionProvider.notifier).clear();
    });
  }

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/punto-venta'),
          tooltip: 'Regresar',
        ),
        title: const Text('Cambio forma de pago - Autorizacion'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Se requiere autorizacion de supervisor para CAMBIO_FPGO.',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _pinCtrl,
                        enabled: !_submitting,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                        decoration: const InputDecoration(
                          labelText: 'PIN supervisor',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      if (_errorText != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _errorText!,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _submitting ? null : _submit,
                          child: _submitting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Autorizar y continuar'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final pin = _pinCtrl.text.trim();
    if (pin.isEmpty) {
      setState(() => _errorText = 'Capture el PIN de supervisor.');
      return;
    }

    setState(() {
      _submitting = true;
      _errorText = null;
    });

    try {
      final session = await ref
          .read(cambioFormaPagoApiProvider)
          .authorizeSupervisor(pin: pin);
      ref.read(cambioFormaPagoSessionProvider.notifier).setSession(session);
      ref.invalidate(cambioFormaPagoTodayProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Autorizado por ${session.supervisorId}.')),
      );
      context.go('/cambio-forma-pago');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = apiErrorMessage(
          e,
          fallback: 'No se pudo autorizar supervisor.',
        );
      });
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }
}
