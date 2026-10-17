import 'package:flutter_test/flutter_test.dart';
import 'package:nus_nus/models/expense.dart';
import 'package:nus_nus/models/settlement_record.dart';
import 'package:nus_nus/utils/settlement_calculator.dart';

SettlementRecord _record({
  bool reverted = false,
  List<String> uids = const ['debtor-uid', 'creditor-uid'],
}) =>
    SettlementRecord(
      id: 's1',
      groupId: 'g1',
      fromId: 2,
      toId: 1,
      amountCents: 6000,
      offsetCents: 4000,
      currency: 'AED',
      recordedBy: 'debtor-uid',
      participantUids: uids,
      reverted: reverted,
    );

void main() {
  group('Expense.isShareCoveredByPairSettlement', () {
    Expense dinner(Map<int, double> settled) => Expense(
          id: 'e1',
          desc: 'Dinner',
          amount: 100,
          payerId: 1,
          splitMap: {1: 50, 2: 50},
          settledAmounts: settled,
        );

    test('false when nothing has been settled', () {
      expect(dinner({}).isShareCoveredByPairSettlement(2), isFalse);
    });

    test('false for a partial settlement, so the creator can still forgive the rest', () {
      expect(dinner({2: 20}).isShareCoveredByPairSettlement(2), isFalse);
    });

    test('true once the whole share is covered', () {
      expect(dinner({2: 50}).isShareCoveredByPairSettlement(2), isTrue);
    });

    test('false for people who are not part of the split', () {
      expect(dinner({9: 50}).isShareCoveredByPairSettlement(9), isFalse);
    });
  });

  group('Expense serialization', () {
    test('toJson writes settledBy as plain id strings Firestore can store', () {
      final json = Expense(
        id: 'e1',
        desc: 'Dinner',
        amount: 100,
        payerId: 1,
        splitMap: {1: 50, 2: 50},
        settledBy: {1, 2},
      ).toJson();
      expect(json['settledBy'], ['1', '2']);
    });
  });

  group('SettlementRecord', () {
    test('either person in the pair may undo an active settlement', () {
      final r = _record();
      expect(r.canBeUndoneBy('debtor-uid'), isTrue);
      expect(r.canBeUndoneBy('creditor-uid'), isTrue);
    });

    test('bystanders and signed-out users may not undo it', () {
      final r = _record();
      expect(r.canBeUndoneBy('someone-else'), isFalse);
      expect(r.canBeUndoneBy(null), isFalse);
    });

    test('an already undone settlement cannot be undone again', () {
      expect(_record(reverted: true).canBeUndoneBy('debtor-uid'), isFalse);
    });

    test('exposes amounts in major units', () {
      final r = _record();
      expect(r.amount, closeTo(60, 0.001));
      expect(r.offsetAmount, closeTo(40, 0.001));
    });
  });

  group('Settlement then undo (ledger view)', () {
    // B owes A 100 (e1, A paid). A owes B 40 (e2, B paid).
    List<Expense> expenses({
      Map<int, double> e1Settled = const {},
      Map<int, double> e2Settled = const {},
    }) =>
        [
          Expense(
            id: 'e1',
            desc: 'Dinner',
            amount: 100,
            payerId: 1,
            splitMap: {2: 100},
            settledAmounts: e1Settled,
          ),
          Expense(
            id: 'e2',
            desc: 'Taxi',
            amount: 40,
            payerId: 2,
            splitMap: {1: 40},
            settledAmounts: e2Settled,
          ),
        ];

    double netOwedByB(List<Expense> list) {
      final balances = SettlementCalculator.computePairBalances(
          SettlementCalculator.deriveLedgerEntries(list));
      if (balances.isEmpty) return 0;
      final b = balances.single;
      return b.debtorId == 2 ? b.owedAmount : -b.owedAmount;
    }

    test('before settling, B owes the net 60', () {
      expect(netOwedByB(expenses()), closeTo(60, 0.01));
    });

    test('after settling the full net, the pair is square', () {
      final settled = expenses(e1Settled: {2: 100}, e2Settled: {1: 40});
      expect(netOwedByB(settled), closeTo(0, 0.01));
    });

    test('undoing restores exactly the original balance', () {
      final undone = expenses(); // allocations removed
      expect(netOwedByB(undone), closeTo(60, 0.01));
    });

    test('a partial settlement leaves the remainder owed', () {
      // B pays 20 of the 60: the 40 offset is reconciled plus 20 of the 100.
      final partial = expenses(e1Settled: {2: 60}, e2Settled: {1: 40});
      expect(netOwedByB(partial), closeTo(40, 0.01));
    });
  });
}
