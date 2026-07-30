import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/split_provider.dart';
import '../widgets/branded_loader.dart';
import 'auth/login_screen.dart';
import 'landing_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final uid = auth.currentUser?.uid;

    // Defer to after this frame so we're not calling notifyListeners()
    // (via SplitProvider.setUserId) in the middle of a build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      context.read<SplitProvider>().setUserId(uid);
    });

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
