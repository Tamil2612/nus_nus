import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../providers/split_provider.dart';
import '../theme/app_colors.dart';
import '../utils/currency_formatter.dart';
import 'common_atoms.dart';

/// Shows each person's net settle-up amount summed across *every* group,
/// not just the one currently open. People are matched by name since
/// there's no shared identity across groups — see
/// [SplitProvider.overallBalancesByName].
class OverviewTab extends StatelessWidget {
  const OverviewTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SplitProvider>();
    final overall = provider.overallBalancesByName;
    final totalOwedToYou =
        overall.where((o) => o.amount > 0).fold(0.0, (s, o) => s + o.amount);
    final totalYouOwe = overall
        .where((o) => o.amount < 0)
        .fold(0.0, (s, o) => s + o.amount.abs());

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        children: [
          // Grand-total summary card
          _panel(
            child: Row(
              children: [
                Expanded(
                  child: _summaryStat(
                    label: 'OWED TO YOU',
                    amount: totalOwedToYou,
                    color: AppColors.sage,
                  ),
                ),
                Container(width: 1, height: 40.h, color: AppColors.line),
                Expanded(
                  child: _summaryStat(
                    label: 'YOU OWE',
                    amount: totalYouOwe,
                    color: AppColors.rust,
                  ),
                ),
              ],
            ),
          ),
          16.verticalSpace,
          _panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle(title: 'All Groups, Combined'),
                6.verticalSpace,
                Text(
                  'Everyone\'s total settle-up amount across every group '
                  'they\'re in, matched by name.',
                  style: TextStyle(fontSize: 11.5.sp, color: AppColors.slate),
                ),
                14.verticalSpace,
                if (overall.isEmpty)
                  const EmptyHint(
                      'No balances yet — add expenses in a group to see totals here.')
                else
                  ...overall.map((o) {
                    final owed = o.amount > 0.005;
                    final owes = o.amount < -0.005;
                    final color = owed
                        ? AppColors.sage
                        : (owes ? AppColors.rust : AppColors.slate);
                    final label =
                        owed ? 'is owed' : (owes ? 'owes' : 'settled');
                    return Container(
                      margin: EdgeInsets.only(bottom: 8.h),
                      padding: EdgeInsets.symmetric(
                          horizontal: 12.w, vertical: 10.h),
                      decoration: BoxDecoration(
                        color: AppColors.paperDim,
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14.r,
                            backgroundColor: color.withOpacity(0.85),
                            child: Text(
                              o.name.isNotEmpty ? o.name[0].toUpperCase() : '?',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                          10.horizontalSpace,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  o.name,
                                  style: TextStyle(
                                      fontSize: 13.5.sp,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.ink),
                                ),
                                Text(
                                  'across ${o.groupCount} group${o.groupCount == 1 ? '' : 's'}',
                                  style: TextStyle(
                                      fontSize: 11.sp, color: AppColors.slate),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '$label ${fmtAed(o.amount.abs())}',
                            style: TextStyle(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w700,
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
        ],
      ),
    );
  }

  Widget _summaryStat(
      {required String label, required double amount, required Color color}) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 10.sp,
                letterSpacing: 1.2,
                color: AppColors.slate,
                fontWeight: FontWeight.w600)),
        6.verticalSpace,
        Text(
          fmtAed(amount),
          style: TextStyle(
              fontSize: 18.sp, fontWeight: FontWeight.w800, color: color),
        ),
      ],
    );
  }

  Widget _panel({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(14.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}
