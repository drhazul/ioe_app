import 'package:flutter/material.dart';

class MermaAuditoriaDialog extends StatefulWidget {
  const MermaAuditoriaDialog({super.key});

  @override
  State<MermaAuditoriaDialog> createState() => _MermaAuditoriaDialogState();
}

class _MermaAuditoriaDialogState extends State<MermaAuditoriaDialog> {
  final _obsCtrl = TextEditingController();
  bool _confirmFisica = true;

  @override
  void dispose() {
    _obsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirmar auditoría'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CheckboxListTile(
              value: _confirmFisica,
              onChanged: (value) => setState(() => _confirmFisica = value ?? false),
              title: const Text('Confirmo revisión física'),
              contentPadding: EdgeInsets.zero,
            ),
            TextField(
              controller: _obsCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Observaciones de auditoría',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (!_confirmFisica) return;
            Navigator.of(context).pop({
              'obsAudit': _obsCtrl.text.trim(),
              'confirmFisica': _confirmFisica,
            });
          },
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}
