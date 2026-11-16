/// Helpers for keeping expense and split values on exact currency cents.
class MoneyUtils {
  MoneyUtils._();

  /// Converts a major-unit amount to cents, returning null for sub-cent values.
  /// The small tolerance accepts ordinary IEEE-754 representation noise only.
  static int? toCents(num amount) {
    if (!amount.isFinite) return null;
    final cents = (amount * 100).round();
    if ((cents / 100 - amount).abs() > 1e-6) return null;
    return cents;
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
