/// Formats a number as an AED / dirham amount, e.g. `fmtAed(1234.5)` -> "د.إ 1,234.50".
String fmtAed(double n) {
  final rounded = (n * 100).round() / 100;
  final parts = rounded.abs().toStringAsFixed(2).split('.');
  final whole = parts[0];
  final buf = StringBuffer();
  for (int i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) buf.write(',');
    buf.write(whole[i]);
  }
  final sign = rounded < 0 ? '-' : '';
  return 'د.إ $sign${buf.toString()}.${parts[1]}';
}
