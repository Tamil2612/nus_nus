import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../theme/app_colors.dart';
import '../../../utils/currency_formatter.dart';

class AiResultCard extends StatelessWidget {
  final Map<String, dynamic> result;

  final String currency;

  final VoidCallback onSave;

  final VoidCallback? onEdit;

  const AiResultCard({
    super.key,
    required this.result,
    required this.currency,
    required this.onSave,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final splitMap = result["splitMap"] as Map<String, dynamic>;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(28.r),
      ),
      child: Column(
        children: [
          /// Header
          Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: AppColors.brass.withValues(alpha: .10),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(28.r),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10.r),
                  decoration: BoxDecoration(
                    color: AppColors.brass,
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  child: Icon(
                    Icons.auto_awesome,
                    color: AppColors.ink,
                    size: 22.r,
                  ),
                ),
                14.horizontalSpace,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "AI Expense Ready",
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      4.verticalSpace,
                      Text(
                        "Review before saving",
                        style: TextStyle(
                          color: AppColors.slate,
                          fontSize: 12.sp,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 6.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.sage.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.verified,
                        color: AppColors.sage,
                        size: 16.r,
                      ),
                      6.horizontalSpace,
                      Text(
                        "98%",
                        style: TextStyle(
                          color: AppColors.sage,
                          fontWeight: FontWeight.bold,
                          fontSize: 11.sp,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: EdgeInsets.all(22.w),
            child: Column(
              children: [
                _InfoTile(
                  icon: Icons.receipt_long,
                  title: "Description",
                  value: result["description"],
                  fontFamily: 'Georgia',
                ),
                18.verticalSpace,
                _InfoTile(
                  icon: Icons.person,
                  title: "Paid By",
                  value: result["payerName"],
                ),
                18.verticalSpace,
                _InfoTile(
                  icon: Icons.payments,
                  title: "Total Amount",
                  value: fmtCurrency(
                    (result["amount"] as num).toDouble(),
                    currency,
                  ),
                  large: true,
                  fontFamily: 'Georgia',
                ),
                28.verticalSpace,
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Split Summary",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                16.verticalSpace,
                ...splitMap.entries.map(
                  (entry) => _SplitTile(
                    name: entry.key,
                    amount: (entry.value as num).toDouble(),
                    currency: currency,
                  ),
                ),
                30.verticalSpace,
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onEdit,
                        icon: const Icon(
                          Icons.edit,
                          size: 15,
                        ),
                        label: const Text("Edit"),
                        style: OutlinedButton.styleFrom(
                          minimumSize: Size(0, 54.h),
                        ),
                      ),
                    ),
                    14.horizontalSpace,
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: onSave,
                        icon: const Icon(Icons.check),
                        label: const Text("Save Expense"),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.sage,
                          foregroundColor: Colors.white,
                          minimumSize: Size(0, 54.h),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final bool large;
  final String? fontFamily;

  const _InfoTile({
    required this.icon,
    required this.title,
    required this.value,
    this.large = false,
    this.fontFamily,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 22.r,
          backgroundColor: AppColors.brass.withValues(alpha: .12),
          child: Icon(
            icon,
            color: AppColors.brass,
          ),
        ),
        14.horizontalSpace,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: AppColors.slate,
                  fontSize: 12.sp,
                ),
              ),
              2.verticalSpace,
              Text(
                value,
                style: TextStyle(
                  fontSize: large ? 24.sp : 16.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.ink,
                  fontFamily: fontFamily,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SplitTile extends StatelessWidget {
  final String name;
  final double amount;
  final String currency;

  const _SplitTile({
    required this.name,
    required this.amount,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.symmetric(
        horizontal: 14.w,
        vertical: 14.h,
      ),
      decoration: BoxDecoration(
        color: AppColors.paperDim,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.line.withValues(alpha: .5)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18.r,
            backgroundColor: AppColors.brass,
            child: Text(
              name.characters.first.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
              ),
            ),
          ),
          12.horizontalSpace,
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
                fontSize: 14.sp,
              ),
            ),
          ),
          Text(
            fmtCurrency(amount, currency),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.ink,
              fontSize: 14.sp,
            ),
          ),
        ],
      ),
    );
  }
}
