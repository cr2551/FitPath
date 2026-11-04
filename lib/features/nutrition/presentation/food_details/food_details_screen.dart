import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/units.dart';
import '../../../../shared/models/enums.dart';
import '../../application/diary_providers.dart';
import '../../data/local/food_repository.dart';
import '../../domain/nutrients.dart';
import '../../domain/nutrition_math.dart';
import '../search/food_labels.dart';
import 'food_details_view.dart';
import 'food_details_view_data.dart';

final _foodProvider = FutureProvider.autoDispose.family<FoodItem, int>((
  ref,
  id,
) async {
  final food = await ref.watch(foodRepositoryProvider).foodById(id);
  if (food == null) throw FoodNotFound(id);
  return food;
  // A missing food will not appear by retrying.
}, retry: (_, _) => null);

/// A food's label values and a live preview for an amount. Works offline:
/// it only reads the local catalog (online results are cached on select).
///
/// "Add to diary" opens the entry screen with the food, meal and date. The
/// amount is not passed on: the route table has no quantity parameter.
class FoodDetailsScreen extends ConsumerStatefulWidget {
  const FoodDetailsScreen({
    super.key,
    required this.foodId,
    this.meal,
    this.date,
  });

  final int foodId;
  final MealType? meal;
  final DateTime? date;

  @override
  ConsumerState<FoodDetailsScreen> createState() => _FoodDetailsScreenState();
}

class _FoodDetailsScreenState extends ConsumerState<FoodDetailsScreen> {
  String? _quantityText;
  QuantityUnit? _unit;

  @override
  Widget build(BuildContext context) {
    final food = ref.watch(_foodProvider(widget.foodId));
    final FoodDetailsBody body;
    List<QuantityUnit> units = const [];
    if (food.hasValue) {
      final f = food.requireValue;
      final nutrition = FoodRepository.foodNutrition(f);
      units = NutritionMath.allowedUnits(nutrition);
      _unit ??= units.first;
      _quantityText ??= _number(_defaultAmount(nutrition, _unit!));
      body = _data(f, nutrition, units);
    } else if (food.hasError) {
      body = const FoodDetailsError("This food doesn't exist any more.");
    } else {
      body = const FoodDetailsLoading();
    }

    return FoodDetailsView(
      body: body,
      onQuantityChanged: (text) => setState(() => _quantityText = text),
      onUnitSelected: (i) => setState(() => _unit = units[i]),
      onAddToDiary: () => context.push(
        Routes.newEntry(
          foodId: widget.foodId,
          meal: widget.meal,
          date: widget.date,
        ),
      ),
      onEdit: () => context.push(Routes.editCustomFood(widget.foodId)),
      onRetry: () => ref.invalidate(_foodProvider(widget.foodId)),
    );
  }

  FoodDetailsData _data(
    FoodItem f,
    FoodNutrition nutrition,
    List<QuantityUnit> units,
  ) {
    final unit = _unit!;
    final q = Units.parseDecimal(_quantityText ?? '');
    final String? error = q == null
        ? 'Enter an amount'
        : q <= 0
        ? 'Must be more than 0'
        : null;
    final amount = error == null
        ? NutritionMath.scale(nutrition, q!, unit)
        : null;
    // Without a valid amount, show the label values themselves.
    final Nutrients n = amount ?? nutrition.nutrients;
    final basis = FoodLabels.basis(
      f.referenceBasis,
      servingDescription: f.servingDescription,
    );

    return FoodDetailsData(
      name: f.name,
      subtitle: [?f.brand, FoodLabels.source(f.source)].join(' · '),
      basisLabel: [
        'Label values per $basis',
        if (f.servingSize != null && f.servingUnit != null)
          'one serving is ${_number(f.servingSize!)} ${f.servingUnit}',
      ].join(' · '),
      initialQuantity: _quantityText!,
      quantityError: error,
      unitLabels: [for (final u in units) _unitLabel(u)],
      selectedUnit: units.indexOf(unit).clamp(0, units.length - 1),
      amountLabel: amount == null
          ? 'Per $basis'
          : 'For ${_number(q!)} ${_unitLabel(unit, plural: q != 1)}',
      nutrients: [
        NutrientLine(label: 'Calories', value: Formatters.energy(n.kcal)),
        NutrientLine(label: 'Protein', value: Formatters.grams(n.proteinG)),
        NutrientLine(label: 'Carbs', value: Formatters.grams(n.carbsG)),
        NutrientLine(label: 'Fat', value: Formatters.grams(n.fatG)),
        if (n.fiberG != null)
          NutrientLine(label: 'Fiber', value: Formatters.grams(n.fiberG)),
        if (n.sugarG != null)
          NutrientLine(label: 'Sugar', value: Formatters.grams(n.sugarG)),
        if (n.sodiumMg != null)
          NutrientLine(
            label: 'Sodium',
            value: '${Formatters.integer(n.sodiumMg)} mg',
          ),
      ],
      canEdit: f.source == FoodSource.custom,
      attribution: f.source == FoodSource.openFoodFacts
          ? 'Data from Open Food Facts (openfoodfacts.org), available under '
                'the Open Database License. Values may be incomplete.'
          : null,
    );
  }

  static String _number(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

  static String _unitLabel(QuantityUnit u, {bool plural = false}) =>
      switch (u) {
        QuantityUnit.gram => 'g',
        QuantityUnit.milliliter => 'ml',
        QuantityUnit.serving => plural ? 'servings' : 'serving',
      };

  static double _defaultAmount(FoodNutrition food, QuantityUnit unit) {
    if (unit == QuantityUnit.serving) return 1;
    if (food.servingSize != null && food.servingUnit == unit) {
      return food.servingSize!;
    }
    return 100;
  }
}
