import 'package:dio/dio.dart';
import 'package:fitpath/core/database/app_database.dart';
import 'package:fitpath/core/database/database_provider.dart';
import 'package:fitpath/core/errors/network_failure.dart';
import 'package:fitpath/core/theme/app_theme.dart';
import 'package:fitpath/features/nutrition/application/food_search_service.dart';
import 'package:fitpath/features/nutrition/data/local/food_repository.dart';
import 'package:fitpath/features/nutrition/data/remote/off_product.dart';
import 'package:fitpath/features/nutrition/data/remote/open_food_facts_client.dart';
import 'package:fitpath/features/nutrition/domain/nutrients.dart';
import 'package:fitpath/features/nutrition/presentation/search/food_search_screen.dart';
import 'package:fitpath/shared/models/enums.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../helpers/test_database.dart';

class _FakeOff extends OpenFoodFactsClient {
  _FakeOff({this.products = const [], this.failure}) : super(Dio());

  final List<OffProduct> products;
  final NetworkFailure? failure;

  @override
  Future<OffSearchPage> search(
    String query, {
    int page = 1,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) async {
    if (failure != null) throw failure!;
    return OffSearchPage(
      products: products,
      page: 1,
      totalCount: products.length,
    );
  }
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<AppDatabase> _db(WidgetTester tester) async {
  final db = createTestDatabase();
  await tester.runAsync(() async {
    await db.customSelect('SELECT 1').get();
    await FoodRepository(db.foodDao).createCustomFood(
      const FoodDetails(
        name: 'Greek yogurt',
        brand: 'Fage',
        basis: ReferenceBasis.per100g,
        nutrients: Nutrients(kcal: 97),
      ),
    );
  });
  return db;
}

Future<void> _pump(
  WidgetTester tester,
  AppDatabase db,
  OpenFoodFactsClient off, {
  bool online = true,
}) async {
  tester.view.physicalSize = const Size(400, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: '/search',
    routes: [
      GoRoute(
        path: '/search',
        builder: (_, _) => const FoodSearchScreen(meal: MealType.lunch),
      ),
    ],
    errorBuilder: (_, state) => Scaffold(body: Text('route ${state.uri}')),
  );
  final foods = FoodRepository(db.foodDao);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        foodSearchServiceProvider.overrideWithValue(
          FoodSearchService(
            local: foods,
            remote: off,
            isOnline: () async => online,
          ),
        ),
      ],
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ),
  );
  await _settle(tester);
}

Future<void> _dispose(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
  await tester.runAsync(db.close);
}

void main() {
  testWidgets('offline: local results stay visible under a banner', (
    tester,
  ) async {
    final db = await _db(tester);
    await _pump(tester, db, _FakeOff(), online: false);
    expect(find.text('Adding to lunch'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'yog');
    await _settle(tester);

    expect(find.text('Greek yogurt'), findsOneWidget);
    expect(find.text('Fage · Custom'), findsOneWidget);
    expect(
      find.text("You're offline. Showing foods saved on this phone."),
      findsOneWidget,
    );

    await tester.tap(find.text('Greek yogurt'));
    await _settle(tester);
    expect(find.textContaining('route /nutrition/food/1?meal=lunch'), findsOne);
    await _dispose(tester, db);
  });

  testWidgets('online results come after local ones and cache on select', (
    tester,
  ) async {
    final db = await _db(tester);
    const product = OffProduct(
      barcode: '123',
      name: 'Yogurt drink',
      brand: 'Acme',
      isLiquid: true,
      kcal: 60,
    );
    await _pump(tester, db, _FakeOff(products: [product]));

    await tester.enterText(find.byType(TextField), 'yog');
    await _settle(tester);
    expect(find.text('ONLINE RESULTS (OPEN FOOD FACTS)'), findsOneWidget);
    expect(find.text('Yogurt drink'), findsOneWidget);
    expect(find.text('60 kcal / 100 ml', findRichText: true), findsOneWidget);

    await tester.tap(find.text('Yogurt drink'));
    await _settle(tester);
    final cached = await tester.runAsync(
      () => FoodRepository(db.foodDao).searchLocal('drink'),
    );
    expect(cached!.single.externalId, '123');
    expect(
      find.textContaining('route /nutrition/food/${cached.single.id}'),
      findsOne,
    );
    await _dispose(tester, db);
  });

  testWidgets('a server error shows a banner, not an error screen', (
    tester,
  ) async {
    final db = await _db(tester);
    await _pump(tester, db, _FakeOff(failure: const RequestTimeout()));
    await tester.enterText(find.byType(TextField), 'yog');
    await _settle(tester);
    expect(find.text('Greek yogurt'), findsOneWidget);
    expect(find.textContaining("Couldn't reach Open Food Facts"), findsOne);
    await _dispose(tester, db);
  });

  testWidgets('no match offers to create a custom food', (tester) async {
    final db = await _db(tester);
    await _pump(tester, db, _FakeOff(), online: false);
    await tester.enterText(find.byType(TextField), 'zzz');
    await _settle(tester);
    expect(find.text('No foods match "zzz".'), findsOneWidget);
    await tester.tap(find.text('Create custom food'));
    await _settle(tester);
    expect(find.text('route /nutrition/custom-food/new'), findsOneWidget);
    await _dispose(tester, db);
  });
}
