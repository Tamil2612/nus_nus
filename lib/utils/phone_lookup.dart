/// Normalizes supported phone formats to the same key used by the lookup
/// callable and stored on user profiles for indexed matching.
String normalizeLookupPhone(String value) {
  var digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('00')) digits = digits.substring(2);

  if (digits.startsWith('971')) {
    final national = digits.substring(3);
    return national.startsWith('0') ? national : '0$national';
  }
  if (digits.startsWith('91') &&
      digits.length == 12 &&
      RegExp(r'^[6-9]\d{9}$').hasMatch(digits.substring(2))) {
    return digits.substring(2);
  }
  if (digits.length == 11 &&
      digits.startsWith('0') &&
      RegExp(r'^[6-9]\d{9}$').hasMatch(digits.substring(1))) {
    return digits.substring(1);
  }
  if (RegExp(r'^[6-9]\d{9}$').hasMatch(digits)) return digits;
  if (RegExp(r'^5\d{8}$').hasMatch(digits)) return '0$digits';
  if (RegExp(r'^05\d{8}$').hasMatch(digits)) return digits;
  return digits;
}
