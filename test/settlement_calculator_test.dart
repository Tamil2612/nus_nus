import 'package:flutter_test/flutter_test.dart';
import 'package:nus_nus/models/expense.dart';
import 'package:nus_nus/utils/settlement_calculator.dart';

void main() {
  group('SettlementCalculator', () {
    test('equal three-way split settles with two transfers', () {
      // Person ids: 1 = Amina, 2 = Sara, 3 = Zayed
      final expenses = [
        Expense(
          id: "1",
          desc: 'Dinner',
          amount: 90,
          payerId: 1,
          splitMap: {1: 30, 2: 30, 3: 30},
        ),
      ];

      final balances = SettlementCalculator.computeBalances(
        personIds: [1, 2, 3],
        expenses: expenses,
      );

      expect(balances[1], closeTo(60, 0.01)); // paid 90, owes 30 -> +60
      expect(balances[2], closeTo(-30, 0.01));
      expect(balances[3], closeTo(-30, 0.01));

      final transfers = SettlementCalculator.computeSettlement(balances);
      expect(transfers.length, 2);
      final total = transfers.fold(0.0, (s, t) => s + t.amount);
      expect(total, closeTo(60, 0.01));
    });

    test('everyone settled produces no transfers', () {
      final balances = {1: 0.0, 2: 0.0};
      final transfers = SettlementCalculator.computeSettlement(balances);
      expect(transfers, isEmpty);
    });
  });
}
