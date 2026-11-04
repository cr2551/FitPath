import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Identifies the app to external APIs. Open Food Facts asks every client to
/// send a descriptive User-Agent; no personal data is included.
const String fitPathUserAgent =
    'FitPath/0.1 (Android; +https://github.com/cr2551/FitPath)';

Dio createDio({String userAgent = fitPathUserAgent}) {
  return Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 5),
      headers: {'User-Agent': userAgent, 'Accept': 'application/json'},
      responseType: ResponseType.json,
    ),
  );
}

/// Shared HTTP client. Override in tests.
final dioProvider = Provider<Dio>((ref) {
  final dio = createDio();
  ref.onDispose(dio.close);
  return dio;
});
