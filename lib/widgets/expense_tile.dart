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
  final VoidCallback onDelete;

  const ExpenseTile({
    super.key,
    required this.expense,
    required this.payer,
    required this.splitNames,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10.h),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14.r,
            backgroundColor: payer?.color ?? AppColors.slate,
            child: Text(
              payer != null ? payer!.name[0].toUpperCase() : '?',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700),
            ),
          ),
          10.verticalSpace,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.desc,
                  style: TextStyle(
                      fontSize: 13.5.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink),
                ),
                Text(
                  '${payer?.name ?? '—'} paid · split with $splitNames',
                  style: TextStyle(fontSize: 11.5.sp, color: AppColors.slate),
                ),
              ],
            ),
          ),
          Text(
            fmtAed(expense.amount),
            style: TextStyle(
                fontSize: 13.5.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.ink),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 16.w, color: AppColors.slate),
            onPressed: onDelete,
            splashRadius: 18.r,
          ),
        ],
      ),
    );
  }
}
