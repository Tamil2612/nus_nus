import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../providers/split_provider.dart';
import '../theme/app_colors.dart';
import '../utils/currency_formatter.dart';
import 'common_atoms.dart';

class BalancesTab extends StatelessWidget {
  const BalancesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SplitProvider>();
    final people = provider.people;
    final net = provider.balances;
    final transfers = provider.settlement;

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        children: [
          // Net Balances Summary Card
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle(title: 'Net Balances'),
                12.verticalSpace,
                if (people.isEmpty)
                  const EmptyHint('Add people to see balances.')
                else
                  ...people.map((p) {
                    final v = net[p.id] ?? 0;
                    final owed = v > 0.005;
                    final owes = v < -0.005;
                    final color = owed
                        ? AppColors.sage
                        : (owes ? AppColors.rust : AppColors.slate);
                    final label =
                        owed ? 'is owed' : (owes ? 'owes' : 'is settled');
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: 6.h),
                      child: Row(
                        children: [
                          Container(
                            width: 8.w,
                            height: 8.w,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          12.horizontalSpace,
                          Text(
                            p.name,
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13.5.sp,
                                color: AppColors.ink),
                          ),
                          const Spacer(),
                          Text(
                            '$label ${fmtAed(v.abs())}',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5.sp,
                                color: color),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
          
          16.verticalSpace,

          // Detailed Who Owes Who breakdown
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle(title: 'Who Owes Who'),
                12.verticalSpace,
                if (transfers.isEmpty)
                  Text(
                    'Everyone is square. 🎉',
                    style: TextStyle(color: AppColors.slate, fontSize: 13.sp),
                  )
                else
                  ...people.where((p) {
                    // Only show people who have an active debt or credit
                    final v = net[p.id] ?? 0;
                    return v.abs() > 0.005;
                  }).map((p) {
                    final paysOthers = transfers.where((t) => t.fromId == p.id).toList();
                    final receivesFromOthers = transfers.where((t) => t.toId == p.id).toList();

                    return Container(
                      margin: EdgeInsets.only(bottom: 16.h),
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14.sp,
                              color: AppColors.ink,
                            ),
                          ),
                          4.verticalSpace,
                          Divider(color: AppColors.line, thickness: 0.5),
                          if (paysOthers.isNotEmpty)
                            ...paysOthers.map((t) => Padding(
                              padding: EdgeInsets.symmetric(vertical: 4.h),
                              child: Row(
                                children: [
                                  Text('Owes ', style: TextStyle(fontSize: 12.sp, color: AppColors.slate)),
                                  Text(provider.personById(t.toId)?.name ?? '?', 
                                    style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold, color: AppColors.rust)),
                                  const Spacer(),
                                  Text(fmtAed(t.amount), style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold, color: AppColors.ink)),
                                ],
                              ),
                            )),
                          if (receivesFromOthers.isNotEmpty)
                            ...receivesFromOthers.map((t) => Padding(
                              padding: EdgeInsets.symmetric(vertical: 4.h),
                              child: Row(
                                children: [
                                  Text('Is owed by ', style: TextStyle(fontSize: 12.sp, color: AppColors.slate)),
                                  Text(provider.personById(t.fromId)?.name ?? '?', 
                                    style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold, color: AppColors.sage)),
                                  const Spacer(),
                                  Text(fmtAed(t.amount), style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold, color: AppColors.ink)),
                                ],
                              ),
                            )),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
