import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../models/person.dart';
import '../models/expense.dart';
import '../providers/split_provider.dart';
import '../theme/app_colors.dart';
import '../utils/currency_formatter.dart';
import '../screens/expense_detail_screen.dart';

class LedgerTab extends StatefulWidget {
  const LedgerTab({super.key});

  @override
  State<LedgerTab> createState() => _LedgerTabState();
}

class _LedgerTabState extends State<LedgerTab> {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SplitProvider>();
    final expenses = provider.expenses; // Keep chronological for chat look

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.all(16.w),
            children: [
              // Activity Feed Title
              Padding(
                padding: EdgeInsets.symmetric(vertical: 16.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Activity Feed',
                      style: TextStyle(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.paper),
                    ),
                    Text(
                      '${expenses.length} splits',
                      style: TextStyle(
                          fontSize: 12.sp,
                          color: AppColors.slate,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),

              if (expenses.isEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 100.h),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.receipt_long_outlined,
                            size: 64.r,
                            color: AppColors.slate.withValues(alpha: 0.3)),
                        16.verticalSpace,
                        Text(
                          'No activity yet.\nAdd a split to get started!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: AppColors.slate, fontSize: 14.sp),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...expenses.reversed.map((e) {
                  final payer = provider.personById(e.payerId);
                  return _ActivityExpenseCard(
                    expense: e,
                    payer: payer,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ExpenseDetailScreen(expense: e)),
                      );
                    },
                  );
                }),

              100.verticalSpace, // Bottom padding
            ],
          ),
        ),
      ],
    );
  }
}

class _ActivityExpenseCard extends StatelessWidget {
  final Expense expense;
  final Person? payer;
  final VoidCallback onTap;

  const _ActivityExpenseCard({
    required this.expense,
    required this.payer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SplitProvider>();
    final settled = expense.isFullySettled;
    final accent = settled ? AppColors.sage : AppColors.brass;
    final ratio = expense.participantCount > 0
        ? (expense.settledCount / expense.participantCount).clamp(0.0, 1.0)
        : 0.0;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10.h),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: accent.withValues(alpha: .7), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .24),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20.r),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Column(
                children: [
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: .12),
                      border: Border(
                        bottom: BorderSide(color: accent.withValues(alpha: .2)),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(4.r),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: .2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                settled
                                    ? Icons.check_circle_rounded
                                    : Icons.receipt_long_rounded,
                                color: accent,
                                size: 14.r,
                              ),
                            ),
                            8.horizontalSpace,
                            Text(
                              settled ? 'FULLY SETTLED' : 'EXPENSE SPLIT',
                              style: TextStyle(
                                color: settled ? AppColors.sage : AppColors.ink,
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          _formatDate(expense.createdAt),
                          style: TextStyle(
                            color: AppColors.slate,
                            fontSize: 10.5.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(16.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 20.r,
                              backgroundColor: payer?.color ?? AppColors.brass,
                              child: Text(
                                (payer?.name ?? 'S')
                                    .characters
                                    .first
                                    .toUpperCase(),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14.sp,
                                ),
                              ),
                            ),
                            12.horizontalSpace,
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    expense.desc,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: AppColors.ink,
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w800,
                                      height: 1.2,
                                    ),
                                  ),
                                  4.verticalSpace,
                                  Text.rich(
                                    TextSpan(
                                      style: TextStyle(
                                          color: AppColors.slate,
                                          fontSize: 12.sp),
                                      children: [
                                        const TextSpan(text: 'Paid by '),
                                        TextSpan(
                                          text: payer?.name ?? 'Someone',
                                          style: const TextStyle(
                                            color: AppColors.ink,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            8.horizontalSpace,
                            Text(
                              fmtCurrency(
                                expense.amount,
                                provider.currentGroup?.currency ?? 'AED',
                              ),
                              style: TextStyle(
                                color: AppColors.ink,
                                fontSize: 18.sp,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        14.verticalSpace,
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              settled
                                  ? 'All shares paid'
                                  : '${expense.settledCount} of ${expense.participantCount} settled',
                              style: TextStyle(
                                color:
                                    settled ? AppColors.sage : AppColors.slate,
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${(ratio * 100).round()}%',
                              style: TextStyle(
                                color: accent,
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        6.verticalSpace,
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6.r),
                          child: LinearProgressIndicator(
                            value: ratio,
                            minHeight: 6.h,
                            backgroundColor:
                                AppColors.line.withValues(alpha: .6),
                            valueColor: AlwaysStoppedAnimation<Color>(accent),
                          ),
                        ),
                        14.verticalSpace,
                        Divider(color: AppColors.line, height: 1),
                        12.verticalSpace,
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                _ParticipantCircles(expense: expense),
                                8.horizontalSpace,
                                Text(
                                  '${expense.splitWith.length} people sharing',
                                  style: TextStyle(
                                    color: AppColors.slate,
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Text(
                                  'VIEW SPLIT',
                                  style: TextStyle(
                                    color: AppColors.ink,
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: .5,
                                  ),
                                ),
                                5.horizontalSpace,
                                Container(
                                  padding: EdgeInsets.all(3.r),
                                  decoration: const BoxDecoration(
                                    color: AppColors.ink,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.arrow_forward_rounded,
                                      color: AppColors.paper, size: 11.r),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _formatDate(DateTime? dateTime) {
  if (dateTime == null) return '';
  final local = dateTime.toLocal();
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[local.month - 1]} ${local.day}';
}

class _ParticipantCircles extends StatelessWidget {
  final Expense expense;

  const _ParticipantCircles({required this.expense});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<SplitProvider>();
    final ids = expense.splitWith.take(4).toList();

    return Row(
      children: [
        for (int i = 0; i < ids.length; i++)
          Transform.translate(
            offset: Offset(i * -8.w, 0),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.paper, width: 1.5.r),
              ),
              child: CircleAvatar(
                radius: 9.r,
                backgroundColor:
                    provider.personById(ids[i])?.color ?? AppColors.slate,
                child: Text(
                  provider.personById(ids[i])?.name[0].toUpperCase() ?? '?',
                  style: TextStyle(
                      fontSize: 7.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ),
            ),
          ),
        if (expense.splitWith.length > 4)
          Transform.translate(
            offset: Offset(-32.w, 0),
            child: Padding(
              padding: EdgeInsets.only(left: 36.w),
              child: Text(
                '+${expense.splitWith.length - 4}',
                style: TextStyle(
                    fontSize: 10.sp,
                    color: AppColors.slate,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }
}
