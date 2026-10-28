import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/app_user.dart';
import '../utils/phone_lookup.dart';

/// Reads and updates profiles. User documents stay private; phone matching
/// goes through the trusted callable.
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
      users
          .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
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
      users
          .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
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
      final data = doc.data()!;
      final phoneNumber = data['phoneNumber'];
      final phoneKey =
          phoneNumber is String ? normalizeLookupPhone(phoneNumber) : '';
      final indexedPhoneKey =
          phoneKey.length >= 7 && phoneKey.length <= 15 ? phoneKey : null;
      if (data['phoneKey'] != indexedPhoneKey) {
        try {
          await doc.reference.update({
            'phoneKey': indexedPhoneKey ?? FieldValue.delete(),
          });
        } catch (e) {
          // Profile reads should still succeed if an account is being deleted
          // or a legacy profile cannot be backfilled.
          debugPrint('Could not backfill phone lookup key: $e');
        }
      }
      return AppUser.fromJson({'uid': doc.id, ...data});
    } catch (e, st) {
      debugPrint('MemberDirectoryRepository.fetchByUid failed: $e\n$st');
      return null;
    }
  }

  Future<void> upsertProfile(AppUser user, {String? fcmToken}) async {
    try {
      // Only write what we actually know — a sign-in with a blank name or
      // no phone must not wipe the stored values. [fcmToken] is ignored:
      // push tokens now live in users/{uid}/private/push.
      final data = <String, dynamic>{
        'platform': defaultTargetPlatform.name,
        'lastLogin': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (user.name.trim().isNotEmpty) data['name'] = user.name;
      if (user.email.trim().isNotEmpty) data['email'] = user.email;
      if (user.phoneNumber != null) data['phoneNumber'] = user.phoneNumber;
      if (user.phoneNumber != null) {
        final phoneKey = normalizeLookupPhone(user.phoneNumber!);
        if (phoneKey.length >= 7 && phoneKey.length <= 15) {
          data['phoneKey'] = phoneKey;
        } else {
          data['phoneKey'] = FieldValue.delete();
        }
      }
      if (user.discoverableByPhone != null) {
        data['discoverableByPhone'] = user.discoverableByPhone;
      }
      await _users.doc(user.uid).set(data, SetOptions(merge: true));
    } catch (e, st) {
      debugPrint('MemberDirectoryRepository.upsertProfile failed: $e\n$st');
    }
  }
}
