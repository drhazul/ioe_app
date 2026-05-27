import 'package:flutter/material.dart';

class MermaRevisionDialog extends StatefulWidget {
  const MermaRevisionDialog({super.key});

  @override
  State<MermaRevisionDialog> createState() => _MermaRevisionDialogState();
}

class _MermaRevisionDialogState extends State<MermaRevisionDialog> {
  final _obsCtrl = TextEditingController();

  @override
  void dispose() {
    _obsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enviar a revisar'),
      content: TextField(
        controller: _obsCtrl,
        maxLines: 4,
        decoration: const InputDecoration(
          labelText: 'Observación de revisión',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final obs = _obsCtrl.text.trim();
            if (obs.isEmpty) return;
            Navigator.of(context).pop(obs);
          },
          child: const Text('Aplicar'),
        ),
      ],
    );
  }
}
