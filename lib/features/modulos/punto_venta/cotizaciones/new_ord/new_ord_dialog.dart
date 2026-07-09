import 'package:flutter/material.dart';

import 'new_ord_models.dart';

Future<NewOrdDialogResult?> showNewOrdDialog(
  BuildContext context, {
  required NewOrdDialogPayload payload,
  Future<String> Function(NewOrdDialogResult result)? onSubmit,
  Future<String> Function(NewOrdDialogResult result)? onDelete,
  Future<NewOrdRelationAuthorization> Function(String passwordSupervisor)?
  onAuthorizeRelation,
}) async {
  final canDelete = (payload.ordExistente ?? '').trim().isNotEmpty;
  final canAuthorizeRelation = !canDelete && onAuthorizeRelation != null;

  String selectedTipo =
      kOrdTipos.contains(payload.tipoInicial.trim().toUpperCase())
      ? payload.tipoInicial.trim().toUpperCase()
      : kOrdTipoTallado;
  DateTime? fechaEntrega = payload.fechaEntregaInicial;
  String comadText = payload.comadInicial ?? '';
  String ticketRelText = '';
  String? relationAuthorizationToken;
  bool relationAuthorized = false;
  String? fechaEntregaError;
  String? comadError;
  String? ticketRelError;
  String? submitMessage;
  bool submitting = false;

  return showDialog<NewOrdDialogResult>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Crear Orden de Trabajo (ORD)'),
            content: SizedBox(
              width: 620,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ReadonlyField(label: 'Folio', value: payload.idfol),
                    _ReadonlyField(label: 'Articulo', value: payload.art),
                    _ReadonlyField(
                      label: 'Cantidad',
                      value: _formatQty(payload.ctd),
                    ),
                    _ReadonlyField(
                      label: 'Descripcion del articulo',
                      value: payload.descArt,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: selectedTipo,
                      decoration: const InputDecoration(
                        labelText: 'Tipo ORD',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: kOrdTipos
                          .map(
                            (tipo) => DropdownMenuItem<String>(
                              value: tipo,
                              child: Text(tipo),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => selectedTipo = value);
                      },
                    ),
                    const SizedBox(height: 8),
                    _DateField(
                      label: 'Fecha de entrega',
                      value: fechaEntrega,
                      errorText: fechaEntregaError,
                      onPick: () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: fechaEntrega ?? now,
                          firstDate: DateTime(now.year - 5),
                          lastDate: DateTime(now.year + 10),
                        );
                        if (picked == null) return;
                        setState(() => fechaEntrega = picked);
                      },
                      onClear: fechaEntrega == null
                          ? null
                          : () => setState(() => fechaEntrega = null),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: comadText,
                      minLines: 3,
                      maxLines: 4,
                      onChanged: (value) {
                        comadText = value;
                        if (comadError != null && value.trim().isNotEmpty) {
                          setState(() => comadError = null);
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'COMAD',
                        border: const OutlineInputBorder(),
                        alignLabelWithHint: true,
                        errorText: comadError,
                      ),
                    ),
                    if (canAuthorizeRelation) ...[
                      const SizedBox(height: 8),
                      if (!relationAuthorized)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton(
                            onPressed: () async {
                              final auth = await _showRelationAuthDialog(
                                context,
                                onAuthorizeRelation,
                              );
                              if (auth == null) return;
                              setState(() {
                                relationAuthorized = true;
                                relationAuthorizationToken =
                                    auth.authorizationToken;
                                ticketRelError = null;
                              });
                            },
                            child: const Text('Relacion Venta Anterior'),
                          ),
                        ),
                      if (relationAuthorized)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                initialValue: ticketRelText,
                                onChanged: (value) {
                                  ticketRelText = value;
                                  if (ticketRelError != null &&
                                      value.trim().isNotEmpty) {
                                    setState(() => ticketRelError = null);
                                  }
                                },
                                decoration: InputDecoration(
                                  labelText: 'TICKET_REL',
                                  border: const OutlineInputBorder(),
                                  errorText: ticketRelError,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: 'Revertir relación',
                              onPressed: () {
                                setState(() {
                                  relationAuthorized = false;
                                  relationAuthorizationToken = null;
                                  ticketRelText = '';
                                  ticketRelError = null;
                                });
                              },
                              icon: const Icon(Icons.undo),
                            ),
                          ],
                        ),
                    ],
                    if (submitMessage != null) ...[
                      const SizedBox(height: 12),
                      _InlineMessage(message: submitMessage!),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: submitting
                    ? null
                    : () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              if (canDelete)
                TextButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          final navigator = Navigator.of(context);
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: const Text('Eliminar ORD'),
                                content: Text(
                                  '¿Deseas eliminar la ORD ${payload.ordExistente?.trim()}?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(false),
                                    child: const Text('No'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(true),
                                    child: const Text('Si, eliminar'),
                                  ),
                                ],
                              );
                            },
                          );
                          if (confirm != true) return;
                          if (!navigator.mounted) return;
                          final result = NewOrdDialogResult(
                            action: NewOrdDialogAction.delete,
                            tipo: selectedTipo,
                            descArt: payload.descArt,
                            fechaEntrega: fechaEntrega,
                            comad: _normalizeNullableText(comadText),
                          );
                          if (onDelete == null) {
                            navigator.pop(result);
                            return;
                          }

                          setState(() {
                            submitting = true;
                            submitMessage = null;
                          });
                          try {
                            final message = await onDelete(result);
                            if (!navigator.mounted) return;
                            navigator.pop(
                              NewOrdDialogResult(
                                action: result.action,
                                tipo: result.tipo,
                                descArt: result.descArt,
                                fechaEntrega: result.fechaEntrega,
                                comad: result.comad,
                                successMessage: message,
                              ),
                            );
                          } catch (e) {
                            setState(() {
                              submitMessage = _dialogErrorText(e);
                            });
                          } finally {
                            if (context.mounted) {
                              setState(() => submitting = false);
                            }
                          }
                        },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                  ),
                  child: const Text('Eliminar'),
                ),
              ElevatedButton(
                onPressed: submitting
                    ? null
                    : () async {
                        final comad = _normalizeNullableText(comadText);
                        setState(() {
                          fechaEntregaError = fechaEntrega == null
                              ? 'Fecha de entrega requerida'
                              : null;
                          comadError = comad == null ? 'COMAD requerido' : null;
                          ticketRelError =
                              relationAuthorized &&
                                  _normalizeNullableText(ticketRelText) == null
                              ? 'TICKET_REL requerido'
                              : null;
                          submitMessage = null;
                        });
                        if (fechaEntregaError != null ||
                            comadError != null ||
                            ticketRelError != null) {
                          return;
                        }

                        final result = NewOrdDialogResult(
                          action: NewOrdDialogAction.save,
                          tipo: selectedTipo,
                          descArt: payload.descArt,
                          fechaEntrega: fechaEntrega,
                          comad: comad,
                          ticketRel: relationAuthorized
                              ? _normalizeNullableText(ticketRelText)
                              : null,
                          relationAuthorizationToken: relationAuthorized
                              ? relationAuthorizationToken
                              : null,
                        );

                        if (onSubmit == null) {
                          Navigator.of(context).pop(result);
                          return;
                        }

                        setState(() => submitting = true);
                        try {
                          final message = await onSubmit(result);
                          if (!context.mounted) return;
                          Navigator.of(context).pop(
                            NewOrdDialogResult(
                              action: result.action,
                              tipo: result.tipo,
                              descArt: result.descArt,
                              fechaEntrega: result.fechaEntrega,
                              comad: result.comad,
                              ticketRel: result.ticketRel,
                              relationAuthorizationToken:
                                  result.relationAuthorizationToken,
                              successMessage: message,
                            ),
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          setState(() {
                            submitMessage = _dialogErrorText(e);
                          });
                        } finally {
                          if (context.mounted) {
                            setState(() => submitting = false);
                          }
                        }
                      },
                child: Text(submitting ? 'Guardando...' : 'Guardar'),
              ),
            ],
          );
        },
      );
    },
  );
}

String _formatQty(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value.toStringAsFixed(2);
}

String _formatDate(DateTime value) {
  final dd = value.day.toString().padLeft(2, '0');
  final mm = value.month.toString().padLeft(2, '0');
  final yyyy = value.year.toString().padLeft(4, '0');
  return '$dd/$mm/$yyyy';
}

String? _normalizeNullableText(String raw) {
  final text = raw.trim();
  return text.isEmpty ? null : text;
}

String _dialogErrorText(Object error) {
  return error.toString().replaceFirst('Exception: ', '').trim();
}

Future<NewOrdRelationAuthorization?> _showRelationAuthDialog(
  BuildContext context,
  Future<NewOrdRelationAuthorization> Function(String passwordSupervisor)
  onAuthorizeRelation,
) async {
  final passwordCtrl = TextEditingController();
  String? error;
  bool validating = false;
  bool dialogClosed = false;
  StateSetter? dialogSetState;

  Future<void> validateAndClose(BuildContext dialogContext) async {
    if (validating) return;
    final value = passwordCtrl.text.trim();
    if (value.isEmpty) {
      error = 'Ingresa la contraseña';
      dialogSetState?.call(() {});
      return;
    }

    validating = true;
    error = null;
    dialogSetState?.call(() {});
    try {
      final auth = await onAuthorizeRelation(value);
      if (!dialogContext.mounted) return;
      dialogClosed = true;
      Navigator.of(dialogContext).pop(auth);
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
      dialogSetState?.call(() {});
    } finally {
      validating = false;
      if (!dialogClosed) {
        dialogSetState?.call(() {});
      }
    }
  }

  return showDialog<NewOrdRelationAuthorization>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Autorización SUPERPV'),
        content: StatefulBuilder(
          builder: (context, setState) {
            dialogSetState = setState;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: passwordCtrl,
                  autofocus: true,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Contraseña SUPERPV',
                    errorText: error,
                  ),
                  onSubmitted: (_) async {
                    await validateAndClose(context);
                  },
                ),
                if (validating) ...[
                  const SizedBox(height: 10),
                  const LinearProgressIndicator(minHeight: 2),
                ],
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: validating ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: validating ? null : () => validateAndClose(context),
            child: const Text('Autorizar'),
          ),
        ],
      );
    },
  );
}

class _ReadonlyField extends StatelessWidget {
  const _ReadonlyField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        child: SelectableText(
          value,
          maxLines: 1,
          style: const TextStyle(fontSize: 13),
        ),
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.error.withValues(alpha: 0.35)),
      ),
      child: Text(message, style: TextStyle(color: colors.onErrorContainer)),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.errorText,
    required this.onPick,
    required this.onClear,
  });

  final String label;
  final DateTime? value;
  final String? errorText;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPick,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
          errorText: errorText,
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onClear != null)
                IconButton(
                  tooltip: 'Limpiar fecha',
                  onPressed: onClear,
                  icon: const Icon(Icons.clear),
                ),
              IconButton(
                tooltip: 'Seleccionar fecha',
                onPressed: onPick,
                icon: const Icon(Icons.calendar_today),
              ),
            ],
          ),
        ),
        child: Text(value == null ? '-' : _formatDate(value!)),
      ),
    );
  }
}
