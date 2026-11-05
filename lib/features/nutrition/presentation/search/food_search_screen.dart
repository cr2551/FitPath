import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/network_failure.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/utils/dates.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/enums.dart';
import '../../application/food_search_service.dart';
import '../../data/remote/off_product.dart';
import 'food_labels.dart';
import 'food_search_view.dart';
import 'food_search_view_data.dart';

/// Hybrid food search: local results first, then Open Food Facts. An online
/// problem shows a banner and never hides local results. Opening an online
/// result caches it locally first, so it can be logged offline later.
class FoodSearchScreen extends ConsumerStatefulWidget {
  const FoodSearchScreen({super.key, this.meal, this.date});

  final MealType? meal;
  final DateTime? date;

  @override
  ConsumerState<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends ConsumerState<FoodSearchScreen> {
  String _query = '';

  /// The last completed results, shown while a newer query runs.
  FoodSearchResults? _last;
  bool _opening = false;

  Future<void> _openLocal(FoodItem food) => context.push(
    Routes.foodDetails(food.id, meal: widget.meal, date: widget.date),
  );

  Future<void> _openRemote(OffProduct product) async {
    if (_opening) return;
    _opening = true;
    try {
      final id = await ref.read(foodSearchServiceProvider).select(product);
      if (!mounted) return;
      await context.push(
        Routes.foodDetails(id, meal: widget.meal, date: widget.date),
      );
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't open this product.")),
        );
      }
    } finally {
      _opening = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim();
    final FoodSearchBody body;
    if (q.isEmpty) {
      body = const SearchIdle();
    } else {
      final value = ref.watch(foodSearchProvider(q));
      if (value.hasValue) _last = value.requireValue;
      final last = _last;
      if (value.hasError && !value.hasValue) {
        body = const SearchFailed("Couldn't search your foods.");
      } else if (last == null) {
        body = SearchResults(
          query: q,
          local: const [],
          remote: const [],
          searchedRemote: false,
          loading: true,
        );
      } else {
        body = _results(
          last,
          loading: last.query != q || value.isLoading || last.remotePending,
        );
      }
    }

    return FoodSearchView(
      body: body,
      target: _target(),
      onQueryChanged: (text) => setState(() => _query = text),
      onOpenLocal: (i) => _openLocal(_last!.local[i]),
      onOpenRemote: (i) => _openRemote(_last!.remote[i]),
      onCreateCustomFood: () => context.push(Routes.newCustomFood),
      onRetry: () => ref.invalidate(foodSearchProvider(q)),
    );
  }

  String? _target() {
    final meal = widget.meal;
    final date = widget.date;
    if (meal == null && date == null) return null;
    return [
      if (meal != null) 'Adding to ${_mealName(meal)}',
      if (date != null)
        Dates.isSameDay(date, DateTime.now())
            ? 'Today'
            : DateFormat('EEE d MMM').format(date),
    ].join(' · ');
  }

  static SearchResults _results(
    FoodSearchResults r, {
    required bool loading,
  }) => SearchResults(
    query: r.query,
    loading: loading,
    searchedRemote: r.searchedRemote,
    banner: switch (r.remoteError) {
      null || RequestCancelled() => null,
      NoConnection() => "You're offline. Showing foods saved on this phone.",
      _ => "Couldn't reach Open Food Facts. Showing foods saved on this phone.",
    },
    local: [
      for (final f in r.local)
        FoodResultRow(
          name: f.name,
          detail: [?f.brand, FoodLabels.source(f.source)].join(' · '),
          kcal: Formatters.integer(f.kcal),
          basis:
              'kcal / ${FoodLabels.basis(f.referenceBasis, servingDescription: f.servingDescription)}',
        ),
    ],
    remote: [
      for (final p in r.remote)
        FoodResultRow(
          name: p.name,
          detail: [?p.brand, 'Open Food Facts'].join(' · '),
          kcal: Formatters.integer(p.kcal),
          basis: p.isLiquid ? 'kcal / 100 ml' : 'kcal / 100 g',
        ),
    ],
  );

  static String _mealName(MealType m) => switch (m) {
    MealType.breakfast => 'breakfast',
    MealType.lunch => 'lunch',
    MealType.dinner => 'dinner',
    MealType.snack => 'snacks',
  };
}
