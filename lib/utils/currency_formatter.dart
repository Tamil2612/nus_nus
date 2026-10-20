/// Formats a number as a dynamic currency amount.
String fmtCurrency(double n, String currency) {
  final rounded = (n * 100).round() / 100;
  final parts = rounded.abs().toStringAsFixed(2).split('.');
  final whole = parts[0];
  final buf = StringBuffer();
  for (int i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) buf.write(',');
    buf.write(whole[i]);
  }
  final sign = rounded < 0 ? '-' : '';
  final symbol = _getSymbol(currency);
  return '$symbol $sign${buf.toString()}.${parts[1]}';
}

String _getSymbol(String code) {
  switch (code.toUpperCase()) {
    case 'AED':
      return 'AED';
    case 'USD':
      return '\$';
    case 'EUR':
      return '€';
    case 'GBP':
      return '£';
    case 'INR':
      return '₹';
    case 'SAR':
      return 'SAR';
    case 'QAR':
      return 'QAR';
    case 'KWD':
      return 'KWD';
    case 'BHD':
      return 'BHD';
    case 'OMR':
      return 'OMR';
    default:
      return code;
  }
}
