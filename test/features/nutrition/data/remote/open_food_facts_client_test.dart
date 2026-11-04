import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fitpath/core/errors/network_failure.dart';
import 'package:fitpath/core/network/dio_client.dart';
import 'package:fitpath/features/nutrition/data/remote/off_product.dart';
import 'package:fitpath/features/nutrition/data/remote/open_food_facts_client.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers every request with [handler]'s response (or throws its error).
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final ResponseBody Function(RequestOptions options) handler;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object body, {int status = 200}) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

const _bar = {
  'code': '5000112637922',
  'product_name': 'Protein bar, chocolate',
  'brands': 'FitCo, FitCo Foods',
  'quantity': '60 g',
  'serving_size': '1 bar (60 g)',
  'serving_quantity': 60,
  'nutriments': {
    'energy-kcal_100g': 350,
    'proteins_100g': 33.3,
    'carbohydrates_100g': '36.7',
    'fat_100g': 11.7,
    'sodium_100g': 0.24,
  },
};

const _juice = {
  'code': '3017620422003',
  'product_name': 'Orange juice',
  'quantity': '1 l',
  'nutriments': {'energy-kj_100g': 188.28, 'carbohydrates_100g': 10.4},
};

(OpenFoodFactsClient, _FakeAdapter) _client(
  ResponseBody Function(RequestOptions) handler,
) {
  final adapter = _FakeAdapter(handler);
  final dio = createDio()..httpClientAdapter = adapter;
  return (OpenFoodFactsClient(dio), adapter);
}

void main() {
  group('OffProduct.fromJson', () {
    test('maps nutrients per 100 g, first brand and serving', () {
      final p = OffProduct.fromJson(_bar)!;
      expect(p.barcode, '5000112637922');
      expect(p.brand, 'FitCo');
      expect(p.isLiquid, isFalse);
      expect(p.kcal, 350);
      expect(p.proteinG, 33.3);
      expect(p.carbsG, 36.7, reason: 'numeric strings are accepted');
      expect(p.fatG, 11.7);
      expect(p.sodiumMg, closeTo(240, 1e-9), reason: 'sodium g -> mg');
      expect(p.servingSize, 60);
      expect(p.servingIsMl, isFalse);
      expect(p.servingDescription, '1 bar (60 g)');
    });

    test('missing nutrients stay null, kJ converts to kcal, ml detected', () {
      final p = OffProduct.fromJson(_juice)!;
      expect(p.isLiquid, isTrue);
      expect(p.kcal, closeTo(45, 1e-9));
      expect(p.proteinG, isNull);
      expect(p.fatG, isNull);
      expect(p.hasAnyNutrient, isTrue);
    });

    test('products without barcode or name are skipped', () {
      expect(OffProduct.fromJson({'product_name': 'x'}), isNull);
      expect(OffProduct.fromJson({'code': '123', 'product_name': ' '}), isNull);
    });

    test('negative or garbage values are treated as unknown', () {
      final p = OffProduct.fromJson({
        'code': '1',
        'product_name': 'Odd',
        'nutriments': {'fat_100g': -1, 'proteins_100g': 'n/a'},
      })!;
      expect(p.fatG, isNull);
      expect(p.proteinG, isNull);
      expect(p.hasAnyNutrient, isFalse);
    });
  });

  group('search', () {
    test('sends the query, fields and User-Agent', () async {
      final (client, adapter) = _client(
        (_) => _json({
          'count': 2,
          'page': 1,
          'products': [_bar, _juice, <String, dynamic>{}],
        }),
      );

      final page = await client.search('  bar ');

      expect(page.products.map((p) => p.name), [
        'Protein bar, chocolate',
        'Orange juice',
      ]);
      expect(page.totalCount, 2);
      final req = adapter.requests.single;
      expect(req.uri.path, '/cgi/search.pl');
      expect(req.queryParameters['search_terms'], 'bar');
      expect(req.queryParameters['fields'], OpenFoodFactsClient.fields);
      expect(req.headers['User-Agent'], startsWith('FitPath/'));
    });

    test('empty query makes no request', () async {
      final (client, adapter) = _client((_) => _json({}));

      expect((await client.search('   ')).products, isEmpty);
      expect(adapter.requests, isEmpty);
    });

    test('server errors become ServerError', () async {
      final (client, _) = _client((_) => _json({}, status: 503));

      await expectLater(
        client.search('bar'),
        throwsA(isA<ServerError>().having((e) => e.statusCode, 'code', 503)),
      );
    });

    test('connection problems become NoConnection', () async {
      final (client, _) = _client(
        (o) => throw DioException.connectionError(
          requestOptions: o,
          reason: 'offline',
        ),
      );

      await expectLater(client.search('bar'), throwsA(isA<NoConnection>()));
    });

    test('unexpected shapes become BadData', () async {
      final (client, _) = _client((_) => _json({'products': 'nope'}));

      await expectLater(client.search('bar'), throwsA(isA<BadData>()));
    });
  });

  group('productByBarcode', () {
    test('returns the product', () async {
      final (client, adapter) = _client(
        (_) => _json({'status': 1, 'product': _bar}),
      );

      final p = await client.productByBarcode('5000112637922');

      expect(p!.name, 'Protein bar, chocolate');
      expect(adapter.requests.single.uri.path, '/api/v2/product/5000112637922');
    });

    test('unknown product or 404 returns null', () async {
      final (notFound, _) = _client((_) => _json({'status': 0}));
      final (missing, _) = _client((_) => _json({}, status: 404));

      expect(await notFound.productByBarcode('12345678'), isNull);
      expect(await missing.productByBarcode('12345678'), isNull);
    });

    test('invalid barcodes make no request', () async {
      final (client, adapter) = _client((_) => _json({}));

      expect(await client.productByBarcode('abc'), isNull);
      expect(adapter.requests, isEmpty);
    });
  });
}
