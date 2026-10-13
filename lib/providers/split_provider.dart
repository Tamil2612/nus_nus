import 'dart:async';
import 'dart:convert';
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
import '../services/notification_service.dart';

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

  bool _personalEnsured = false;
  String? _writeError;

  /// Returns (and clears) the last failed-save message so the UI can show it.
  String? takeWriteError() {
    final e = _writeError;
    _writeError = null;
    return e;
  }

  /// Runs a Firestore write whose result the UI doesn't wait for. A failure
  /// no longer goes unhandled: it records a message and re-subscribes so the
  /// local optimistic state is replaced by what the server really has.
  void _persist(Future<void> write, {bool resync = true}) {
    write.catchError((Object e) {
      debugPrint('SplitProvider: save failed: $e');
      _writeError = "Couldn't save your last change. It was reverted.";
      final uid = _uid;
      if (resync && uid != null) {
        _uid = null;
        setUserId(uid);
      }
      notifyListeners();
    });
  }

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
    _personalEnsured = false;

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

    // Trigger push notification permission request & FCM token registration
    NotificationService.instance.initialize(uid);

    // Resolve the signed-in user's authoritative display name in the
    // background — the member directory (`users/{uid}`) is always correct
    // since it's written directly from the name typed at registration,
    // unlike FirebaseAuth's cached profile which can lag behind.
    MemberDirectoryRepository.instance.fetchByUid(uid).then((profile) {
      if (_uid != uid || profile == null || profile.name.isEmpty) return;
      _myDisplayName = profile.name;
      notifyListeners();
    });

    _groupsSub = FirestoreRepository.instance.watchGroupsForUser(uid).listen(
          (loaded) {
        _onGroupMetaUpdated(loaded);
        _ensurePersonalGroupExists(uid, loaded);
      },
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
    final merged = _groupMeta.map((g) {
      final list = _expensesByGroup[g.id] ?? [];
      // Sort by timestamp if available, otherwise fallback to ID
      final sorted = List<Expense>.from(list)
        ..sort((a, b) {
          if (a.createdAt != null && b.createdAt != null) {
            return a.createdAt!.compareTo(b.createdAt!);
          }
          return a.id.compareTo(b.id);
        });
      return g.copyWith(expenses: sorted);
    }).toList();

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

  Group? get personalGroup {
    try {
      return _groups.firstWhere((g) => g.isPersonal && g.ownerId == _uid);
    } catch (_) {
      return null;
    }
  }

  List<Group> get sharedGroups =>
      _groups.where((g) => !g.isPersonal).toList();

  List<Group> get ownedGroups =>
      _groups.where((g) => g.ownerId == _uid && !g.isPersonal).toList();

  List<Group> get allOwnedGroups =>
      _groups.where((g) => g.ownerId == _uid).toList();

  List<Group> get linkedGroups =>
      _groups.where((g) => g.ownerId != _uid && !g.isPersonal).toList();

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
    final resolvedOwnerName = (_myDisplayName != null &&
        _myDisplayName!.isNotEmpty)
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
      name: name
          .trim()
          .isEmpty ? 'New Group' : name.trim(),
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
    _persist(FirestoreRepository.instance.saveGroupMeta(group));
  }

  void _ensurePersonalGroupExists(String uid, List<Group> loaded) {
    if (loaded.any((g) => g.isPersonal && g.ownerId == uid)) return;
    if (_personalEnsured) return;
    _personalEnsured = true;

    final resolvedOwnerName =
    (_myDisplayName != null && _myDisplayName!.isNotEmpty)
        ? _myDisplayName!
        : 'You';

    final me = Person(
      id: 1,
      name: resolvedOwnerName,
      color: AppColors.avatarColorFor(0),
      linkedUserId: uid,
    );

    final group = Group(
      id: 'personal_$uid',
      // Deterministic ID prevents duplicate creation
      name: 'My Expenses',
      isPersonal: true,
      ownerId: uid,
      ownerName: resolvedOwnerName,
      members: [me],
      expenses: const [],
    );
    // Don't need to add to local _groupMeta yet, the stream will catch it
    // after Firestore write. Create-only, so an existing group is never overwritten.
    FirestoreRepository.instance.ensurePersonalGroup(group).catchError((_) {
      _personalEnsured = false; // retry on the next stream emission
    });
  }

  /// Deletes a group entirely (including its people/expenses). Only the
  /// creator can do this. If the deleted group was the one currently
  /// open, falls back to another visible group, or the empty state if
  /// none are left.
  void removeGroup(String groupId) {
    final idx = _groupMeta.indexWhere((g) => g.id == groupId);
    if (idx == -1) return;
    if (_groupMeta[idx].ownerId != _uid) return; // not the creator
    if (_groupMeta[idx].isPersonal) {
      return; // Protect personal group from deletion
    }

    _groupMeta = [..._groupMeta]..removeAt(idx);
    _rebuildGroups();
    notifyListeners();
    _persist(FirestoreRepository.instance.deleteGroup(groupId));
  }

  void renameGroup(String groupId, String newName, {String? newCurrency}) {
    final idx = _groupMeta.indexWhere((g) => g.id == groupId);
    if (idx == -1 || newName.trim().isEmpty) {
      return;
    }
    if (_groupMeta[idx].ownerId != _uid) return; // not the creator
    final updated = _groupMeta[idx].copyWith(
      name: newName.trim(),
      currency: newCurrency,
    );
    _groupMeta = [..._groupMeta];
    _groupMeta[idx] = updated;
    _rebuildGroups();
    notifyListeners();
    _persist(FirestoreRepository.instance.saveGroupMeta(updated));
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

  double get totalSpent =>
      expenses
          .where((e) => !e.isSettlement)
          .fold(0.0, (s, e) => s + e.amount);

  int get expenseCount =>
      expenses
          .where((e) => !e.isSettlement)
          .length;

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
    _persist(FirestoreRepository.instance.saveGroupMeta(updated));
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
      if (customSplits.values.any((v) => v < 0)) {
        return "Shares can't be negative.";
      }
      final known = (currentGroup?.members ?? []).map((p) => p.id).toSet();
      if (!customSplits.keys.every(known.contains)) {
        return 'Someone in this split is not in the group.';
      }
      double sum = customSplits.values.fold(0, (a, b) => a + b);
      if ((sum - amount).abs() > 0.01) {
        return 'Sum of splits (${fmtCurrency(
            sum, currency)}) must equal total (${fmtCurrency(
            amount, currency)})';
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
    if (payerId == null) return 'Select who paid.';
    if (splitWith.isEmpty) return 'Pick who this should be split between.';

    final payerPerson = personById(payerId);
    if (payerPerson == null) return 'Select who paid.';

    // Payer lock: a split can only be logged by the person who paid. The
    // payer must be the signed-in user's own member entry in this group —
    // this also rules out logging on behalf of a name-only (unlinked)
    // member, which would otherwise bypass the lock.
    if (payerPerson.linkedUserId != _uid) {
      return 'You can only log expenses that you paid. '
          'Ask ${payerPerson.name} to add this split.';
    }

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
      desc: desc
          .trim()
          .isEmpty
          ? (isSettlement ? 'Settlement' : 'Untitled expense')
          : desc.trim(),
      amount: amount,
      payerId: payerId,
      splitMap: finalSplitMap,
      isSettlement: isSettlement,
      settledBy: {payerId},
      // The person who paid is already paid/settled
      addedBy: _uid,
      // security rules require addedBy == the signed-in uid
      createdAt: DateTime.now(),
    );

    _expensesByGroup[group.id] = [...expenses, newExpense];
    _rebuildGroups();
    notifyListeners();
    _persist(FirestoreRepository.instance.createExpense(group.id, newExpense));
    return null;
  }

  /// Settles up between [fromId] and [toId] in [groupId] (defaults to the
  /// currently open group) by marking their open shares as paid on the
  /// individual expenses — no separate settlement record is created, so the
  /// activity feed stays clean and every expense's PAID/PENDING status
  /// stays the single source of truth.
  ///
  /// Both directions between the pair are cleared (shares [fromId] owes on
  /// expenses [toId] paid, and vice versa) because the Balances tab shows
  /// the *net* of the two; clearing only one side would flip the balance
  /// instead of zeroing it. [amount] is only validated — the amount to pay
  /// is whatever the Balances tab showed for the pair.
  ///
  /// This is the single place that decides who's allowed to confirm a
  /// settlement — both the per-group Balances tab and the cross-group
  /// Overview's "settle all dues" go through it: only the group's creator
  /// or the person actually being paid can confirm.
  Future<String?> settleUp(int fromId, int toId, double amount, {String? groupId}) async {
    final targetId = groupId ?? currentGroup?.id;
    if (targetId == null) return 'Select a group first.';
    if (!amount.isFinite || amount <= 0 || fromId == toId) {
      return 'Enter a valid settlement amount.';
    }
    Group? group;
    for (final g in _groups) { if (g.id == targetId) { group = g; break; } }
    if (group == null) return 'Could not find that group.';
    if (!group.memberUids.contains(_uid)) return "You're not a member of this group.";
    Person? fromPerson;
    Person? toPerson;
    for (final p in group.members) { if (p.id == fromId) fromPerson = p; if (p.id == toId) toPerson = p; }
    if (fromPerson == null || toPerson == null) return 'Could not find one of the people in this settlement.';
    // Either linked account in the debtor-creditor pair may record settlement.
    if (fromPerson.linkedUserId != _uid && toPerson.linkedUserId != _uid) {
      return 'Only someone in this debtor-creditor pair can confirm settlement.';
    }
    final pair = SettlementCalculator.computePairBalances(
      SettlementCalculator.deriveLedgerEntries(_expensesByGroup[group.id] ?? const <Expense>[]),
    ).where((balance) =>
      (balance.personAId == fromId && balance.personBId == toId) ||
      (balance.personAId == toId && balance.personBId == fromId),
    ).toList();
    if (pair.isEmpty || pair.first.debtorId != fromId || pair.first.creditorId != toId) {
      return 'The debt direction changed. Refresh and try again.';
    }
    if (amount - pair.first.owedAmount > 0.005) return 'Settlement amount exceeds the current outstanding balance.';
    // Server recomputes the net and atomically allocates this amount to existing shares.
    try {
      await FirestoreRepository.instance.recordPairSettlement(
        groupId: group.id, fromId: fromId, toId: toId, amount: amount,
      );
      return null;
    } catch (error) {
      debugPrint('SplitProvider: settlement failed: $error');
      return 'Could not record settlement. Refresh and try again.';
    }
  }

  /// deleting an expense someone else logged (or your own) is a destructive
  /// action, so it's kept restricted to whoever originally added it or the payer.
  void removeExpense(String id) {
    final group = currentGroup;
    if (group == null) return;

    final existingIndex = expenses.indexWhere((e) => e.id == id);
    if (existingIndex == -1) return;

    final expense = expenses[existingIndex];
    final payerPerson = personById(expense.payerId);
    final isPayer = payerPerson?.linkedUserId == _uid ||
        expense.addedBy == _uid;
    if (!isPayer && group.ownerId != _uid) return; // not authorized

    _expensesByGroup[group.id] = expenses.where((e) => e.id != id).toList();
    _rebuildGroups();
    notifyListeners();
    _persist(FirestoreRepository.instance.deleteExpense(group.id, id));
  }

  /// RESTRICTED TO THE CREATOR / PAYER of the expense.
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
    final payerPerson = personById(original.payerId);
    final isPayer = payerPerson?.linkedUserId == _uid ||
        original.addedBy == _uid;
    if (!isPayer) {
      return 'Only the person who paid can edit this split.';
    }

    if (amount == null || amount <= 0) return 'Enter a valid amount.';
    if (payerId == null) return 'Add at least one person first.';
    // Payer lock: who paid can't be reassigned after the fact, otherwise the
    // "only the payer can log a split" rule could be sidestepped by editing.
    if (payerId != original.payerId) {
      return "Who paid can't be changed. Delete this split and log it again.";
    }
    if (splitWith.isEmpty) return 'Pick who this should be split between.';

    final finalSplitMap = _buildSplitMap(
      amount: amount,
      splitWith: splitWith,
      currency: group.currency,
      customSplits: customSplits,
    );
    if (finalSplitMap is String) return finalSplitMap; // error message

    final newSplitMap = finalSplitMap as Map<int, double>;

    // Keep "paid" flags only for people still in the split whose share
    // didn't change — a changed share means the old payment no longer
    // matches what they owe. The payer always stays marked as paid.
    final newSettledBy = <int>{payerId};
    for (final id in original.settledBy) {
      final oldShare = original.splitMap[id];
      final newShare = newSplitMap[id];
      if (oldShare != null &&
          newShare != null &&
          (oldShare - newShare).abs() < 0.005) {
        newSettledBy.add(id);
      }
    }

    final updatedExpense = original.copyWith(
      desc: desc
          .trim()
          .isEmpty ? original.desc : desc.trim(),
      amount: amount,
      payerId: payerId,
      splitMap: newSplitMap,
      settledBy: newSettledBy,
    );

    final updatedExpenses = [...expenses];
    updatedExpenses[existingIndex] = updatedExpense;
    _expensesByGroup[group.id] = updatedExpenses;
    _rebuildGroups();
    notifyListeners();
    _persist(
        FirestoreRepository.instance.updateExpense(group.id, updatedExpense));
    return null;
  }

  /// Every ledger entry derived from the current group's expenses. See
  /// [SettlementCalculator.deriveLedgerEntries] for the derivation rules.
  List<LedgerEntry> get ledgerEntries =>
      SettlementCalculator.deriveLedgerEntries(expenses);

  /// Toggles whether a specific person has settled their share of an expense.
  void togglePersonSettlement(String expenseId, int personId) {
    final group = currentGroup;
    if (group == null) return;

    final groupExpenses = _expensesByGroup[group.id] ?? const [];
    final existingIndex = groupExpenses.indexWhere((e) => e.id == expenseId);
    if (existingIndex == -1) return;

    final expense = groupExpenses[existingIndex];
    if (expense.isSettlement) {
      return; // legacy settlement records aren't toggleable
    }
    if (!expense.splitMap.containsKey(personId)) {
      return; // not part of this split
    }
    if (personId == expense.payerId) {
      return; // Cannot toggle/revert the person who paid
    }

    final isExpenseCreator = expense.addedBy == _uid;
    // Only the person who logged this expense can change its paid/pending flags.
    if (!isExpenseCreator) {
      return;
    }

    final updatedSettledBy = Set<int>.from(expense.settledBy);
    if (updatedSettledBy.contains(personId)) {
      updatedSettledBy.remove(personId);
    } else {
      updatedSettledBy.add(personId);
    }
    final updated = expense.copyWith(settledBy: updatedSettledBy);

    final list = List<Expense>.from(groupExpenses);
    list[existingIndex] = updated;

    _expensesByGroup[group.id] = list;
    _rebuildGroups();
    notifyListeners();
    _persist(FirestoreRepository.instance
        .updateSettledBy(group.id, updated.id, updated.settledBy));
  }

  Expense? _expenseById(String expenseId) {
    for (final e in expenses) {
      if (e.id == expenseId) return e;
    }
    return null;
  }

  /// Checks if a specific person has settled their share of an expense.
  bool isPersonSettled(String expenseId, int personId) =>
      _expenseById(expenseId)?.isPersonPaid(personId) ?? false;

  /// Number of split participants who have settled their share (the payer
  /// counts as settled when they're part of the split).
  int getSettledCount(String expenseId) =>
      _expenseById(expenseId)?.settledCount ?? 0;

  /// Number of people the expense is split between.
  int getParticipantCount(String expenseId) =>
      _expenseById(expenseId)?.participantCount ?? 0;

  /// Checks if all people in an expense have settled their share.
  bool isExpenseFullySettled(String expenseId) =>
      _expenseById(expenseId)?.isFullySettled ?? false;

  /// The net debt between every pair of people who have ever transacted in
  /// this group — this is the "who specifically owes whom" detail that a
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
        .map((key) =>
        OverallBalance(
          key: key,
          name: displayNames[key]!,
          groupCount: groupCounts[key] ?? 0,
          currencyBalances: currencyMaps[key] ?? {},
          breakdown: breakdowns[key] ?? [],
        ))
        .where((o) =>
    o.breakdown.isNotEmpty) // Only show people with active history
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

      final error = await settleUp(
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

extension AiContextExtension on SplitProvider {
  /// Generates a structured summary of all spending data across all groups.
  /// This is used as context for the "Ask Anything" AI feature.
  String getAiSummaryContext() {
    final Map<String, dynamic> context = {
      'user': _myDisplayName ?? 'Me',
      'groups': groups.map((g) {
        return {
          'name': g.name,
          'currency': g.currency,
          'isPersonal': g.isPersonal,
          'totalSpentInGroup': g.expenses
              .where((e) => !e.isSettlement)
              .fold(0.0, (s, e) => s + e.amount),
          'members': g.members.map((m) => m.name).toList(),
          'recentExpenses': g.expenses
              .where((e) => !e.isSettlement)
              .take(10)
              .map((e) =>
          {
            'desc': e.desc,
            'amount': e.amount,
            'paidBy': g.members
                .firstWhere((m) => m.id == e.payerId,
                orElse: () => Person(id: 0, name: '?', color: Colors.grey))
                .name,
          })
              .toList(),
        };
      }).toList(),
      'globalNetStandings': globalNetStandings,
    };

    return JsonEncoder.withIndent('  ').convert(context);
  }
}
