import 'package:flutter/material.dart';

import '../../domain/merma_models.dart';
import 'merma_item_table.dart';
import 'merma_status_chip.dart';
import 'merma_totals_card.dart';

class MermaReadonlyDetail extends StatelessWidget {
  const MermaReadonlyDetail({super.key, required this.doc});

  final MermaDocModel doc;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            Text(
              'DOCMER: ${doc.docmer}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('Sucursal: ${doc.suc}'),
            Text('Usuario: ${doc.user}'),
            MermaStatusChip(estatus: doc.estatus),
          ],
        ),
        const SizedBox(height: 10),
        MermaTotalsCard(narts: doc.narts, total: doc.total),
        const SizedBox(height: 10),
        MermaItemTable(
          items: doc.detalle,
          documentArea: doc.areaM,
          readOnly: true,
        ),
      ],
    );
  }
}
