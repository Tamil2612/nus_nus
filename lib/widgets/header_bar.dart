import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_colors.dart';
import '../utils/currency_formatter.dart';

class HeaderBar extends StatelessWidget {
  final double totalSpent;

  const HeaderBar({super.key, required this.totalSpent});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 32.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.paper,
                      fontFamily: 'Georgia',
                    ),
                    children: [
                      TextSpan(text: 'Nus'),
                      TextSpan(
                          text: '·', style: TextStyle(color: AppColors.brass)),
                      TextSpan(text: 'Nus'),
                    ],
                  ),
                ),
                2.verticalSpace,
                Text(
                  'Split the tab — settled in dirhams, nothing ever moves.',
                  style: TextStyle(fontSize: 12.sp, color: AppColors.slate),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'TOTAL TABBED',
                style: TextStyle(
                  fontSize: 10.sp,
                  letterSpacing: 1.2,
                  color: AppColors.slate,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                fmtAed(totalSpent),
                style:  TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brassSoft,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
