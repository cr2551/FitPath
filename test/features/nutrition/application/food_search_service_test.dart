import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fitpath/core/database/app_database.dart';
import 'package:fitpath/core/errors/network_failure.dart';
import 'package:fitpath/features/nutrition/application/food_search_service.dart';
import 'package:fitpath/features/nutrition/data/local/food_repository.dart';
import 'package:fitpath/features/nutrition/data/remote/off_product.dart';
import 'package:fitpath/features/nutrition/data/remote/open_food_facts_client.dart';
import 'package:fitpath/features/nutrition/domain/nutrients.dart';
import 'package:fitpath/features/nutrition/domain/nutrition_math.dart';
import 'package:fitpath/shared/models/enums.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_database.dart';

/// Returns [products], or throws [error]; records every query.
class _FakeOff extends OpenFoodFactsClient {
  _FakeOff({this.products = const [], this.error}) : super(Dio());

  final List<OffProduct> products;
  final NetworkFailure? error;
  final queries = <String>[];

  @override
  Future<OffSearchPage> search(
    String query, {
    int page = 1,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) async {
    queries.add(query);
    if (error != null) throw error!;
    return OffSearchPage(
      products: products,
      page: 1,
      totalCount: products.length,
    );
  }
}

const bar = OffProduct(
  barcode: '5000112637922',
  name: 'Protein bar, chocolate',
  brand: 'FitCo',
  kcal: 350,
  proteinG: 33.3,
  servingSize: 60,
  servingDescription: '1 bar (60 g)',
);

const juice = OffProduct(
  barcode: '3017620422003',
  name: 'Orange juice',
  isLiquid: true,
  kcal: 45,
);

void main() {
  late AppDatabase db;
  late FoodRepository repo;

  setUp(() {
    db = createTestDatabase();
    repo = FoodRepository(db.foodDao);
  });
  tearDown(() => db.close());

  FoodSearchService service(_FakeOff off, {bool online = true}) =>
      FoodSearchService(local: repo, remote: off, isOnline: () async => online);

  Future<void> addLocal(String name, {String? barcode}) async {
    final details = FoodDetails(name: name, basis: ReferenceBasis.per100g);
    if (barcode == null) {
      await repo.createCustomFood(details);
    } else {
      await repo.cacheExternalFood(barcode, details);
    }
  }

  test('local results come first; online fills in when they are few', () async {
    await addLocal('Protein shake');
    final off = _FakeOff(products: [bar, juice]);

    final r = await service(off).search('protein');

    expect(r.local.map((f) => f.name), ['Protein shake']);
    expect(r.remote.map((p) => p.name), [
      'Protein bar, chocolate',
      'Orange juice',
    ]);
    expect(r.searchedRemote, isTrue);
    expect(off.queries, ['protein']);
  });

  test('enough local results: no online request', () async {
    for (var i = 0; i < 8; i++) {
      await addLocal('Apple $i');
    }
    final off = _FakeOff(products: [bar]);

    final r = await service(off).search('apple');

    expect(r.local, hasLength(8));
    expect(r.remote, isEmpty);
    expect(r.searchedRemote, isFalse);
    expect(off.queries, isEmpty);
  });

  test('short queries stay local', () async {
    final off = _FakeOff(products: [bar]);
    await service(off).search('pr');
    expect(off.queries, isEmpty);
  });

  test('offline: local results and a clear error, no request', () async {
    await addLocal('Protein shake');
    final off = _FakeOff(products: [bar]);

    final r = await service(off, online: false).search('protein');

    expect(r.local, hasLength(1));
    expect(r.remoteError, isA<NoConnection>());
    expect(off.queries, isEmpty);
  });

  test('an API failure never hides local results', () async {
    await addLocal('Protein shake');
    final off = _FakeOff(error: const ServerError(503));

    final r = await service(off).search('protein');

    expect(r.local, hasLength(1));
    expect(r.remote, isEmpty);
    expect(r.remoteError, isA<ServerError>());
  });

  test('online results already cached locally are not repeated', () async {
    await addLocal('Protein bar, chocolate', barcode: bar.barcode);
    final off = _FakeOff(products: [bar, juice]);

    final r = await service(off).search('protein bar');

    expect(r.local.single.externalId, bar.barcode);
    expect(r.remote.map((p) => p.barcode), [juice.barcode]);
  });

  test('selecting an online result caches it for offline use', () async {
    final off = _FakeOff(products: [bar]);
    final s = service(off);

    final id = await s.select(bar);
    final again = await s.select(bar);

    expect(again, id);
    final offline = await service(_FakeOff(), online: false).search('protein');
    final food = offline.local.single;
    expect(food.id, id);
    expect(food.source, FoodSource.openFoodFacts);
    expect(food.brand, 'FitCo');
  });

  test('product mapping keeps the basis and unknown values', () {
    final solid = FoodSearchService.detailsFor(bar);
    expect(solid.basis, ReferenceBasis.per100g);
    expect(solid.nutrients, const Nutrients(kcal: 350, proteinG: 33.3));
    expect(solid.servingSize, 60);
    expect(solid.servingUnit, QuantityUnit.gram);

    final liquid = FoodSearchService.detailsFor(juice);
    expect(liquid.basis, ReferenceBasis.per100ml);
    expect(liquid.servingUnit, isNull);
    expect(liquid.nutrients.fatG, isNull);
  });

  group('connectivity check problems never hide local results', () {
    test('a throwing check is ignored and the request is tried', () async {
      await addLocal('Protein shake');
      final off = _FakeOff(products: [bar]);
      final results = await FoodSearchService(
        local: repo,
        remote: off,
        isOnline: () => Future.error(StateError('no D-Bus')),
      ).search('protein');
      expect(results.local.single.name, 'Protein shake');
      expect(results.remote.single.barcode, bar.barcode);
      expect(results.remoteError, isNull);
    });

    test('a hanging check times out', () async {
      await addLocal('Protein shake');
      final results = await FoodSearchService(
        local: repo,
        remote: _FakeOff(error: const NoConnection()),
        isOnline: () => Completer<bool>().future,
        connectivityTimeout: const Duration(milliseconds: 50),
      ).search('protein');
      expect(results.local.single.name, 'Protein shake');
      expect(results.remoteError, isA<NoConnection>());
    });

    test(
      'an unexpected request error becomes a banner, not a failure',
      () async {
        await addLocal('Protein shake');
        final results = await FoodSearchService(
          local: repo,
          remote: _ThrowingOff(),
          isOnline: () async => true,
        ).search('protein');
        expect(results.local, hasLength(1));
        expect(results.remoteError, isNotNull);
      },
    );
  });

  test(
    'the stream shows local results before the online lookup ends',
    () async {
      await addLocal('Protein shake');
      final emitted = await service(_FakeOff(products: [bar]))
          .searchStream('protein')
          .toList();
      expect(emitted, hasLength(2));
      expect(emitted.first.local.single.name, 'Protein shake');
      expect(emitted.first.remotePending, isTrue);
      expect(emitted.last.remotePending, isFalse);
      expect(emitted.last.remote, hasLength(1));
    },
  );
}

class _ThrowingOff extends OpenFoodFactsClient {
  _ThrowingOff() : super(Dio());

  @override
  Future<OffSearchPage> search(
    String query, {
    int page = 1,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) async => throw const FormatException('bad JSON');
}
