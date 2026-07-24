import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/expense.dart';
import '../models/person.dart';
import '../theme/app_colors.dart';
import '../utils/currency_formatter.dart';

class ExpenseTile extends StatelessWidget {
  final Expense expense;
  final Person? payer;
  final String splitNames;
  /// Null for anyone viewing a group they didn't create — they can see
  /// every expense but can't delete one.
  final VoidCallback? onDelete;
  /// Settlement records shouldn't be edited in place (correct them by
  /// deleting and re-recording) — leave this null to disable tap-to-edit.
  final VoidCallback? onEdit;
  /// e.g. "Added by Priya" — shown when someone other than the group's
  /// creator logged this expense, so it's clear at a glance who added
  /// what in a group with multiple contributors. Null hides the line.
  final String? addedByLabel;

  const ExpenseTile({
    super.key,
    required this.expense,
    required this.payer,
    required this.splitNames,
    required this.onDelete,
    this.onEdit,
    this.addedByLabel,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(10.r),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 10.h),
        child: Row(
          children: [
            CircleAvatar(
              radius: 14.r,
              backgroundColor: expense.isSettlement
                  ? AppColors.sage
                  : (payer?.color ?? AppColors.slate),
              child: expense.isSettlement
                  ? Icon(Icons.check, size: 16.r, color: Colors.white)
                  : Text(
                      payer != null ? payer!.name[0].toUpperCase() : '?',
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
                    expense.desc,
                    style: TextStyle(
                        fontSize: 13.5.sp,
                        fontWeight: FontWeight.w600,
                        color:
                            expense.isSettlement ? AppColors.sage : AppColors.ink),
                  ),
                  Text(
                    expense.isSettlement
                        ? 'Payment recorded'
                        : '${payer?.name ?? '—'} paid · split with $splitNames',
                    style: TextStyle(fontSize: 11.5.sp, color: AppColors.slate),
                  ),
                  if (addedByLabel != null)
                    Padding(
                      padding: EdgeInsets.only(top: 2.h),
                      child: Text(
                        addedByLabel!,
                        style: TextStyle(
                            fontSize: 10.sp,
                            color: AppColors.brass,
                            fontStyle: FontStyle.italic),
                      ),
                    ),
                ],
              ),
            ),
            Text(
              fmtAed(expense.amount),
              style: TextStyle(
                  fontSize: 13.5.sp,
                  fontWeight: FontWeight.w700,
                  color: expense.isSettlement ? AppColors.sage : AppColors.ink),
            ),
            if (onEdit != null)
              IconButton(
                icon: Icon(Icons.edit_outlined, size: 15.w, color: AppColors.slate),
                onPressed: onEdit,
                splashRadius: 18.r,
                tooltip: 'Edit',
              ),
            if (onDelete != null)
              IconButton(
                icon: Icon(Icons.close, size: 16.w, color: AppColors.slate),
                onPressed: onDelete,
                splashRadius: 18.r,
                tooltip: 'Delete',
              ),
          ],
        ),
      ),
    );
  }
}
