import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/network_failure.dart';
import '../../../../core/network/dio_client.dart';
import 'off_product.dart';

/// Read-only client for the Open Food Facts API.
///
/// Only the search text or barcode is sent; no personal data. Every failure
/// surfaces as a [NetworkFailure] and never as an uncaught exception. Callers
/// must debounce search (OFF allows about 10 searches per minute).
/// See `docs/third-party-data.md` for licensing and attribution.
class OpenFoodFactsClient {
  OpenFoodFactsClient(
    this._dio, {
    this.baseUrl = 'https://world.openfoodfacts.org',
  });

  final Dio _dio;
  final String baseUrl;

  /// Only the fields FitPath maps, to keep responses small.
  static const fields =
      'code,product_name,product_name_en,generic_name,brands,quantity,'
      'product_quantity_unit,serving_size,serving_quantity,'
      'serving_quantity_unit,nutriments';

  /// Full-text product search. An empty query returns an empty page without
  /// a request.
  Future<OffSearchPage> search(
    String query, {
    int page = 1,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return OffSearchPage.empty;

    final json = await _get('$baseUrl/cgi/search.pl', {
      'search_terms': q,
      'search_simple': 1,
      'action': 'process',
      'json': 1,
      'page': page,
      'page_size': pageSize,
      'fields': fields,
    }, cancelToken);

    final raw = json['products'];
    if (raw is! List) throw const BadData('Search response has no products.');
    return OffSearchPage(
      products: [
        for (final p in raw)
          if (p is Map<String, dynamic>) ?OffProduct.fromJson(p),
      ],
      page: _int(json['page']) ?? page,
      totalCount: _int(json['count']) ?? raw.length,
    );
  }

  /// Looks up one product. Returns null when OFF does not know the barcode.
  Future<OffProduct?> productByBarcode(
    String barcode, {
    CancelToken? cancelToken,
  }) async {
    final code = barcode.trim();
    if (!RegExp(r'^\d{6,14}$').hasMatch(code)) return null;
    try {
      final json = await _get('$baseUrl/api/v2/product/$code', {
        'fields': fields,
      }, cancelToken);
      final product = json['product'];
      if (_int(json['status']) != 1 || product is! Map<String, dynamic>) {
        return null;
      }
      return OffProduct.fromJson(product);
    } on ServerError catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _get(
    String url,
    Map<String, Object> query,
    CancelToken? cancelToken,
  ) async {
    try {
      final response = await _dio.get<Object>(
        url,
        queryParameters: query,
        cancelToken: cancelToken,
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const BadData('Unexpected response format.');
      }
      return data;
    } on DioException catch (e) {
      throw NetworkFailure.fromDio(e);
    }
  }

  static int? _int(Object? v) => switch (v) {
    final int i => i,
    final num n => n.toInt(),
    final String s => int.tryParse(s),
    _ => null,
  };
}

final openFoodFactsClientProvider = Provider<OpenFoodFactsClient>(
  (ref) => OpenFoodFactsClient(ref.watch(dioProvider)),
);
