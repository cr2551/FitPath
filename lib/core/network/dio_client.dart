import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Identifies the app to external APIs. Open Food Facts asks every client to
/// send a descriptive User-Agent; no personal data is included.
const String fitPathUserAgent =
    'FitPath/0.1 (Android; +https://github.com/cr2551/FitPath)';

/// In a browser the browser sets the User-Agent itself (a custom one is
/// refused), and a send timeout only applies to requests with a body.
Dio createDio({String userAgent = fitPathUserAgent, bool web = kIsWeb}) {
  return Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 10),
      sendTimeout: web ? null : const Duration(seconds: 5),
      headers: {
        if (!web) 'User-Agent': userAgent,
        'Accept': 'application/json',
      },
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
