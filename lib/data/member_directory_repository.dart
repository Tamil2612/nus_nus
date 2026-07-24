import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/app_user.dart';

/// Reads the public directory of registered accounts — the `users/{uid}`
/// profile documents (name/email only). Every signed-in user can read this
/// collection (see the suggested Firestore rules in README.md); it never
/// touches anyone's private `appState` subcollection.
class MemberDirectoryRepository {
  MemberDirectoryRepository._();
  static final MemberDirectoryRepository instance =
      MemberDirectoryRepository._();

  CollectionReference<Map<String, dynamic>> get _users =>
      FirebaseFirestore.instance.collection('users');

  /// One-off fetch of every registered member, sorted by name.
  Future<List<AppUser>> fetchAll() async {
    try {
      final snap = await _users.get();
      final users = snap.docs
          .map((d) => AppUser.fromJson({'uid': d.id, ...d.data()}))
          .toList();
      users.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return users;
    } catch (e, st) {
      debugPrint('MemberDirectoryRepository.fetchAll failed: $e\n$st');
      return [];
    }
  }

  /// Live stream, for the picker to update in real time as people register.
  Stream<List<AppUser>> watchAll() {
    return _users.snapshots().map((snap) {
      final users = snap.docs
          .map((d) => AppUser.fromJson({'uid': d.id, ...d.data()}))
          .toList();
      users.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return users;
    }).handleError((e) {
      debugPrint('MemberDirectoryRepository.watchAll error: $e');
    });
  }

  /// Single-document fetch of one registered profile by uid — used
  /// wherever the app needs one person's authoritative name (e.g. the
  /// current user's own name when creating a group) without pulling the
  /// whole directory down.
  Future<AppUser?> fetchByUid(String uid) async {
    try {
      final doc = await _users.doc(uid).get();
      if (!doc.exists) return null;
      return AppUser.fromJson({'uid': doc.id, ...?doc.data()});
    } catch (e, st) {
      debugPrint('MemberDirectoryRepository.fetchByUid failed: $e\n$st');
      return null;
    }
  }

  Future<void> upsertProfile(AppUser user) async {
    try {
      await _users.doc(user.uid).set({
        'name': user.name,
        'email': user.email,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e, st) {
      debugPrint('MemberDirectoryRepository.upsertProfile failed: $e\n$st');
    }
  }
}
