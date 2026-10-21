import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_colors.dart';

/// Unifies all popup dialog boxes across Nus·Nus with consistent
/// paper background, rounded corner geometry, icon header badge,
/// and clear visual button hierarchy.
class AppDialog extends StatelessWidget {
  final IconData? icon;
  final Color? iconColor;
  final Color? iconBackgroundColor;
  final String title;
  final String? message;
  final Widget? content;
  final String cancelText;
  final String confirmText;
  final Color? confirmColor;
  final VoidCallback? onCancel;
  final VoidCallback? onConfirm;
  final bool isConfirmDisabled;
  final bool showCancel;

  const AppDialog({
    super.key,
    this.icon,
    this.iconColor,
    this.iconBackgroundColor,
    required this.title,
    this.message,
    this.content,
    this.cancelText = 'Cancel',
    this.confirmText = 'Confirm',
    this.confirmColor,
    this.onCancel,
    this.onConfirm,
    this.isConfirmDisabled = false,
    this.showCancel = true,
  });

  /// Quick helper to trigger a standard confirmation popup.
  static Future<bool?> showConfirm(
    BuildContext context, {
    IconData? icon,
    Color? iconColor,
    Color? iconBackgroundColor,
    required String title,
    required String message,
    String cancelText = 'Cancel',
    String confirmText = 'Confirm',
    Color confirmColor = AppColors.ink,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        icon: icon,
        iconColor: iconColor,
        iconBackgroundColor: iconBackgroundColor,
        title: title,
        message: message,
        cancelText: cancelText,
        confirmText: confirmText,
        confirmColor: confirmColor,
        onCancel: () => Navigator.pop(ctx, false),
        onConfirm: () => Navigator.pop(ctx, true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = iconColor ?? confirmColor ?? AppColors.brass;
    final effectiveBgColor = iconBackgroundColor ??
        effectiveIconColor.withValues(alpha: 0.12);

    return Dialog(
      backgroundColor: AppColors.paper,
      surfaceTintColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24.r),
      ),
      child: Padding(
        padding: EdgeInsets.all(22.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Container(
                width: 44.r,
                height: 44.r,
                decoration: BoxDecoration(
                  color: effectiveBgColor,
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Icon(
                  icon,
                  color: effectiveIconColor,
                  size: 22.r,
                ),
              ),
              14.verticalSpace,
            ],
            Text(
              title,
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
                letterSpacing: -0.2,
              ),
            ),
            if (message != null && message!.isNotEmpty) ...[
              8.verticalSpace,
              Text(
                message!,
                style: TextStyle(
                  fontSize: 13.5.sp,
                  color: AppColors.slate,
                  height: 1.4,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
            if (content != null) ...[
              14.verticalSpace,
              Flexible(child: content!),
            ],
            20.verticalSpace,
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (showCancel && cancelText.isNotEmpty)
                  TextButton(
                    onPressed: onCancel ?? () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.slate,
                      padding: EdgeInsets.symmetric(
                          horizontal: 16.w, vertical: 10.h),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r)),
                    ),
                    child: Text(
                      cancelText,
                      style: TextStyle(
                        fontSize: 13.5.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (showCancel && cancelText.isNotEmpty) 8.horizontalSpace,
                ElevatedButton(
                  onPressed: isConfirmDisabled ? null : onConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: confirmColor ?? AppColors.ink,
                    foregroundColor: AppColors.paper,
                    disabledBackgroundColor:
                        AppColors.slate.withValues(alpha: 0.3),
                    elevation: 0,
                    padding: EdgeInsets.symmetric(
                        horizontal: 18.w, vertical: 10.h),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r)),
                  ),
                  child: Text(
                    confirmText,
                    style: TextStyle(
                      fontSize: 13.5.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
