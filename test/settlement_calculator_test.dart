import 'package:flutter_test/flutter_test.dart';
import 'package:nus_nus/models/expense.dart';
import 'package:nus_nus/utils/settlement_calculator.dart';

void main() {
  group('SettlementCalculator — Pairwise Specification Compliance', () {
    // Person IDs: 1 = A, 2 = B, 3 = C, 4 = D

    test('Test 1: A pays 300, A/B/C equal -> B owes A 100, C owes A 100', () {
      final expenses = [
        Expense(
          id: "e1",
          desc: 'Dinner',
          amount: 300,
          payerId: 1, // A
          splitMap: {1: 100, 2: 100, 3: 100},
        ),
      ];

      final entries = SettlementCalculator.deriveLedgerEntries(expenses);
      final pairBalances = SettlementCalculator.computePairBalances(entries);

      // Expect 2 pair balances: B -> A = 100, C -> A = 100
      expect(pairBalances.length, 2);

      final bToA = pairBalances.firstWhere((p) => (p.personAId == 1 && p.personBId == 2) || (p.personAId == 2 && p.personBId == 1));
      final cToA = pairBalances.firstWhere((p) => (p.personAId == 1 && p.personBId == 3) || (p.personAId == 3 && p.personBId == 1));

      expect(bToA.owedAmount, closeTo(100, 0.01));
      expect(cToA.owedAmount, closeTo(100, 0.01));
    });

    test('Test 2: A pays 300, B pays 150, A/B/C equal -> B -> A = 50, C -> A = 100, C -> B = 50', () {
      final expenses = [
        Expense(
          id: "e1",
          desc: 'Dinner',
          amount: 300,
          payerId: 1, // A
          splitMap: {1: 100, 2: 100, 3: 100},
        ),
        Expense(
          id: "e2",
          desc: 'Lunch',
          amount: 150,
          payerId: 2, // B
          splitMap: {1: 50, 2: 50, 3: 50},
        ),
      ];

      final entries = SettlementCalculator.deriveLedgerEntries(expenses);
      final pairBalances = SettlementCalculator.computePairBalances(entries);

      // Expected Pairwise Balances:
      // B -> A = 50
      // C -> A = 100
      // C -> B = 50
      expect(pairBalances.length, 3);

      final ab = pairBalances.firstWhere((p) => (p.personAId == 1 && p.personBId == 2) || (p.personAId == 2 && p.personBId == 1));
      final ac = pairBalances.firstWhere((p) => (p.personAId == 1 && p.personBId == 3) || (p.personAId == 3 && p.personBId == 1));
      final bc = pairBalances.firstWhere((p) => (p.personAId == 2 && p.personBId == 3) || (p.personAId == 3 && p.personBId == 2));

      expect(ab.debtorId, 2); // B owes A
      expect(ab.creditorId, 1);
      expect(ab.owedAmount, closeTo(50, 0.01));

      expect(ac.debtorId, 3); // C owes A
      expect(ac.creditorId, 1);
      expect(ac.owedAmount, closeTo(100, 0.01));

      expect(bc.debtorId, 3); // C owes B
      expect(bc.creditorId, 2);
      expect(bc.owedAmount, closeTo(50, 0.01));
    });

    test('Test 3: A owes B 100, B owes A 40 -> A owes B 60', () {
      final expenses = [
        Expense(
          id: "e1",
          desc: 'Expense 1',
          amount: 100,
          payerId: 2, // B paid for A
          splitMap: {1: 100},
        ),
        Expense(
          id: "e2",
          desc: 'Expense 2',
          amount: 40,
          payerId: 1, // A paid for B
          splitMap: {2: 40},
        ),
      ];

      final pairBalances = SettlementCalculator.computePairBalances(
        SettlementCalculator.deriveLedgerEntries(expenses),
      );

      expect(pairBalances.length, 1);
      final ab = pairBalances.first;
      expect(ab.debtorId, 1); // A owes B
      expect(ab.creditorId, 2);
      expect(ab.owedAmount, closeTo(60, 0.01));
    });

    test('Test 4: B owes A 50, B owes A 30 -> B owes A 80', () {
      final expenses = [
        Expense(
          id: "e1",
          desc: 'Expense 1',
          amount: 50,
          payerId: 1, // A paid
          splitMap: {2: 50},
        ),
        Expense(
          id: "e2",
          desc: 'Expense 2',
          amount: 30,
          payerId: 1, // A paid
          splitMap: {2: 30},
        ),
      ];

      final pairBalances = SettlementCalculator.computePairBalances(
        SettlementCalculator.deriveLedgerEntries(expenses),
      );

      expect(pairBalances.length, 1);
      final ab = pairBalances.first;
      expect(ab.debtorId, 2); // B owes A
      expect(ab.creditorId, 1);
      expect(ab.owedAmount, closeTo(80, 0.01));
    });

    test('Test 5: A owes B 100, B owes A 100 -> No outstanding debt', () {
      final expenses = [
        Expense(
          id: "e1",
          desc: 'Expense 1',
          amount: 100,
          payerId: 2, // B paid for A
          splitMap: {1: 100},
        ),
        Expense(
          id: "e2",
          desc: 'Expense 2',
          amount: 100,
          payerId: 1, // A paid for B
          splitMap: {2: 100},
        ),
      ];

      final pairBalances = SettlementCalculator.computePairBalances(
        SettlementCalculator.deriveLedgerEntries(expenses),
      );

      expect(pairBalances, isEmpty);
    });

    test('Test 6: A pays for themselves -> No self-debt generated', () {
      final expenses = [
        Expense(
          id: "e1",
          desc: 'Solo Expense',
          amount: 100,
          payerId: 1, // A
          splitMap: {1: 100},
        ),
      ];

      final entries = SettlementCalculator.deriveLedgerEntries(expenses);
      expect(entries, isEmpty);

      final pairBalances = SettlementCalculator.computePairBalances(entries);
      expect(pairBalances, isEmpty);
    });

    test('settled share is excluded from the outstanding balance', () {
      final expenses = [
        Expense(
          id: 'e-settled',
          desc: 'Dinner',
          amount: 100,
          payerId: 1,
          splitMap: {1: 40, 2: 60},
          settledBy: {1, 2},
        ),
      ];

      final entries = SettlementCalculator.deriveLedgerEntries(expenses);
      expect(entries, isEmpty);
      expect(SettlementCalculator.computePairBalances(entries), isEmpty);
    });

    test('settling one participant does not clear another participant share', () {
      final expenses = [
        Expense(
          id: 'e-one-settled',
          desc: 'Dinner',
          amount: 100,
          payerId: 1,
          splitMap: {1: 40, 2: 30, 3: 30},
          settledBy: {1, 2},
        ),
      ];

      final balances = SettlementCalculator.computePairBalances(
        SettlementCalculator.deriveLedgerEntries(expenses),
      );

      expect(balances.length, 1);
      expect(balances.single.debtorId, 3);
      expect(balances.single.creditorId, 1);
      expect(balances.single.owedAmount, closeTo(30, 0.01));
    });
  });
}
