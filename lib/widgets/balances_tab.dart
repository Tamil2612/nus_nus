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
      padding:  EdgeInsets.all(16.w),
      child: Container(
        padding:  EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle(title: 'Balances'),
            8.verticalSpace,
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
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  child: Row(
                    children: [
                      Text(
                        p.name,
                        style:  TextStyle(
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
             Padding(
              padding: EdgeInsets.symmetric(vertical: 18.h),
              child: Divider(color: AppColors.line, height: 1),
            ),
            const SectionTitle(title: 'Suggested settle-up'),
            8.verticalSpace,
            if (transfers.isEmpty)
               Text(
                'Everyone is square. 🎉',
                style: TextStyle(color: AppColors.slate, fontSize: 13.sp),
              )
            else
              ...transfers.map((t) {
                final from = provider.personById(t.fromId);
                final to = provider.personById(t.toId);
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 6.h),
                  child: Row(
                    children: [
                      Text(
                        from?.name ?? '?',
                        style:  TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.sp,
                            color: AppColors.ink),
                      ),
                       Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6.w),
                        child: Text('→',
                            style: TextStyle(
                                color: AppColors.brass,
                                fontWeight: FontWeight.w700)),
                      ),
                      Text(
                        to?.name ?? '?',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.sp,
                            color: AppColors.ink),
                      ),
                      const Spacer(),
                      Text(
                        fmtAed(t.amount),
                        style:  TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.sp,
                            color: AppColors.ink),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
