import 'package:flutter/material.dart';

import '../../shared/widgets/fit_path_logo.dart';
import '../theme/app_spacing.dart';
import '../theme/fit_colors.dart';

/// Shows the logo over [child] when the app opens, then fades it out.
///
/// The app builds underneath meanwhile, so the first screen is ready when
/// the logo goes. Touches pass through, so it never blocks the app.
class SplashOverlay extends StatefulWidget {
  const SplashOverlay({super.key, required this.child});

  final Widget child;

  @override
  State<SplashOverlay> createState() => _SplashOverlayState();
}

class _SplashOverlayState extends State<SplashOverlay>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  /// Fully visible for the first 70%, then fades out.
  late final _opacity = Tween<double>(begin: 1, end: 0).animate(
    CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.7, 1, curve: Curves.easeOut),
    ),
  );

  bool _done = false;

  @override
  void initState() {
    super.initState();
    _controller.forward().whenComplete(() {
      if (mounted) setState(() => _done = true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return widget.child;
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: FadeTransition(opacity: _opacity, child: const _Splash()),
          ),
        ),
      ],
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    final c = context.fitColors;
    // Material: the overlay sits above the navigator, so the text needs its
    // own default style (otherwise it gets the yellow debug underline).
    return Material(
      color: c.background,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const FitPathLogo(size: 112),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'FITPATH',
              style: context.textStyles.headline.copyWith(letterSpacing: 2),
            ),
          ],
        ),
      ),
    );
  }
}
