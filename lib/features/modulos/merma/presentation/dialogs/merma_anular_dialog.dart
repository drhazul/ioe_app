import 'package:flutter/material.dart';

class MermaAnularDialog extends StatefulWidget {
  const MermaAnularDialog({super.key});

  @override
  State<MermaAnularDialog> createState() => _MermaAnularDialogState();
}

class _MermaAnularDialogState extends State<MermaAnularDialog> {
  final _obsCtrl = TextEditingController();

  @override
  void dispose() {
    _obsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Anular documento'),
      content: TextField(
        controller: _obsCtrl,
        maxLines: 4,
        decoration: const InputDecoration(
          labelText: 'Motivo de anulación',
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
          child: const Text('Anular'),
        ),
      ],
    );
  }
}
