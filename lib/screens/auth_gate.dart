import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/split_provider.dart';
import '../theme/app_colors.dart';
import 'auth/login_screen.dart';
import 'split_home_screen.dart';

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

    if (uid == null) {
      return const LoginScreen();
    }

    return const _SplitProviderGuard(child: SplitHomeScreen());
  }
}

/// Shows a spinner instead of the (briefly stale) home screen while
/// SplitProvider is switching over to the newly signed-in user's data.
class _SplitProviderGuard extends StatelessWidget {
  final Widget child;
  const _SplitProviderGuard({required this.child});

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<SplitProvider>().isLoading;
    if (isLoading) {
      return const Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-0.4, -0.6),
              radius: 1.2,
              colors: [AppColors.inkSoft, AppColors.ink],
            ),
          ),
          child: Center(
            child: CircularProgressIndicator(color: AppColors.brass),
          ),
        ),
      );
    }
    return child;
  }
}
