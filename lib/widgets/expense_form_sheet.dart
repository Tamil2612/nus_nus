import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../models/expense.dart';
import '../providers/split_provider.dart';
import '../theme/app_colors.dart';
import 'expense_form.dart';

/// Opens the Add/Edit Expense bottom sheet.
void showExpenseFormSheet(BuildContext context, {Expense? existing}) {
  final isPersonal =
      context.read<SplitProvider>().currentGroup?.isPersonal ?? false;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.ink.withValues(alpha: .48),
    builder: (sheetContext) {
      final title = existing != null
          ? (isPersonal ? 'Edit expense' : 'Edit split')
          : (isPersonal ? 'Add personal expense' : 'Add new expense');
      final subtitle = isPersonal
          ? 'Keep track of your spending'
          : 'Record it now. Settle up whenever you are ready.';

      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * .94,
          ),
          decoration: BoxDecoration(
            color: AppColors.paper,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(24.r)),
            boxShadow: [
              BoxShadow(
                color: AppColors.ink.withValues(alpha: .18),
                blurRadius: 24,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(20.w, 12.h, 12.w, 15.h),
                child: Column(
                  children: [
                    Container(
                      width: 38.w,
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: AppColors.slate.withValues(alpha: .3),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                    17.verticalSpace,
                    Row(
                      children: [
                        Container(
                          width: 44.r,
                          height: 44.r,
                          decoration: BoxDecoration(
                            color: AppColors.ink,
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                          child: Icon(
                            isPersonal
                                ? Icons.account_balance_wallet_outlined
                                : Icons.receipt_long_rounded,
                            color: AppColors.brassSoft,
                            size: 22.r,
                          ),
                        ),
                        12.horizontalSpace,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: TextStyle(
                                  color: AppColors.ink,
                                  fontSize: 17.sp,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              3.verticalSpace,
                              Text(
                                subtitle,
                                style: TextStyle(
                                  color: AppColors.slate,
                                  fontSize: 10.5.sp,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: Icon(Icons.close_rounded,
                              color: AppColors.slate, size: 21.r),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: AppColors.line),
              Flexible(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(18.w, 16.h, 18.w, 20.h),
                  child: ExpenseForm(existingExpense: existing),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
