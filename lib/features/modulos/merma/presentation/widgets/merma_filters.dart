import 'package:flutter/material.dart';

class MermaFilters extends StatelessWidget {
  const MermaFilters({
    super.key,
    required this.folioCtrl,
    required this.usuarioCtrl,
    required this.sucursales,
    required this.suc,
    required this.fromCtrl,
    required this.toCtrl,
    required this.estatus,
    required this.estatusOptions,
    required this.onSucChanged,
    required this.onStatusChanged,
    required this.onPickFrom,
    required this.onPickTo,
    required this.onApply,
    required this.onClear,
  });

  final TextEditingController folioCtrl;
  final TextEditingController usuarioCtrl;
  final List<String> sucursales;
  final String suc;
  final TextEditingController fromCtrl;
  final TextEditingController toCtrl;
  final String? estatus;
  final List<String> estatusOptions;
  final ValueChanged<String?> onSucChanged;
  final ValueChanged<String?> onStatusChanged;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;
  final VoidCallback onApply;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    const fieldWidth = 170.0;
    const dropWidth = 140.0;
    const dateWidth = 140.0;
    const fieldDecoration = InputDecoration(
      border: OutlineInputBorder(),
      isDense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );

    return Column(
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            SizedBox(
              width: fieldWidth,
              child: TextField(
                controller: folioCtrl,
                decoration: fieldDecoration.copyWith(
                  labelText: 'Documento',
                ),
                onSubmitted: (_) => onApply(),
              ),
            ),
            SizedBox(
              width: fieldWidth,
              child: TextField(
                controller: usuarioCtrl,
                decoration: fieldDecoration.copyWith(
                  labelText: 'Usuario',
                ),
                onSubmitted: (_) => onApply(),
              ),
            ),
            SizedBox(
              width: dropWidth,
              child: DropdownButtonFormField<String>(
                key: ValueKey('suc-$suc'),
                initialValue: suc.trim().isEmpty ? null : suc,
                isExpanded: true,
                hint: const Text('Seleccionar'),
                decoration: fieldDecoration.copyWith(
                  labelText: 'Sucursal',
                ),
                items: [
                  ...sucursales.map(
                    (item) => DropdownMenuItem(value: item, child: Text(item)),
                  ),
                ],
                onChanged: onSucChanged,
              ),
            ),
            SizedBox(
              width: dropWidth,
              child: DropdownButtonFormField<String>(
                initialValue: (estatus ?? '').trim().isEmpty ? null : estatus,
                key: ValueKey('estatus-${estatus ?? ''}'),
                isExpanded: true,
                hint: const Text('Seleccionar'),
                decoration: fieldDecoration.copyWith(
                  labelText: 'Estatus',
                ),
                items: [
                  ...estatusOptions.map(
                    (item) => DropdownMenuItem(value: item, child: Text(item)),
                  ),
                ],
                onChanged: onStatusChanged,
              ),
            ),
            SizedBox(
              width: dateWidth,
              child: TextField(
                controller: fromCtrl,
                readOnly: true,
                decoration: fieldDecoration.copyWith(
                  labelText: 'Desde',
                  suffixIcon: IconButton(
                    onPressed: onPickFrom,
                    icon: const Icon(Icons.calendar_today),
                  ),
                ),
                onTap: onPickFrom,
              ),
            ),
            SizedBox(
              width: dateWidth,
              child: TextField(
                controller: toCtrl,
                readOnly: true,
                decoration: fieldDecoration.copyWith(
                  labelText: 'Hasta',
                  suffixIcon: IconButton(
                    onPressed: onPickTo,
                    icon: const Icon(Icons.calendar_today),
                  ),
                ),
                onTap: onPickTo,
              ),
            ),
            ElevatedButton.icon(
              onPressed: onApply,
              icon: const Icon(Icons.search),
              label: const Text('Filtrar'),
            ),
            OutlinedButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.refresh),
              label: const Text('Limpiar'),
            ),
          ],
        ),
      ],
    );
  }
}
