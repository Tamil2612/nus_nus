import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What happened to a push notification, as far as the UI cares.
enum PushEventKind {
  /// A push arrived while the app was open.
  foreground,

  /// The user tapped a push (app was in the background or closed).
  opened,
}

enum NotificationEnableStatus {
  enabled,
  permissionRequired,
  permissionDenied,
  unsupported,
  missingConfiguration,
  registrationFailed,
}

class NotificationEnableResult {
  final NotificationEnableStatus status;
  final String? message;

  const NotificationEnableResult(this.status, {this.message});

  bool get succeeded => status == NotificationEnableStatus.enabled;
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
  String? _requestedUid;
  String? _token;
  String? _registeredUid;
  String? _registrationUid;
  int _sessionGeneration = 0;
  int? _registrationGeneration;
  Future<NotificationEnableResult>? _registrationFuture;

  StreamSubscription<String>? _refreshSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedSub;

  DocumentReference<Map<String, dynamic>> _pushDoc(String uid) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('private')
          .doc('push');

  String _notificationsEnabledKey(String uid) =>
      'nus_nus_notifications_enabled_$uid';

  Future<bool> _isOptedOut(String uid) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_notificationsEnabledKey(uid)) == false;
  }

  /// Current capability and registration state for the signed-in user.
  Future<NotificationEnableResult> statusFor(String uid) async {
    if (uid.trim().isEmpty || !isSupported) {
      return const NotificationEnableResult(
        NotificationEnableStatus.unsupported,
      );
    }
    if (kIsWeb && webVapidKey.isEmpty) {
      return const NotificationEnableResult(
        NotificationEnableStatus.missingConfiguration,
      );
    }
    try {
      if (await _isOptedOut(uid)) {
        return const NotificationEnableResult(
          NotificationEnableStatus.permissionRequired,
          message: 'Notifications are off on this device.',
        );
      }
      if (!await _messaging.isSupported()) {
        return const NotificationEnableResult(
          NotificationEnableStatus.unsupported,
        );
      }
      final settings = await _messaging.getNotificationSettings();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return const NotificationEnableResult(
          NotificationEnableStatus.permissionDenied,
        );
      }
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        return const NotificationEnableResult(
          NotificationEnableStatus.permissionRequired,
        );
      }
      if (_registeredUid == uid) {
        return const NotificationEnableResult(
          NotificationEnableStatus.enabled,
        );
      }
      final pending = _registrationFuture;
      if (_registrationUid == uid &&
          _registrationGeneration == _sessionGeneration &&
          _requestedUid == uid &&
          pending != null) {
        return await pending;
      }
      // Permission exists, but this app instance has not finished registering
      // its token yet. Keep the opt-in action available as a retry.
      return const NotificationEnableResult(
        NotificationEnableStatus.permissionRequired,
        message: 'Permission is allowed; finish registering this device.',
      );
    } catch (error, stackTrace) {
      debugPrint('NotificationService.statusFor failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return NotificationEnableResult(
        NotificationEnableStatus.registrationFailed,
        message: 'Could not check notification settings. Please try again.',
      );
    }
  }

  /// Initializes notifications. Web startup only checks existing permission;
  /// the explicit opt-in method below is the only web permission prompt.
  Future<NotificationEnableResult> initialize(
    String uid, {
    bool requestPermission = true,
  }) async {
    if (uid.trim().isEmpty || !isSupported) {
      return const NotificationEnableResult(
        NotificationEnableStatus.unsupported,
      );
    }
    if (kIsWeb && webVapidKey.isEmpty) {
      return const NotificationEnableResult(
        NotificationEnableStatus.missingConfiguration,
      );
    }
    _claimSession(uid);
    final generation = _sessionGeneration;
    try {
      if (await _isOptedOut(uid)) {
        return const NotificationEnableResult(
          NotificationEnableStatus.permissionRequired,
          message: 'Notifications are off on this device.',
        );
      }
      final settings = requestPermission
          ? await _messaging.requestPermission(
              alert: true,
              badge: true,
              sound: true,
            )
          : await _messaging.getNotificationSettings();
      if (generation != _sessionGeneration || _requestedUid != uid) {
        return _sessionChangedResult;
      }
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        return NotificationEnableResult(
          settings.authorizationStatus == AuthorizationStatus.denied
              ? NotificationEnableStatus.permissionDenied
              : NotificationEnableStatus.permissionRequired,
        );
      }
      return await _registerAuthorizedUser(uid, generation);
    } catch (error, stackTrace) {
      debugPrint('NotificationService initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return const NotificationEnableResult(
        NotificationEnableStatus.registrationFailed,
        message: 'Could not initialize notifications. Please try again.',
      );
    }
  }

  /// Must be called directly from a user action. On iPhone/iPad, Web Push is
  /// available only in an installed Home Screen web app on OS 16.4 or later.
  Future<NotificationEnableResult> enableNotifications(String uid) async {
    if (uid.trim().isEmpty || !isSupported) {
      return const NotificationEnableResult(
        NotificationEnableStatus.unsupported,
      );
    }
    if (kIsWeb && webVapidKey.isEmpty) {
      return const NotificationEnableResult(
        NotificationEnableStatus.missingConfiguration,
      );
    }
    _claimSession(uid);
    final generation = _sessionGeneration;
    if (_registeredUid == uid) {
      return const NotificationEnableResult(
        NotificationEnableStatus.enabled,
      );
    }

    try {
      // Keep this as the first asynchronous operation so the browser preserves
      // the user activation from the opt-in tap.
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (generation != _sessionGeneration || _requestedUid != uid) {
        return _sessionChangedResult;
      }
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        return NotificationEnableResult(
          settings.authorizationStatus == AuthorizationStatus.denied
              ? NotificationEnableStatus.permissionDenied
              : NotificationEnableStatus.permissionRequired,
        );
      }
      return await _registerAuthorizedUser(uid, generation);
    } catch (error, stackTrace) {
      debugPrint('NotificationService.enableNotifications failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return NotificationEnableResult(
        NotificationEnableStatus.registrationFailed,
        message:
            'Could not enable notifications. Check your connection and try again.',
      );
    }
  }

  void _claimSession(String uid) {
    if (_requestedUid == uid) return;
    _requestedUid = uid;
    _sessionGeneration++;
    _activeUid = null;
    _registeredUid = null;
  }

  static const _sessionChangedResult = NotificationEnableResult(
    NotificationEnableStatus.registrationFailed,
    message: 'The signed-in account changed. Please try again.',
  );

  Future<NotificationEnableResult> _registerAuthorizedUser(
    String uid,
    int generation,
  ) {
    if (generation != _sessionGeneration || _requestedUid != uid) {
      return Future.value(_sessionChangedResult);
    }
    if (_registeredUid == uid) {
      return Future.value(const NotificationEnableResult(
        NotificationEnableStatus.enabled,
      ));
    }
    final pending = _registrationFuture;
    if (_registrationUid == uid &&
        _registrationGeneration == generation &&
        pending != null) {
      return pending;
    }

    final registration = _performRegistration(uid, generation);
    _registrationUid = uid;
    _registrationGeneration = generation;
    _registrationFuture = registration;
    return registration.whenComplete(() {
      if (identical(_registrationFuture, registration)) {
        _registrationFuture = null;
        _registrationUid = null;
        _registrationGeneration = null;
      }
    });
  }

  Future<NotificationEnableResult> _performRegistration(
    String uid,
    int generation,
  ) async {
    var failedAt = 'starting registration';
    try {
      failedAt = 'preparing notification listeners';
      await _detach();
      if (generation != _sessionGeneration || _requestedUid != uid) {
        return _sessionChangedResult;
      }
      _activeUid = uid;

      // iOS: allow system banners while the app is in the foreground.
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        await _messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }
      if (_activeUid != uid || generation != _sessionGeneration) {
        return _sessionChangedResult;
      }

      _foregroundSub = FirebaseMessaging.onMessage.listen((message) {
        if (_activeUid == uid && generation == _sessionGeneration) {
          _publish(PushEventKind.foreground, message);
        }
      });
      _openedSub = FirebaseMessaging.onMessageOpenedApp.listen((message) {
        if (_activeUid == uid && generation == _sessionGeneration) {
          _publish(PushEventKind.opened, message);
        }
      });

      // Retain FCM registration tokens until the notification backend migrates.
      // ignore: deprecated_member_use
      _refreshSub = _messaging.onTokenRefresh.listen(
        (newToken) {
          if (_activeUid != uid || generation != _sessionGeneration) return;
          _token = newToken;
          _saveToken(uid, newToken).then((_) {
            _registeredUid = uid;
          }).catchError((Object _) {
            debugPrint('Failed to save refreshed notification token.');
          });
        },
        onError: (Object _) => debugPrint('Notification token refresh failed.'),
      );

      failedAt = 'requesting an FCM token';
      final token = await _fetchToken();
      if (_activeUid != uid || generation != _sessionGeneration) {
        return _sessionChangedResult;
      }
      if (token == null || token.isEmpty) {
        throw StateError('Notification token was not returned.');
      }
      _token = token;
      failedAt = 'saving the FCM token to Firestore';
      await _saveToken(uid, token);
      if (_activeUid != uid || generation != _sessionGeneration) {
        return _sessionChangedResult;
      }
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_notificationsEnabledKey(uid), true);
      _registeredUid = uid;
      failedAt = 'checking for a notification that opened the app';
      final initial = await _messaging.getInitialMessage();
      if (initial != null &&
          _activeUid == uid &&
          generation == _sessionGeneration) {
        _publish(PushEventKind.opened, initial);
      }
      return const NotificationEnableResult(NotificationEnableStatus.enabled);
    } catch (error, stackTrace) {
      debugPrint(
        'NotificationService registration failed while $failedAt: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      if (_activeUid == uid && generation == _sessionGeneration) {
        _activeUid = null;
        _registeredUid = null;
        await _detach();
      }
      return NotificationEnableResult(
        NotificationEnableStatus.registrationFailed,
        message:
            'Could not register this device. Check your connection and try again.',
      );
    }
  }

  /// Call BEFORE signing out so the device stops receiving this account's
  /// pushes. Firestore rules may require the user to still be signed in.
  Future<void> clear(String uid) async {
    await _clearDeviceToken(uid);
  }

  /// Stops push delivery on this device without signing the user out.
  Future<NotificationEnableResult> disableNotifications(String uid) async {
    if (uid.trim().isEmpty || !isSupported) {
      return const NotificationEnableResult(
        NotificationEnableStatus.unsupported,
      );
    }
    final removed = await _clearDeviceToken(uid);
    if (!removed) {
      return const NotificationEnableResult(
        NotificationEnableStatus.registrationFailed,
        message: 'Could not turn off notifications. Please try again.',
      );
    }
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_notificationsEnabledKey(uid), false);
    } catch (_) {
      return const NotificationEnableResult(
        NotificationEnableStatus.registrationFailed,
        message: 'Could not save this notification setting. Please try again.',
      );
    }
    return const NotificationEnableResult(
      NotificationEnableStatus.permissionRequired,
      message: 'Notifications are off on this device.',
    );
  }

  Future<void> forgetAccount(String uid) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_notificationsEnabledKey(uid));
  }

  Future<bool> _clearDeviceToken(String uid) async {
    final pending = _registrationUid == uid ? _registrationFuture : null;
    final registeredToken = _token;
    _sessionGeneration++;
    _requestedUid = null;
    _activeUid = null;
    _registeredUid = null;
    // Let an in-flight Firestore token write finish before removing the token,
    // so sign-out cannot leave a newly written token behind.
    if (pending != null) await pending;
    final token = _token ?? registeredToken;
    await _detach();
    _registeredUid = null;

    if (!isSupported) return true;

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
      return true;
    } catch (error, stackTrace) {
      debugPrint('NotificationService.clear error: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
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
