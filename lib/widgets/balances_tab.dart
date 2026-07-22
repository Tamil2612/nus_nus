import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../models/pair_balance.dart';
import '../models/person.dart';
import '../providers/split_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';
import 'common_atoms.dart';

class BalancesTab extends StatelessWidget {
  const BalancesTab({super.key});

  /// People to show a balance row for: everyone active, plus anyone
  /// archived who still has a non-zero balance outstanding.
  List<Person> _visiblePeople(SplitProvider provider, Map<int, double> net) {
    final active = provider.people;
    final archivedWithBalance = provider.allPeople.where((p) =>
        p.archived && (net[p.id] ?? 0).abs() > 0.005);
    return [...active, ...archivedWithBalance];
  }

  Future<void> _confirmSettle(
    BuildContext context,
    SplitProvider provider,
    int fromId,
    int toId,
    double amount,
  ) async {
    final from = provider.personById(fromId);
    final to = provider.personById(toId);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.paper,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: const Text('Record settlement?',
            style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.bold)),
        content: Text(
          'This records that ${from?.name ?? '?'} paid ${to?.name ?? '?'} '
          '${fmtAed(amount)} outside the app. It just updates the ledger — '
          'no money actually moves.',
          style: const TextStyle(color: AppColors.slate),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.slate)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: AppTheme.solidButton.copyWith(
              backgroundColor: WidgetStateProperty.all(AppColors.sage),
            ),
            child: const Text('Mark as settled'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final error = provider.settleUp(fromId, toId, amount);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? 'Settled up — balances updated.'),
        backgroundColor: error != null ? AppColors.rust : AppColors.sage,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SplitProvider>();
    final net = provider.balances;
    final people = _visiblePeople(provider, net);
    final pairsToSettle = provider.pairBalances;

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        children: [
          // Net Balances Summary Card
          _panel(
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

                    // The pairwise detail behind the net total — this is
                    // what actually answers "owed by whom, specifically".
                    final breakdown = owed
                        ? provider.owedToPerson(p.id)
                        : (owes
                            ? provider.owedByPerson(p.id)
                            : const <PairBalance>[]);

                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: 6.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8.w,
                                height: 8.w,
                                decoration: BoxDecoration(
                                    color: color, shape: BoxShape.circle),
                              ),
                              12.horizontalSpace,
                              Expanded(
                                child: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        p.name,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13.5.sp,
                                            color: AppColors.ink),
                                      ),
                                    ),
                                    if (p.archived) ...[
                                      4.horizontalSpace,
                                      Text('(left)',
                                          style: TextStyle(
                                              fontSize: 10.5.sp,
                                              color: AppColors.slate,
                                              fontStyle: FontStyle.italic)),
                                    ],
                                  ],
                                ),
                              ),
                              Text(
                                '$label ${fmtAed(v.abs())}',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5.sp,
                                    color: color),
                              ),
                            ],
                          ),
                          if (breakdown.isNotEmpty)
                            Padding(
                              padding: EdgeInsets.only(left: 20.w, top: 4.h),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: breakdown.map((pb) {
                                  final counterpartId = owed
                                      ? pb.debtorId
                                      : pb.creditorId;
                                  final counterpart =
                                      provider.personById(counterpartId!);
                                  return Padding(
                                    padding: EdgeInsets.only(bottom: 2.h),
                                    child: Text(
                                      '↳ ${counterpart?.name ?? '?'}  ${fmtAed(pb.owedAmount)}',
                                      style: TextStyle(
                                        fontSize: 11.5.sp,
                                        color: AppColors.slate,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),

          16.verticalSpace,

          // Actionable settle-up list
          _panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle(title: 'Settle up'),
                6.verticalSpace,
                Text(
                  'Every pair with an open balance — settle each one individually.',
                  style: TextStyle(fontSize: 11.5.sp, color: AppColors.slate),
                ),
                14.verticalSpace,
                if (pairsToSettle.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    child: Row(
                      children: [
                        Icon(Icons.celebration_outlined,
                            color: AppColors.sage, size: 22.r),
                        8.horizontalSpace,
                        Text(
                          'Everyone is square.',
                          style: TextStyle(
                              color: AppColors.sage,
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5.sp),
                        ),
                      ],
                    ),
                  )
                else
                  ...pairsToSettle.map((pb) {
                    final from = provider.personById(pb.debtorId!);
                    final to = provider.personById(pb.creditorId!);
                    return Container(
                      margin: EdgeInsets.only(bottom: 10.h),
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                      decoration: BoxDecoration(
                        color: AppColors.paperDim,
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(from?.name ?? '?',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13.sp,
                                        color: AppColors.ink)),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 6.w),
                                  child: Icon(Icons.arrow_forward,
                                      size: 14.r, color: AppColors.brass),
                                ),
                                Text(to?.name ?? '?',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13.sp,
                                        color: AppColors.ink)),
                                8.horizontalSpace,
                                Text(fmtAed(pb.owedAmount),
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13.sp,
                                        color: AppColors.slate)),
                              ],
                            ),
                          ),
                          8.horizontalSpace,
                          ElevatedButton(
                            onPressed: () => _confirmSettle(context, provider,
                                pb.debtorId!, pb.creditorId!, pb.owedAmount),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.sage,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding:
                                  EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.r)),
                              textStyle:
                                  TextStyle(fontSize: 11.5.sp, fontWeight: FontWeight.w700),
                            ),
                            child: const Text('Settle'),
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
