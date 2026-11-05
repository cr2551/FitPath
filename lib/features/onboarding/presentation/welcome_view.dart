import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/fit_colors.dart';
import '../../../shared/widgets/widgets.dart';

/// Pure layout for the first onboarding screen.
class WelcomeView extends StatelessWidget {
  const WelcomeView({super.key, required this.onGetStarted});

  final VoidCallback onGetStarted;

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    final c = context.fitColors;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.xxl,
            AppSpacing.gutter,
            AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('FITPATH', style: t.display.copyWith(color: c.accent)),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Food, workouts and weight in one place.',
                style: t.headline,
              ),
              const SizedBox(height: AppSpacing.xl),
              for (final (icon, title, text) in const [
                (
                  FitIcons.calories,
                  'Calories and macros',
                  'Log meals from a built-in list or millions of packaged '
                      'foods.',
                ),
                (
                  Icons.fitness_center_outlined,
                  'Workouts',
                  'Record exercises, sets, reps and weight as you train.',
                ),
                (
                  Icons.show_chart,
                  'Progress',
                  'Follow your weight and training over time.',
                ),
              ]) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconTile(icon: icon),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: t.bodyStrong),
                          Text(text, style: t.label),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              const Spacer(),
              Text(
                'No account needed. Everything stays on this phone.',
                style: t.label,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                style: AppTheme.accentButton(context),
                onPressed: onGetStarted,
                child: const Text('GET STARTED'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
