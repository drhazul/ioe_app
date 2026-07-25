import 'package:flutter/material.dart';

/// Brand palette derived from the IOE logo.
abstract final class AppColors {
  static const navy = Color(0xFF061226);
  static const navyMid = Color(0xFF102A4B);
  static const navyLight = Color(0xFF244B70);
  static const steel = Color(0xFF66839D);
  static const silver = Color(0xFFBFCAD5);
  static const canvas = Color(0xFFF4F7FA);
  static const canvasAlt = Color(0xFFE8EEF4);
  static const border = Color(0xFFD5E0E8);
  static const ink = Color(0xFF182A3D);
  static const muted = Color(0xFF60758A);
}

ColorScheme get appColorScheme => const ColorScheme.light(
  primary: AppColors.navy,
  onPrimary: Colors.white,
  primaryContainer: AppColors.navyMid,
  onPrimaryContainer: Colors.white,
  secondary: AppColors.steel,
  onSecondary: Colors.white,
  secondaryContainer: AppColors.canvasAlt,
  onSecondaryContainer: AppColors.navy,
  tertiary: AppColors.silver,
  onTertiary: AppColors.navy,
  surface: AppColors.canvas,
  onSurface: AppColors.ink,
  error: Color(0xFFB3261E),
  onError: Colors.white,
  outline: AppColors.border,
);
