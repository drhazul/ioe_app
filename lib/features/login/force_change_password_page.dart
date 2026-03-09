import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';

class ForceChangePasswordPage extends ConsumerStatefulWidget {
  const ForceChangePasswordPage({super.key});

  @override
  ConsumerState<ForceChangePasswordPage> createState() =>
      _ForceChangePasswordPageState();
}

class _ForceChangePasswordPageState
    extends ConsumerState<ForceChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _saving = false;
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final currentPassword = _currentCtrl.text.trim();
    final newPassword = _newCtrl.text.trim();

    setState(() => _saving = true);
    try {
      await ref.read(authControllerProvider.notifier).changePassword(
            currentPassword: currentPassword,
            newPassword: newPassword,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contraseña actualizada correctamente')),
      );
    } catch (e) {
      if (!mounted) return;
      final text = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text)),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _cancel() async {
    if (_saving) return;
    await ref.read(authControllerProvider.notifier).logout();
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Cambio obligatorio de contraseña'),
          automaticallyImplyLeading: false,
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Debes cambiar tu contraseña temporal para continuar.',
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _currentCtrl,
                          enabled: !_saving,
                          obscureText: !_showCurrent,
                          decoration: InputDecoration(
                            labelText: 'Contraseña actual',
                            suffixIcon: IconButton(
                              tooltip: _showCurrent
                                  ? 'Ocultar contraseña'
                                  : 'Mostrar contraseña',
                              icon: Icon(
                                _showCurrent
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: _saving
                                  ? null
                                  : () => setState(
                                        () => _showCurrent = !_showCurrent,
                                      ),
                            ),
                          ),
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (text.isEmpty) return 'Requerida';
                            if (text.length < 6) return 'Mínimo 6 caracteres';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _newCtrl,
                          enabled: !_saving,
                          obscureText: !_showNew,
                          decoration: InputDecoration(
                            labelText: 'Nueva contraseña',
                            suffixIcon: IconButton(
                              tooltip: _showNew
                                  ? 'Ocultar contraseña'
                                  : 'Mostrar contraseña',
                              icon: Icon(
                                _showNew
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: _saving
                                  ? null
                                  : () => setState(() => _showNew = !_showNew),
                            ),
                          ),
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (text.isEmpty) return 'Requerida';
                            if (text.length < 6) return 'Mínimo 6 caracteres';
                            if (text == _currentCtrl.text.trim()) {
                              return 'Debe ser diferente a la actual';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _confirmCtrl,
                          enabled: !_saving,
                          obscureText: !_showConfirm,
                          decoration: InputDecoration(
                            labelText: 'Confirmar nueva contraseña',
                            suffixIcon: IconButton(
                              tooltip: _showConfirm
                                  ? 'Ocultar contraseña'
                                  : 'Mostrar contraseña',
                              icon: Icon(
                                _showConfirm
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: _saving
                                  ? null
                                  : () => setState(
                                        () => _showConfirm = !_showConfirm,
                                      ),
                            ),
                          ),
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (text.isEmpty) return 'Requerida';
                            if (text != _newCtrl.text.trim()) {
                              return 'No coincide con la nueva contraseña';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: _saving ? null : _submit,
                          icon: _saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.lock_reset),
                          label: Text(
                            _saving
                                ? 'Guardando...'
                                : 'Actualizar contraseña y continuar',
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _saving ? null : _cancel,
                          icon: const Icon(Icons.cancel_outlined),
                          label: const Text('Cancelar'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
