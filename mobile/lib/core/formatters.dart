import 'dart:math';

/// Định dạng số nguyên VND theo chuẩn `50.000đ`, `401.000đ`.
String formatVnd(int amount) {
  final neg = amount < 0;
  final digits = amount.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buf.write('.');
    }
    buf.write(digits[i]);
  }
  return '${neg ? '-' : ''}${buf}đ';
}

/// Chuyển `YYYY-MM-DD` sang `DateTime` (ngày lịch, không lệch múi giờ).
DateTime? parseYmd(String? ymd) {
  if (ymd == null || ymd.isEmpty) return null;
  final parts = ymd.split('-');
  if (parts.length != 3) return null;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}

String toYmd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Số ngày thuê tính cả hai đầu (thuê trong ngày = 1 ngày).
int calculateRentalDays(String startYmd, String endYmd) {
  final s = parseYmd(startYmd);
  final e = parseYmd(endYmd);
  if (s == null || e == null) return 0;
  final diff = e.difference(s).inDays + 1;
  return diff < 1 ? 0 : diff;
}

String formatShortDateVi(String ymd) {
  final d = parseYmd(ymd);
  if (d == null) return ymd;
  const weekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
  final wd = weekdays[d.weekday - 1];
  return '$wd, ${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
}

String formatDateRangeVi(String startYmd, String endYmd) {
  final days = calculateRentalDays(startYmd, endYmd);
  final s = formatShortDateVi(startYmd);
  final e = formatShortDateVi(endYmd);
  if (startYmd == endYmd) return '$s (1 ngày)';
  return '$s – $e ($days ngày)';
}

String formatTimestampVi(String isoUtc) {
  final dt = DateTime.tryParse(isoUtc)?.toLocal();
  if (dt == null) return isoUtc;
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  final dd = dt.day.toString().padLeft(2, '0');
  final mo = dt.month.toString().padLeft(2, '0');
  return '$hh:$mm · $dd/$mo/${dt.year}';
}

/// Tạo UUIDv4 ngẫu nhiên cho header `Idempotency-Key`.
String newUuidV4() {
  final rng = Random.secure();
  final b = List<int>.generate(16, (_) => rng.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  String hex(int v) => v.toRadixString(16).padLeft(2, '0');
  final h = b.map(hex).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}
