/// The net debt between exactly two people, after every ledger entry
/// between them (across every expense and every settlement) has been
/// collapsed into one number. This is what makes "Tamilarasan is owed: •
/// Pushpa AED 15.50 • Nivetha AED 48.60" possible — each [PairBalance] is
/// one of those bullet lines.
///
/// Convention: [amount] > 0 means personA owes personB; [amount] < 0 means
/// personB owes personA. Use [debtorId]/[creditorId]/[owedAmount] rather
/// than reading personA/personB + sign directly — they resolve the sign
/// for you.
class PairBalance {
  final int personAId;
  final int personBId;
  final double amount;

  PairBalance({
    required this.personAId,
    required this.personBId,
    required this.amount,
  });

  bool get isSettled => amount.abs() <= 0.005;

  int? get debtorId {
    if (isSettled) return null;
    return amount > 0 ? personAId : personBId;
  }

  int? get creditorId {
    if (isSettled) return null;
    return amount > 0 ? personBId : personAId;
  }

  double get owedAmount => amount.abs();
}
