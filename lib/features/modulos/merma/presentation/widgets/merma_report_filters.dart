import 'package:flutter/material.dart';

class MermaReportFilters extends StatelessWidget {
  const MermaReportFilters({
    super.key,
    required this.fromCtrl,
    required this.toCtrl,
    required this.onApply,
  });

  final TextEditingController fromCtrl;
  final TextEditingController toCtrl;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: fromCtrl,
            decoration: const InputDecoration(
              labelText: 'Desde (YYYY-MM-DD)',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: toCtrl,
            decoration: const InputDecoration(
              labelText: 'Hasta (YYYY-MM-DD)',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: onApply,
          icon: const Icon(Icons.search),
          label: const Text('Generar'),
        ),
      ],
    );
  }
}
