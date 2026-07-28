import 'dart:async';
import 'package:flutter/material.dart';
import '../data/firestore_repository.dart';
import '../data/member_directory_repository.dart';
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
  /// Metadata (name/members/ownership) for every group visible to the
  /// signed-in user, as last received from [FirestoreRepository.
  /// watchGroupsForUser] — expenses are *not* included here, they're
  /// merged in from [_expensesByGroup] before being exposed as [groups].
  List<Group> _groupMeta = [];

  /// Live expenses per group id, kept in sync by one subscription per
  /// visible group (see [_syncExpenseSubscriptions]).
  final Map<String, List<Expense>> _expensesByGroup = {};
  final Map<String, StreamSubscription<List<Expense>>> _expenseSubs = {};

  List<Group> _groups = [];
  String? _currentGroupId;
  bool _isLoading = true;
  String? _uid;

  /// The signed-in user's own registered display name, resolved from the
  /// member directory (the authoritative source — see [setUserId]) rather
  /// than trusted from FirebaseAuth's often-stale cached profile. Used as
  /// `ownerName` when creating a group and to auto-add the creator as a
  /// participant.
  String? _myDisplayName;

  StreamSubscription<List<Group>>? _groupsSub;

  String? get uid => _uid;
  bool get isLoading => _isLoading;

  /// Called by [AuthGate] whenever the signed-in user changes. Subscribes
  /// to every group that user can see (owned or linked-into) in real
  /// time, or clears everything back to a blank slate when [uid] is null
  /// (signed out).
  Future<void> setUserId(String? uid) async {
    if (_uid == uid) return;
    _uid = uid;
    await _groupsSub?.cancel();
    _groupsSub = null;
    for (final sub in _expenseSubs.values) {
      await sub.cancel();
    }
    _expenseSubs.clear();
    _expensesByGroup.clear();
    _myDisplayName = null;

    if (uid == null) {
      _groupMeta = [];
      _groups = [];
      _currentGroupId = null;
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    // Resolve the signed-in user's authoritative display name in the
    // background — the member directory (`users/{uid}`) is always correct
    // since it's written directly from the name typed at registration,
    // unlike FirebaseAuth's cached profile which can lag behind.
    MemberDirectoryRepository.instance.fetchByUid(uid).then((profile) {
      if (_uid != uid || profile == null || profile.name.isEmpty) return;
      _myDisplayName = profile.name;
    });

    _groupsSub = FirestoreRepository.instance.watchGroupsForUser(uid).listen(
      (loaded) => _onGroupMetaUpdated(loaded),
      onError: (_) {
        // Don't leave the user staring at a spinner forever if the
        // stream errors out (e.g. offline, permission issue) — fall back
        // to an empty, editable-nothing state so the UI can recover.
        _groupMeta = [];
        _rebuildGroups();
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  void _onGroupMetaUpdated(List<Group> loaded) {
    _groupMeta = loaded;
    _syncExpenseSubscriptions(loaded.map((g) => g.id).toSet());
    _rebuildGroups();
    _isLoading = false;
    notifyListeners();
  }

  /// Starts an expenses subscription for every newly-visible group and
  /// cancels the ones for groups that disappeared (deleted, or the
  /// signed-in user was removed from them).
  void _syncExpenseSubscriptions(Set<String> visibleGroupIds) {
    for (final groupId in visibleGroupIds) {
      if (_expenseSubs.containsKey(groupId)) continue;
      _expenseSubs[groupId] = FirestoreRepository.instance
          .watchExpenses(groupId)
          .listen((expenses) {
        _expensesByGroup[groupId] = expenses;
        _rebuildGroups();
        notifyListeners();
      }, onError: (e) {
        debugPrint('SplitProvider: Expense stream error for $groupId: $e');
        // If the stream fails (e.g. permission lag for a newly added member),
        // clear the stale subscription so we can try again.
        _expenseSubs.remove(groupId)?.cancel();
        _expensesByGroup.remove(groupId);
        _rebuildGroups();
        notifyListeners();

        // Proactive retry after a short delay to account for Firestore
        // permission propagation lag.
        Future.delayed(const Duration(seconds: 2), () {
          if (_uid != null && _groupMeta.any((g) => g.id == groupId)) {
            _syncExpenseSubscriptions(_groupMeta.map((g) => g.id).toSet());
          }
        });
      });
    }

    final stale = _expenseSubs.keys
        .where((id) => !visibleGroupIds.contains(id))
        .toList();
    for (final id in stale) {
      _expenseSubs.remove(id)?.cancel();
      _expensesByGroup.remove(id);
    }
  }

  /// Recombines the latest group metadata with whatever expenses are
  /// cached for each group, keeping the current selection stable where
  /// possible.
  void _rebuildGroups() {
    final merged = _groupMeta
        .map((g) => g.copyWith(expenses: _expensesByGroup[g.id] ?? const []))
        .toList();

    merged.sort((a, b) {
      final aOwned = a.ownerId == _uid;
      final bOwned = b.ownerId == _uid;
      if (aOwned != bOwned) return aOwned ? -1 : 1; // owned groups first
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    _groups = merged;

    // Keep the current selection if it still exists; otherwise fall back
    // to the first owned group, then the first linked group, then empty.
    if (_currentGroupId == null ||
        !_groups.any((g) => g.id == _currentGroupId)) {
      _currentGroupId = _groups.isNotEmpty ? _groups.first.id : null;
    }
  }

  @override
  void dispose() {
    _groupsSub?.cancel();
    for (final sub in _expenseSubs.values) {
      sub.cancel();
    }
    super.dispose();
  }

  List<Group> get groups => List.unmodifiable(_groups);
  List<Group> get ownedGroups =>
      _groups.where((g) => g.ownerId == _uid).toList();
  List<Group> get linkedGroups =>
      _groups.where((g) => g.ownerId != _uid).toList();

  Group? get currentGroup {
    if (_currentGroupId == null) return null;
    for (final g in _groups) {
      if (g.id == _currentGroupId) return g;
    }
    return null;
  }

  /// Whether the signed-in user created the currently open group. The
  /// creator is the only one who can rename/delete the group, manage its
  /// member list, edit or delete an expense, or settle a balance up.
  bool get isCurrentGroupOwner =>
      currentGroup != null && currentGroup!.ownerId == _uid;

  void selectGroup(String groupId) {
    if (_groups.any((g) => g.id == groupId)) {
      _currentGroupId = groupId;
      notifyListeners();
    }
  }

  void addGroup(String name, {String? ownerName, String currency = 'AED'}) {
    final uid = _uid;
    if (uid == null) return;
    // Prefer the authoritative name resolved from the member directory —
    // it's always correct. The caller-supplied [ownerName] (typically
    // read straight off FirebaseAuth, which can lag behind) is only used
    // as a stand-in for the rare case the directory lookup hasn't
    // resolved yet.
    final resolvedOwnerName = (_myDisplayName != null && _myDisplayName!.isNotEmpty)
        ? _myDisplayName!
        : (ownerName ?? '');

    // Splitwise-style default: the creator is a participant in their own
    // group from the start, not just an admin looking in from outside —
    // otherwise they'd have to manually add themselves before they could
    // be included in any expense.
    final me = Person(
      id: 1,
      name: resolvedOwnerName.isEmpty ? 'You' : resolvedOwnerName,
      color: AppColors.avatarColorFor(0),
      linkedUserId: uid,
    );

    final group = Group(
      id: FirestoreRepository.instance.newGroupId(),
      name: name.trim().isEmpty ? 'New Group' : name.trim(),
      currency: currency,
      ownerId: uid,
      ownerName: resolvedOwnerName,
      members: [me],
      expenses: const [],
    );
    _groupMeta = [..._groupMeta, group];
    _rebuildGroups();
    _currentGroupId = group.id;
    notifyListeners();
    FirestoreRepository.instance.saveGroupMeta(group);
  }

  /// Deletes a group entirely (including its people/expenses). Only the
  /// creator can do this. If the deleted group was the one currently
  /// open, falls back to another visible group, or the empty state if
  /// none are left.
  void removeGroup(String groupId) {
    final idx = _groupMeta.indexWhere((g) => g.id == groupId);
    if (idx == -1) return;
    if (_groupMeta[idx].ownerId != _uid) return; // not the creator

    _groupMeta = [..._groupMeta]..removeAt(idx);
    _rebuildGroups();
    notifyListeners();
    FirestoreRepository.instance.deleteGroup(groupId);
  }

  void renameGroup(String groupId, String newName, {String? newCurrency}) {
    final idx = _groupMeta.indexWhere((g) => g.id == groupId);
    if (idx == -1 || newName.trim().isEmpty) return;
    if (_groupMeta[idx].ownerId != _uid) return; // not the creator
    final updated = _groupMeta[idx].copyWith(
      name: newName.trim(),
      currency: newCurrency,
    );
    _groupMeta = [..._groupMeta];
    _groupMeta[idx] = updated;
    _rebuildGroups();
    notifyListeners();
    FirestoreRepository.instance.saveGroupMeta(updated);
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

  /// Finds the member of the current group whose registered account is
  /// [uid], if any — used to show "Added by X" against an expense from
  /// its `addedBy` uid without an extra Firestore lookup, since whoever
  /// added an expense must already be a member of the group.
  Person? personByUid(String? uid) {
    if (uid == null) return null;
    for (final p in allPeople) {
      if (p.linkedUserId == uid) return p;
    }
    return null;
  }

  /// Smallest id not already used by a member of [group] — person ids
  /// only need to be unique within a single group.
  int _nextPersonId(Group group) {
    int maxId = 0;
    for (final p in group.members) {
      if (p.id > maxId) maxId = p.id;
    }
    return maxId + 1;
  }

  int get _currentGroupMetaIndex =>
      _groupMeta.indexWhere((g) => g.id == _currentGroupId);

  void addPerson(String name, {String? linkedUserId}) {
    final group = currentGroup;
    if (group == null || group.ownerId != _uid) return;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    if (linkedUserId != null &&
        allPeople.any((p) => p.linkedUserId == linkedUserId && !p.archived)) {
      return; // already a member of this group
    }

    final newPerson = Person(
      id: _nextPersonId(group),
      name: trimmed,
      color: AppColors.avatarColorFor(allPeople.length),
      linkedUserId: linkedUserId,
    );

    final updatedMembers = [...allPeople, newPerson];
    _updateGroupMeta(group.copyWith(members: updatedMembers));
  }

  /// Returns true if the person was soft-deleted (had history) rather than
  /// fully removed, so the caller can tell the user what happened.
  bool removePerson(int id) {
    final group = currentGroup;
    if (group == null || group.ownerId != _uid) return false;

    final hasHistory = expenses.any(
      (e) => e.payerId == id || e.splitMap.containsKey(id),
    );

    final updatedMembers = allPeople.map((p) {
      if (p.id != id) return p;
      return hasHistory ? p.copyWith(archived: true) : p;
    }).where((p) => hasHistory ? true : p.id != id).toList();

    _updateGroupMeta(group.copyWith(members: updatedMembers));
    return hasHistory;
  }

  /// Applies a metadata-only change (name/members) to the current group:
  /// updates local state, rebuilds, notifies, and persists — the shared
  /// tail end of every member-list mutator above.
  void _updateGroupMeta(Group updated) {
    _groupMeta = [..._groupMeta];
    _groupMeta[_currentGroupMetaIndex] = updated;
    _rebuildGroups();
    notifyListeners();
    FirestoreRepository.instance.saveGroupMeta(updated);
  }

  /// Returns a `Map<int, double>` split map on success, or a `String` error
  /// message on failure. (Small internal helper, not worth a sealed
  /// Result type for two call sites.)
  dynamic _buildSplitMap({
    required double amount,
    required Set<int> splitWith,
    required String currency,
    Map<int, double>? customSplits,
  }) {
    if (customSplits != null && customSplits.isNotEmpty) {
      double sum = customSplits.values.fold(0, (a, b) => a + b);
      if ((sum - amount).abs() > 0.01) {
        return 'Sum of splits (${fmtCurrency(sum, currency)}) must equal total (${fmtCurrency(amount, currency)})';
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

  /// Returns null on success, or an error message. Any member of the
  /// group can log a new expense — not just the creator — the same way
  /// Splitwise lets any participant add one. Editing or deleting an
  /// existing expense is still creator-only; see [editExpense] and
  /// [removeExpense].
  String? addExpense({
    required String desc,
    required double? amount,
    required int? payerId,
    required Set<int> splitWith,
    Map<int, double>? customSplits,
    bool isSettlement = false,
  }) {
    final group = currentGroup;
    if (group == null) return 'Select a group first.';
    if (!group.memberUids.contains(_uid)) {
      return "You're not a member of this group.";
    }
    if (amount == null || amount <= 0) return 'Enter a valid amount.';
    if (payerId == null) return 'Add at least one person first.';
    if (splitWith.isEmpty) return 'Pick who this should be split between.';

    final splitResult = _buildSplitMap(
      amount: amount,
      splitWith: splitWith,
      currency: group.currency,
      customSplits: customSplits,
    );
    if (splitResult is String) return splitResult; // error message
    final finalSplitMap = splitResult as Map<int, double>;

    final newExpense = Expense(
      id: FirestoreRepository.instance.newExpenseId(group.id),
      desc: desc.trim().isEmpty
          ? (isSettlement ? 'Settlement' : 'Untitled expense')
          : desc.trim(),
      amount: amount,
      payerId: payerId,
      splitMap: finalSplitMap,
      isSettlement: isSettlement,
      addedBy: _uid,
    );

    _expensesByGroup[group.id] = [...expenses, newExpense];
    _rebuildGroups();
    notifyListeners();
    FirestoreRepository.instance.createExpense(group.id, newExpense);
    return null;
  }

  /// Records that [fromId] paid [toId] [amount] to settle up, in
  /// [groupId] (defaults to the currently open group). This is the single
  /// place that decides who's allowed to confirm a settlement — both the
  /// per-group Balances tab *and* the cross-group Overview's "settle all
  /// dues" go through this, so the same rule (only the group's creator or
  /// the person actually being paid can confirm) applies everywhere,
  /// rather than the two surfaces silently drifting apart.
  String? settleUp(int fromId, int toId, double amount, {String? groupId}) {
    final targetId = groupId ?? currentGroup?.id;
    if (targetId == null) return 'Select a group first.';
    if (amount <= 0) return 'Enter a valid amount.';

    Group? group;
    for (final g in _groups) {
      if (g.id == targetId) {
        group = g;
        break;
      }
    }
    if (group == null) return 'Could not find that group.';

    Person? fromPerson;
    Person? toPerson;
    for (final p in group.members) {
      if (p.id == fromId) fromPerson = p;
      if (p.id == toId) toPerson = p;
    }
    if (fromPerson == null || toPerson == null) {
      return 'Could not find one of the people in this settlement.';
    }

    // Permission check: only the group owner OR the person being paid
    // (creditor) can officially record this settlement — a debtor can't
    // unilaterally mark their own debt as paid without the creditor (or
    // the group owner) confirming it.
    final isOwner = group.ownerId == _uid;
    final isCreditor = toPerson.linkedUserId == _uid;

    if (!isOwner && !isCreditor) {
      return 'Only ${toPerson.name} or the group creator can settle this up.';
    }

    if (!group.memberUids.contains(_uid)) {
      return "You're not a member of this group.";
    }

    final newExpense = Expense(
      id: FirestoreRepository.instance.newExpenseId(group.id),
      desc: '${fromPerson.name} settled with ${toPerson.name}',
      amount: amount,
      payerId: fromId,
      splitMap: {toId: amount},
      isSettlement: true,
      addedBy: _uid,
    );

    _expensesByGroup[group.id] = [
      ...(_expensesByGroup[group.id] ?? const []),
      newExpense,
    ];
    _rebuildGroups();
    notifyListeners();
    FirestoreRepository.instance.createExpense(group.id, newExpense);
    return null;
  }

  /// deleting an expense someone else logged (or your own) is a destructive
  /// action, so it's kept restricted to whoever originally added it.
  void removeExpense(String id) {
    final group = currentGroup;
    if (group == null) return;
    
    final existingIndex = expenses.indexWhere((e) => e.id == id);
    if (existingIndex == -1) return;
    
    final expense = expenses[existingIndex];
    if (expense.addedBy != _uid) return; // not the person who added it

    _expensesByGroup[group.id] = expenses.where((e) => e.id != id).toList();
    _rebuildGroups();
    notifyListeners();
    FirestoreRepository.instance.deleteExpense(group.id, id);
  }

  /// RESTRICTED TO THE CREATOR of the expense, even if they aren't the group
  /// owner — see the class-level note on [removeExpense] for why editing
  /// stays this restrictive even though anyone can add.
  String? editExpense({
    required String id,
    required String desc,
    required double? amount,
    required int? payerId,
    required Set<int> splitWith,
    Map<int, double>? customSplits,
  }) {
    final group = currentGroup;
    if (group == null) return 'Select a group first.';

    final existingIndex = expenses.indexWhere((e) => e.id == id);
    if (existingIndex == -1) return 'That expense no longer exists.';

    final original = expenses[existingIndex];
    if (original.addedBy != _uid) {
      return 'Only the person who added this split can edit it.';
    }

    if (amount == null || amount <= 0) return 'Enter a valid amount.';
    if (payerId == null) return 'Add at least one person first.';
    if (splitWith.isEmpty) return 'Pick who this should be split between.';

    final finalSplitMap = _buildSplitMap(
      amount: amount,
      splitWith: splitWith,
      currency: group.currency,
      customSplits: customSplits,
    );
    if (finalSplitMap is String) return finalSplitMap; // error message

    final updatedExpense = original.copyWith(
      desc: desc.trim().isEmpty ? original.desc : desc.trim(),
      amount: amount,
      payerId: payerId,
      splitMap: finalSplitMap as Map<int, double>,
    );

    final updatedExpenses = [...expenses];
    updatedExpenses[existingIndex] = updatedExpense;
    _expensesByGroup[group.id] = updatedExpenses;
    _rebuildGroups();
    notifyListeners();
    FirestoreRepository.instance.updateExpense(group.id, updatedExpense);
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

  /// Aggregated net balance per currency across EVERY group the signed-in 
  /// user is a member of.
  Map<String, double> get globalNetStandings {
    final standings = <String, double>{};
    final mine = myBalancesByPerson();
    for (final person in mine) {
      person.currencyBalances.forEach((currency, amount) {
        standings[currency] = (standings[currency] ?? 0) + amount;
      });
    }
    return standings;
  }

  // -- Cross-group overview ------------------------------------------------

  /// The signed-in user's *own* balance with each other person, combined
  /// across every group they're a participant in (owned or linked-into).
  /// Unlike a naive "everyone's balance in every group" aggregate, this
  /// only ever includes pairs that involve the signed-in user, so what's
  /// shown is exactly "who owes me" and "who I owe" — nothing about how
  /// other members stand with each other.
  ///
  /// A person is matched across groups by their registered uid when
  /// available, falling back to a case-insensitive name match for people
  /// who were only ever added as a free-text label (no shared identity
  /// otherwise exists for those).
  List<OverallBalance> myBalancesByPerson() {
    final uid = _uid;
    if (uid == null) return [];

    final displayNames = <String, String>{};
    final groupCounts = <String, int>{};
    final breakdowns = <String, List<GroupContribution>>{};
    final currencyMaps = <String, Map<String, double>>{};

    for (final g in _groups) {
      final mine = g.members.where((p) => p.linkedUserId == uid).toList();
      if (mine.isEmpty) continue; // not a participant in this group
      final myId = mine.first.id;

      final pairs = SettlementCalculator.computePairBalances(
        SettlementCalculator.deriveLedgerEntries(g.expenses),
      );

      final seenInThisGroup = <String>{};
      for (final pb in pairs) {
        if (pb.personAId != myId && pb.personBId != myId) continue;
        final counterpartId =
            pb.personAId == myId ? pb.personBId : pb.personAId;
        Person? counterpart;
        for (final p in g.members) {
          if (p.id == counterpartId) {
            counterpart = p;
            break;
          }
        }
        if (counterpart == null) continue;

        // PairBalance convention: amount > 0 means personA owes personB.
        // Flip to "from my perspective": positive = they owe me.
        final signedFromMe = pb.personAId == myId ? -pb.amount : pb.amount;

        final key = counterpart.linkedUserId ??
            'name:${counterpart.name.trim().toLowerCase()}';
        
        displayNames.putIfAbsent(key, () => counterpart!.name.trim());
        if (seenInThisGroup.add(key)) {
          groupCounts[key] = (groupCounts[key] ?? 0) + 1;
        }

        if (signedFromMe.abs() > 0.005) {
          currencyMaps.putIfAbsent(key, () => {})[g.currency] = 
              (currencyMaps[key]![g.currency] ?? 0) + signedFromMe;

          breakdowns.putIfAbsent(key, () => []).add(
                GroupContribution(
                  groupId: g.id,
                  groupName: g.name,
                  currency: g.currency,
                  amount: signedFromMe,
                  myId: myId,
                  counterpartId: counterpartId,
                ),
              );
        }
      }
    }

    final result = displayNames.keys
        .map((key) => OverallBalance(
              key: key,
              name: displayNames[key]!,
              groupCount: groupCounts[key] ?? 0,
              currencyBalances: currencyMaps[key] ?? {},
              breakdown: breakdowns[key] ?? [],
            ))
        .where((o) => o.breakdown.isNotEmpty) // Only show people with active history
        .toList();

    result.sort((a, b) => b.primarySortAmount.compareTo(a.primarySortAmount));
    return result;
  }

  /// Settles all shared dues with a specific person across every group they
  /// share. Returns a list of error messages (empty on total success).
  ///
  /// Deliberately calls [settleUp] per group rather than writing the
  /// settlement expense directly — that's what makes "settle up from here
  /// owes you, that side is enforced the same way everywhere, not just in
  /// this specific group's Balances tab.
  Future<List<String>> settlePairwise(OverallBalance entry) async {
    final errors = <String>[];

    for (final contrib in entry.breakdown) {
      if (contrib.amount.abs() <= 0.005) continue;

      // Settlement record logic:
      // If amount > 0 (they owe you), then record that THEY paid YOU.
      // If amount < 0 (you owe them), then record that YOU paid THEM.
      final fromId = contrib.amount > 0 ? contrib.counterpartId : contrib.myId;
      final toId = contrib.amount > 0 ? contrib.myId : contrib.counterpartId;

      final error = settleUp(
        fromId,
        toId,
        contrib.amount.abs(),
        groupId: contrib.groupId,
      );
      if (error != null) {
        errors.add('"${contrib.groupName}": $error');
      }
      // No manual local-state update needed on success — the Firestore
      // stream for that group picks up the new expense and rebuilds.
    }

    return errors;
  }

}

class GroupContribution {
  final String groupId;
  final String groupName;
  final String currency;
  final double amount;
  final int myId;
  final int counterpartId;

  GroupContribution({
    required this.groupId,
    required this.groupName,
    required this.currency,
    required this.amount,
    required this.myId,
    required this.counterpartId,
  });
}

/// One other person's net balance against the signed-in user, summed
/// across every group they share.
class OverallBalance {
  final String key; // Unique identifier (UID or name-key)
  final String name;
  final int groupCount;
  final List<GroupContribution> breakdown;

  /// Net balance keyed by currency code (e.g. {'AED': 500, 'USD': -20})
  final Map<String, double> currencyBalances;

  OverallBalance({
    required this.key,
    required this.name,
    required this.groupCount,
    this.currencyBalances = const {},
    this.breakdown = const [],
  });

  /// Helpful for sorting: returns the maximum absolute balance across all currencies.
  double get primarySortAmount {
    if (currencyBalances.isEmpty) return 0;
    double maxAbs = 0;
    for (final amt in currencyBalances.values) {
      if (amt.abs() > maxAbs) maxAbs = amt.abs();
    }
    return maxAbs;
  }
}
