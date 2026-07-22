import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/person.dart';
import '../theme/app_colors.dart';

class PersonChip extends StatelessWidget {
  final Person person;
  final VoidCallback onRemove;

  const PersonChip({super.key, required this.person, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(left: 6.w, right: 10.w, top: 6.h, bottom: 6.h),
      decoration: BoxDecoration(
        color: AppColors.paperDim,
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 10.r,
            backgroundColor: person.color,
            child: Text(
              person.name[0].toUpperCase(),
              style:  TextStyle(
                  fontSize: 10.sp, color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
          6.horizontalSpace,
          Text(
            person.name,
            style: TextStyle(
                fontSize: 13.sp, fontWeight: FontWeight.w600, color: AppColors.ink),
          ),
          if (person.linkedUserId != null) ...[
            4.horizontalSpace,
            Icon(Icons.verified, size: 13.r, color: AppColors.brass),
          ],
          GestureDetector(
            onTap: onRemove,
            child:  Padding(
              padding: EdgeInsets.only(left: 4.w),
              child: Icon(Icons.close, size: 14.w, color: AppColors.slate),
            ),
          ),
        ],
      ),
    );
  }
}
