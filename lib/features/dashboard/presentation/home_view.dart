import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/widgets.dart';
import 'edit/dashboard_edit_view.dart';

/// Everything Home renders. Plain values, plus the already-built card
/// widgets (each card is its own container, see `card_registry.dart`).
class HomeViewData {
  const HomeViewData({
    required this.title,
    required this.goalLine,
    required this.week,
    required this.selected,
    required this.today,
    required this.daysWithEntries,
    required this.body,
  });

  /// "Today", or the selected day ("Mon 2 Nov").
  final String title;

  /// E.g. "Lose weight · 72 kg by 1 Mar"; null without a goal.
  final String? goalLine;
  final List<DateTime> week;
  final DateTime selected;
  final DateTime today;

  /// Local date keys (yyyy-MM-dd) of days in [week] with food entries.
  final Set<String> daysWithEntries;
  final HomeBody body;
}

sealed class HomeBody {
  const HomeBody();
}

class HomeLoading extends HomeBody {
  const HomeLoading();
}

class HomeError extends HomeBody {
  const HomeError(this.message);

  final String message;
}

/// The visible cards, in order. Empty shows the empty dashboard state.
class HomeCards extends HomeBody {
  const HomeCards(this.cards);

  final List<Widget> cards;
}

class HomeEditing extends HomeBody {
  const HomeEditing(this.rows);

  final List<EditCardRowData> rows;
}

class HomeCallbacks {
  const HomeCallbacks({
    required this.onProfile,
    required this.onToggleEdit,
    required this.onSelectDay,
    required this.onLogFood,
    required this.onStartWorkout,
    required this.onRetry,
    required this.edit,
  });

  final VoidCallback onProfile;
  final VoidCallback onToggleEdit;
  final ValueChanged<DateTime> onSelectDay;
  final VoidCallback onLogFood;
  final VoidCallback onStartWorkout;
  final VoidCallback onRetry;

  /// Also used by the empty dashboard state (add cards, restore preset).
  final DashboardEditCallbacks edit;
}

/// Pure layout for the Home tab (DESIGN/home.html).
class HomeView extends StatelessWidget {
  const HomeView({super.key, required this.data, required this.callbacks});

  final HomeViewData data;
  final HomeCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    final body = data.body;
    return Scaffold(
      body: SafeArea(
        child: body is HomeEditing
            ? DashboardEditView(
                header: ScreenHeader(
                  title: 'Edit dashboard',
                  trailing: HeaderIconButton(
                    icon: Icons.check,
                    tooltip: 'Done editing',
                    onPressed: callbacks.onToggleEdit,
                  ),
                ),
                rows: body.rows,
                callbacks: callbacks.edit,
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter,
                  AppSpacing.md,
                  AppSpacing.gutter,
                  AppSpacing.xl,
                ),
                children: [
                  ScreenHeader(
                    title: data.title,
                    subtitle: data.goalLine,
                    leading: HeaderIconButton(
                      icon: Icons.person_outline,
                      tooltip: 'Profile',
                      onPressed: callbacks.onProfile,
                    ),
                    trailing: HeaderIconButton(
                      icon: Icons.dashboard_customize_outlined,
                      tooltip: 'Edit dashboard',
                      onPressed: callbacks.onToggleEdit,
                    ),
                  ),
                  DateStrip(
                    days: data.week,
                    selected: data.selected,
                    today: data.today,
                    daysWithEntries: data.daysWithEntries,
                    onSelected: callbacks.onSelectDay,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ..._body(context, body),
                ],
              ),
      ),
    );
  }

  List<Widget> _body(BuildContext context, HomeBody body) {
    const gap = SizedBox(height: AppSpacing.md);
    final actions = _QuickActions(
      onLogFood: callbacks.onLogFood,
      onStartWorkout: callbacks.onStartWorkout,
    );
    return switch (body) {
      HomeLoading() || HomeEditing() => const [
        Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
      HomeError(:final message) => [
        ErrorState(message: message, onRetry: callbacks.onRetry),
      ],
      HomeCards(:final cards) when cards.isEmpty => [
        _EmptyDashboard(
          onAdd: callbacks.edit.onAdd,
          onRestore: callbacks.edit.onRestorePreset,
        ),
        gap,
        actions,
      ],
      HomeCards(:final cards) => [
        cards.first,
        gap,
        actions,
        for (final card in cards.skip(1)) ...[gap, card],
      ],
    };
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onLogFood, required this.onStartWorkout});

  final VoidCallback onLogFood;
  final VoidCallback onStartWorkout;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            style: AppTheme.accentButton(context),
            onPressed: onLogFood,
            icon: const Icon(Icons.add),
            label: const Text('LOG FOOD'),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: FilledButton.icon(
            onPressed: onStartWorkout,
            icon: const Icon(Icons.bolt),
            label: const Text('START WORKOUT'),
          ),
        ),
      ],
    );
  }
}

class _EmptyDashboard extends StatelessWidget {
  const _EmptyDashboard({required this.onAdd, required this.onRestore});

  final VoidCallback? onAdd;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      header: const CardHeader(
        title: 'Your dashboard is empty',
        subtitle: TextSpan(text: 'Add the cards you want to see here.'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('ADD CARDS'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: onRestore,
            child: const Text('Use suggested layout'),
          ),
        ],
      ),
    );
  }
}
