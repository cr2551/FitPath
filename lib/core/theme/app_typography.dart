import 'package:flutter/painting.dart';

/// Font families bundled in `assets/fonts/` (SIL OFL).
abstract final class AppFonts {
  /// Headlines, numbers, labels: reads like a scoreboard.
  static const condensed = 'Barlow Condensed';

  /// Body text.
  static const body = 'Barlow';
}

/// Base type scale (DESIGN/README.md section 2), without colors. Colors are
/// applied per theme in `FitTextStyles`.
abstract final class AppTypography {
  /// Every number that can change uses tabular figures so digits don't jump.
  static const _tabular = [FontFeature.tabularFigures()];

  static const hero = TextStyle(
    fontFamily: AppFonts.condensed,
    fontSize: 40,
    fontWeight: FontWeight.w700,
    height: 1,
    fontFeatures: _tabular,
  );

  static const display = TextStyle(
    fontFamily: AppFonts.condensed,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1,
    fontFeatures: _tabular,
  );

  static const headline = TextStyle(
    fontFamily: AppFonts.condensed,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    height: 1.1,
  );

  static const cardTitle = TextStyle(
    fontFamily: AppFonts.condensed,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    height: 1.1,
    fontFeatures: _tabular,
  );

  static const body = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.4,
    fontFeatures: _tabular,
  );

  static const bodyStrong = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.4,
    fontFeatures: _tabular,
  );

  static const label = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.3,
    fontFeatures: _tabular,
  );

  /// Use with UPPERCASE text (weekdays, stat labels, badges).
  static const overline = TextStyle(
    fontFamily: AppFonts.condensed,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.96,
    height: 1.2,
  );

  /// Button labels (use with UPPERCASE text).
  static const button = TextStyle(
    fontFamily: AppFonts.condensed,
    fontSize: 17,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.85,
  );
}
