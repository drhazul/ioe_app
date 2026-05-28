import 'package:flutter/material.dart';

class MermaStatusChip extends StatelessWidget {
  const MermaStatusChip({super.key, required this.estatus});

  final String estatus;

  @override
  Widget build(BuildContext context) {
    final text = estatus.trim().toUpperCase();
    final baseColor = switch (text) {
      'ABIERTO' => Colors.blueGrey,
      'PENDIENTE' => Colors.orange,
      'REVISAR' => Colors.amber,
      'ANULADO' => Colors.red,
      'CONTABILIZADO' => Colors.green,
      'AUDITADO' => Colors.teal,
      _ => Colors.grey,
    };
    return Chip(
      label: Text(text),
      backgroundColor: baseColor.withValues(alpha: 0.15),
      labelStyle: TextStyle(color: baseColor.shade700, fontWeight: FontWeight.w700),
      visualDensity: VisualDensity.compact,
    );
  }
}
