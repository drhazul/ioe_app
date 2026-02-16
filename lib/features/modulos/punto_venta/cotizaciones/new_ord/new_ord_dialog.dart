import 'package:flutter/material.dart';

import 'new_ord_models.dart';

Future<NewOrdDialogResult?> showNewOrdDialog(
  BuildContext context, {
  required NewOrdDialogPayload payload,
}) async {
  final canDelete = (payload.ordExistente ?? '').trim().isNotEmpty;

  String selectedTipo = kOrdTipos.contains(payload.tipoInicial.trim().toUpperCase())
      ? payload.tipoInicial.trim().toUpperCase()
      : kOrdTipoTallado;
  DateTime? fechaEntrega = payload.fechaEntregaInicial;
  String comadText = payload.comadInicial ?? '';
  String? fechaEntregaError;
  String? comadError;

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
                      _ReadonlyField(label: 'Cantidad', value: _formatQty(payload.ctd)),
                      _ReadonlyField(label: 'Cliente', value: '${payload.clien} - ${payload.ncliente}'),
                      _ReadonlyField(label: 'Sucursal', value: payload.suc),
                      _ReadonlyField(label: 'OPV', value: payload.opv),
                      _ReadonlyField(
                        label: 'ORD actual',
                        value: canDelete ? payload.ordExistente!.trim() : '-',
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
                      _ReadonlyField(
                        label: 'Descripcion del articulo',
                        value: payload.descArt,
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
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                if (canDelete)
                  TextButton(
                    onPressed: () async {
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
                                onPressed: () => Navigator.of(context).pop(false),
                                child: const Text('No'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.of(context).pop(true),
                                child: const Text('Si, eliminar'),
                              ),
                            ],
                          );
                        },
                      );
                      if (confirm != true) return;
                      if (!navigator.mounted) return;
                      navigator.pop(
                        NewOrdDialogResult(
                          action: NewOrdDialogAction.delete,
                          tipo: selectedTipo,
                          descArt: payload.descArt,
                          fechaEntrega: fechaEntrega,
                          comad: _normalizeNullableText(comadText),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
                    child: const Text('Eliminar'),
                  ),
                ElevatedButton(
                  onPressed: () {
                    final comad = _normalizeNullableText(comadText);
                    setState(() {
                      fechaEntregaError =
                          fechaEntrega == null ? 'Fecha de entrega requerida' : null;
                      comadError = comad == null ? 'COMAD requerido' : null;
                    });
                    if (fechaEntregaError != null || comadError != null) return;

                    Navigator.of(context).pop(
                      NewOrdDialogResult(
                        action: NewOrdDialogAction.save,
                        tipo: selectedTipo,
                        descArt: payload.descArt,
                        fechaEntrega: fechaEntrega,
                        comad: comad,
                      ),
                    );
                  },
                  child: const Text('Guardar'),
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

class _ReadonlyField extends StatelessWidget {
  const _ReadonlyField({
    required this.label,
    required this.value,
  });

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
