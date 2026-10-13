import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Registers this device's FCM token under users/{uid}/private/push (readable
/// only by that user and the Cloud Function) and removes it on sign-out.
/// [initialize] is idempotent per uid, so it can be called more than once
/// without stacking listeners.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  String? _activeUid;
  String? _token;
  StreamSubscription<String>? _refreshSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;

  DocumentReference<Map<String, dynamic>> _pushDoc(String uid) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('private')
          .doc('push');

  Future<void> initialize(String uid) async {
    if (_activeUid == uid) return;
    await _detach();
    _activeUid = uid;
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (_activeUid != uid) return;
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        return;
      }

      final token = await _messaging.getToken();
      if (_activeUid != uid) return;
      if (token != null) {
        _token = token;
        await _saveToken(uid, token);
      }

      _refreshSub = _messaging.onTokenRefresh.listen((newToken) {
        _token = newToken;
        _saveToken(uid, newToken);
      });
      _foregroundSub = FirebaseMessaging.onMessage.listen((message) {
        debugPrint('Received foreground message: ${message.notification?.title}');
      });
    } catch (e) {
      debugPrint('NotificationService initialization error: $e');
    }
  }

  /// Call BEFORE signing out so the device stops receiving this account's pushes.
  Future<void> clear(String uid) async {
    final token = _token;
    await _detach();
    _activeUid = null;
    try {
      if (token != null) {
        await _pushDoc(uid).set(
          {'tokens': FieldValue.arrayRemove([token])},
          SetOptions(merge: true),
        );
      }
      await _messaging.deleteToken();
    } catch (e) {
      debugPrint('NotificationService.clear error: $e');
    }
  }

  Future<void> _detach() async {
    await _refreshSub?.cancel();
    await _foregroundSub?.cancel();
    _refreshSub = null;
    _foregroundSub = null;
    _token = null;
  }

  Future<void> _saveToken(String uid, String token) async {
    try {
      await _pushDoc(uid).set(
        {
          'tokens': FieldValue.arrayUnion([token]),
          'tokenUpdatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('Failed to save FCM token: $e');
    }
  }
}