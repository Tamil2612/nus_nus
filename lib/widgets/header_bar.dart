import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_colors.dart';
import '../utils/currency_formatter.dart';

class HeaderBar extends StatelessWidget {
  final double totalSpent;

  const HeaderBar({super.key, required this.totalSpent});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4.w, 16.h, 20.w, 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(Icons.menu, color: AppColors.paper, size: 28.r),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
          8.horizontalSpace,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 28.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.paper,
                      fontFamily: 'Georgia',
                    ),
                    children: [
                      const TextSpan(text: 'Nus'),
                      TextSpan(
                          text: '·', style: TextStyle(color: AppColors.brass)),
                      const TextSpan(text: 'Nus'),
                    ],
                  ),
                ),
                Text(
                  'Split the bill.',
                  style: TextStyle(fontSize: 11.sp, color: AppColors.slate),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'TOTAL TABBED',
                style: TextStyle(
                  fontSize: 9.sp,
                  letterSpacing: 1.1,
                  color: AppColors.slate,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                fmtAed(totalSpent),
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brassSoft,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
