import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/errors/network_failure.dart';
import '../../../shared/models/enums.dart';
import '../data/local/food_repository.dart';
import '../data/remote/off_product.dart';
import '../data/remote/open_food_facts_client.dart';
import '../domain/nutrients.dart';
import '../domain/nutrition_math.dart';
import 'diary_providers.dart';

/// Results of one search. Local results are always returned, even when the
/// online lookup fails (NFR-02).
class FoodSearchResults {
  const FoodSearchResults({
    required this.query,
    required this.local,
    this.remote = const [],
    this.remoteError,
    this.searchedRemote = false,
    this.remotePending = false,
  });

  final String query;

  /// Bundled, cached and custom foods.
  final List<FoodItem> local;

  /// Open Food Facts products not already in [local].
  final List<OffProduct> remote;

  /// Why online results are missing, if the lookup was attempted and failed.
  final NetworkFailure? remoteError;

  /// False when the online lookup was not needed (enough local results or a
  /// very short query).
  final bool searchedRemote;

  /// Local results are ready and the online lookup is still running.
  final bool remotePending;

  bool get isEmpty => local.isEmpty && remote.isEmpty;
}

/// Hybrid food search (spec section 9): search the local catalog first; when
/// local results are insufficient and the device is online, query Open Food
/// Facts. Selecting an online result caches it locally, so it can be logged
/// offline later.
class FoodSearchService {
  FoodSearchService({
    required this._local,
    required this._remote,
    Future<bool> Function()? isOnline,
    this.enoughLocalResults = 8,
    this.minRemoteQueryLength = 3,
    this.connectivityTimeout = const Duration(seconds: 2),
  }) : _isOnline = isOnline ?? _connectivityOnline;

  final FoodRepository _local;
  final OpenFoodFactsClient _remote;
  final Future<bool> Function() _isOnline;

  /// With at least this many local matches, the online lookup is skipped.
  final int enoughLocalResults;

  /// Shorter queries never go online (they match too much and waste the
  /// API's rate limit).
  final int minRemoteQueryLength;

  /// How long the connectivity check may take before it is ignored.
  final Duration connectivityTimeout;

  /// The final results of [searchStream].
  Future<FoodSearchResults> search(String query, {CancelToken? cancelToken}) =>
      searchStream(query, cancelToken: cancelToken).last;

  /// Emits the local results as soon as they are ready, then (only when an
  /// online lookup is needed) the combined results. A failing or hanging
  /// connectivity check or online request never hides local results.
  Stream<FoodSearchResults> searchStream(
    String query, {
    CancelToken? cancelToken,
  }) async* {
    final q = query.trim();
    final local = await _local.searchLocal(q);
    if (q.length < minRemoteQueryLength || local.length >= enoughLocalResults) {
      yield FoodSearchResults(query: q, local: local);
      return;
    }
    yield FoodSearchResults(query: q, local: local, remotePending: true);

    if (!await _probablyOnline()) {
      yield FoodSearchResults(
        query: q,
        local: local,
        remoteError: const NoConnection(),
        searchedRemote: true,
      );
      return;
    }

    try {
      final page = await _remote.search(q, cancelToken: cancelToken);
      final cached = {
        for (final f in local)
          if (f.externalId != null) f.externalId!,
      };
      yield FoodSearchResults(
        query: q,
        local: local,
        remote: [
          for (final p in page.products)
            if (!cached.contains(p.barcode)) p,
        ],
        searchedRemote: true,
      );
    } on Object catch (e) {
      yield FoodSearchResults(
        query: q,
        local: local,
        remoteError: e is NetworkFailure ? e : const ServerError(null),
        searchedRemote: true,
      );
    }
  }

  /// The connectivity check is only a shortcut to skip a doomed request. If
  /// it fails or takes too long, assume online and let the request (which
  /// has its own timeouts) decide.
  Future<bool> _probablyOnline() async {
    try {
      return await _isOnline().timeout(connectivityTimeout);
    } on Object {
      return true;
    }
  }

  /// Caches [product] in the local catalog and returns its local food id.
  Future<int> select(OffProduct product) =>
      _local.cacheExternalFood(product.barcode, detailsFor(product));

  /// Maps an Open Food Facts product to catalog details. OFF values are per
  /// 100 g, or per 100 ml for liquids; unknown values stay unknown.
  static FoodDetails detailsFor(OffProduct p) => FoodDetails(
    name: p.name,
    brand: p.brand,
    basis: p.isLiquid ? ReferenceBasis.per100ml : ReferenceBasis.per100g,
    nutrients: Nutrients(
      kcal: p.kcal,
      proteinG: p.proteinG,
      carbsG: p.carbsG,
      fatG: p.fatG,
      fiberG: p.fiberG,
      sugarG: p.sugarG,
      sodiumMg: p.sodiumMg,
    ),
    servingSize: p.servingSize,
    servingUnit: p.servingSize == null
        ? null
        : (p.servingIsMl ? QuantityUnit.milliliter : QuantityUnit.gram),
    servingDescription: p.servingDescription,
  );

  static Future<bool> _connectivityOnline() async {
    final result = await Connectivity().checkConnectivity();
    return result.any((r) => r != ConnectivityResult.none);
  }
}

final foodSearchServiceProvider = Provider<FoodSearchService>(
  (ref) => FoodSearchService(
    local: ref.watch(foodRepositoryProvider),
    remote: ref.watch(openFoodFactsClientProvider),
  ),
);

/// How long typing must pause before a search runs.
const foodSearchDebounce = Duration(milliseconds: 400);

/// Debounced, cancellable search for the search screen. Typing a new query
/// disposes the previous one, which cancels its pending request.
final foodSearchProvider = StreamProvider.autoDispose
    .family<FoodSearchResults, String>((ref, query) async* {
      final cancelToken = CancelToken();
      var disposed = false;
      ref.onDispose(() {
        disposed = true;
        cancelToken.cancel();
      });

      await Future<void>.delayed(foodSearchDebounce);
      if (disposed) return;

      yield* ref
          .read(foodSearchServiceProvider)
          .searchStream(query, cancelToken: cancelToken);
    });
