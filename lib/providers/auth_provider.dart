import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../data/member_directory_repository.dart';
import '../models/app_user.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? _user;
  AppUser? _appUser;
  bool _isBusy = false;
  String? _errorMessage;

  AuthProvider() {
    _user = _auth.currentUser;
    if (_user != null) {
      _fetchAppUser(_user!.uid);
    }
    // userChanges() (not authStateChanges()) so that a profile-only
    // update — like the displayName we set right after registering —
    // refreshes [currentUser] too. authStateChanges() only fires on
    // sign-in/sign-out and would leave displayName looking empty
    // anywhere it's read (e.g. group ownership labels) until the next
    // full sign-in.
    _auth.userChanges().listen((user) {
      _user = user;
      if (user != null) {
        _fetchAppUser(user.uid);
      } else {
        _appUser = null;
      }
      notifyListeners();
    });
  }

  User? get currentUser => _user;
  AppUser? get appUser => _appUser;
  bool get isSignedIn => _user != null;
  bool get isBusy => _isBusy;
  String? get errorMessage => _errorMessage;

  void _setBusy(bool value) {
    _isBusy = value;
    notifyListeners();
  }

  Future<void> _fetchAppUser(String uid) async {
    final profile = await MemberDirectoryRepository.instance.fetchByUid(uid);
    if (profile != null) {
      _appUser = profile;
      notifyListeners();
    }
  }

  Future<String?> register({
    required String name,
    required String email,
    required String password,
    String? phoneNumber,
  }) async {
    _errorMessage = null;
    _setBusy(true);
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await credential.user?.updateDisplayName(name.trim());
      // updateDisplayName() writes to the server but doesn't refresh the
      // locally cached User object on its own — reload() pulls the fresh
      // profile back down so `currentUser.displayName` is correct the
      // moment this call returns, instead of staying blank until some
      // unrelated later refresh.
      await credential.user?.reload();
      _user = _auth.currentUser;

      final uid = credential.user?.uid;
      if (uid != null) {
        // Publish the public profile so this person shows up in every
        // other signed-in user's "add from registered members" picker.
        await MemberDirectoryRepository.instance.upsertProfile(
          AppUser(
              uid: uid,
              name: name.trim(),
              email: email.trim(),
              phoneNumber: phoneNumber),
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

  Future<void> reloadUser() async {
    await _user?.reload();
    _user = _auth.currentUser;
    if (_user != null) {
      await _fetchAppUser(_user!.uid);
    }
    notifyListeners();
  }

  Future<String?> updateProfile({String? name, String? phoneNumber}) async {
    final uid = _user?.uid;
    if (uid == null) return 'No user signed in.';
    _setBusy(true);
    try {
      if (name != null) {
        await _user?.updateDisplayName(name.trim());
        await _user?.reload();
        _user = _auth.currentUser;
      }

      await MemberDirectoryRepository.instance.upsertProfile(
        AppUser(
          uid: uid,
          name: name ?? _user?.displayName ?? '',
          email: _user?.email ?? '',
          phoneNumber: phoneNumber,
        ),
      );
      await _fetchAppUser(uid);
      _setBusy(false);
      return null;
    } on FirebaseAuthException catch (e) {
      _setBusy(false);
      return _friendlyError(e);
    } catch (e) {
      _setBusy(false);
      return 'Failed to update profile.';
    }
  }

  Future<String?> updateEmail(String newEmail, String currentPassword) async {
    _setBusy(true);
    try {
      final email = _user?.email;
      if (email == null) return 'No user signed in.';

      // Re-authenticate
      AuthCredential credential = EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );
      await _user?.reauthenticateWithCredential(credential);

      // Update Email (Newer Firebase Auth uses verifyBeforeUpdateEmail)
      await _user?.verifyBeforeUpdateEmail(newEmail.trim());
      await _user?.reload();
      _user = _auth.currentUser;

      // Update Firestore with the NEW email immediately so the app shows it
      await MemberDirectoryRepository.instance.upsertProfile(
        AppUser(
          uid: _user!.uid,
          name: _user!.displayName ?? '',
          email: newEmail.trim(),
          phoneNumber: _appUser?.phoneNumber,
        ),
      );
      await _fetchAppUser(_user!.uid);

      _setBusy(false);
      return null;
    } on FirebaseAuthException catch (e) {
      _setBusy(false);
      return _friendlyError(e);
    } catch (e) {
      _setBusy(false);
      return 'Failed to update email.';
    }
  }

  Future<String?> updatePassword(
      String newPassword, String currentPassword) async {
    _setBusy(true);
    try {
      final email = _user?.email;
      if (email == null) return 'No user signed in.';

      // Re-authenticate
      AuthCredential credential = EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );
      await _user?.reauthenticateWithCredential(credential);

      // Update Password
      await _user?.updatePassword(newPassword);
      _setBusy(false);
      return null;
    } on FirebaseAuthException catch (e) {
      _setBusy(false);
      return _friendlyError(e);
    } catch (e) {
      _setBusy(false);
      return 'Failed to update password.';
    }
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
