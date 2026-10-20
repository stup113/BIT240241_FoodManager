/// 45000 -> "45,000₫"
String formatPrice(double v) {
  final isInt = v == v.roundToDouble();
  final s = isInt ? v.toInt().toString() : v.toStringAsFixed(2);
  final parts = s.split('.');
  final intPart = parts[0];
  final buf = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    final fromEnd = intPart.length - i;
    buf.write(intPart[i]);
    if (fromEnd > 1 && fromEnd % 3 == 1) buf.write(',');
  }
  if (parts.length > 1) buf.write('.${parts[1]}');
  buf.write('₫');
  return buf.toString();
}

/// Đọc số từ ô nhập; trả về null nếu không hợp lệ (chữ, NaN, vô cực...).
double? parseNumber(String s) {
  final v = double.tryParse(s.trim().replaceAll(',', '.'));
  if (v == null || !v.isFinite) return null;
  return v;
}

/// Giá trị hiển thị trong ô nhập (bỏ ".0" nếu là số nguyên).
String numberToText(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toString();

bool isHttpUrl(String s) {
  final u = Uri.tryParse(s.trim());
  return u != null &&
      (u.scheme == 'http' || u.scheme == 'https') &&
      u.host.isNotEmpty;
}
