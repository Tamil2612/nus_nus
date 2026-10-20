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

  /// The `data` payload sent by the Cloud Function.
  /// For a new expense: {type: 'expense_created', groupId, expenseId}.
  final Map<String, String> data;

  const PushEvent({
    required this.kind,
    required this.data,
    this.title,
    this.body,
  });
}

/// Push notifications for Android, iOS and supported web PWAs.
///
/// * Registers this device's FCM token under users/{uid}/private/push.
/// * Removes this device's token on sign-out.
/// * Keeps initialization idempotent per user.
/// * Publishes notification events for push_navigation.dart.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  /// Push is wired up for Android/iOS and web. Desktop platforms are omitted.
  static bool get isSupported =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  /// Set with `--dart-define=FIREBASE_VAPID_KEY=<Firebase Web Push key>`.
  static const String webVapidKey =
      String.fromEnvironment('FIREBASE_VAPID_KEY');

  /// Access messaging lazily.
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

  /// Requests permission, registers this device and starts listening.
  ///
  /// If initialization fails, the active UID is reset so a later call can
  /// retry instead of returning early.
  Future<void> initialize(String uid, {bool requestPermission = true}) async {
    if (!isSupported) return;
    if (_activeUid == uid) return;

    await _detach();
    _activeUid = uid;

    try {
      final settings = requestPermission
          ? await _messaging.requestPermission(
              alert: true,
              badge: true,
              sound: true,
            )
          : await _messaging.getNotificationSettings();

// The user may have signed out or switched accounts while waiting.
      if (_activeUid != uid) return;

      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        debugPrint('Push notifications not allowed by the user.');

// Allow initialize() to retry if permission is granted later.
        _activeUid = null;
        await _detach();
        return;
      }

// iOS: allow system banners while the app is in the foreground.
// Android foreground presentation can be handled through [events].
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      if (_activeUid != uid) return;

// Install listeners before fetching the token so refreshes and
// incoming notifications are not missed.
      _foregroundSub = FirebaseMessaging.onMessage.listen((message) {
        if (_activeUid != uid) return;
        _publish(PushEventKind.foreground, message);
      });

      _openedSub = FirebaseMessaging.onMessageOpenedApp.listen((message) {
        if (_activeUid != uid) return;
        _publish(PushEventKind.opened, message);
      });

      // Keep legacy FCM registration tokens until the server sender is migrated
      // to Firebase Installation IDs; changing only the client breaks delivery.
      // ignore: deprecated_member_use
      _refreshSub = _messaging.onTokenRefresh.listen(
        (newToken) {
          if (_activeUid != uid) return;

          _token = newToken;

// Do not allow an asynchronous Firestore failure to go unnoticed.
          _saveToken(uid, newToken).catchError((Object error) {
            debugPrint('Failed to save refreshed FCM token: $error');
          });
        },
        onError: (Object error) {
          debugPrint('FCM token refresh stream error: $error');
        },
      );

      final token = await _fetchToken();

      if (_activeUid != uid) return;

      if (token == null || token.isEmpty) {
        debugPrint('FCM token is not available yet.');
      } else {
        _token = token;
        await _saveToken(uid, token);
      }

      if (_activeUid != uid) return;

// Handle a notification that launched the app from a terminated state.
      final initial = await _messaging.getInitialMessage();

      if (initial != null && _activeUid == uid) {
        _publish(PushEventKind.opened, initial);
      }
    } catch (error, stackTrace) {
      debugPrint('NotificationService initialization error: $error');
      debugPrintStack(stackTrace: stackTrace);

// Reset only if this initialization still belongs to the active user.
      if (_activeUid == uid) {
        _activeUid = null;
        await _detach();
      }
    }
  }

  /// Call from a visible user action to enable web push. iOS requires this
  /// permission prompt to follow a user gesture, and Home Screen installation.
  Future<void> enableNotifications(String uid) async {
    if (!isSupported) return;
    if (kIsWeb && webVapidKey.isEmpty) {
      debugPrint('Set FIREBASE_VAPID_KEY to enable web push notifications.');
      return;
    }

    // Make the permission call before the first await so browsers retain the
    // user activation that is required for the iPhone PWA prompt.
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) {
      return;
    }
    await initialize(uid, requestPermission: false);
  }

  /// Call BEFORE signing out so the device stops receiving this account's
  /// pushes. Firestore rules may require the user to still be signed in.
  Future<void> clear(String uid) async {
    final token = _token;

// Stop listeners and invalidate the active account before async work.
    _activeUid = null;
    await _detach();

    if (!isSupported) return;

    try {
      if (token != null && token.isNotEmpty) {
        await _pushDoc(uid).set(
          {
            'tokens': FieldValue.arrayRemove([token]),
          },
          SetOptions(merge: true),
        );
      }

// Invalidate this device's current FCM token.
      // ignore: deprecated_member_use
      await _messaging.deleteToken();
    } catch (error, stackTrace) {
      debugPrint('NotificationService.clear error: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void _publish(PushEventKind kind, RemoteMessage message) {
    if (_events.isClosed) return;

    _events.add(
      PushEvent(
        kind: kind,
        title: message.notification?.title,
        body: message.notification?.body,
        data: {
          for (final entry in message.data.entries)
            entry.key: entry.value?.toString() ?? '',
        },
      ),
    );
  }

  Future<String?> _fetchToken() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
// The APNs token can arrive asynchronously after launch.
// getToken() may fail until the APNs token exists.
      for (var i = 0; i < 10; i++) {
        if (await _messaging.getAPNSToken() != null) break;
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }

    if (kIsWeb) {
      if (webVapidKey.isEmpty) return null;
      // The app's backend currently stores legacy FCM registration tokens.
      // ignore: deprecated_member_use
      return _messaging.getToken(
        vapidKey: webVapidKey,
        serviceWorkerScriptPath: 'firebase-messaging-sw.js',
      );
    }
    // ignore: deprecated_member_use
    return _messaging.getToken();
  }

  /// Cancels listeners and clears the cached token.
  Future<void> _detach() async {
    await _refreshSub?.cancel();
    await _foregroundSub?.cancel();
    await _openedSub?.cancel();

    _refreshSub = null;
    _foregroundSub = null;
    _openedSub = null;
    _token = null;
  }

  /// Saves the FCM token for the signed-in user.
  ///
  /// Errors deliberately propagate to the caller so initialization failures
  /// can be logged and retried.
  Future<void> _saveToken(String uid, String token) async {
    await _pushDoc(uid).set(
      {
        'tokens': FieldValue.arrayUnion([token]),
        'tokenUpdatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
