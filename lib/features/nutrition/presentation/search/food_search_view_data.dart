/// One search result row. Plain strings only.
class FoodResultRow {
  const FoodResultRow({
    required this.name,
    required this.detail,
    required this.kcal,
    required this.basis,
  });

  final String name;

  /// Brand and source, e.g. "Fage · Bundled".
  final String detail;

  /// Calories per [basis], "—" when unknown.
  final String kcal;

  /// E.g. "kcal / 100 g".
  final String basis;
}

sealed class FoodSearchBody {
  const FoodSearchBody();
}

/// Nothing typed yet.
class SearchIdle extends FoodSearchBody {
  const SearchIdle();
}

class SearchFailed extends FoodSearchBody {
  const SearchFailed(this.message);

  final String message;
}

class SearchResults extends FoodSearchBody {
  const SearchResults({
    required this.query,
    required this.local,
    required this.remote,
    required this.searchedRemote,
    required this.loading,
    this.banner,
  });

  final String query;
  final List<FoodResultRow> local;
  final List<FoodResultRow> remote;

  /// Whether the online catalog was consulted for [query].
  final bool searchedRemote;

  /// A newer query is running; these are the previous results.
  final bool loading;

  /// Why online results are missing (offline, timeout, ...).
  final String? banner;

  bool get isEmpty => local.isEmpty && remote.isEmpty;
}
