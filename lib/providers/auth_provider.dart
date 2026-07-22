import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../data/member_directory_repository.dart';
import '../models/app_user.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? _user;
  bool _isBusy = false;
  String? _errorMessage;

  AuthProvider() {
    _user = _auth.currentUser;
    _auth.authStateChanges().listen((user) {
      _user = user;
      notifyListeners();
    });
  }

  User? get currentUser => _user;
  bool get isSignedIn => _user != null;
  bool get isBusy => _isBusy;
  String? get errorMessage => _errorMessage;

  void _setBusy(bool value) {
    _isBusy = value;
    notifyListeners();
  }

  /// Returns null on success, or a user-facing error message.
  Future<String?> register({
    required String name,
    required String email,
    required String password,
  }) async {
    _errorMessage = null;
    _setBusy(true);
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await credential.user?.updateDisplayName(name.trim());

      final uid = credential.user?.uid;
      if (uid != null) {
        // Publish the public profile so this person shows up in every
        // other signed-in user's "add from registered members" picker.
        await MemberDirectoryRepository.instance.upsertProfile(
          AppUser(uid: uid, name: name.trim(), email: email.trim()),
        );
      }
      _setBusy(false);
      return null;
    } on FirebaseAuthException catch (e) {
      _setBusy(false);
      return _friendlyError(e);
    } catch (e) {
      _setBusy(false);
      return 'Something went wrong. Please try again.';
    }
  }

  /// Returns null on success, or a user-facing error message.
  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    _errorMessage = null;
    _setBusy(true);
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      _setBusy(false);
      return null;
    } on FirebaseAuthException catch (e) {
      _setBusy(false);
      return _friendlyError(e);
    } catch (e) {
      _setBusy(false);
      return 'Something went wrong. Please try again.';
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  String _friendlyError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'weak-password':
        return 'Password should be at least 6 characters.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'Network error — check your connection and try again.';
      default:
        return e.message ?? 'Authentication failed.';
    }
  }
}
