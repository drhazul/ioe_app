import 'package:flutter/material.dart';

class MermaTotalsCard extends StatelessWidget {
  const MermaTotalsCard({
    super.key,
    required this.narts,
    required this.total,
  });

  final double narts;
  final double total;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(child: Text('Artículos: ${narts.toStringAsFixed(2)}')),
            Expanded(
              child: Text(
                'Total: \$${total.toStringAsFixed(2)}',
                textAlign: TextAlign.end,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
