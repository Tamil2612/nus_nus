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
