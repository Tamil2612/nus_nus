import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../providers/split_provider.dart';
import '../theme/app_colors.dart';
import '../utils/currency_formatter.dart';

class HeaderBar extends StatelessWidget {
  const HeaderBar({super.key});

  @override
  Widget build(BuildContext context) {
    context.watch<SplitProvider>();
    return Padding(
      padding: EdgeInsets.fromLTRB(5.w, 16.h, 4.w, 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          InkWell(
            onTap: () => Scaffold.of(context).openDrawer(),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.w),
              child: Image.asset(
                'assets/icon/menu.png',
                width: 28.w,
                color: AppColors.paper,
              ),
            ),
          ),
          8.horizontalSpace,
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
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
                12.horizontalSpace,
                Padding(
                  padding: EdgeInsets.only(top: 4.h), // Optical baseline adjustment
                  child: Text(
                    'نص نص',
                    style: TextStyle(
                      fontSize: 16.sp,
                      color: AppColors.brassSoft,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          12.horizontalSpace,
        ],
      ),
    );
  }
}
