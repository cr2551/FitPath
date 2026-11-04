import 'package:fitpath/core/database/app_database.dart';
import 'package:fitpath/core/database/database_provider.dart';
import 'package:fitpath/core/theme/app_theme.dart';
import 'package:fitpath/features/nutrition/data/local/food_repository.dart';
import 'package:fitpath/features/nutrition/domain/nutrients.dart';
import 'package:fitpath/features/nutrition/domain/nutrition_math.dart';
import 'package:fitpath/features/profile/data/profile_repository.dart';
import 'package:fitpath/features/settings/presentation/profile_edit_screen.dart';
import 'package:fitpath/features/settings/presentation/settings_screen.dart';
import 'package:fitpath/shared/models/enums.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/test_database.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 300));
  }
}

/// A database with a profile, a weight and one diary entry.
Future<AppDatabase> _db(WidgetTester tester) async {
  final db = createTestDatabase();
  await tester.runAsync(() async {
    final profile = ProfileRepository(db.profileDao);
    await profile.saveProfile(
      ageYears: 27,
      heightCm: 178,
      sex: Sex.male,
      activityLevel: ActivityLevel.moderate,
    );
    await profile.logWeight(74.2);
    final foods = FoodRepository(db.foodDao);
    final id = await foods.createCustomFood(
      const FoodDetails(
        name: 'Oats',
        basis: ReferenceBasis.per100g,
        nutrients: Nutrients(kcal: 380),
      ),
    );
    await foods.logFood(
      foodId: id,
      quantity: 50,
      unit: QuantityUnit.gram,
      meal: MealType.breakfast,
    );
  });
  return db;
}

Future<void> _pump(WidgetTester tester, AppDatabase db, Widget screen) async {
  tester.view.physicalSize = const Size(400, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: '/s',
    routes: [GoRoute(path: '/s', builder: (_, _) => screen)],
    errorBuilder: (_, state) => Scaffold(body: Text('route ${state.uri}')),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
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

Future<UserProfileRow?> _profile(WidgetTester tester, AppDatabase db) =>
    tester.runAsync<UserProfileRow?>(() => db.profileDao.getProfile());

void main() {
  testWidgets('units switch the display only; stored values stay metric', (
    tester,
  ) async {
    final db = await _db(tester);
    await _pump(tester, db, const SettingsScreen());

    expect(find.text('178 cm', findRichText: true), findsOneWidget);
    expect(find.text('74.2 kg', findRichText: true), findsOneWidget);
    expect(find.text('Moderate', findRichText: true), findsOneWidget);

    await tester.tap(find.text('Imperial'));
    await _settle(tester);
    expect(find.text('5′ 10″', findRichText: true), findsOneWidget);
    expect(find.text('163.6 lb', findRichText: true), findsOneWidget);

    expect((await _profile(tester, db))!.heightCm, 178);
    final kg = await tester.runAsync(
      () => ProfileRepository(db.profileDao).watchCurrentWeightKg().first,
    );
    expect(kg, 74.2);
    await _dispose(tester, db);
  });

  testWidgets('theme mode is persisted', (tester) async {
    final db = await _db(tester);
    await _pump(tester, db, const SettingsScreen());
    await tester.tap(find.text('Dark'));
    await _settle(tester);
    final mode = await tester.runAsync(
      () => ProfileRepository(db.profileDao).watchThemeMode().first,
    );
    expect(mode, 'dark');
    await _dispose(tester, db);
  });

  testWidgets('entry points open their screens', (tester) async {
    final db = await _db(tester);
    await _pump(tester, db, const SettingsScreen());
    await tester.tap(find.text('Reset all data'));
    await _settle(tester);
    expect(find.text('route /profile/reset'), findsOneWidget);
    await _dispose(tester, db);
  });

  testWidgets('editing details saves the profile and keeps history', (
    tester,
  ) async {
    final db = await _db(tester);
    await _pump(tester, db, const ProfileEditScreen());

    final age = find.widgetWithText(TextField, 'Age');
    await tester.enterText(age, '5');
    await tester.pump();
    expect(find.textContaining('between 13 and 100'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'SAVE'))
          .onPressed,
      isNull,
    );

    await tester.enterText(age, '28');
    await tester.tap(find.text('Not given'));
    await tester.pump();
    await tester.tap(find.text('SAVE'));
    await _settle(tester);

    final p = (await _profile(tester, db))!;
    expect(p.ageYears, 28);
    expect(p.sex, Sex.unspecified);
    expect(p.heightCm, 178);
    expect(p.activityLevel, ActivityLevel.moderate);
    final entries = await tester.runAsync(
      () => db.select(db.foodEntries).get(),
    );
    expect(entries, hasLength(1));
    await _dispose(tester, db);
  });

  testWidgets('imperial height is entered in inches and stored in cm', (
    tester,
  ) async {
    final db = await _db(tester);
    await tester.runAsync(
      () => ProfileRepository(db.profileDao).setUnitSystem(UnitSystem.imperial),
    );
    await _pump(tester, db, const ProfileEditScreen());
    await tester.enterText(find.widgetWithText(TextField, 'Height'), '70');
    await tester.pump();
    await tester.tap(find.text('SAVE'));
    await _settle(tester);
    expect((await _profile(tester, db))!.heightCm, closeTo(177.8, 0.001));
    await _dispose(tester, db);
  });
}
