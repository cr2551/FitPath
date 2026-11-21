import 'package:flutter/widgets.dart';

import '../../core/theme/fit_colors.dart';

/// The FitPath mark: an "F" drawn as a path, with a dot for the goal at the
/// end of its top arm. Square, drawn in code so it stays sharp at any size.
class FitPathLogo extends StatelessWidget {
  const FitPathLogo({
    super.key,
    this.size = 96,
    this.tileColor = FitColors.logoTile,
    this.markColor = FitColors.logoMark,
    this.dotColor = FitColors.logoDot,
  });

  final double size;
  final Color tileColor;
  final Color markColor;
  final Color dotColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'FitPath',
      image: true,
      child: CustomPaint(
        size: Size.square(size),
        painter: _LogoPainter(tileColor, markColor, dotColor),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter(this.tile, this.mark, this.dot);

  final Color tile;
  final Color mark;
  final Color dot;

  /// The artwork is drawn on a 180 x 180 grid and scaled to fit.
  static const _grid = 180.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / _grid, size.height / _grid);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, _grid, _grid),
        const Radius.circular(4),
      ),
      Paint()..color = tile,
    );

    final markPaint = Paint()..color = mark;
    canvas
      ..drawRect(const Rect.fromLTRB(56, 31, 73, 148), markPaint) // stem
      ..drawRect(const Rect.fromLTRB(56, 31, 122, 48), markPaint) // top arm
      ..drawRect(const Rect.fromLTRB(56, 83, 108, 100), markPaint) // middle
      ..drawCircle(const Offset(145, 40), 10, Paint()..color = dot);
  }

  @override
  bool shouldRepaint(_LogoPainter old) =>
      old.tile != tile || old.mark != mark || old.dot != dot;
}
