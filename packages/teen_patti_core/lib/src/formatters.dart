/// Formats an integer with comma thousands separators (e.g. `25000` -> `25,000`).
String formatCommaNumber(int value) {
  final s = value.toString();
  final buffer = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    final remaining = s.length - i;
    if (i > 0 && remaining % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(s[i]);
  }
  return buffer.toString();
}

/// Formats an integer using Indian numbering grouping (e.g. `124500` -> `1,24,500`).
String formatIndianNumber(int value) {
  final isNegative = value < 0;
  final s = value.abs().toString();
  if (s.length <= 3) {
    return isNegative ? '-$s' : s;
  }

  final lastThree = s.substring(s.length - 3);
  final rest = s.substring(0, s.length - 3);
  final buffer = StringBuffer();
  for (int i = 0; i < rest.length; i++) {
    final remaining = rest.length - i;
    if (i > 0 && remaining % 2 == 0) {
      buffer.write(',');
    }
    buffer.write(rest[i]);
  }
  final formatted = '$buffer,$lastThree';
  return isNegative ? '-$formatted' : formatted;
}
