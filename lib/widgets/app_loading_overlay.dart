import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// App-wide blocking loader for operations that must finish before the user
/// can continue (settlements, sign-out, and other critical actions).
///
/// Call [show] before awaiting work and always call [hide] in a finally block.
class AppLoadingOverlay {
  AppLoadingOverlay._();

  static final ValueNotifier<String?> _message = ValueNotifier<String?>(null);

  static void show(String message) {
    _message.value = message;
  }

  static void hide() {
    _message.value = null;
  }

  static Widget wrap(Widget child) {
    return ValueListenableBuilder<String?>(
      valueListenable: _message,
      builder: (context, message, _) {
        return Stack(
          fit: StackFit.expand,
          children: [
            child,
            if (message != null)
              Positioned.fill(
                child: AbsorbPointer(
                  absorbing: true,
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.58),
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 260),
                        margin: const EdgeInsets.symmetric(horizontal: 28),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 24,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.ink,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.brass.withValues(alpha: 0.65),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.22),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 36,
                              height: 36,
                              child: CircularProgressIndicator(
                                color: AppColors.brass,
                                strokeWidth: 3,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              message,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.paper,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 5),
                            const Text(
                              'Please wait…',
                              style: TextStyle(
                                color: AppColors.slate,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
