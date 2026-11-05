import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/utils/dates.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/units.dart';
import '../../../../shared/models/enums.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../application/diary_providers.dart';
import '../../data/local/food_repository.dart';
import '../../domain/nutrients.dart';
import '../../domain/nutrition_math.dart';
import 'entry_view.dart';
import 'entry_view_data.dart';

/// The food being logged and, when editing, the entry.
typedef _Source = ({FoodItem food, FoodEntry? entry});

final _sourceProvider = FutureProvider.autoDispose
    .family<_Source, ({int? entryId, int? foodId})>((ref, ids) async {
      final foods = ref.watch(foodRepositoryProvider);
      final entry = ids.entryId == null
          ? null
          : await foods.entryById(ids.entryId!);
      if (ids.entryId != null && entry == null) {
        throw StateError('Entry ${ids.entryId} not found');
      }
      final foodId = entry?.foodItemId ?? ids.foodId;
      final food = foodId == null ? null : await foods.foodById(foodId);
      if (food == null) throw FoodNotFound(foodId ?? -1);
      return (food: food, entry: entry);
    });

/// Largest amount accepted per unit (a sanity limit, not a nutrition rule).
const _maxAmount = {
  QuantityUnit.gram: 5000.0,
  QuantityUnit.milliliter: 5000.0,
  QuantityUnit.serving: 50.0,
};

/// Creates a diary entry (`foodId` + optional `meal`/`date`) or edits one
/// (`entryId`).
///
/// **Snapshot rule:** when editing, the entry's nutrients are recomputed from
/// the food's CURRENT catalog values only if the amount (quantity or unit)
/// changes. Changing only the meal, date or time keeps the stored snapshot.
class EntryScreen extends ConsumerStatefulWidget {
  const EntryScreen({
    super.key,
    this.entryId,
    this.foodId,
    this.meal,
    this.date,
    this.quantity,
    this.unit,
  });

  final int? entryId;
  final int? foodId;
  final MealType? meal;
  final DateTime? date;

  /// Prefilled amount for a new entry, used when [unit] ('g', 'ml' or
  /// 'serving') is valid for the food; otherwise the default amount applies.
  final double? quantity;
  final String? unit;

  @override
  ConsumerState<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends ConsumerState<EntryScreen> {
  bool _initialized = false;
  late String _quantityText;

  /// The unrounded amount after a unit switch, so switching back and forth
  /// never drifts. Null once the user types (the text is then the amount).
  double? _convertedQuantity;
  late QuantityUnit _unit;
  late MealType _meal;
  late DateTime _day;
  late TimeOfDay _time;
  bool _saving = false;

  bool get _isEdit => widget.entryId != null;

  void _init(_Source source) {
    _initialized = true;
    final entry = source.entry;
    if (entry != null) {
      _unit = FoodRepository.unitFromCode(entry.quantityUnit);
      _quantityText = _amount(entry.quantity, _unit);
      _convertedQuantity = entry.quantity;
      _meal = entry.mealType;
      final at = entry.consumedAt.toLocal();
      _day = Dates.startOfDay(at);
      _time = TimeOfDay.fromDateTime(at);
      return;
    }
    final now = DateTime.now();
    final food = FoodRepository.foodNutrition(source.food);
    final allowed = NutritionMath.allowedUnits(food);
    final requested = _unitFromCode(widget.unit);
    final q = widget.quantity;
    if (requested != null &&
        allowed.contains(requested) &&
        q != null &&
        q > 0) {
      _unit = requested;
      _quantityText = _amount(q, _unit);
      _convertedQuantity = q;
    } else {
      _unit = allowed.first;
      _quantityText = _amount(_defaultAmount(food, _unit), _unit);
    }
    _meal = widget.meal ?? _mealFor(now);
    _day = Dates.startOfDay(widget.date ?? now);
    _time = TimeOfDay.fromDateTime(now);
  }

  double? get _quantity =>
      _convertedQuantity ?? Units.parseDecimal(_quantityText);

  void _onQuantityChanged(String text) => setState(() {
    _quantityText = text;
    _convertedQuantity = null;
  });

  /// Switches the unit and converts the amount, e.g. 2.3 servings of a 46 g
  /// egg becomes 105.8 g.
  void _onUnitSelected(FoodItem food, QuantityUnit unit) => setState(() {
    final q = _quantityError == null ? _quantity : null;
    final converted = q == null
        ? null
        : NutritionMath.convert(
            FoodRepository.foodNutrition(food),
            q,
            _unit,
            unit,
          );
    _unit = unit;
    if (converted != null) {
      _quantityText = _amount(converted, unit);
      _convertedQuantity = converted;
    }
  });

  String? get _quantityError {
    final q = _quantity;
    if (_quantityText.trim().isEmpty) return 'Enter an amount';
    if (q == null || Units.parseDecimal(_quantityText) == null) {
      return 'Enter a number';
    }
    if (q <= 0) return 'Must be more than 0';
    final max = _maxAmount[_unit]!;
    if (q > max) return 'At most ${_amount(max, _unit)} ${_unitLabel(_unit)}';
    return null;
  }

  DateTime get _consumedAt =>
      DateTime(_day.year, _day.month, _day.day, _time.hour, _time.minute);

  Future<void> _save(_Source source) async {
    final q = _quantity;
    if (q == null || _quantityError != null) return;
    setState(() => _saving = true);
    final foods = ref.read(foodRepositoryProvider);
    try {
      if (_isEdit) {
        await foods.updateEntry(
          widget.entryId!,
          quantity: q,
          unit: _unit,
          meal: _meal,
          consumedAt: _consumedAt,
        );
      } else {
        await foods.logFood(
          foodId: source.food.id,
          quantity: q,
          unit: _unit,
          meal: _meal,
          consumedAt: _consumedAt,
        );
      }
      if (mounted) context.go(Routes.nutritionDay(_day));
    } on Object {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Couldn't save the entry.")));
    }
  }

  Future<void> _delete() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete entry?',
      message: 'This removes it from your diary.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await ref.read(foodRepositoryProvider).deleteEntry(widget.entryId!);
    if (mounted) context.go(Routes.nutritionDay(_day));
  }

  Future<void> _pickDate() async {
    final today = Dates.startOfDay(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _day.isAfter(today) ? today : _day,
      firstDate: DateTime(2000),
      lastDate: today,
    );
    if (picked != null) setState(() => _day = Dates.startOfDay(picked));
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  @override
  Widget build(BuildContext context) {
    final ids = (entryId: widget.entryId, foodId: widget.foodId);
    final source = ref.watch(_sourceProvider(ids));

    final EntryBody body;
    List<QuantityUnit> units = const [];
    if (source.hasValue) {
      final value = source.requireValue;
      if (!_initialized) _init(value);
      units = NutritionMath.allowedUnits(
        FoodRepository.foodNutrition(value.food),
      );
      body = _form(value, units);
    } else if (source.hasError) {
      body = EntryError(
        _isEdit
            ? "This entry doesn't exist any more."
            : "This food doesn't exist any more.",
      );
    } else {
      body = const EntryLoading();
    }

    return EntryView(
      title: _isEdit ? 'Edit entry' : 'Log food',
      body: body,
      onQuantityChanged: _onQuantityChanged,
      onUnitSelected: (i) =>
          _onUnitSelected(source.requireValue.food, units[i]),
      onMealSelected: (meal) => setState(() => _meal = meal),
      onPickDate: _pickDate,
      onPickTime: _pickTime,
      onSave: () => _save(source.requireValue),
      onDelete: _delete,
      onRetry: () => ref.invalidate(_sourceProvider(ids)),
    );
  }

  EntryFormData _form(_Source source, List<QuantityUnit> units) {
    final food = source.food;
    final entry = source.entry;
    final q = _quantityError == null ? _quantity : null;

    // Unchanged amount on an existing entry: show its stored snapshot.
    final unchanged =
        entry != null &&
        q == entry.quantity &&
        FoodRepository.unitCode(_unit) == entry.quantityUnit;
    final Nutrients? n = q == null
        ? null
        : unchanged
        ? FoodRepository.entryNutrients(entry)
        : NutritionMath.scale(FoodRepository.foodNutrition(food), q, _unit);

    return EntryFormData(
      isEdit: entry != null,
      foodName: entry?.nameSnapshot ?? food.name,
      foodDetail: [
        ?(entry?.brandSnapshot ?? food.brand),
        '${Formatters.energy(food.kcal)} per ${_basisLabel(food)}',
      ].join(' · '),
      quantity: _quantityText,
      quantityError: _quantityError,
      unitLabels: [for (final u in units) _unitLabel(u)],
      selectedUnit: units.indexOf(_unit).clamp(0, units.length - 1),
      meal: _meal,
      dateLabel: Dates.isSameDay(_day, DateTime.now())
          ? 'Today'
          : DateFormat('EEE d MMM y').format(_day),
      timeLabel: _time.format(context),
      kcal: Formatters.integer(n?.kcal),
      proteinG: _grams(n?.proteinG),
      carbsG: _grams(n?.carbsG),
      fatG: _grams(n?.fatG),
      canSave: n != null,
      saving: _saving,
    );
  }

  static String _grams(double? g) =>
      g == null ? Formatters.unknownValue : _number(g);

  static String _number(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

  /// Servings get two decimals (1.25), grams and millilitres one.
  static String _amount(double v, QuantityUnit unit) {
    final text = v.toStringAsFixed(unit == QuantityUnit.serving ? 2 : 1);
    return text.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  static QuantityUnit? _unitFromCode(String? code) => switch (code) {
    'g' => QuantityUnit.gram,
    'ml' => QuantityUnit.milliliter,
    'serving' => QuantityUnit.serving,
    _ => null,
  };

  static String _unitLabel(QuantityUnit u) => switch (u) {
    QuantityUnit.gram => 'g',
    QuantityUnit.milliliter => 'ml',
    QuantityUnit.serving => 'serving',
  };

  static String _basisLabel(FoodItem f) => switch (f.referenceBasis) {
    ReferenceBasis.per100g => '100 g',
    ReferenceBasis.per100ml => '100 ml',
    ReferenceBasis.perServing => f.servingDescription ?? 'serving',
  };

  static double _defaultAmount(FoodNutrition food, QuantityUnit unit) {
    if (unit == QuantityUnit.serving) return 1;
    if (food.servingSize != null && food.servingUnit == unit) {
      return food.servingSize!;
    }
    return 100;
  }

  /// A reasonable default meal for the time of day.
  static MealType _mealFor(DateTime t) {
    final minutes = t.hour * 60 + t.minute;
    if (minutes >= 5 * 60 && minutes < 10 * 60 + 30) return MealType.breakfast;
    if (minutes >= 11 * 60 && minutes < 15 * 60) return MealType.lunch;
    if (minutes >= 17 * 60 && minutes < 21 * 60 + 30) return MealType.dinner;
    return MealType.snack;
  }
}
