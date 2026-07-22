import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/expense.dart';
import '../theme/app_colors.dart';
import 'expense_form.dart';

/// Opens the Add/Edit Expense bottom sheet. Pass [existing] to edit that
/// expense in place instead of creating a new one.
void showExpenseFormSheet(BuildContext context, {Expense? existing}) {
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
              existing != null ? 'Edit Expense' : 'Add New Expense',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.ink,
              ),
            ),
            20.verticalSpace,
            ExpenseForm(existingExpense: existing),
          ],
        ),
      ),
    ),
  );
}
