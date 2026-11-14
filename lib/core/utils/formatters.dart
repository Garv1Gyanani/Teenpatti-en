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

