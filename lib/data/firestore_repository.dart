import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/group.dart';

/// Cloud persistence for a signed-in user's app state (groups, members,
/// expenses), mirroring [DatabaseHelper]'s "snapshot the whole thing"
/// strategy but backed by Firestore instead of sqlite.
///
/// Stored at `users/{uid}/private/appState` — deliberately *not* on the
/// `users/{uid}` document itself, which holds the public profile
/// (name/email) used by the registered-members directory. Keeping the two
/// apart means the directory query never has to read (or risk exposing)
/// anyone's private balances.
class FirestoreRepository {
  FirestoreRepository._();
  static final FirestoreRepository instance = FirestoreRepository._();

  DocumentReference<Map<String, dynamic>> _appStateDoc(String uid) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('private')
          .doc('appState');

  Future<void> saveAll(String uid, List<Group> groups) async {
    try {
      await _appStateDoc(uid).set({
        'groups': groups.map((g) => g.toJson()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e, st) {
      debugPrint('FirestoreRepository.saveAll failed: $e\n$st');
    }
  }

  Future<List<Group>> loadAll(String uid) async {
    try {
      final snap = await _appStateDoc(uid).get();
      final data = snap.data();
      if (data == null || data['groups'] == null) return [];
      return (data['groups'] as List)
          .map((g) => Group.fromJson(Map<String, dynamic>.from(g as Map)))
          .toList();
    } catch (e, st) {
      debugPrint('FirestoreRepository.loadAll failed: $e\n$st');
      return [];
    }
  }
}
