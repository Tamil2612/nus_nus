import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../providers/split_provider.dart';
import '../theme/app_colors.dart';

class HeaderBar extends StatelessWidget {
  final double totalSpent;
  final int tabIndex;

  const HeaderBar({super.key, required this.totalSpent, this.tabIndex = 0});

  @override
  Widget build(BuildContext context) {
    context.watch<SplitProvider>();
    return Padding(
      padding: EdgeInsets.fromLTRB(4.w, 16.h, 20.w, 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          InkWell(
            onTap: () => Scaffold.of(context).openDrawer(),
            child: Padding(
              padding:  EdgeInsets.symmetric(horizontal: 8.w),
              child: Image.asset('assets/icon/menu.png', width: 28.w,color: AppColors.paper,),
            ),
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
        ],
      ),
    );
  }
}
