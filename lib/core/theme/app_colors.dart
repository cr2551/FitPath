import 'package:flutter/painting.dart';

/// Raw palette (DESIGN/README.md section 2). ONLY `lib/core/theme/` may use
/// these constants; everything else reads colors from the theme
/// (`Theme.of(context)` or `context.fitColors`).
///
/// No pastel tints: surfaces are neutral, and color comes from the açaí
/// accent and the saturated macro colors.
abstract final class AppColors {
  // Light
  static const background = Color(0xFFF5F5F4);
  static const surface = Color(0xFFFFFFFF);
  static const subtle = Color(0xFFE9EAE7);
  static const ink = Color(0xFF121815);
  static const inkMuted = Color(0xFF5E625F);
  static const line = Color(0xFFDEDFDB);
  static const accent = Color(0xFF5B2A6E);
  static const onAccent = Color(0xFFFFFFFF);
  static const success = Color(0xFF18804A);
  static const warning = Color(0xFF9A5A00);
  static const error = Color(0xFFC6282B);

  // Macros (fills only, never body text)
  static const protein = Color(0xFFEF4C4C);
  static const carbs = Color(0xFF7DB547);
  static const fat = Color(0xFFF7B500);
  static const unknown = Color(0xFFA2A7A3);

  // Dark
  static const darkBackground = Color(0xFF0F1110);
  static const darkSurface = Color(0xFF181B19);
  static const darkSubtle = Color(0xFF242826);
  static const darkInk = Color(0xFFEDEFEC);
  static const darkInkMuted = Color(0xFFA3A9A5);
  static const darkLine = Color(0xFF2F3431);
  static const darkAccent = Color(0xFFAA69C7);
  static const darkOnAccent = Color(0xFF0F1110);
  static const darkSuccess = Color(0xFF4CC27F);
  static const darkWarning = Color(0xFFE0A040);
  static const darkError = Color(0xFFF2726F);
  static const darkUnknown = Color(0xFF6E7570);
}
