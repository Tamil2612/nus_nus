import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_colors.dart';

/// The single loading screen used everywhere the app needs to wait on
/// something (auth handoff, first Firestore snapshot, etc.) — a plain
/// bare spinner looks like a glitch when it flashes on screen for a
/// fraction of a second; a branded screen with a short message reads as
/// intentional even when it's only visible briefly.
class BrandedLoader extends StatelessWidget {
  final String message;

  const BrandedLoader({super.key, this.message = 'Loading…'});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.4, -0.6),
            radius: 1.2,
            colors: [AppColors.inkSoft, AppColors.ink],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 30.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.paper,
                    fontFamily: 'Georgia',
                  ),
                  children: [
                    const TextSpan(text: 'Nus'),
                    TextSpan(text: '·', style: TextStyle(color: AppColors.brass)),
                    const TextSpan(text: 'Nus'),
                  ],
                ),
              ),
              22.verticalSpace,
              SizedBox(
                width: 26.r,
                height: 26.r,
                child: const CircularProgressIndicator(
                  color: AppColors.brass,
                  strokeWidth: 2.4,
                ),
              ),
              14.verticalSpace,
              Text(
                message,
                style: TextStyle(color: AppColors.slate, fontSize: 12.5.sp),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
