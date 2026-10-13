import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ioe_app/core/api_error.dart';

import 'csd_models.dart';
import 'csd_providers.dart';

class EditarCuentaQuadrumDialog extends ConsumerStatefulWidget {
  const EditarCuentaQuadrumDialog({super.key, required this.csd});

  final CsdModel csd;

  @override
  ConsumerState<EditarCuentaQuadrumDialog> createState() =>
      _EditarCuentaQuadrumDialogState();
}

class _EditarCuentaQuadrumDialogState
    extends ConsumerState<EditarCuentaQuadrumDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _usuario;
  final _password = TextEditingController();
  bool _visible = false;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _usuario = TextEditingController(text: widget.csd.quadrumUsuario ?? '');
  }

  @override
  void dispose() {
    _usuario.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_guardando || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await ref
          .read(csdApiProvider)
          .actualizarCuentaQuadrum(
            rfc: widget.csd.rfc,
            usuario: _usuario.text.trim(),
            password: _password.text.isEmpty ? null : _password.text,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = apiErrorMessage(
            error,
            fallback: 'No se pudo actualizar cuenta de Quadrum.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_guardando,
      child: AlertDialog(
        title: const Text('Editar cuenta de Quadrum'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.csd.rfc,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  if (widget.csd.nombre != null) Text(widget.csd.nombre!),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _usuario,
                    enabled: !_guardando,
                    maxLength: 100,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Usuario de Quadrum',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Captura el usuario de Quadrum'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _password,
                    enabled: !_guardando,
                    obscureText: !_visible,
                    maxLength: 255,
                    autocorrect: false,
                    enableSuggestions: false,
                    enableIMEPersonalizedLearning: false,
                    autofillHints: const [],
                    decoration: InputDecoration(
                      labelText: 'Nueva contraseña de Quadrum',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        tooltip: _visible
                            ? 'Ocultar contraseña'
                            : 'Mostrar contraseña',
                        onPressed: _guardando
                            ? null
                            : () => setState(() => _visible = !_visible),
                        icon: Icon(
                          _visible ? Icons.visibility_off : Icons.visibility,
                        ),
                      ),
                    ),
                    validator: (value) {
                      final cambiaUsuario =
                          _usuario.text.trim() !=
                          (widget.csd.quadrumUsuario ?? '').trim();
                      if ((cambiaUsuario ||
                              (widget.csd.quadrumUsuario ?? '')
                                  .trim()
                                  .isEmpty) &&
                          (value == null || value.isEmpty)) {
                        return 'Captura contraseña de esa cuenta';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'La contraseña actual no se muestra. Déjala vacía para conservarla; si cambias usuario, captura contraseña nueva.',
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _guardando
                ? null
                : () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: _guardando ? null : _guardar,
            icon: _guardando
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_guardando ? 'Guardando...' : 'Guardar'),
          ),
        ],
      ),
    );
  }
}
