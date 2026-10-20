import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../providers/split_provider.dart';
import '../theme/app_colors.dart';

class HeaderBar extends StatelessWidget {
  const HeaderBar({super.key});

  @override
  Widget build(BuildContext context) {
    context.watch<SplitProvider>();
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 10.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Material(
            color: Colors.white.withValues(alpha: .06),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => Scaffold.of(context).openDrawer(),
              child: SizedBox(
                width: 42.r,
                height: 42.r,
                child: Icon(Icons.menu_rounded,
                    color: AppColors.paper, size: 23.r),
              ),
            ),
          ),
          13.horizontalSpace,
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.paper,
                  fontFamily: 'Georgia',
                  letterSpacing: -.5,
                ),
                children: [
                  const TextSpan(text: 'Nus'),
                  TextSpan(text: '·', style: TextStyle(color: AppColors.brass)),
                  const TextSpan(text: 'Nus'),
                ],
              ),
            ),
          ),
          4.horizontalSpace,
        ],
      ),
    );
  }
}
