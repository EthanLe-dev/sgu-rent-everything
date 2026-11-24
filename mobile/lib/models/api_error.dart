class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    required this.code,
    required this.message,
    this.fields = const {},
    this.retryAfterSeconds,
  });

  final int statusCode;
  final String code;
  final String message;
  final Map<String, String> fields;
  final int? retryAfterSeconds;

  bool get isUnauthenticated => statusCode == 401 || code == 'unauthenticated';
  bool get isVerificationRequired =>
      statusCode == 403 && code == 'verification_required';
  bool get isForbidden => statusCode == 403 || statusCode == 404;
  bool get isNetwork => statusCode == 0;

  factory ApiException.fromJson(
    int statusCode,
    Map<String, dynamic> json, {
    int? retryAfterSeconds,
  }) {
    final err = (json['error'] as Map<String, dynamic>?) ?? json;
    final rawFields = (err['fields'] as Map<String, dynamic>?) ?? const {};
    return ApiException(
      statusCode: statusCode,
      code: err['code'] as String? ?? 'unknown_error',
      message: err['message'] as String? ?? 'Đã xảy ra lỗi. Vui lòng thử lại.',
      fields: rawFields.map((k, v) => MapEntry(k, v.toString())),
      retryAfterSeconds: retryAfterSeconds,
    );
  }

  @override
  String toString() => 'ApiException($statusCode, $code: $message)';
}

class PagedResult<T> {
  const PagedResult({required this.items, this.nextCursor});

  final List<T> items;
  final String? nextCursor;

  factory PagedResult.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromItem,
  ) {
    final rawItems = (json['items'] as List<dynamic>?) ?? const [];
    return PagedResult(
      items: rawItems
          .map((e) => fromItem(e as Map<String, dynamic>))
          .toList(),
      nextCursor: json['next_cursor'] as String?,
    );
  }
}
