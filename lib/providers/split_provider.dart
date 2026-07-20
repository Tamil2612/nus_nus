import 'package:flutter/material.dart';
import '../models/expense.dart';
import '../models/person.dart';
import '../models/transfer.dart';
import '../theme/app_colors.dart';
import '../utils/settlement_calculator.dart';

/// Holds all app state (people + expenses) and every mutation. Screens and
/// widgets should only ever read from here or call these methods — no
/// business logic belongs in the widget tree.
class SplitProvider extends ChangeNotifier {
  final List<Person> _people = [];
  final List<Expense> _expenses = [];
  int _nextId = 1;

  List<Person> get people => List.unmodifiable(_people);
  List<Expense> get expenses => List.unmodifiable(_expenses);

  double get totalSpent => _expenses.fold(0.0, (s, e) => s + e.amount);
  int get expenseCount => _expenses.length;

  Person? personById(int id) {
    for (final p in _people) {
      if (p.id == id) return p;
    }
    return null;
  }

  void addPerson(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    _people.add(Person(
      id: _nextId++,
      name: trimmed,
      color: AppColors.avatarColorFor(_people.length),
    ));
    notifyListeners();
  }

  void removePerson(int id) {
    _people.removeWhere((p) => p.id == id);
    _expenses.removeWhere((e) => e.payerId == id);
    for (final e in _expenses) {
      e.splitWith.remove(id);
    }
    notifyListeners();
  }

  /// Returns null on success, or an error message to show the user.
  String? addExpense({
    required String desc,
    required double? amount,
    required int? payerId,
    required Set<int> splitWith,
  }) {
    if (amount == null || amount <= 0) return 'Enter a valid amount.';
    if (payerId == null) return 'Add at least one person first.';
    if (splitWith.isEmpty) {
      return 'Pick who this should be split between.';
    }

    _expenses.add(Expense(
      id: _nextId++,
      desc: desc.trim().isEmpty ? 'Untitled expense' : desc.trim(),
      amount: amount,
      payerId: payerId,
      splitWith: splitWith.toList(),
    ));
    notifyListeners();
    return null;
  }

  void removeExpense(int id) {
    _expenses.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  Map<int, double> get balances => SettlementCalculator.computeBalances(
        personIds: _people.map((p) => p.id).toList(),
        expenses: _expenses,
      );

  List<Transfer> get settlement =>
      SettlementCalculator.computeSettlement(balances);
}
