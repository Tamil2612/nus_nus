import 'package:flutter/material.dart';
import '../models/expense.dart';
import '../models/person.dart';
import '../models/transfer.dart';
import '../models/group.dart';
import '../theme/app_colors.dart';
import '../utils/settlement_calculator.dart';
import '../utils/currency_formatter.dart';

class SplitProvider extends ChangeNotifier {
  final List<Group> _groups = [];
  int _currentGroupIndex = -1;
  int _nextId = 1;

  List<Group> get groups => List.unmodifiable(_groups);
  
  Group? get currentGroup => 
      _currentGroupIndex >= 0 && _currentGroupIndex < _groups.length 
          ? _groups[_currentGroupIndex] 
          : null;

  void selectGroup(int index) {
    if (index >= 0 && index < _groups.length) {
      _currentGroupIndex = index;
      notifyListeners();
    }
  }

  void addGroup(String name) {
    final group = Group(
      id: _nextId++,
      name: name.trim().isEmpty ? 'New Group' : name.trim(),
      members: [],
      expenses: [],
    );
    _groups.add(group);
    if (_groups.length == 1) _currentGroupIndex = 0;
    notifyListeners();
  }

  // Getters for current group data
  List<Person> get people => currentGroup?.members ?? [];
  List<Expense> get expenses => currentGroup?.expenses ?? [];
  double get totalSpent => expenses.fold(0.0, (s, e) => s + e.amount);
  int get expenseCount => expenses.length;

  Person? personById(int id) {
    for (final p in people) {
      if (p.id == id) return p;
    }
    return null;
  }

  void addPerson(String name) {
    if (currentGroup == null) return;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    
    final newPerson = Person(
      id: _nextId++,
      name: trimmed,
      color: AppColors.avatarColorFor(people.length),
    );

    final updatedMembers = [...people, newPerson];
    _groups[_currentGroupIndex] = currentGroup!.copyWith(members: updatedMembers);
    notifyListeners();
  }

  void removePerson(int id) {
    if (currentGroup == null) return;

    final updatedMembers = people.where((p) => p.id != id).toList();
    
    final updatedExpenses = expenses.where((e) => e.payerId != id).map((e) {
      if (e.splitMap.containsKey(id)) {
        final newMap = Map<int, double>.from(e.splitMap)..remove(id);
        return e.copyWith(splitMap: newMap);
      }
      return e;
    }).toList();

    _groups[_currentGroupIndex] = currentGroup!.copyWith(
      members: updatedMembers,
      expenses: updatedExpenses,
    );
    notifyListeners();
  }

  /// Returns null on success, or an error message.
  String? addExpense({
    required String desc,
    required double? amount,
    required int? payerId,
    required Set<int> splitWith,
    Map<int, double>? customSplits,
    bool isSettlement = false,
  }) {
    if (currentGroup == null) return 'Select a group first.';
    if (amount == null || amount <= 0) return 'Enter a valid amount.';
    if (payerId == null) return 'Add at least one person first.';
    if (splitWith.isEmpty) return 'Pick who this should be split between.';

    Map<int, double> finalSplitMap = {};
    if (customSplits != null && customSplits.isNotEmpty) {
      double sum = customSplits.values.fold(0, (a, b) => a + b);
      if ((sum - amount).abs() > 0.01) {
        String msg = 'Sum of splits (${fmtAed(sum)}) must equal total (${fmtAed(amount)})';
        return msg;
      }
      finalSplitMap = customSplits;
    } else {
      double share = amount / splitWith.length;
      for (var id in splitWith) {
        finalSplitMap[id] = share;
      }
    }

    final newExpense = Expense(
      id: _nextId++,
      desc: desc.trim().isEmpty ? (isSettlement ? 'Settlement' : 'Untitled expense') : desc.trim(),
      amount: amount,
      payerId: payerId,
      splitMap: finalSplitMap,
      isSettlement: isSettlement,
    );

    final updatedExpenses = [...expenses, newExpense];
    _groups[_currentGroupIndex] = currentGroup!.copyWith(expenses: updatedExpenses);
    notifyListeners();
    return null;
  }

  void settleUp(int fromId, int toId, double amount) {
    if (currentGroup == null) return;
    
    final fromPerson = personById(fromId);
    final toPerson = personById(toId);
    if (fromPerson == null || toPerson == null) return;

    addExpense(
      desc: '${fromPerson.name} settled with ${toPerson.name}',
      amount: amount,
      payerId: fromId,
      splitWith: {toId},
      isSettlement: true,
    );
  }

  void removeExpense(int id) {
    if (currentGroup == null) return;
    final updatedExpenses = expenses.where((e) => e.id != id).toList();
    _groups[_currentGroupIndex] = currentGroup!.copyWith(expenses: updatedExpenses);
    notifyListeners();
  }

  Map<int, double> get balances => SettlementCalculator.computeBalances(
        personIds: people.map((p) => p.id).toList(),
        expenses: expenses,
      );

  List<Transfer> get settlement =>
      SettlementCalculator.computeSettlement(balances);
}
