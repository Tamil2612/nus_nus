import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/split_provider.dart';
import '../widgets/branded_loader.dart';
import 'auth/login_screen.dart';
import 'landing_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _hasHandledUid = false;
  String? _handledUid;

  void _scheduleAuthEffects(String? uid) {
    if (_hasHandledUid && _handledUid == uid) return;
    _hasHandledUid = true;
    _handledUid = uid;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || context.read<AuthProvider>().currentUser?.uid != uid) {
        return;
      }
      context.read<SplitProvider>().setUserId(uid);
      if (uid == null) {
        final navigator = Navigator.of(context);
        if (navigator.canPop()) {
          navigator.popUntil((route) => route.isFirst);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final uid = auth.currentUser?.uid;
    // Schedule once per auth change. Repeating Navigator.popUntil on every
    // rebuild can tear down an in-flight route transition more than once.
    _scheduleAuthEffects(uid);

    Widget child;
    String key;
    if (uid == null) {
      child = const LoginScreen();
      key = 'login';
    } else if (context.watch<SplitProvider>().isLoading) {
      // Covers both the moment auth flips over and the (usually brief)
      // wait for the first Firestore snapshot — one crossfaded branded
      // screen instead of two different spinners flashing one after the
      // other, which is what made the old loading state feel broken.
      child = const BrandedLoader(message: 'Getting your groups ready…');
      key = 'loading';
    } else {
      child = const LandingScreen();
      key = 'home';
    }

    // Do not keep the signed-in screen alive in AnimatedSwitcher while the
    // navigator is simultaneously popping protected routes on sign-out.
    // Its outgoing subtree can retain inherited dependents during teardown.
    if (uid == null) return child;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (widget, animation) =>
          FadeTransition(opacity: animation, child: widget),
      child: KeyedSubtree(key: ValueKey(key), child: child),
    );
  }
}
