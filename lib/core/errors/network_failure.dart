import 'package:dio/dio.dart';

/// Typed network failures. Repositories catch these and show a clear,
/// non-blocking message; they never prevent local logging (NFR-02).
sealed class NetworkFailure implements Exception {
  const NetworkFailure(this.message);

  final String message;

  /// Maps a [DioException] to the matching failure.
  factory NetworkFailure.fromDio(DioException e) {
    return switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.transformTimeout => const RequestTimeout(),
      DioExceptionType.connectionError => const NoConnection(),
      DioExceptionType.cancel => const RequestCancelled(),
      DioExceptionType.badResponse => ServerError(e.response?.statusCode),
      DioExceptionType.badCertificate ||
      DioExceptionType.unknown => const NoConnection(),
    };
  }

  @override
  String toString() => '$runtimeType: $message';
}

class NoConnection extends NetworkFailure {
  const NoConnection() : super('No internet connection.');
}

class RequestTimeout extends NetworkFailure {
  const RequestTimeout() : super('The server took too long to respond.');
}

class RequestCancelled extends NetworkFailure {
  const RequestCancelled() : super('The request was cancelled.');
}

class ServerError extends NetworkFailure {
  const ServerError(this.statusCode)
    : super('The server returned an error ($statusCode).');

  final int? statusCode;
}

class BadData extends NetworkFailure {
  const BadData(super.message);
}
