import 'package:flutter/material.dart';
import 'package:ioe_app/core/app_theme.dart';

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
      'AUDITADO' => AppColors.navyLight,
      _ => Colors.grey,
    };
    return Chip(
      label: Text(text),
      backgroundColor: baseColor.withValues(alpha: 0.15),
      labelStyle: TextStyle(color: baseColor, fontWeight: FontWeight.w700),
      visualDensity: VisualDensity.compact,
    );
  }
}
