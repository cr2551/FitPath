import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:fitpath/app.dart';
import 'package:fitpath/core/database/app_database.dart';
import 'package:fitpath/core/database/database_provider.dart';
import 'package:fitpath/core/database/open_database.dart';
import 'package:fitpath/core/errors/network_failure.dart';
import 'package:fitpath/features/nutrition/data/remote/off_product.dart';
import 'package:fitpath/features/nutrition/data/remote/open_food_facts_client.dart';
import 'package:fitpath/shared/widgets/screen_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Shared driver for the Phase 2 end-to-end tests: the real app on a real
// SQLite file, opened the way `main` opens it, with Open Food Facts offline.

class OfflineClient extends OpenFoodFactsClient {
  OfflineClient() : super(Dio());

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
class Device {
  Device()
    : file = File(
        '${Directory.systemTemp.createTempSync('fitpath_p2').path}'
        '${Platform.pathSeparator}fitpath.db',
      );

  final File file;
  AppDatabase? db;

  Future<void> close() async {
    await db?.close();
    db = null;
  }

  Future<void> dispose() async {
    await close();
    file.parent.deleteSync(recursive: true);
  }
}

/// Starts the app on [device]'s database, as on a cold launch (including
/// the startup re-seed of bundled recipes).
Future<void> launch(WidgetTester tester, Device device) async {
  await tester.pumpWidget(const SizedBox());
  await settle(tester);
  await device.close();
  final db = device.db = await openAppDatabase(
    open: () => AppDatabase(NativeDatabase(device.file)),
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        openFoodFactsClientProvider.overrideWithValue(OfflineClient()),
      ],
      child: const FitPathApp(),
    ),
  );
  await settle(tester);
}

/// Real time for database work and animations; never pumpAndSettle (the
/// active workout's timer never settles).
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Finder field(String label) => find.widgetWithText(TextField, label);
Finder header(String title) =>
    find.byWidgetPredicate((w) => w is ScreenHeader && w.title == title);
Finder screenTitle(String title) => find.byWidgetPredicate(
  (w) =>
      (w is AppBar && w.title is Text && (w.title! as Text).data == title) ||
      (w is ScreenHeader && w.title == title),
);

/// Taps the last widget [f] matches, scrolling the screen's list to it
/// first if needed.
Future<void> tap(WidgetTester tester, Finder f, [String? what]) async {
  await reveal(tester, f, what);
  await tester.tap(f.last);
  await settle(tester);
}

/// Scrolls the screen's list until [f] is built and on screen; fails with
/// what is on screen otherwise. Lists build lazily, so off-screen rows
/// are not found until revealed.
Future<void> reveal(WidgetTester tester, Finder f, [String? what]) async {
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
  await settle(tester);
}

Future<void> tapText(WidgetTester tester, String text) =>
    tap(tester, find.text(text), text);

Future<void> enter(WidgetTester tester, Finder f, String text) async {
  await tester.ensureVisible(f);
  await tester.enterText(f, text);
  await settle(tester);
}

Future<void> tab(WidgetTester tester, String label) => tap(
  tester,
  find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
);

/// Metric onboarding: 30-year-old man, 180 cm, 90 kg, moderate activity,
/// losing weight, with the suggested targets.
Future<void> onboard(WidgetTester tester) async {
  await tapText(tester, 'GET STARTED');
  await tapText(tester, 'METRIC (KG, CM)');
  await enter(tester, field('Age'), '30');
  await enter(tester, field('Height'), '180');
  await enter(tester, field('Current weight'), '90');
  await tapText(tester, 'Activity level');
  await tapText(tester, 'Moderate (3-5 days a week)');
  await tapText(tester, 'MALE');
  await tapText(tester, 'NEXT');
  await tap(tester, find.text('Lose weight').first);
  await tapText(tester, 'NEXT');
  await tapText(tester, 'NEXT');
  await tapText(tester, 'FINISH SETUP');
}
