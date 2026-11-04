import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/fit_colors.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/widgets/widgets.dart';

enum ThemeChoice { system, light, dark }

/// Everything the Profile & Settings tab shows. Plain, formatted values.
class SettingsViewData {
  const SettingsViewData({
    required this.age,
    required this.height,
    required this.weight,
    required this.activity,
    required this.bmi,
    required this.bmr,
    required this.tdee,
    required this.estimateExplanation,
    required this.estimateNotes,
    required this.goalsSummary,
    required this.targetsSummary,
    required this.units,
    required this.theme,
  });

  final String age;
  final String height;
  final String weight;
  final String activity;

  /// "—" when the estimate is unavailable.
  final String bmi;
  final String bmr;
  final String tdee;
  final String estimateExplanation;
  final List<String> estimateNotes;

  final String goalsSummary;
  final String targetsSummary;
  final UnitSystem units;
  final ThemeChoice theme;
}

class SettingsCallbacks {
  const SettingsCallbacks({
    required this.onEditDetails,
    required this.onGoals,
    required this.onTargets,
    required this.onUnitsChanged,
    required this.onThemeChanged,
    required this.onDashboard,
    required this.onBackup,
    required this.onReset,
    required this.onAbout,
    required this.onRetry,
  });

  final VoidCallback onEditDetails;
  final VoidCallback onGoals;
  final VoidCallback onTargets;
  final ValueChanged<UnitSystem> onUnitsChanged;
  final ValueChanged<ThemeChoice> onThemeChanged;
  final VoidCallback onDashboard;
  final VoidCallback onBackup;
  final VoidCallback onReset;
  final VoidCallback onAbout;
  final VoidCallback onRetry;
}

/// Pure layout for the Profile tab. [data] is null while loading;
/// [error] is set when loading failed.
class SettingsView extends StatelessWidget {
  const SettingsView({
    super.key,
    required this.data,
    required this.callbacks,
    this.error,
  });

  final SettingsViewData? data;
  final String? error;
  final SettingsCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    final cb = callbacks;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.md,
            AppSpacing.gutter,
            AppSpacing.xl,
          ),
          children: [
            ScreenHeader(
              title: 'Profile',
              trailing: HeaderIconButton(
                icon: Icons.info_outline,
                tooltip: 'About and disclaimer',
                onPressed: cb.onAbout,
              ),
            ),
            if (error != null)
              ErrorState(message: error!, onRetry: cb.onRetry)
            else if (data == null)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              ..._content(context, data!),
          ],
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context, SettingsViewData d) {
    final c = context.fitColors;
    final cb = callbacks;
    const gap = SizedBox(height: AppSpacing.md);
    return [
      SectionCard(
        header: CardHeader(
          title: 'Your details',
          trailing: TextButton.icon(
            onPressed: cb.onEditDetails,
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text('Edit'),
          ),
        ),
        child: Column(
          children: [
            StatRow(
              items: [
                StatItem(label: 'Age', value: d.age),
                StatItem(label: 'Height', value: d.height),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            StatRow(
              items: [
                StatItem(label: 'Weight', value: d.weight),
                StatItem(label: 'Activity', value: d.activity),
              ],
            ),
          ],
        ),
      ),
      gap,
      SectionCard(
        header: CardHeader(
          title: 'Estimates',
          trailing: EstimateBadge(
            onTap: () => showEstimateSheet(
              context,
              title: 'How estimates are calculated',
              explanation: d.estimateExplanation,
              notes: d.estimateNotes,
            ),
          ),
        ),
        child: StatRow(
          items: [
            StatItem(label: 'BMI', value: d.bmi),
            StatItem(label: 'BMR', value: d.bmr, unit: 'kcal'),
            StatItem(label: 'TDEE', value: d.tdee, unit: 'kcal'),
          ],
        ),
      ),
      const _GroupLabel('Goals & targets'),
      _ListCard(
        children: [
          ListRow(title: 'Goals', subtitle: d.goalsSummary, onTap: cb.onGoals),
          ListRow(
            title: 'Nutrition targets',
            subtitle: d.targetsSummary,
            onTap: cb.onTargets,
          ),
        ],
      ),
      const _GroupLabel('Preferences'),
      _ListCard(
        children: [
          ListRow(
            title: 'Units',
            trailing: SegmentedButton<UnitSystem>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: UnitSystem.metric, label: Text('Metric')),
                ButtonSegment(
                  value: UnitSystem.imperial,
                  label: Text('Imperial'),
                ),
              ],
              selected: {d.units},
              onSelectionChanged: (s) => cb.onUnitsChanged(s.single),
            ),
          ),
          ListRow(
            title: 'Theme',
            trailing: SegmentedButton<ThemeChoice>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: ThemeChoice.system, label: Text('Auto')),
                ButtonSegment(value: ThemeChoice.light, label: Text('Light')),
                ButtonSegment(value: ThemeChoice.dark, label: Text('Dark')),
              ],
              selected: {d.theme},
              onSelectionChanged: (s) => cb.onThemeChanged(s.single),
            ),
          ),
          ListRow(title: 'Dashboard cards', onTap: cb.onDashboard),
        ],
      ),
      const _GroupLabel('Your data'),
      _ListCard(
        children: [
          ListRow(title: 'Backup & restore', onTap: cb.onBackup),
          ListRow(
            title: 'Reset all data',
            titleColor: c.error,
            onTap: cb.onReset,
          ),
        ],
      ),
    ];
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(0, AppSpacing.xl, 0, AppSpacing.sm),
    child: Text(text.toUpperCase(), style: context.textStyles.overline),
  );
}

class _ListCard extends StatelessWidget {
  const _ListCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SectionCard(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const Divider(height: 1),
          children[i],
        ],
      ],
    ),
  );
}
