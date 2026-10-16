import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/expense.dart';
import '../models/group.dart';

/// Cloud persistence for groups and their expenses.
///
/// Groups live in a top-level `groups` collection — deliberately *not*
/// nested under `users/{uid}`, because a group needs to be readable by
/// everyone linked into it, not just the person who created it.
/// `memberUids` (owner + every linked registered member) is kept on the
/// document so a single `array-contains` query finds every group a
/// signed-in user should see, whether they created it or were just added
/// to it.
///
/// Expenses live in a `groups/{groupId}/expenses` *subcollection* rather
/// than an array field on the group document itself. Two reasons:
///  - Any member should be able to log an expense without needing write
///    access to the group's name/members/ownership — a subcollection lets
///    the security rules grant that narrowly (create only, on your own
///    doc) instead of opening up the whole group document.
///  - Embedding expenses as an array means every write replaces the
///    *entire* array; two members adding an expense at the same moment
///    would silently clobber one another. Separate documents don't have
///    that problem — each write only touches its own doc.
///
/// Security rules: see `firestore.rules` at the repo root (source of truth).
class FirestoreRepository {
  FirestoreRepository._();
  static final FirestoreRepository instance = FirestoreRepository._();

  CollectionReference<Map<String, dynamic>> get _groups =>
      FirebaseFirestore.instance.collection('groups');

  CollectionReference<Map<String, dynamic>> _expensesCol(String groupId) =>
      _groups.doc(groupId).collection('expenses');

  // -- Group metadata (name / members / ownership) -------------------------

  /// Live stream of every group's *metadata* visible to [uid] — the ones
  /// they created and the ones they've been linked into by someone else.
  /// Expenses are not included here; each group's expenses are streamed
  /// separately via [watchExpenses] so a group's activity feed can update
  /// without re-fetching its whole member list, and vice versa.
  Stream<List<Group>> watchGroupsForUser(String uid) {
    return _groups.where('memberUids', arrayContains: uid).snapshots().map(
            (snap) => snap.docs
            .map((d) => Group.fromJson(d.id, d.data()))
            .toList());
  }

  /// Reserves a document id for a brand-new group without writing
  /// anything yet — lets the caller build the [Group] object (with a real
  /// id) before the first [saveGroupMeta].
  String newGroupId() => _groups.doc().id;

  /// Writes a group's metadata (name/members/ownership) — never its
  /// expenses, which are written individually via [createExpense] /
  /// [updateExpense] / [deleteExpense] instead.
  Future<void> saveGroupMeta(Group group) async {
    try {
      await _groups.doc(group.id).set(group.toJson());
    } catch (e, st) {
      debugPrint('FirestoreRepository.saveGroupMeta failed: $e\n$st');
      rethrow;
    }
  }

  /// Creates the group only if it doesn't exist yet, so an existing
  /// personal group is never overwritten.
  Future<void> ensurePersonalGroup(Group group) async {
    final ref = _groups.doc(group.id);
    final snap = await ref.get();
    if (!snap.exists) await ref.set(group.toJson());
  }

  /// Deletes a group and its nested records through a trusted callable.
  Future<void> deleteGroup(String groupId) async {
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        throw FirebaseFunctionsException(
          code: 'unauthenticated',
          message: 'Sign in again before deleting this group.',
        );
      }
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('deleteGroup');
      await callable.call({'groupId': groupId});
    } catch (e, st) {
      debugPrint('FirestoreRepository.deleteGroup failed: $e\n$st');
      rethrow;
    }
  }

  // -- Expenses --------------------------------------------------------------

  /// Reserves a document id for a brand-new expense in [groupId].
  String newExpenseId(String groupId) => _expensesCol(groupId).doc().id;

  /// Live stream of every expense in [groupId], newest write order isn't
  /// guaranteed by Firestore so callers should sort by whatever field they
  /// display by (the app sorts by insertion order client-side already).
  Stream<List<Expense>> watchExpenses(String groupId) {
    return _expensesCol(groupId).snapshots().map((snap) => snap.docs
        .map((d) => Expense.fromJson(d.id, d.data()))
        .toList());
  }

  /// Adds a brand-new expense. Any member of the group may call this —
  /// the security rules only require that [expense.addedBy] is the
  /// caller's own uid.
  Future<void> createExpense(String groupId, Expense expense) async {
    try {
      await _expensesCol(groupId).doc(expense.id).set(expense.toJson());
    } catch (e, st) {
      debugPrint('FirestoreRepository.createExpense failed: $e\n$st');
      rethrow;
    }
  }

  /// Overwrites an existing expense in place (edits, and per-person
  /// paid/pending toggles via `settledBy`). Restricted server-side to
  /// whoever originally added it (`addedBy`) or the group's creator.
  Future<void> updateExpense(String groupId, Expense expense) async {
    try {
      await _expensesCol(groupId).doc(expense.id).set(expense.toJson());
    } catch (e, st) {
      debugPrint('FirestoreRepository.updateExpense failed: $e\n$st');
      rethrow;
    }
  }

  /// Updates only the expense creator's whole-share paid/pending flags.
  Future<void> updateSettledBy(
      String groupId, String expenseId, Set<int> settledBy) async {
    try {
      await _expensesCol(groupId).doc(expenseId).update({
        'settledBy': settledBy.map((e) => e.toString()).toList(),
      });
    } catch (e, st) {
      debugPrint('FirestoreRepository.updateSettledBy failed: $e\n$st');
      rethrow;
    }
  }

  /// Records an external pairwise settlement through a trusted callable.
  /// The function validates both participants, the current net balance and
  /// atomically allocates the settled amount to existing expense shares.
  Future<void> recordPairSettlement({
    required String groupId,
    required int fromId,
    required int toId,
    required double amount,
  }) async {
    // Refresh the cached ID token before the callable SDK attaches it.
    // This does not bypass authentication; it ensures the signed-in session
    // has a fresh token for the trusted server-side settlement endpoint.
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw FirebaseFunctionsException(
        code: 'unauthenticated',
        message: 'Your session has expired. Sign in again to record a settlement.',
      );
    }
    final token = await user.getIdToken(true);
    if (token == null || token.isEmpty) {
      throw FirebaseFunctionsException(
        code: 'unauthenticated',
        message: 'Could not refresh your sign-in. Please sign in again.',
      );
    }
    final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
        .httpsCallable('recordPairSettlement');
    await callable.call({
      'groupId': groupId,
      'fromId': fromId,
      'toId': toId,
      'amount': amount,
    });
  }

  Future<void> deleteExpense(String groupId, String expenseId) async {
    try {
      await _expensesCol(groupId).doc(expenseId).delete();
    } catch (e, st) {
      debugPrint('FirestoreRepository.deleteExpense failed: $e\n$st');
      rethrow;
    }
  }
}