import 'api_exception.dart';

/// Generic API response wrapper
sealed class ApiResponse<T> {
  const ApiResponse();

  factory ApiResponse.success({
    required T? data,
    required int statusCode,
    Map<String, String>? headers,
  }) = ApiSuccess<T>;

  factory ApiResponse.failure(ApiException error) = ApiFailure<T>;

  bool get isSuccess => this is ApiSuccess<T>;
  bool get isFailure => this is ApiFailure<T>;

  T? get dataOrNull => switch (this) {
        ApiSuccess(data: final d) => d,
        ApiFailure() => null,
      };

  ApiException? get errorOrNull => switch (this) {
        ApiSuccess() => null,
        ApiFailure(error: final e) => e,
      };

  R when<R>({
    required R Function(T? data, int statusCode, Map<String, String> headers)
        success,
    required R Function(ApiException error) failure,
  }) {
    return switch (this) {
      ApiSuccess(:final data, :final statusCode, :final headers) => success(
          data,
          statusCode,
          headers,
        ),
      ApiFailure(:final error) => failure(error),
    };
  }
}

final class ApiSuccess<T> extends ApiResponse<T> {
  final T? data;
  final int statusCode;
  final Map<String, String> headers;

  const ApiSuccess({
    required this.data,
    required this.statusCode,
    Map<String, String>? headers,
  }) : headers = headers ?? const {};
}

final class ApiFailure<T> extends ApiResponse<T> {
  final ApiException error;

  const ApiFailure(this.error);
}
