/// Helpers for keeping expense and split values on exact currency cents.
class MoneyUtils {
  MoneyUtils._();

  /// Converts a major-unit amount to the nearest cent.
  ///
  /// Users may enter more than two decimal places; values are rounded once
  /// when saved so backend records always use the currency's minor unit.
  /// Returns null only for NaN or infinite values.
  static int? toCents(num amount) {
    if (!amount.isFinite) return null;
    return (amount * 100).round();
  }

  static double fromCents(int cents) => cents / 100;

  /// Splits [totalCents] evenly, assigning leftover cents to the first IDs.
  static Map<int, double> equalSplit(int totalCents, Iterable<int> personIds) {
    final ids = personIds.toList();
    if (ids.isEmpty) return {};
    final baseCents = totalCents ~/ ids.length;
    var remainderCents = totalCents % ids.length;
    final result = <int, double>{};
    for (final id in ids) {
      final shareCents = baseCents + (remainderCents > 0 ? 1 : 0);
      if (remainderCents > 0) remainderCents--;
      result[id] = fromCents(shareCents);
    }
    return result;
  }
}
