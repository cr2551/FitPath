import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fitpath/app.dart';
import 'package:fitpath/core/database/app_database.dart';
import 'package:fitpath/core/database/database_provider.dart';
import 'package:fitpath/core/errors/network_failure.dart';
import 'package:fitpath/features/nutrition/data/remote/off_product.dart';
import 'package:fitpath/features/nutrition/data/remote/open_food_facts_client.dart';
import 'package:fitpath/features/settings/backup/backup_validator.dart';
import 'package:fitpath/features/settings/backup/export_service.dart';
import 'package:fitpath/features/settings/backup/import_service.dart';
import 'package:fitpath/shared/models/enums.dart';
import 'package:fitpath/shared/widgets/screen_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// End-to-end tests for the MVP acceptance criteria (spec section 13). Each
// test drives the real app (router, screens, repositories) on a real SQLite
// file, with Open Food Facts offline. They need a device, an emulator or the
// desktop, so CI's `flutter test` doesn't run them:
//
//   flutter test integration_test -d <device id>

/// Open Food Facts with no network: every request fails.
class _OfflineClient extends OpenFoodFactsClient {
  _OfflineClient() : super(Dio());

  @override
  Future<OffSearchPage> search(
    String query, {
    int page = 1,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) => Future.error(const NoConnection());

  @override
  Future<OffProduct?> productByBarcode(
    String barcode, {
    CancelToken? cancelToken,
  }) => Future.error(const NoConnection());
}

/// A database file that survives app restarts within one test.
class _Device {
  _Device()
    : file = File(
        '${Directory.systemTemp.createTempSync('fitpath_it').path}'
        '${Platform.pathSeparator}fitpath.db',
      );

  final File file;
  AppDatabase? db;

  Future<void> close() async {
    await db?.close();
    db = null;
  }
}

/// Starts the app on [device]'s database, as on a cold launch.
Future<void> _launch(WidgetTester tester, _Device device) async {
  await tester.pumpWidget(const SizedBox());
  await _settle(tester);
  await device.close();
  final db = device.db = AppDatabase(NativeDatabase(device.file));
  // Unmount the app before the database closes in tearDown.
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await _settle(tester);
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        openFoodFactsClientProvider.overrideWithValue(_OfflineClient()),
      ],
      child: const FitPathApp(),
    ),
  );
  await _settle(tester);
}

/// Lets real time pass for database work and animations. Not
/// pumpAndSettle: the active workout's timer never settles.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Finder _field(String label) => find.widgetWithText(TextField, label);
Finder _header(String title) =>
    find.byWidgetPredicate((w) => w is ScreenHeader && w.title == title);
Finder _title(String title) => find.byWidgetPredicate(
  (w) =>
      (w is AppBar && w.title is Text && (w.title! as Text).data == title) ||
      (w is ScreenHeader && w.title == title),
);

/// Taps the last widget [f] matches (e.g. the open menu's item rather than
/// the field behind it), scrolling the screen's list to it first if needed.
Future<void> _tap(WidgetTester tester, Finder f, [String? what]) async {
  // The screen's main list: the last vertical one that can scroll (the top
  // route is last in the tree).
  final lists = [
    for (final e in find.byType(Scrollable).evaluate())
      if (e is StatefulElement &&
          e.state is ScrollableState &&
          (e.state as ScrollableState).position.axis == Axis.vertical &&
          (e.state as ScrollableState).position.maxScrollExtent > 0)
        e.widget,
  ];
  if (f.evaluate().isEmpty && lists.isNotEmpty) {
    await tester.scrollUntilVisible(
      f,
      200,
      scrollable: find.byWidget(lists.last),
      maxScrolls: 30,
    );
  }
  if (f.evaluate().isEmpty) {
    final texts = [
      for (final e in find.byType(Text).evaluate()) (e.widget as Text).data,
    ].whereType<String>();
    final message = 'Not found: ${what ?? f}\nOn screen: ${texts.join(' | ')}';
    debugPrint(message);
    fail(message);
  }
  await tester.ensureVisible(f.last);
  await _settle(tester);
  await tester.tap(f.last);
  await _settle(tester);
}

Future<void> _tapText(WidgetTester tester, String text) =>
    _tap(tester, find.text(text), text);

Future<void> _enter(WidgetTester tester, Finder field, String text) async {
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
  await _settle(tester);
}

Future<void> _tab(WidgetTester tester, String label) => _tap(
  tester,
  find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
);

/// Onboarding in metric units: 30-year-old man, 180 cm, 90 kg, moderate
/// activity, losing weight, with the suggested targets.
Future<void> _onboard(WidgetTester tester) async {
  await _tapText(tester, 'GET STARTED');
  await _tapText(tester, 'METRIC (KG, CM)');
  await _enter(tester, _field('Age'), '30');
  await _enter(tester, _field('Height'), '180');
  await _enter(tester, _field('Current weight'), '90');
  await _tapText(tester, 'Activity level');
  await _tapText(tester, 'Moderate (3-5 days a week)');
  await _tapText(tester, 'MALE');
  await _tapText(tester, 'NEXT');

  await _tap(tester, find.text('Lose weight').first); // the main goal
  await _tapText(tester, 'NEXT');
  await _tapText(tester, 'NEXT'); // goal details: no target weight
  await _tapText(tester, 'FINISH SETUP');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late _Device device;
  setUp(() => device = _Device());
  tearDown(() async {
    await device.close();
    device.file.parent.deleteSync(recursive: true);
  });

  testWidgets('first launch: onboarding, then Home; profile and dashboard '
      'survive a restart', (tester) async {
    await _launch(tester, device);
    expect(find.text('GET STARTED'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await _onboard(tester);
    expect(_header('Today'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    // The "lose weight" preset.
    expect(
      [for (final c in await device.db!.dashboardDao.layout()) c.cardType],
      [
        DashboardCardType.caloriesMacros,
        DashboardCardType.weightTrend,
        DashboardCardType.nutritionSummary,
        DashboardCardType.workoutSummary,
      ],
    );

    // Hide the weight card.
    await _tap(tester, find.byTooltip('Edit dashboard'));
    await _tap(tester, find.byTooltip('Hide Weight'));
    await _tap(tester, find.byTooltip('Done editing'));
    final before = await device.db!.dashboardDao.layout();

    await _launch(tester, device);
    expect(_header('Today'), findsOneWidget); // no onboarding again
    final after = await device.db!.dashboardDao.layout();
    expect(
      [for (final c in after) (c.cardType, c.position, c.isVisible)],
      [for (final c in before) (c.cardType, c.position, c.isVisible)],
    );
    expect(
      after
          .firstWhere((c) => c.cardType == DashboardCardType.weightTrend)
          .isVisible,
      isFalse,
    );

    await _tab(tester, 'Profile');
    expect(find.textContaining('180'), findsWidgets);
    expect(find.textContaining('90'), findsWidgets);
  });

  testWidgets('offline food logging from the local catalog', (tester) async {
    await _launch(tester, device);
    await _onboard(tester);

    await _tab(tester, 'Nutrition');
    await _tap(tester, find.byTooltip('Add to Breakfast'));
    await _enter(tester, find.byType(TextField).first, 'banana');
    // The remote search fails without blocking local results.
    expect(find.text('Banana, raw'), findsWidgets);
    await _tapText(tester, 'Banana, raw');
    await _tapText(tester, 'ADD TO DIARY');
    await _tapText(tester, 'LOG FOOD');

    expect(find.byTooltip('Add to Breakfast'), findsOneWidget); // the day
    expect(find.text('Banana, raw'), findsOneWidget);
    final entries = await device.db!.select(device.db!.foodEntries).get();
    expect(entries.single.mealType, MealType.breakfast);
    expect(entries.single.kcal, greaterThan(0));
  });

  testWidgets('log a workout with two exercises and several sets, finish '
      'it and review it', (tester) async {
    await _launch(tester, device);
    await _onboard(tester);

    await _tab(tester, 'Workouts');
    await _tapText(tester, 'START WORKOUT');
    await _tapText(tester, 'START'); // the name dialog: no name
    for (final (exercise, load) in [
      ('Bench press', '60'),
      ('Back squat', '100'),
    ]) {
      await _tapText(tester, 'ADD EXERCISE');
      await _enter(tester, find.byType(TextField).first, exercise);
      await _tap(tester, find.text(exercise).last);
      await _tapText(tester, 'Add set');
      for (final set in [1, 2]) {
        await _enter(
          tester,
          find.bySemanticsLabel(RegExp('^$exercise set $set load')),
          load,
        );
        await _enter(
          tester,
          find.bySemanticsLabel(RegExp('^$exercise set $set reps')),
          '5',
        );
      }
    }
    final done = find.byType(Checkbox);
    expect(done, findsNWidgets(4));
    for (var i = 0; i < 4; i++) {
      await _tap(tester, done.at(i));
    }
    await _tapText(tester, 'FINISH WORKOUT');
    await _tapText(tester, 'FINISH');

    expect(_title('Session'), findsOneWidget);
    expect(find.text('Bench press'), findsWidgets);
    expect(find.text('Back squat'), findsWidgets);
    final sets = await device.db!.select(device.db!.workoutSets).get();
    expect(sets, hasLength(4));
    expect(sets.every((s) => s.completed), isTrue);
  });

  testWidgets('record a weight and see it in Progress; changing units never '
      'changes stored values', (tester) async {
    await _launch(tester, device);
    await _onboard(tester);

    await _tab(tester, 'Progress');
    await _tapText(tester, 'Log weight');
    await _enter(tester, _field('Weight'), '89.5');
    await _tapText(tester, 'SAVE');
    expect(find.textContaining('89.5'), findsWidgets);

    await _tab(tester, 'Profile');
    await _tapText(tester, 'Imperial');
    await _tab(tester, 'Progress');
    expect(find.textContaining('197.3'), findsWidgets); // 89.5 kg in lb

    final weights = await device.db!.select(device.db!.weightEntries).get();
    expect(weights.map((w) => w.weightKg), containsAll([90.0, 89.5]));
  });

  testWidgets('export and import round trip', (tester) async {
    await _launch(tester, device);
    await _onboard(tester);
    final db = device.db!;

    final backup = jsonEncode(
      (await ExportService(db).buildBackup(appVersion: 'test')).toJson(),
    );
    final weightsBefore = await db.select(db.weightEntries).get();
    final targetsBefore = await db.select(db.nutritionTargets).get();

    // Change the data, then restore the backup over it.
    await db.delete(db.weightEntries).go();
    await ImportService(db).restore(BackupValidator.parse(backup));

    expect(await db.select(db.weightEntries).get(), weightsBefore);
    expect(await db.select(db.nutritionTargets).get(), targetsBefore);

    await _launch(tester, device);
    expect(_header('Today'), findsOneWidget);
  });
}
