import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/utils/units.dart';
import '../../../../shared/models/enums.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../application/diary_providers.dart';
import '../../data/local/food_repository.dart';
import '../../domain/nutrients.dart';
import '../../domain/nutrition_math.dart';
import 'custom_food_view.dart';
import 'custom_food_view_data.dart';

final _foodProvider = FutureProvider.autoDispose.family<FoodItem, int>((
  ref,
  id,
) async {
  final food = await ref.watch(foodRepositoryProvider).foodById(id);
  if (food == null || food.source != FoodSource.custom) {
    throw FoodNotFound(id);
  }
  return food;
});

typedef _F = CustomFoodField;

const _numberFields = [
  _F.servingSize,
  _F.kcal,
  _F.protein,
  _F.carbs,
  _F.fat,
  _F.fiber,
  _F.sugar,
  _F.sodium,
];

/// Upper sanity limits per field (in the field's unit).
const _max = {_F.servingSize: 5000.0, _F.sodium: 100000.0};
const _defaultMax = 10000.0;

/// Creates a custom food, or edits one (`foodId`).
///
/// Editing never changes past diary entries: they keep the nutrient snapshot
/// taken when they were logged. Deleting a food that the diary uses only
/// hides it from search (see `FoodRepository.removeFood`).
class CustomFoodScreen extends ConsumerStatefulWidget {
  const CustomFoodScreen({super.key, this.foodId});

  final int? foodId;

  @override
  ConsumerState<CustomFoodScreen> createState() => _CustomFoodScreenState();
}

class _CustomFoodScreenState extends ConsumerState<CustomFoodScreen> {
  bool _initialized = false;
  final _text = <CustomFoodField, String>{};
  final _touched = <CustomFoodField>{};
  BasisChoice _basis = BasisChoice.per100g;
  ServingUnitChoice _servingUnit = ServingUnitChoice.gram;
  bool _saving = false;

  bool get _isEdit => widget.foodId != null;

  void _init(FoodItem? food) {
    _initialized = true;
    if (food == null) return;
    String n(double? v) => v == null ? '' : _number(v);
    _text.addAll({
      _F.name: food.name,
      _F.brand: food.brand ?? '',
      _F.servingSize: n(food.servingSize),
      _F.servingDescription: food.servingDescription ?? '',
      _F.kcal: n(food.kcal),
      _F.protein: n(food.proteinG),
      _F.carbs: n(food.carbsG),
      _F.fat: n(food.fatG),
      _F.fiber: n(food.fiberG),
      _F.sugar: n(food.sugarG),
      _F.sodium: n(food.sodiumMg),
    });
    _basis = switch (food.referenceBasis) {
      ReferenceBasis.per100g => BasisChoice.per100g,
      ReferenceBasis.per100ml => BasisChoice.per100ml,
      ReferenceBasis.perServing => BasisChoice.perServing,
    };
    _servingUnit = food.servingUnit == 'ml'
        ? ServingUnitChoice.milliliter
        : ServingUnitChoice.gram;
  }

  String _t(CustomFoodField f) => (_text[f] ?? '').trim();

  double? _value(CustomFoodField f) => Units.parseDecimal(_t(f));

  Map<CustomFoodField, String> get _errors {
    final errors = <CustomFoodField, String>{};
    if (_t(_F.name).isEmpty) errors[_F.name] = 'Enter a name';
    if (_t(_F.name).length > 200) errors[_F.name] = 'At most 200 characters';
    for (final f in _numberFields) {
      if (_t(f).isEmpty) continue;
      final v = _value(f);
      final max = _max[f] ?? _defaultMax;
      if (v == null) {
        errors[f] = _t(f).startsWith('-')
            ? 'Must not be negative'
            : 'Enter a number';
      } else if (v > max) {
        errors[f] = 'At most ${_number(max)}';
      } else if (f == _F.servingSize && v == 0) {
        errors[f] = 'Must be more than 0';
      }
    }
    if (_basis == BasisChoice.perServing &&
        _t(_F.servingSize).isEmpty &&
        _t(_F.servingDescription).isEmpty) {
      errors[_F.servingDescription] = 'Describe one serving or give its size';
    }
    return errors;
  }

  FoodDetails _details() {
    double? v(CustomFoodField f) => _t(f).isEmpty ? null : _value(f);
    final size = v(_F.servingSize);
    return FoodDetails(
      name: _t(_F.name),
      brand: _t(_F.brand),
      basis: switch (_basis) {
        BasisChoice.per100g => ReferenceBasis.per100g,
        BasisChoice.per100ml => ReferenceBasis.per100ml,
        BasisChoice.perServing => ReferenceBasis.perServing,
      },
      servingSize: size,
      servingUnit: size == null
          ? null
          : _servingUnit == ServingUnitChoice.gram
          ? QuantityUnit.gram
          : QuantityUnit.milliliter,
      servingDescription: _t(_F.servingDescription).isEmpty
          ? null
          : _t(_F.servingDescription),
      nutrients: Nutrients(
        kcal: v(_F.kcal),
        proteinG: v(_F.protein),
        carbsG: v(_F.carbs),
        fatG: v(_F.fat),
        fiberG: v(_F.fiber),
        sugarG: v(_F.sugar),
        sodiumMg: v(_F.sodium),
      ),
    );
  }

  void _leave() =>
      context.canPop() ? context.pop() : context.go(Routes.nutrition);

  Future<void> _save() async {
    if (_errors.isNotEmpty) return;
    setState(() => _saving = true);
    final foods = ref.read(foodRepositoryProvider);
    try {
      if (_isEdit) {
        await foods.updateFood(widget.foodId!, _details());
      } else {
        await foods.createCustomFood(_details());
      }
      if (mounted) _leave();
    } on Object {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Couldn't save the food.")));
    }
  }

  Future<void> _delete() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete food?',
      message:
          'It will no longer appear in search. Entries you already logged '
          'are kept.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await ref.read(foodRepositoryProvider).removeFood(widget.foodId!);
    if (mounted) _leave();
  }

  @override
  Widget build(BuildContext context) {
    final CustomFoodBody body;
    if (!_isEdit) {
      if (!_initialized) _init(null);
      body = _form();
    } else {
      final food = ref.watch(_foodProvider(widget.foodId!));
      if (food.hasValue) {
        if (!_initialized) _init(food.requireValue);
        body = _form();
      } else if (food.hasError) {
        body = const CustomFoodError(
          'This custom food does not exist any more.',
        );
      } else {
        body = const CustomFoodLoading();
      }
    }

    return CustomFoodView(
      body: body,
      onChanged: (field, text) => setState(() {
        _text[field] = text;
        _touched.add(field);
      }),
      onBasisSelected: (b) => setState(() => _basis = b),
      onServingUnitSelected: (u) => setState(() => _servingUnit = u),
      onSave: _save,
      onDelete: _delete,
      onRetry: () => ref.invalidate(_foodProvider(widget.foodId!)),
    );
  }

  CustomFoodFormData _form() {
    final errors = _errors;
    return CustomFoodFormData(
      isEdit: _isEdit,
      initialText: Map.of(_text),
      // Only nag about a field once the user has typed in it.
      errors: {
        for (final MapEntry(:key, :value) in errors.entries)
          if (_touched.contains(key) || key == _F.servingDescription)
            key: value,
      },
      basis: _basis,
      servingUnit: _servingUnit,
      canSave: errors.isEmpty,
      saving: _saving,
    );
  }

  static String _number(double v) =>
      v == v.roundToDouble() ? v.round().toString() : '$v';
}
