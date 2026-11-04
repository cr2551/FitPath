import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/fit_colors.dart';
import '../../../core/utils/units.dart';
import '../../../shared/widgets/widgets.dart';

class TargetsViewData {
  const TargetsViewData({
    required this.current,
    required this.currentSource,
    required this.suggestion,
    required this.suggestionNote,
    required this.initialKcal,
    required this.initialProtein,
    required this.initialCarbs,
    required this.initialFat,
    required this.canSave,
    required this.saving,
  });

  /// E.g. "2,100 kcal · P 140 · C 230 · F 70 g"; null when never set.
  final String? current;

  /// E.g. "Set by you · since 3 Nov 2026".
  final String? currentSource;

  /// Calculated suggestion, e.g. "2,310 kcal · P 150 · C 260 · F 75 g";
  /// null when it cannot be calculated.
  final String? suggestion;

  /// Why there is no suggestion, or its guardrail note.
  final String? suggestionNote;

  final double? initialKcal;
  final double? initialProtein;
  final double? initialCarbs;
  final double? initialFat;
  final bool canSave;
  final bool saving;
}

class TargetsCallbacks {
  const TargetsCallbacks({
    required this.onKcal,
    required this.onProtein,
    required this.onCarbs,
    required this.onFat,
    required this.onUseSuggestion,
    required this.onEditDetails,
    required this.onSave,
    required this.onRetry,
  });

  /// Null while empty or invalid.
  final ValueChanged<double?> onKcal;
  final ValueChanged<double?> onProtein;
  final ValueChanged<double?> onCarbs;
  final ValueChanged<double?> onFat;
  final VoidCallback onUseSuggestion;
  final VoidCallback onEditDetails;
  final VoidCallback onSave;
  final VoidCallback onRetry;
}

/// Allowed manual target values.
abstract final class TargetRanges {
  static const kcal = ValueRange(800, 10000);
  static const grams = ValueRange(0, 1000);
}

/// Pure layout for viewing and changing nutrition targets.
class TargetsView extends StatelessWidget {
  const TargetsView({
    super.key,
    required this.data,
    required this.callbacks,
    this.error,
  });

  final TargetsViewData? data;
  final String? error;
  final TargetsCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    final d = data;
    return Scaffold(
      appBar: AppBar(title: const Text('Nutrition targets')),
      body: SafeArea(
        child: error != null
            ? Padding(
                padding: AppSpacing.screenPadding,
                child: ErrorState(message: error!, onRetry: callbacks.onRetry),
              )
            : d == null
            ? const Center(child: CircularProgressIndicator())
            : _form(context, d),
      ),
    );
  }

  Widget _form(BuildContext context, TargetsViewData d) {
    final t = context.textStyles;
    final cb = callbacks;
    const gap = SizedBox(height: AppSpacing.md);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.sm,
        AppSpacing.gutter,
        AppSpacing.xl,
      ),
      children: [
        SectionCard(
          header: const CardHeader(title: 'Current targets'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(d.current ?? 'Not set yet', style: t.bodyStrong),
              if (d.currentSource != null)
                Text(d.currentSource!, style: t.label),
            ],
          ),
        ),
        gap,
        SectionCard(
          header: const CardHeader(
            title: 'Suggested',
            trailing: EstimateBadge(),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(d.suggestion ?? 'Not available yet', style: t.bodyStrong),
              if (d.suggestionNote != null)
                Text(d.suggestionNote!, style: t.label),
              const SizedBox(height: AppSpacing.md),
              if (d.suggestion != null)
                OutlinedButton(
                  onPressed: d.saving ? null : cb.onUseSuggestion,
                  child: const Text('USE SUGGESTED TARGETS'),
                )
              else
                OutlinedButton(
                  onPressed: cb.onEditDetails,
                  child: const Text('COMPLETE YOUR DETAILS'),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('SET YOUR OWN', style: t.overline),
        gap,
        UnitNumberField(
          label: 'Calories',
          unit: 'kcal',
          range: TargetRanges.kcal,
          decimals: 0,
          initialValue: d.initialKcal,
          onChanged: cb.onKcal,
        ),
        gap,
        UnitNumberField(
          label: 'Protein',
          unit: 'g',
          range: TargetRanges.grams,
          decimals: 0,
          isRequired: false,
          initialValue: d.initialProtein,
          onChanged: cb.onProtein,
        ),
        gap,
        UnitNumberField(
          label: 'Carbs',
          unit: 'g',
          range: TargetRanges.grams,
          decimals: 0,
          isRequired: false,
          initialValue: d.initialCarbs,
          onChanged: cb.onCarbs,
        ),
        gap,
        UnitNumberField(
          label: 'Fat',
          unit: 'g',
          range: TargetRanges.grams,
          decimals: 0,
          isRequired: false,
          initialValue: d.initialFat,
          onChanged: cb.onFat,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'New targets apply from today. Past days keep the targets that '
          'applied then.',
          style: t.label,
        ),
        const SizedBox(height: AppSpacing.xl),
        FilledButton(
          style: AppTheme.accentButton(context),
          onPressed: d.canSave && !d.saving ? cb.onSave : null,
          child: const Text('SAVE TARGETS'),
        ),
      ],
    );
  }
}
