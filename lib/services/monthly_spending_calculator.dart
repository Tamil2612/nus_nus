import '../models/expense.dart';
import '../models/group.dart';

class MonthlySpending {
  final double personal;
  final double shared;
  final int expenseCount;
  final Map<String, double> byCategory;

  const MonthlySpending({
    required this.personal,
    required this.shared,
    required this.expenseCount,
    this.byCategory = const {},
  });

  double get total => personal + shared;
}

class MonthlySpendingCalculator {
  MonthlySpendingCalculator._();

  static MonthlySpending calculate({
    required List<Group> groups,
    required String uid,
    required DateTime month,
    required String currency,
    Map<String, String?> memberCategories = const {},
  }) {
    var personal = 0.0;
    var shared = 0.0;
    var count = 0;
    final categories = <String, double>{};
    for (final group in groups) {
      // Do not silently combine currencies. The report is scoped to the
      // selected budget currency until explicit FX conversion is supported.
      if (group.currency.toUpperCase() != currency.toUpperCase()) continue;
      final mine = group.members.where((p) => p.linkedUserId == uid).toList();
      final myPersonId = mine.isNotEmpty
          ? mine.first.id
          : (group.isPersonal && group.ownerId == uid ? 1 : null);
      if (myPersonId == null) continue;

      for (final expense in group.expenses) {
        if (expense.isSettlement || expense.createdAt == null) continue;
        final date = expense.createdAt!;
        if (date.year != month.year || date.month != month.month) continue;

        final amount = group.isPersonal
            ? expense.amount
            : (expense.splitMap[myPersonId] ?? 0);
        if (amount <= 0) continue;
        if (group.isPersonal) {
          personal += amount;
        } else {
          shared += amount;
        }
        count++;
        final overrideKey = '${group.id}/${expense.id}';
        final category = memberCategories.containsKey(overrideKey)
            ? memberCategories[overrideKey]
            : expense.categoryId;
        final categoryKey = category ?? 'uncategorized';
        categories[categoryKey] = (categories[categoryKey] ?? 0) + amount;
      }
    }
    return MonthlySpending(
      personal: personal,
      shared: shared,
      expenseCount: count,
      byCategory: categories,
    );
  }
}
