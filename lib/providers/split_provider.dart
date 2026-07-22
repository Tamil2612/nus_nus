import 'package:flutter/material.dart';
import '../data/firestore_repository.dart';
import '../models/expense.dart';
import '../models/ledger_entry.dart';
import '../models/pair_balance.dart';
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
  bool _isLoading = true;
  String? _uid;

  bool get isLoading => _isLoading;

  /// Called by [AuthGate] whenever the signed-in user changes. Loads that
  /// user's data from Firestore, or clears everything back to a blank
  /// slate when [uid] is null (signed out).
  Future<void> setUserId(String? uid) async {
    if (_uid == uid) return;
    _uid = uid;

    if (uid == null) {
      _groups.clear();
      _currentGroupIndex = -1;
      _nextId = 1;
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();
    await _loadFromCloud(uid);
  }

  Future<void> _loadFromCloud(String uid) async {
    final loaded = await FirestoreRepository.instance.loadAll(uid);
    _groups
      ..clear()
      ..addAll(loaded);

    int maxId = 0;
    for (final g in _groups) {
      if (g.id > maxId) maxId = g.id;
      for (final p in g.members) {
        if (p.id > maxId) maxId = p.id;
      }
      for (final e in g.expenses) {
        if (e.id > maxId) maxId = e.id;
      }
    }
    _nextId = maxId + 1;
    _currentGroupIndex = _groups.isNotEmpty ? 0 : -1;
    _isLoading = false;
    notifyListeners();
  }

  /// Fire-and-forget persistence: the in-memory state is already the
  /// source of truth for the UI (notifyListeners happens synchronously in
  /// every mutator), this just mirrors it to Firestore in the background.
  void _persist() {
    final uid = _uid;
    if (uid == null) return; // not signed in yet — nothing to save to
    FirestoreRepository.instance.saveAll(uid, _groups);
  }

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
    // Always jump to the group that was just created, not only the first one.
    _currentGroupIndex = _groups.length - 1;
    notifyListeners();
    _persist();
  }

  /// Deletes a group entirely (including its people/expenses). If the
  /// deleted group was the one currently open, falls back to the most
  /// recent remaining group, or the empty state if none are left.
  void removeGroup(int groupId) {
    final removingCurrent = currentGroup?.id == groupId;
    final removedIndex = _groups.indexWhere((g) => g.id == groupId);
    if (removedIndex == -1) return;

    _groups.removeAt(removedIndex);

    if (_groups.isEmpty) {
      _currentGroupIndex = -1;
    } else if (removingCurrent) {
      _currentGroupIndex = (removedIndex - 1).clamp(0, _groups.length - 1);
    } else if (removedIndex < _currentGroupIndex) {
      _currentGroupIndex -= 1;
    }
    notifyListeners();
    _persist();
  }

  void renameGroup(int groupId, String newName) {
    final idx = _groups.indexWhere((g) => g.id == groupId);
    if (idx == -1 || newName.trim().isEmpty) return;
    _groups[idx] = _groups[idx].copyWith(name: newName.trim());
    notifyListeners();
    _persist();
  }

  // Getters for current group data --------------------------------------

  /// Active (non-archived) members — use this for "who paid" / "split
  /// between" pickers and the member chip list.
  List<Person> get people =>
      (currentGroup?.members ?? []).where((p) => !p.archived).toList();

  /// Every member ever added to this group, including soft-deleted ones —
  /// use this for name/color lookups so history never shows "?".
  List<Person> get allPeople => currentGroup?.members ?? [];

  List<Expense> get expenses => currentGroup?.expenses ?? [];
  double get totalSpent => expenses
      .where((e) => !e.isSettlement)
      .fold(0.0, (s, e) => s + e.amount);
  int get expenseCount => expenses.where((e) => !e.isSettlement).length;

  Person? personById(int id) {
    for (final p in allPeople) {
      if (p.id == id) return p;
    }
    return null;
  }

  void addPerson(String name, {String? linkedUserId}) {
    if (currentGroup == null) return;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    if (linkedUserId != null &&
        allPeople.any((p) => p.linkedUserId == linkedUserId && !p.archived)) {
      return; // already a member of this group
    }

    final newPerson = Person(
      id: _nextId++,
      name: trimmed,
      color: AppColors.avatarColorFor(allPeople.length),
      linkedUserId: linkedUserId,
    );

    final updatedMembers = [...allPeople, newPerson];
    _groups[_currentGroupIndex] =
        currentGroup!.copyWith(members: updatedMembers);
    notifyListeners();
    _persist();
  }

  /// Returns true if the person was soft-deleted (had history) rather than
  /// fully removed, so the caller can tell the user what happened.
  bool removePerson(int id) {
    if (currentGroup == null) return false;

    final hasHistory = expenses.any(
      (e) => e.payerId == id || e.splitMap.containsKey(id),
    );

    final updatedMembers = allPeople.map((p) {
      if (p.id != id) return p;
      return hasHistory ? p.copyWith(archived: true) : p;
    }).where((p) => hasHistory ? true : p.id != id).toList();

    _groups[_currentGroupIndex] =
        currentGroup!.copyWith(members: updatedMembers);
    notifyListeners();
    _persist();
    return hasHistory;
  }

  /// Returns a `Map<int, double>` split map on success, or a `String` error
  /// message on failure. (Small internal helper, not worth a sealed
  /// Result type for two call sites.)
  dynamic _buildSplitMap({
    required double amount,
    required Set<int> splitWith,
    Map<int, double>? customSplits,
  }) {
    if (customSplits != null && customSplits.isNotEmpty) {
      double sum = customSplits.values.fold(0, (a, b) => a + b);
      if ((sum - amount).abs() > 0.01) {
        return 'Sum of splits (${fmtAed(sum)}) must equal total (${fmtAed(amount)})';
      }
      return customSplits;
    }

    // Round each share to the cent, then hand any leftover cent(s) from
    // rounding to the first split members so the map always sums back
    // to exactly `amount` instead of drifting with repeating decimals.
    final ids = splitWith.toList();
    final baseShare = ((amount / ids.length) * 100).floor() / 100;
    double allocated = baseShare * ids.length;
    double remainder = (((amount - allocated) * 100).round()) / 100;
    final map = <int, double>{};
    for (final id in ids) {
      double share = baseShare;
      if (remainder > 0) {
        share += 0.01;
        remainder = (((remainder - 0.01) * 100).round()) / 100;
      }
      map[id] = share;
    }
    return map;
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

    final splitResult = _buildSplitMap(
      amount: amount,
      splitWith: splitWith,
      customSplits: customSplits,
    );
    if (splitResult is String) return splitResult; // error message
    final finalSplitMap = splitResult as Map<int, double>;

    final newExpense = Expense(
      id: _nextId++,
      desc: desc.trim().isEmpty
          ? (isSettlement ? 'Settlement' : 'Untitled expense')
          : desc.trim(),
      amount: amount,
      payerId: payerId,
      splitMap: finalSplitMap,
      isSettlement: isSettlement,
    );

    final updatedExpenses = [...expenses, newExpense];
    _groups[_currentGroupIndex] =
        currentGroup!.copyWith(expenses: updatedExpenses);
    notifyListeners();
    _persist();
    return null;
  }

  /// Records that [fromId] paid [toId] [amount] to settle up. This is the
  /// action behind the "Settle up" buttons in the Balances tab.
  String? settleUp(int fromId, int toId, double amount) {
    if (currentGroup == null) return 'Select a group first.';

    final fromPerson = personById(fromId);
    final toPerson = personById(toId);
    if (fromPerson == null || toPerson == null) {
      return 'Could not find one of the people in this settlement.';
    }

    return addExpense(
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
    _groups[_currentGroupIndex] =
        currentGroup!.copyWith(expenses: updatedExpenses);
    notifyListeners();
    _persist();
  }

  String? editExpense({
    required int id,
    required String desc,
    required double? amount,
    required int? payerId,
    required Set<int> splitWith,
    Map<int, double>? customSplits,
  }) {
    if (currentGroup == null) return 'Select a group first.';
    final existingIndex = expenses.indexWhere((e) => e.id == id);
    if (existingIndex == -1) return 'That expense no longer exists.';
    if (amount == null || amount <= 0) return 'Enter a valid amount.';
    if (payerId == null) return 'Add at least one person first.';
    if (splitWith.isEmpty) return 'Pick who this should be split between.';

    final finalSplitMap = _buildSplitMap(
      amount: amount,
      splitWith: splitWith,
      customSplits: customSplits,
    );
    if (finalSplitMap is String) return finalSplitMap; // error message

    final original = expenses[existingIndex];
    final updated = original.copyWith(
      desc: desc.trim().isEmpty ? original.desc : desc.trim(),
      amount: amount,
      payerId: payerId,
      splitMap: finalSplitMap as Map<int, double>,
    );

    final updatedExpenses = [...expenses];
    updatedExpenses[existingIndex] = updated;
    _groups[_currentGroupIndex] =
        currentGroup!.copyWith(expenses: updatedExpenses);
    notifyListeners();
    _persist();
    return null;
  }

  /// Every ledger entry derived from the current group's expenses. See
  /// [SettlementCalculator.deriveLedgerEntries] for the derivation rules.
  List<LedgerEntry> get ledgerEntries =>
      SettlementCalculator.deriveLedgerEntries(expenses);

  /// The net debt between every pair of people who have ever transacted in
  /// this group — this is the "who specifically owes whom" detail (e.g.
  /// "Tamilarasan is owed: Pushpa AED 15.50, Nivetha AED 48.60") that a
  /// flat net-balance map can't express.
  List<PairBalance> get pairBalances =>
      SettlementCalculator.computePairBalances(ledgerEntries);

  /// Balances keyed by person id, computed over *every* member who has ever
  /// been part of this group (including archived/removed ones still owed
  /// or owing money), not just the currently-active roster.
  Map<int, double> get balances {
    final net = <int, double>{for (final p in allPeople) p.id: 0.0};
    SettlementCalculator.computeNetBalances(pairBalances).forEach((id, amt) {
      net[id] = (net[id] ?? 0) + amt;
    });
    return net;
  }

  /// For a given person, who they're owed by and how much each owes —
  /// the breakdown behind "is owed AED 64.10" in the summary row.
  List<PairBalance> owedToPerson(int personId) =>
      pairBalances.where((pb) => pb.creditorId == personId).toList();

  /// For a given person, who they owe and how much.
  List<PairBalance> owedByPerson(int personId) =>
      pairBalances.where((pb) => pb.debtorId == personId).toList();

  List<Transfer> get settlement =>
      SettlementCalculator.computeSettlement(balances);

  // -- Cross-group overview ------------------------------------------------

  /// Aggregates every person's net balance across *all* groups, matched by
  /// name (there's no global "contact" identity — a person is scoped to a
  /// group — so two people named "Sara" in different groups are treated as
  /// the same person here). Returns entries sorted by the size of the
  /// balance, largest first.
  List<OverallBalance> get overallBalancesByName {
    final totals = <String, double>{};
    final displayNames = <String, String>{};
    final groupCounts = <String, int>{};

    for (final g in _groups) {
      final net = SettlementCalculator.computeBalances(
        personIds: g.members.map((p) => p.id).toList(),
        expenses: g.expenses,
      );
      final seenInThisGroup = <String>{};
      for (final p in g.members) {
        final key = p.name.trim().toLowerCase();
        if (key.isEmpty) continue;
        totals[key] = (totals[key] ?? 0) + (net[p.id] ?? 0);
        displayNames.putIfAbsent(key, () => p.name.trim());
        if (seenInThisGroup.add(key)) {
          groupCounts[key] = (groupCounts[key] ?? 0) + 1;
        }
      }
    }

    final result = totals.entries
        .map((e) => OverallBalance(
              name: displayNames[e.key] ?? e.key,
              amount: e.value,
              groupCount: groupCounts[e.key] ?? 0,
            ))
        .toList();
    result.sort((a, b) => b.amount.abs().compareTo(a.amount.abs()));
    return result;
  }
}

/// A person's net balance summed across every group they appear in.
class OverallBalance {
  final String name;
  final double amount; // positive = owed overall, negative = owes overall
  final int groupCount;

  OverallBalance({
    required this.name,
    required this.amount,
    required this.groupCount,
  });
}
