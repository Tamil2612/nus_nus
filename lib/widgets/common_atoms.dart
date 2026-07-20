import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_colors.dart';

class SectionTitle extends StatelessWidget {
  final String title;
  final String trailing;

  const SectionTitle({super.key, required this.title, this.trailing = ''});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.ink),
        ),
        if (trailing.isNotEmpty)
          Text(
            trailing,
            style: TextStyle(
                fontSize: 10.5.sp,
                letterSpacing: 1.2,
                color: AppColors.slate,
                fontWeight: FontWeight.w600),
          ),
      ],
    );
  }
}

class EmptyHint extends StatelessWidget {
  final String text;

  const EmptyHint(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Text(text,
          style: TextStyle(color: AppColors.slate, fontSize: 12.5.sp)),
    );
  }
}
