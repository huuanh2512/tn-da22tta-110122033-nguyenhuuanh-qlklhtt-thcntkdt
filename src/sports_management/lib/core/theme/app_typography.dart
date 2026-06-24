import 'package:flutter/material.dart';

// Font substitute: Inter (free) — closest match to Saans
// Add to pubspec: google_fonts: ^6.x
// import 'package:google_fonts/google_fonts.dart';

abstract final class AppTypography {
  static const String _fontFamily = 'Inter';

  // NOTE: Colors are intentionally omitted here so Flutter can inherit the
  // correct color from the active ColorScheme (light or dark). Individual
  // widgets that need a specific muted/subtle shade should apply it inline via
  // `.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))`.

  static const TextStyle displayXl = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 72,
    fontWeight: FontWeight.w500,
    height: 1.05,
    letterSpacing: -2.0,
  );

  static const TextStyle displayLg = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 56,
    fontWeight: FontWeight.w500,
    height: 1.10,
    letterSpacing: -1.4,
  );

  static const TextStyle displayMd = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 40,
    fontWeight: FontWeight.w500,
    height: 1.15,
    letterSpacing: -0.8,
  );

  static const TextStyle headline = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w500,
    height: 1.20,
    letterSpacing: -0.5,
  );

  static const TextStyle cardTitle = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w500,
    height: 1.25,
    letterSpacing: -0.3,
  );

  static const TextStyle subhead = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w400,
    height: 1.40,
    letterSpacing: -0.2,
  );

  static const TextStyle bodyLg = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w400,
    height: 1.50,
    letterSpacing: -0.1,
  );

  static const TextStyle body = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.50,
  );

  static const TextStyle bodySm = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.50,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.40,
  );

  static const TextStyle button = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.20,
  );

  static const TextStyle eyebrow = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.30,
  );
}