import 'package:flutter_test/flutter_test.dart';
import 'package:nus_nus/utils/money.dart';

void main() {
  group('MoneyUtils', () {
    test('converts valid amounts to whole cents', () {
      expect(MoneyUtils.toCents(12.34), 1234);
      expect(MoneyUtils.toCents(0.1 + 0.2), 30);
      expect(MoneyUtils.toCents(1), 100);
    });

    test('rounds user-entered precision to the nearest cent', () {
      expect(MoneyUtils.toCents(12.345), 1235);
      expect(MoneyUtils.toCents(12.344), 1234);
      expect(MoneyUtils.toCents(0.1 + 0.2), 30);
    });

    test('rejects only non-finite amounts', () {
      expect(MoneyUtils.toCents(double.nan), isNull);
      expect(MoneyUtils.toCents(double.infinity), isNull);
    });

    test('equal split allocates every cent without drift', () {
      final split = MoneyUtils.equalSplit(1000, [1, 2, 3]);
      expect(split, {1: 3.34, 2: 3.33, 3: 3.33});
      expect(split.values.fold<int>(0, (sum, value) =>
          sum + MoneyUtils.toCents(value)!), 1000);
    });

    test('empty equal split remains empty', () {
      expect(MoneyUtils.equalSplit(100, []), isEmpty);
    });
  });
}
