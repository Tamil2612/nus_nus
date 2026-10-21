import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AccountDeletionCandidate {
  final String uid;
  final String name;

  const AccountDeletionCandidate({required this.uid, required this.name});
}

class AccountDeletionGroup {
  final String id;
  final String name;
  final List<AccountDeletionCandidate> candidates;
  final double balance;
  final String currency;

  const AccountDeletionGroup({
    required this.id,
    required this.name,
    required this.candidates,
    required this.balance,
    required this.currency,
  });
}

class AccountDeletionBalance {
  final String id;
  final String name;
  final String currency;
  final double balance;
  final List<AccountDeletionCounterpartyBalance> counterparties;

  const AccountDeletionBalance({
    required this.id,
    required this.name,
    required this.currency,
    required this.balance,
    required this.counterparties,
  });
}

class AccountDeletionCounterpartyBalance {
  final String personName;
  final double balance;

  const AccountDeletionCounterpartyBalance({
    required this.personName,
    required this.balance,
  });
}

class AccountDeletionPlan {
  final List<AccountDeletionGroup> ownedGroups;
  final List<AccountDeletionBalance> groupBalances;

  const AccountDeletionPlan({
    required this.ownedGroups,
    required this.groupBalances,
  });
}

class AccountDeletionRepository {
  AccountDeletionRepository._();
  static final AccountDeletionRepository instance =
      AccountDeletionRepository._();

  FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: 'us-central1');

  Future<AccountDeletionPlan> getPlan() async {
    final callable = _functions.httpsCallable('getAccountDeletionPlan');
    final response = await callable.call();
    final data = Map<String, dynamic>.from(response.data as Map);
    final groups = (data['ownedGroups'] as List? ?? const [])
        .whereType<Map>()
        .map((rawGroup) {
          final group = Map<String, dynamic>.from(rawGroup);
          final candidates = (group['candidates'] as List? ?? const [])
              .whereType<Map>()
              .map((rawCandidate) {
                final candidate = Map<String, dynamic>.from(rawCandidate);
                return AccountDeletionCandidate(
                  uid: candidate['uid'] as String? ?? '',
                  name: candidate['name'] as String? ?? 'Member',
                );
              })
              .where((candidate) => candidate.uid.isNotEmpty)
              .toList();
          return AccountDeletionGroup(
            id: group['groupId'] as String? ?? '',
            name: group['name'] as String? ?? 'Untitled group',
            candidates: candidates,
            balance: (group['balance'] as num?)?.toDouble() ?? 0,
            currency: group['currency'] as String? ?? 'AED',
          );
        })
        .where((group) => group.id.isNotEmpty)
        .toList();
    final groupBalances = (data['groupBalances'] as List? ?? const [])
        .whereType<Map>()
        .map((rawGroup) {
          final group = Map<String, dynamic>.from(rawGroup);
          final counterparties =
              (group['counterpartyBalances'] as List? ?? const [])
                  .whereType<Map>()
                  .map((rawBalance) {
            final item = Map<String, dynamic>.from(rawBalance);
            return AccountDeletionCounterpartyBalance(
              personName: item['personName'] as String? ?? 'Former member',
              balance: (item['balance'] as num?)?.toDouble() ?? 0,
            );
          }).toList();
          return AccountDeletionBalance(
            id: group['groupId'] as String? ?? '',
            name: group['name'] as String? ?? 'Untitled group',
            currency: group['currency'] as String? ?? 'AED',
            balance: (group['balance'] as num?)?.toDouble() ?? 0,
            counterparties: counterparties,
          );
        })
        .where((group) => group.id.isNotEmpty)
        .toList();
    return AccountDeletionPlan(
      ownedGroups: groups,
      groupBalances: groupBalances,
    );
  }

  Future<void> deleteAccount({
    required Map<String, String> transfers,
    required List<String> deleteGroupIds,
    required bool acknowledgeUnsettled,
  }) async {
    if (FirebaseAuth.instance.currentUser == null) {
      throw FirebaseFunctionsException(
        code: 'unauthenticated',
        message: 'Sign in again before deleting your account.',
      );
    }
    final callable = _functions.httpsCallable('deleteAccountData');
    await callable.call({
      'transfers': transfers,
      'deleteGroupIds': deleteGroupIds,
      'acknowledgeUnsettled': acknowledgeUnsettled,
    });
  }
}
