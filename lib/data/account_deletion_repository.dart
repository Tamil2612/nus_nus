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

  const AccountDeletionGroup({
    required this.id,
    required this.name,
    required this.candidates,
  });
}

class AccountDeletionPlan {
  final List<AccountDeletionGroup> ownedGroups;

  const AccountDeletionPlan({required this.ownedGroups});
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
          );
        })
        .where((group) => group.id.isNotEmpty)
        .toList();
    return AccountDeletionPlan(ownedGroups: groups);
  }

  Future<void> deleteAccount({
    required Map<String, String> transfers,
    required List<String> deleteGroupIds,
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
    });
  }
}
