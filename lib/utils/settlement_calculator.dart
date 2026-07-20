import '../models/expense.dart';
import '../models/transfer.dart';

/// Pure calculation helpers, kept free of Flutter/UI imports so they can be
/// unit-tested in isolation (see test/settlement_calculator_test.dart).
class SettlementCalculator {
  SettlementCalculator._();

  /// Returns the net balance per person id.
  /// Positive => that person is owed money. Negative => that person owes money.
  static Map<int, double> computeBalances({
    required List<int> personIds,
    required List<Expense> expenses,
  }) {
    final net = <int, double>{for (final id in personIds) id: 0.0};
    for (final e in expenses) {
      net[e.payerId] = (net[e.payerId] ?? 0) + e.amount;
      final share = e.shareEach;
      for (final id in e.splitWith) {
        net[id] = (net[id] ?? 0) - share;
      }
    }
    return net;
  }

  /// Greedily matches the largest debtor against the largest creditor to
  /// produce the minimum number of transfers that settles every balance.
  static List<Transfer> computeSettlement(Map<int, double> net) {
    final creditors = <MapEntry<int, double>>[];
    final debtors = <MapEntry<int, double>>[];

    net.forEach((id, amt) {
      final v = (amt * 100).round() / 100;
      if (v > 0.005) creditors.add(MapEntry(id, v));
      if (v < -0.005) debtors.add(MapEntry(id, -v));
    });

    creditors.sort((a, b) => b.value.compareTo(a.value));
    debtors.sort((a, b) => b.value.compareTo(a.value));

    final debtRemain = debtors.map((e) => e.value).toList();
    final credRemain = creditors.map((e) => e.value).toList();

    final result = <Transfer>[];
    int i = 0, j = 0;
    while (i < debtors.length && j < creditors.length) {
      final pay =
          debtRemain[i] < credRemain[j] ? debtRemain[i] : credRemain[j];
      result.add(Transfer(debtors[i].key, creditors[j].key, pay));
      debtRemain[i] -= pay;
      credRemain[j] -= pay;
      if (debtRemain[i] < 0.01) i++;
      if (credRemain[j] < 0.01) j++;
    }
    return result;
  }
}
