import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// What happened to a push notification, as far as the UI cares.
enum PushEventKind {
  /// A push arrived while the app was open.
  foreground,

  /// The user tapped a push (app was in the background or closed).
  opened,
}

class PushEvent {
  final PushEventKind kind;
  final String? title;
  final String? body;

  /// The `data` payload sent by the Cloud Function. For a new expense:
  /// `{type: 'expense_created', groupId, expenseId}`.
  final Map<String, String> data;

  const PushEvent({
    required this.kind,
    required this.data,
    this.title,
    this.body,
  });
}

/// Push notifications for the mobile apps (Android / iOS).
///
/// * Registers this device's FCM token under users/{uid}/private/push
///   (readable only by that user and the Cloud Function) and removes it on
///   sign-out. [initialize] is idempotent per uid, so calling it more than
///   once never stacks listeners.
/// * Contains no UI. Anything the user should see or any screen to open is
///   published on [events]; lib/services/push_navigation.dart handles those.
/// * Does nothing on web / desktop, where the same FCM setup doesn't apply.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  /// Push is only wired up for the Android and iOS apps.
  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  // Looked up lazily so merely creating the singleton never touches the
  // messaging plugin on platforms that don't have it.
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  final StreamController<PushEvent> _events =
      StreamController<PushEvent>.broadcast();

  /// Foreground arrivals and notification taps.
  Stream<PushEvent> get events => _events.stream;

  String? _activeUid;
  String? _token;
  StreamSubscription<String>? _refreshSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedSub;

  DocumentReference<Map<String, dynamic>> _pushDoc(String uid) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('private')
          .doc('push');

  /// Asks for permission, registers this device and starts listening.
  Future<void> initialize(String uid) async {
    if (!isSupported) return;
    if (_activeUid == uid) return;
    await _detach();
    _activeUid = uid;
    try {
      // Android 13+ shows the system permission dialog here (it also needs
      // POST_NOTIFICATIONS in AndroidManifest.xml); iOS shows its own.
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (_activeUid != uid) return;
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        debugPrint('Push notifications not allowed by the user.');
        return;
      }

      // iOS only: show the system banner even while the app is open.
      // (Android can't, so the UI shows its own banner from [events].)
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      // Listeners go first so nothing is missed while the token is fetched.
      _foregroundSub = FirebaseMessaging.onMessage.listen((message) {
        if (_activeUid != uid) return;
        _publish(PushEventKind.foreground, message);
      });
      _openedSub = FirebaseMessaging.onMessageOpenedApp.listen((message) {
        if (_activeUid != uid) return;
        _publish(PushEventKind.opened, message);
      });
      _refreshSub = _messaging.onTokenRefresh.listen((newToken) {
        // A refresh can arrive after sign-out / account switching.
        if (_activeUid != uid) return;
        _token = newToken;
        _saveToken(uid, newToken);
      });

      final token = await _fetchToken();
      if (_activeUid != uid) return;
      if (token != null) {
        _token = token;
        await _saveToken(uid, token);
      }

      // The app was launched (from closed) by tapping a notification.
      final initial = await _messaging.getInitialMessage();
      if (initial != null && _activeUid == uid) {
        _publish(PushEventKind.opened, initial);
      }
    } catch (e) {
      debugPrint('NotificationService initialization error: $e');
    }
  }

  /// Call BEFORE signing out so the device stops receiving this account's
  /// pushes (the Firestore rules need the user to still be signed in).
  Future<void> clear(String uid) async {
    final token = _token;
    await _detach();
    _activeUid = null;
    if (!isSupported) return;
    try {
      if (token != null) {
        await _pushDoc(uid).set(
          {'tokens': FieldValue.arrayRemove([token])},
          SetOptions(merge: true),
        );
      }
      // Invalidate the token itself, so it can never deliver one account's
      // notifications to whoever signs in on this phone next.
      await _messaging.deleteToken();
    } catch (e) {
      debugPrint('NotificationService.clear error: $e');
    }
  }

  void _publish(PushEventKind kind, RemoteMessage message) {
    _events.add(PushEvent(
      kind: kind,
      title: message.notification?.title,
      body: message.notification?.body,
      data: {
        for (final entry in message.data.entries)
          entry.key: entry.value?.toString() ?? '',
      },
    ));
  }

  Future<String?> _fetchToken() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // The APNs token arrives asynchronously after launch and getToken()
      // fails until it exists. (It never arrives on the iOS simulator.)
      for (var i = 0; i < 10; i++) {
        if (await _messaging.getAPNSToken() != null) break;
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }
    return _messaging.getToken();
  }

  Future<void> _detach() async {
    await _refreshSub?.cancel();
    await _foregroundSub?.cancel();
    await _openedSub?.cancel();
    _refreshSub = null;
    _foregroundSub = null;
    _openedSub = null;
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
