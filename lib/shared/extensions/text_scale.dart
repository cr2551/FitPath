import 'package:flutter/widgets.dart';

extension TextScaleContext on BuildContext {
  /// True when the user's font size is large enough (130% and up) that
  /// side-by-side layouts should stack instead.
  bool get hasLargeText => MediaQuery.textScalerOf(this).scale(10) >= 13;
}
