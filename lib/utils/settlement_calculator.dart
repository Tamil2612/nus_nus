import '../models/expense.dart';
import '../models/ledger_entry.dart';
import '../models/pair_balance.dart';
import '../models/transfer.dart';

/// Pure calculation helpers, kept free of Flutter/UI imports so they can be
/// unit-tested in isolation (see test/settlement_calculator_test.dart).
///
/// The pipeline, each stage feeding the next:
///
///   Expenses  →  LedgerEntry list  →  PairBalance list  →  net balances  →  optimized Settlement
///
/// Every stage is a pure function of the one before it — nothing here is
/// stored. Editing or deleting an expense just changes the input list and
/// the whole pipeline recomputes; past expenses are never mutated to
/// "absorb" a settlement, which is what keeps the debtor-creditor history
/// (item 3 of the spec) honest.
class SettlementCalculator {
  SettlementCalculator._();

  // Stage 1: Expenses -> LedgerEntry ---------------------------------------

  /// Turns each expense into one or more directed debt records.
  ///
  /// - Normal expense: every split participant who isn't the payer gets a
  ///   positive entry `participant -> payer : theirShare`. The payer never
  ///   owes themselves, so their own share (if present in the split map) is
  ///   skipped entirely.
  /// - Settlement expense (created via [SplitProvider.settleUp]): stored as
  ///   payerId = the person settling up (the debtor), splitMap = a single
  ///   `{creditorId: amount}` entry. This produces one *negative* entry
  ///   `debtor -> creditor : -amount`, which nets against earlier positive
  ///   entries between the same pair rather than editing them.
  static List<LedgerEntry> deriveLedgerEntries(List<Expense> expenses) {
    final entries = <LedgerEntry>[];
    for (final e in expenses) {
      if (e.isSettlement) {
        if (e.splitMap.isEmpty) continue;
        final toId = e.splitMap.keys.first;
        final amount = e.splitMap[toId]!;
        entries.add(LedgerEntry(
          expenseId: e.id,
          fromId: e.payerId,
          toId: toId,
          amount: -amount,
          isSettlement: true,
        ));
      } else {
        e.splitMap.forEach((personId, share) {
          if (personId == e.payerId) return; // payer never owes themselves
          if (share.abs() <= 0.001) return;
          entries.add(LedgerEntry(
            expenseId: e.id,
            fromId: personId,
            toId: e.payerId,
            amount: share,
          ));
        });
      }
    }
    return entries;
  }

  // Stage 2: LedgerEntry -> PairBalance -------------------------------------

  /// Collapses every ledger entry between each unique pair of people into a
  /// single net [PairBalance]. This is what "opposite debts automatically
  /// cancel" (spec item 4) actually means: it's not a special case, it just
  /// falls out of summing signed entries per pair.
  ///
  /// Pairs that fully cancel out (net ~0) are omitted from the result.
  static List<PairBalance> computePairBalances(List<LedgerEntry> entries) {
    final netByPair = <String, double>{};
    final idsByPair = <String, List<int>>{};

    for (final entry in entries) {
      final a = entry.fromId, b = entry.toId;
      final lower = a < b ? a : b;
      final higher = a < b ? b : a;
      final key = '$lower-$higher';
      idsByPair[key] = [lower, higher];

      // Convention: netByPair[key] > 0 means `lower` owes `higher`.
      // An entry from `lower` contributes positively; an entry from
      // `higher` (i.e. the reverse direction) contributes negatively.
      final sign = (a == lower) ? 1.0 : -1.0;
      netByPair[key] = (netByPair[key] ?? 0) + sign * entry.amount;
    }

    final result = <PairBalance>[];
    netByPair.forEach((key, amount) {
      if (amount.abs() <= 0.005) return; // fully cancelled out
      final ids = idsByPair[key]!;
      result.add(PairBalance(personAId: ids[0], personBId: ids[1], amount: amount));
    });
    return result;
  }

  // Stage 3: PairBalance -> net balance per person --------------------------

  /// Sums every pairwise debt into a single net figure per person.
  /// Positive => that person is owed money overall. Negative => they owe.
  ///
  /// This is intentionally a *summary* view — it's what powers the
  /// optimized settle-up in stage 4, and the top-line "is owed AED X" in
  /// the UI. The detailed "who specifically" breakdown should come from
  /// [computePairBalances] directly, not from this.
  static Map<int, double> computeNetBalances(List<PairBalance> pairBalances) {
    final net = <int, double>{};
    for (final pb in pairBalances) {
      net[pb.personAId] = (net[pb.personAId] ?? 0) - pb.amount;
      net[pb.personBId] = (net[pb.personBId] ?? 0) + pb.amount;
    }
    return net;
  }

  /// Convenience: expenses straight to net balances, skipping the
  /// intermediate lists when only the summary is needed.
  static Map<int, double> computeBalances({
    required List<int> personIds,
    required List<Expense> expenses,
  }) {
    final net = <int, double>{for (final id in personIds) id: 0.0};
    final pairBalances = computePairBalances(deriveLedgerEntries(expenses));
    computeNetBalances(pairBalances).forEach((id, amt) {
      net[id] = (net[id] ?? 0) + amt;
    });
    return net;
  }

  // Stage 4: net balances -> optimized settlement ---------------------------

  /// Greedily matches the largest debtor against the largest creditor to
  /// produce the minimum number of transfers that settles every balance.
  /// This deliberately loses the "who specifically owes whom" detail in
  /// exchange for the fewest payments — it's a distinct view from
  /// [computePairBalances], not a replacement for it.
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
