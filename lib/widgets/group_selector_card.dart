import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../models/group.dart';
import '../../../providers/split_provider.dart';
import '../../../theme/app_colors.dart';

class GroupSelectorCard extends StatelessWidget {
  final Group? selectedGroup;
  final ValueChanged<Group> onGroupChanged;

  const GroupSelectorCard({
    super.key,
    required this.selectedGroup,
    required this.onGroupChanged,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.read<SplitProvider>();

    final group = selectedGroup;

    return InkWell(
      borderRadius: BorderRadius.circular(24.r),
      onTap: () => _showGroupPicker(context, provider),
      child: Container(
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .06),
          borderRadius: BorderRadius.circular(28.r),
          border: Border.all(
            color: AppColors.line.withValues(alpha: .3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52.r,
                  height: 52.r,
                  decoration: BoxDecoration(
                    color: AppColors.brass.withValues(alpha: .15),
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Icon(
                    Icons.groups_rounded,
                    color: AppColors.brass,
                    size: 28.r,
                  ),
                ),
                16.horizontalSpace,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Expense Group",
                        style: TextStyle(
                          color: AppColors.slate,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      4.verticalSpace,
                      Text(
                        group?.name ?? "Choose a group",
                        style: TextStyle(
                          color: AppColors.paper,
                          fontSize: 20.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.paper,
                  size: 28.r,
                ),
              ],
            ),
            if (group != null) ...[
              18.verticalSpace,
              Divider(
                color: AppColors.line.withValues(alpha: .30),
              ),
              14.verticalSpace,
              Text(
                "Members",
                style: TextStyle(
                  color: AppColors.slate,
                  fontWeight: FontWeight.w600,
                ),
              ),
              14.verticalSpace,
              SizedBox(
                height: 48.h,
                child: Stack(
                  children: List.generate(
                    group.members.length > 6 ? 6 : group.members.length,
                    (index) {
                      final member = group.members[index];

                      return Positioned(
                        left: index * 30.w,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.ink, width: 2),
                          ),
                          child: CircleAvatar(
                            radius: 20.r,
                            backgroundColor: member.color,
                            child: Text(
                              member.name.characters.first.toUpperCase(),
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14.sp,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              if (group.members.length > 6)
                Padding(
                  padding: EdgeInsets.only(top: 8.h),
                  child: Text(
                    "+${group.members.length - 6} more",
                    style: TextStyle(color: AppColors.slate, fontSize: 11.sp),
                  ),
                ),
              12.verticalSpace,
              Text(
                "${group.members.length} members",
                style: TextStyle(
                  color: AppColors.paperDim,
                  fontSize: 12.sp,
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  void _showGroupPicker(
    BuildContext context,
    SplitProvider provider,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.inkSoft,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28.r),
        ),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.all(20.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 50.w,
                  height: 5.h,
                  decoration: BoxDecoration(
                    color: AppColors.slate,
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
                24.verticalSpace,
                Text(
                  "Choose Group",
                  style: TextStyle(
                    color: AppColors.paper,
                    fontWeight: FontWeight.bold,
                    fontSize: 22.sp,
                  ),
                ),
                20.verticalSpace,
                ...provider.groups.map((group) {
                  final selected = provider.currentGroup?.id == group.id;

                  return Padding(
                    padding: EdgeInsets.only(bottom: 14.h),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18.r),
                      onTap: () {
                        onGroupChanged(group);
                        Navigator.pop(context);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: EdgeInsets.all(16.w),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.brass.withValues(alpha: .15)
                              : Colors.white.withValues(alpha: .04),
                          borderRadius: BorderRadius.circular(18.r),
                          border: Border.all(
                            color: selected
                                ? AppColors.brass
                                : AppColors.line.withValues(alpha: .25),
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppColors.brass,
                              child: Icon(
                                Icons.groups,
                                color: AppColors.ink,
                              ),
                            ),
                            16.horizontalSpace,
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    group.name,
                                    style: TextStyle(
                                      color: AppColors.paper,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16.sp,
                                    ),
                                  ),
                                  4.verticalSpace,
                                  Text(
                                    "${group.members.length} members",
                                    style: TextStyle(
                                      color: AppColors.paperDim,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (selected)
                              Icon(
                                Icons.check_circle,
                                color: AppColors.brass,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}
