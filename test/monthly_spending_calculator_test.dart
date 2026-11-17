import 'package:flutter_test/flutter_test.dart';
import 'package:nus_nus/models/expense.dart';
import 'package:nus_nus/models/group.dart';
import 'package:nus_nus/models/person.dart';
import 'package:nus_nus/services/monthly_spending_calculator.dart';
import 'package:nus_nus/models/monthly_budget.dart';
import 'package:flutter/material.dart';

void main() {
  final month = DateTime(2026, 11, 1);
  final me = Person(id: 1, name: 'Me', color: Colors.blue, linkedUserId: 'uid-me');
  final payer = Person(id: 2, name: 'Payer', color: Colors.red, linkedUserId: 'uid-payer');

  test('counts only current user share of shared expense, regardless of payer', () {
    final group = Group(
      id: 'g1', name: 'Flatmates', ownerId: 'uid-payer',
      members: [me, payer],
      expenses: [
        Expense(id: 'e1', desc: 'Groceries', amount: 300, payerId: 2,
          splitMap: {1: 120, 2: 180}, createdAt: DateTime(2026, 11, 4)),
      ],
    );
    final result = MonthlySpendingCalculator.calculate(
      groups: [group], uid: 'uid-me', month: month, currency: 'AED');
    expect(result.personal, 0);
    expect(result.shared, 120);
    expect(result.total, 120);
  });

  test('uses member category override before original expense category', () {
    final group = Group(
      id: 'g1', name: 'Flatmates', ownerId: 'uid-payer',
      members: [me, payer],
      expenses: [
        Expense(id: 'e1', desc: 'Groceries', amount: 300, payerId: 2,
          splitMap: {1: 120, 2: 180}, categoryId: 'shopping',
          createdAt: DateTime(2026, 11, 4)),
      ],
    );
    final result = MonthlySpendingCalculator.calculate(
      groups: [group], uid: 'uid-me', month: month, currency: 'AED',
      memberCategories: {'g1/e1': 'food'});
    expect(result.byCategory, {'food': 120});
  });

  test('excludes settlements and other months, and does not convert other currencies', () {
    final aedGroup = Group(
      id: 'g1', name: 'Flatmates', ownerId: 'uid-payer',
      members: [me, payer],
      expenses: [
        Expense(id: 'settle', desc: 'Settlement', amount: 50, payerId: 2,
          splitMap: {1: 50}, isSettlement: true, createdAt: DateTime(2026, 11, 4)),
        Expense(id: 'old', desc: 'Old', amount: 20, payerId: 2,
          splitMap: {1: 20}, createdAt: DateTime(2026, 10, 4)),
        Expense(id: 'valid', desc: 'Valid', amount: 20, payerId: 2,
          splitMap: {1: 20}, createdAt: DateTime(2026, 11, 4)),
      ],
    );
    final usdGroup = Group(
      id: 'g2', name: 'Trip', ownerId: 'uid-payer', currency: 'USD',
      members: [me, payer],
      expenses: [
        Expense(id: 'usd', desc: 'USD expense', amount: 90, payerId: 2,
          splitMap: {1: 90}, createdAt: DateTime(2026, 11, 4)),
      ],
    );
    final result = MonthlySpendingCalculator.calculate(
      groups: [aedGroup, usdGroup], uid: 'uid-me', month: month, currency: 'AED');
    expect(result.total, 20);
  });

  test('formats monthly budget key with leading zero', () {
    expect(MonthlyBudget.monthKey(DateTime(2026, 3, 2)), '2026-03');
  });
}
