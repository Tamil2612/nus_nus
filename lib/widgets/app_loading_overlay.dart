import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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
                    color: Colors.black.withValues(alpha: 0.6),
                    child: Center(
                      child: Container(
                        constraints: BoxConstraints(maxWidth: 280.w),
                        margin: EdgeInsets.symmetric(horizontal: 32.w),
                        padding: EdgeInsets.symmetric(
                          horizontal: 24.w,
                          vertical: 24.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.inkSoft,
                          borderRadius: BorderRadius.circular(24.r),
                          border: Border.all(
                            color: AppColors.brass.withValues(alpha: 0.5),
                            width: 1.5.r,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 24,
                              offset: Offset(0, 8.h),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 36.r,
                              height: 36.r,
                              child: CircularProgressIndicator(
                                color: AppColors.brass,
                                strokeWidth: 3.5.r,
                              ),
                            ),
                            20.verticalSpace,
                            Text(
                              message,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.paper,
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.none,
                                letterSpacing: 0.5,
                              ),
                            ),
                            6.verticalSpace,
                            Text(
                              'Please wait…',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.slate,
                                fontSize: 12.5.sp,
                                fontWeight: FontWeight.w500,
                                decoration: TextDecoration.none,
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
