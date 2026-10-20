/// Lỗi nghiệp vụ; [key] là khóa chuỗi trong i18n (được dịch ở tầng giao diện).
class AppException implements Exception {
  final String key;
  const AppException(this.key);
  @override
  String toString() => 'AppException($key)';
}

/// Lỗi validation theo từng trường: field -> khóa chuỗi i18n.
/// field: name, price, time, category, images
class ValidationException implements Exception {
  final Map<String, String> errors;
  const ValidationException(this.errors);
  @override
  String toString() => 'ValidationException($errors)';
}

/// Lỗi khi gọi MockAPI (mất mạng, timeout, 4xx/5xx...).
class ApiException implements Exception {
  final String message;
  final int? status;
  const ApiException(this.message, [this.status]);
  @override
  String toString() => 'ApiException($status): $message';
}
