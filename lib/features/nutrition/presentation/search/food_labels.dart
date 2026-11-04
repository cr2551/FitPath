import '../../../../shared/models/enums.dart';

/// Display labels shared by the search and food details screens.
abstract final class FoodLabels {
  static String source(FoodSource s) => switch (s) {
    FoodSource.bundled => 'Bundled',
    FoodSource.openFoodFacts => 'Open Food Facts',
    FoodSource.custom => 'Custom',
  };

  /// "100 g", "100 ml", or the serving description ("1 bar").
  static String basis(ReferenceBasis b, {String? servingDescription}) =>
      switch (b) {
        ReferenceBasis.per100g => '100 g',
        ReferenceBasis.per100ml => '100 ml',
        ReferenceBasis.perServing => servingDescription ?? 'serving',
      };
}
