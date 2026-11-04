import 'package:flutter/widgets.dart';

/// 4-pt spacing scale.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Horizontal screen padding.
  static const double gutter = lg;

  static const screenPadding = EdgeInsets.symmetric(horizontal: gutter);
}

/// Corner radii. **8 px is the maximum**: no pill or stadium shapes anywhere.
/// The calorie ring is the only circle in the app.
abstract final class AppRadii {
  /// Dividers, bars, ring segment ends.
  static const double none = 0;

  /// Buttons, inputs, chips, segmented controls, nav indicator.
  static const double sm = 4;

  /// Cards, sheets, dialogs, date tiles, icon buttons.
  static const double md = 8;

  static const smAll = BorderRadius.all(Radius.circular(sm));
  static const mdAll = BorderRadius.all(Radius.circular(md));
}
