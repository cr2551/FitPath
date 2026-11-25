import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/seed/substitution_seed.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/units.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../application/diary_providers.dart';
import '../../application/recipe_providers.dart';
import '../../data/local/food_repository.dart';
import '../../data/local/recipe_repository.dart';
import '../../domain/nutrients.dart';
import '../../domain/nutrition_math.dart';
import '../../domain/substitution_math.dart';
import '../search/food_labels.dart';
import '../search/food_search_screen.dart';
import 'recipe_view.dart';
import 'recipe_view_data.dart';
import 'substitution_sheet.dart';

final _recipeProvider = FutureProvider.autoDispose.family<RecipeDetails, int>((
  ref,
  foodId,
) async {
  final recipe = await ref.watch(recipeRepositoryProvider).byFoodId(foodId);
  if (recipe == null) throw FoodNotFound(foodId);
  return recipe;
}, retry: (_, _) => null);

const _maxServings = 50;
const _maxQuantity = 100000.0;

String _number(double v) =>
    v == v.roundToDouble() ? v.round().toString() : '$v';

/// An ingredient being edited.
class _Line {
  _Line(this.key, this.food, this.quantityText, this.unit);

  final int key;
  FoodItem food;
  String quantityText;
  QuantityUnit unit;

  FoodNutrition get nutrition => FoodRepository.foodNutrition(food);
  List<QuantityUnit> get units => NutritionMath.allowedUnits(nutrition);

  double? get quantity {
    final q = Units.parseDecimal(quantityText);
    return q != null && q > 0 && q <= _maxQuantity ? q : null;
  }

  String? get error {
    final q = Units.parseDecimal(quantityText);
    if (q == null) return 'Enter an amount';
    if (q <= 0) return 'Must be more than 0';
    if (q > _maxQuantity) return 'At most ${_number(_maxQuantity)}';
    return null;
  }

  /// Nutrients of the amount, or null while the amount is invalid.
  Nutrients? get nutrients {
    final q = quantity;
    return q == null ? null : NutritionMath.scale(nutrition, q, unit);
  }
}

/// Builds a new recipe, or edits the recipe stored as food [foodId].
///
/// A recipe is a food (basis per serving), so it is found in search and
/// logged through the entry screen like any other. Editing it never changes
/// logged entries; deleting one the diary uses only hides it (see
/// `RecipeRepository`).
class RecipeScreen extends ConsumerStatefulWidget {
  const RecipeScreen({super.key, this.foodId});

  final int? foodId;

  @override
  ConsumerState<RecipeScreen> createState() => _RecipeScreenState();
}

class _RecipeScreenState extends ConsumerState<RecipeScreen> {
  bool _initialized = false;
  String _name = '';
  String _servings = '1';
  final _touched = <RecipeField>{};
  final _lines = <_Line>[];
  int _nextKey = 0;
  String? _sourceVersion;
  bool _saving = false;

  bool get _isEdit => widget.foodId != null;

  void _init(RecipeDetails? recipe) {
    _initialized = true;
    if (recipe == null) return;
    _name = recipe.food.name;
    _servings = '${recipe.recipe.servings}';
    _sourceVersion = recipe.recipe.sourceVersion;
    for (final i in recipe.ingredients) {
      final line = _Line(
        _nextKey++,
        i.food,
        _number(i.ingredient.quantity),
        i.unit,
      );
      // The food may have changed since; fall back to a unit it allows.
      if (!line.units.contains(line.unit)) line.unit = line.units.first;
      _lines.add(line);
    }
  }

  int? get _servingCount {
    final s = int.tryParse(_servings.trim());
    return s != null && s >= 1 && s <= _maxServings ? s : null;
  }

  String? get _nameError {
    final name = _name.trim();
    if (name.isEmpty) return 'Enter a name';
    if (name.length > 200) return 'At most 200 characters';
    return null;
  }

  String? get _servingsError =>
      _servingCount == null ? 'Enter a whole number from 1 to 50' : null;

  bool get _canSave =>
      _nameError == null &&
      _servingCount != null &&
      _lines.isNotEmpty &&
      _lines.every((l) => l.nutrients != null);

  void _leave() =>
      context.canPop() ? context.pop() : context.go(Routes.nutrition);

  Future<void> _addIngredient() async {
    // A plain push: the route table is frozen, and the picker only returns
    // a food id to this screen.
    final id = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => const FoodSearchScreen(pickIngredient: true),
      ),
    );
    if (id == null || !mounted) return;
    final food = await ref.read(foodRepositoryProvider).foodById(id);
    if (food == null || !mounted) return;
    final nutrition = FoodRepository.foodNutrition(food);
    final unit = NutritionMath.allowedUnits(nutrition).first;
    setState(
      () => _lines.add(
        _Line(_nextKey++, food, _number(_defaultAmount(nutrition, unit)), unit),
      ),
    );
  }

  /// Bundled substitutions whose original is [food], matched by name.
  List<BundledSubstitution> _substitutionsFor(FoodItem food) {
    final name = food.name.trim().toLowerCase();
    return [
      for (final s
          in ref.read(substitutionsProvider).value ??
              const <BundledSubstitution>[])
        if (s.fromFoodName.toLowerCase() == name) s,
    ];
  }

  Future<FoodItem?> _foodNamed(String name) async {
    final found = await ref.read(foodRepositoryProvider).searchLocal(name);
    final key = name.toLowerCase();
    return found.where((f) => f.name.trim().toLowerCase() == key).firstOrNull;
  }

  Future<void> _swap(int key) async {
    final line = _line(key);
    final servings = _servingCount;
    final original = line?.nutrients;
    if (line == null || servings == null || original == null) return;

    final options = <(SubstitutionOptionData, FoodItem, double)>[];
    for (final s in _substitutionsFor(line.food)) {
      final food = await _foodNamed(s.toFoodName);
      if (food == null) continue;
      final quantity = SubstitutionMath.scaledQuantity(line.quantity!, s.ratio);
      final scaled = NutritionMath.scale(
        FoodRepository.foodNutrition(food),
        quantity,
        line.unit,
      );
      // The substitute must be measurable in the ingredient's unit.
      if (scaled == null) continue;
      final diff = SubstitutionMath.perServingDifference(
        original,
        scaled,
        servings,
      );
      options.add((
        SubstitutionOptionData(
          name: food.name,
          amount: [
            '${_number(quantity)} ${_unitLabel(line.unit)}',
            if (s.ratio != 1) '(${_number(s.ratio)} × the amount)',
          ].join(' '),
          note: s.note,
          differences: [
            _difference(diff.kcal, 'kcal', Formatters.integer),
            _difference(diff.proteinG, 'protein', Formatters.grams),
            _difference(diff.carbsG, 'carbs', Formatters.grams),
            _difference(diff.fatG, 'fat', Formatters.grams),
          ],
        ),
        food,
        quantity,
      ));
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (options.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No substitute foods are available.')),
      );
      return;
    }
    final picked = await showSubstitutionSheet(
      context,
      ingredient: line.food.name,
      options: [for (final o in options) o.$1],
    );
    if (picked == null || !mounted) return;

    final (_, food, quantity) = options[picked];
    final before = (line.food, line.quantityText, line.unit);
    setState(() {
      line.food = food;
      line.quantityText = _number(quantity);
    });
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Swapped ${before.$1.name} for ${food.name}'),
          action: SnackBarAction(
            label: 'UNDO',
            onPressed: () {
              if (!mounted || !_lines.contains(line)) return;
              setState(() {
                line.food = before.$1;
                line.quantityText = before.$2;
                line.unit = before.$3;
              });
            },
          ),
        ),
      );
  }

  /// "+12 kcal", "−3 g protein", "fat unknown".
  static String _difference(
    double? value,
    String name,
    String Function(double) format,
  ) {
    if (value == null) return '$name unknown';
    final amount = format(value.abs());
    final sign = value > 0 ? '+' : (value < 0 ? '−' : '±');
    return '$sign$amount $name';
  }

  void _onAction(int key, IngredientAction action) {
    if (action == IngredientAction.swap) {
      _swap(key);
      return;
    }
    final i = _lines.indexWhere((l) => l.key == key);
    if (i < 0) return;
    setState(() {
      switch (action) {
        case IngredientAction.moveUp when i > 0:
          _lines.insert(i - 1, _lines.removeAt(i));
        case IngredientAction.moveDown when i < _lines.length - 1:
          _lines.insert(i + 1, _lines.removeAt(i));
        case IngredientAction.remove:
          _lines.removeAt(i);
        default:
          break;
      }
    });
  }

  _Line? _line(int key) {
    for (final l in _lines) {
      if (l.key == key) return l;
    }
    return null;
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    final input = RecipeInput(
      name: _name.trim(),
      servings: _servingCount!,
      sourceVersion: _sourceVersion,
      ingredients: [
        for (final l in _lines)
          IngredientInput(
            foodId: l.food.id,
            quantity: l.quantity!,
            unit: l.unit,
          ),
      ],
    );
    final recipes = ref.read(recipeRepositoryProvider);
    try {
      if (_isEdit) {
        await recipes.update(widget.foodId!, input);
      } else {
        await recipes.create(input);
      }
      if (mounted) _leave();
    } on Object {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't save the recipe.")),
      );
    }
  }

  Future<void> _delete() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete recipe?',
      message:
          'It will no longer appear in search. Entries you already logged '
          'are kept.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await ref.read(recipeRepositoryProvider).delete(widget.foodId!);
    if (mounted) _leave();
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild once the bundled substitutions have loaded.
    ref.watch(substitutionsProvider);
    final RecipeBody body;
    if (!_isEdit) {
      if (!_initialized) _init(null);
      body = _form();
    } else if (_initialized) {
      body = _form();
    } else {
      final recipe = ref.watch(_recipeProvider(widget.foodId!));
      if (recipe.hasValue) {
        _init(recipe.requireValue);
        body = _form();
      } else if (recipe.hasError) {
        body = const RecipeError('This recipe does not exist any more.');
      } else {
        body = const RecipeLoading();
      }
    }

    return RecipeView(
      body: body,
      onChanged: (field, text) => setState(() {
        switch (field) {
          case RecipeField.name:
            _name = text;
          case RecipeField.servings:
            _servings = text;
        }
        _touched.add(field);
      }),
      onAddIngredient: _addIngredient,
      onQuantityChanged: (key, text) =>
          setState(() => _line(key)?.quantityText = text),
      onUnitSelected: (key, i) => setState(() {
        final l = _line(key);
        if (l != null) l.unit = l.units[i];
      }),
      onIngredientAction: _onAction,
      onSave: _save,
      onDelete: _delete,
      onRetry: () => ref.invalidate(_recipeProvider(widget.foodId!)),
    );
  }

  RecipeFormData _form() {
    final servings = _servingCount;
    final amounts = [for (final l in _lines) ?l.nutrients];
    final perServing = amounts.isEmpty || servings == null
        ? null
        : RecipeRepository.perServing(amounts, servings);

    String? missing(String nutrient, double? Function(Nutrients) f) {
      final count = amounts.where((n) => f(n) == null).length;
      if (count == 0) return null;
      return count == 1
          ? '1 ingredient has no $nutrient data'
          : '$count ingredients have no $nutrient data';
    }

    return RecipeFormData(
      isEdit: _isEdit,
      initialName: _name,
      initialServings: _servings,
      // Only nag about a field once the user has typed in it.
      nameError: _touched.contains(RecipeField.name) ? _nameError : null,
      servingsError: _touched.contains(RecipeField.servings)
          ? _servingsError
          : null,
      ingredients: [
        for (final (i, l) in _lines.indexed)
          IngredientRowData(
            key: l.key,
            name: l.food.name,
            detail: [
              ?l.food.brand,
              FoodLabels.source(l.food.source),
            ].join(' · '),
            initialQuantity: l.quantityText,
            quantityError: l.error,
            unitLabels: [for (final u in l.units) _unitLabel(u)],
            selectedUnit: l.units.indexOf(l.unit).clamp(0, l.units.length - 1),
            kcal: switch (l.nutrients?.kcal) {
              final kcal? => Formatters.energy(kcal),
              null => '${Formatters.unknownValue} kcal',
            },
            canMoveUp: i > 0,
            canMoveDown: i < _lines.length - 1,
            canSwap:
                servings != null &&
                l.nutrients != null &&
                _substitutionsFor(l.food).isNotEmpty,
          ),
      ],
      perServing: perServing == null
          ? const []
          : [
              RecipeNutrientLine(
                label: 'Calories',
                value: Formatters.energy(perServing.kcal),
              ),
              RecipeNutrientLine(
                label: 'Protein',
                value: Formatters.grams(perServing.proteinG),
              ),
              RecipeNutrientLine(
                label: 'Carbs',
                value: Formatters.grams(perServing.carbsG),
              ),
              RecipeNutrientLine(
                label: 'Fat',
                value: Formatters.grams(perServing.fatG),
              ),
            ],
      notes: perServing == null
          ? const []
          : [
              ?missing('calorie', (n) => n.kcal),
              ?missing('protein', (n) => n.proteinG),
              ?missing('carbs', (n) => n.carbsG),
              ?missing('fat', (n) => n.fatG),
            ],
      canSave: _canSave,
      saving: _saving,
    );
  }

  static String _unitLabel(QuantityUnit u) => switch (u) {
    QuantityUnit.gram => 'g',
    QuantityUnit.milliliter => 'ml',
    QuantityUnit.serving => 'serving',
  };

  static double _defaultAmount(FoodNutrition food, QuantityUnit unit) {
    if (unit == QuantityUnit.serving) return 1;
    if (food.servingSize != null && food.servingUnit == unit) {
      return food.servingSize!;
    }
    return 100;
  }
}
