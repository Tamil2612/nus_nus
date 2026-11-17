import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/monthly_budget.dart';

class MonthlyBudgetRepository {
  MonthlyBudgetRepository._();
  static final instance = MonthlyBudgetRepository._();

  CollectionReference<Map<String, dynamic>> _budgets(String uid) =>
      FirebaseFirestore.instance.collection('users').doc(uid).collection('budgets');

  Future<MonthlyBudget?> getBudget(String uid, String monthId) async {
    final snapshot = await _budgets(uid).doc(monthId).get();
    if (!snapshot.exists) return null;
    return MonthlyBudget.fromJson(monthId, snapshot.data()!);
  }

  Future<void> saveBudget({
    required String uid,
    required String monthId,
    required double amount,
    required String currency,
  }) async {
    if (FirebaseAuth.instance.currentUser?.uid != uid) {
      throw StateError('You can only update your own budget.');
    }
    if (!amount.isFinite || amount <= 0 || amount > 100000000) {
      throw ArgumentError('Enter a valid monthly budget.');
    }
    await _budgets(uid).doc(monthId).set({
      'amount': (amount * 100).round() / 100,
      'currency': currency.toUpperCase(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<String?> getMemberCategory({
    required String groupId,
    required String expenseId,
    required String uid,
  }) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('groups').doc(groupId)
        .collection('expenses').doc(expenseId)
        .collection('memberCategories').doc(uid).get();
    return snapshot.data()?['categoryId'] as String?;
  }

  Future<void> setMemberCategory({
    required String groupId,
    required String expenseId,
    required String uid,
    required String? categoryId,
  }) async {
    if (FirebaseAuth.instance.currentUser?.uid != uid) {
      throw StateError('You can only update your own category.');
    }
    final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
        .httpsCallable('setMemberExpenseCategory');
    await callable.call({
      'groupId': groupId,
      'expenseId': expenseId,
      'categoryId': categoryId,
    });
  }
}
