import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/fit_colors.dart';
import '../../../../shared/widgets/widgets.dart';
import 'food_search_view_data.dart';

/// Pure layout for the food search screen.
class FoodSearchView extends StatelessWidget {
  const FoodSearchView({
    super.key,
    required this.body,
    required this.onQueryChanged,
    required this.onOpenLocal,
    required this.onOpenRemote,
    required this.onCreateCustomFood,
    required this.onRetry,
    this.target,
  });

  final FoodSearchBody body;

  /// E.g. "Adding to Lunch · Today".
  final String? target;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<int> onOpenLocal;
  final ValueChanged<int> onOpenRemote;
  final VoidCallback onCreateCustomFood;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    return Scaffold(
      appBar: AppBar(title: const Text('Search foods')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.sm,
            AppSpacing.gutter,
            AppSpacing.xl,
          ),
          children: [
            if (target != null) ...[
              Text(target!, style: t.label, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.sm),
            ],
            TextField(
              autofocus: true,
              onChanged: onQueryChanged,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Search foods',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ...switch (body) {
              SearchIdle() => [
                EmptyState(
                  message: 'Type a food name or brand.',
                  actionLabel: 'Create custom food',
                  onAction: onCreateCustomFood,
                ),
              ],
              SearchFailed(:final message) => [
                ErrorState(message: message, onRetry: onRetry),
              ],
              final SearchResults r => _results(context, r),
            },
          ],
        ),
      ),
    );
  }

  List<Widget> _results(BuildContext context, SearchResults r) {
    final c = context.fitColors;
    final t = context.textStyles;
    return [
      if (r.loading) const LinearProgressIndicator(minHeight: 2),
      if (r.banner != null)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Row(
            children: [
              Icon(Icons.cloud_off_outlined, size: 18, color: c.warning),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  r.banner!,
                  style: t.label.copyWith(color: c.warning),
                ),
              ),
            ],
          ),
        ),
      if (r.isEmpty && !r.loading)
        EmptyState(
          message: 'No foods match "${r.query}".',
          actionLabel: 'Create custom food',
          onAction: onCreateCustomFood,
        ),
      if (r.local.isNotEmpty)
        _Section(title: 'Your foods', rows: r.local, onOpen: onOpenLocal),
      if (r.remote.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.md),
        _Section(
          title: 'Online results (Open Food Facts)',
          rows: r.remote,
          onOpen: onOpenRemote,
        ),
      ],
      if (!r.isEmpty) ...[
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onCreateCustomFood,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Create custom food'),
          ),
        ),
      ],
    ];
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.rows,
    required this.onOpen,
  });

  final String title;
  final List<FoodResultRow> rows;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      header: Text(title.toUpperCase(), style: context.textStyles.overline),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            ListRow(
              title: rows[i].name,
              subtitle: rows[i].detail,
              value: rows[i].kcal,
              unit: rows[i].basis,
              onTap: () => onOpen(i),
            ),
          ],
        ],
      ),
    );
  }
}
