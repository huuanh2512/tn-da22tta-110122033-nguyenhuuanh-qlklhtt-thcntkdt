import 'package:flutter/material.dart';

abstract final class AppColors {
  // Canvas & Surfaces
  static const Color canvas = Color(0xFFF5F1EC);
  static const Color surface1 = Color(0xFFFFFFFF);
  static const Color surface2 = Color(0xFFEDE9E3);
  static const Color inverseCanvas = Color(0xFF000000);

  // Ink (text & primary)
  static const Color ink = Color(0xFF111111);
  static const Color inkMuted = Color(0xFF626260);
  static const Color inkSubtle = Color(0xFF7B7B78);
  static const Color inkTertiary = Color(0xFF9C9FA5);
  static const Color inverseInk = Color(0xFFFFFFFF);
  static const Color inverseInkMuted = Color(0xFFCCCAC6);

  // Accent
  static const Color finOrange = Color(0xFFFF5600);

  // Borders
  static const Color hairline = Color(0xFFD3CEC6);
  static const Color hairlineSoft = Color(0xFFE3DED7);

  // Semantic
  static const Color semanticError = Color(0xFFD93025);
  static const Color semanticSuccess = Color(0xFF1E8A44);
  static const Color semanticWarning = Color(0xFFF59E0B);
}