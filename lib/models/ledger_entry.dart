/// A single directed debt record: [fromId] owes [toId] [amount].
///
/// Derived from expenses, never stored/edited directly — see
/// [SettlementCalculator.deriveLedgerEntries]. For a normal expense this is
/// always positive (a real debt). For a settlement, [amount] is negative,
/// representing a *reduction* of an existing debt rather than a new one —
/// per the "never edit past expenses" rule, settlements are their own
/// ledger entries that net out against earlier ones when balances are
/// computed, rather than mutating history.
class LedgerEntry {
  final int expenseId;
  final int fromId; // debtor
  final int toId; // creditor
  final double amount; // positive = new debt, negative = debt repayment
  final bool isSettlement;

  LedgerEntry({
    required this.expenseId,
    required this.fromId,
    required this.toId,
    required this.amount,
    this.isSettlement = false,
  });
}
