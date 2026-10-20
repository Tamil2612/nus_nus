import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../models/expense.dart';
import '../providers/split_provider.dart';
import '../theme/app_colors.dart';
import 'expense_form.dart';

/// Opens the Add/Edit Expense bottom sheet. Pass [existing] to edit that
/// expense in place instead of creating a new one.
void showExpenseFormSheet(BuildContext context, {Expense? existing}) {
  final isPersonal =
      context.read<SplitProvider>().currentGroup?.isPersonal ?? false;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(20.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40.w,
              height: 4.h,
              margin: EdgeInsets.only(bottom: 20.h),
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            Text(
              existing != null
                  ? (isPersonal ? 'Edit expense' : 'Edit split')
                  : (isPersonal ? 'Add personal expense' : 'Add New Expense'),
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.ink,
              ),
            ),
            if (isPersonal) ...[
              5.verticalSpace,
              Text(
                'Record an expense in your personal ledger.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.slate, fontSize: 11.5.sp),
              ),
            ],
            20.verticalSpace,
            ExpenseForm(existingExpense: existing),
          ],
        ),
      ),
    ),
  );
}
