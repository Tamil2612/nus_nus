import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/app_colors.dart';

class AiExpenseScreen extends StatefulWidget {
  const AiExpenseScreen({super.key});

  @override
  State<AiExpenseScreen> createState() => _AiExpenseScreenState();
}

class _AiExpenseScreenState extends State<AiExpenseScreen> {
  final TextEditingController controller = TextEditingController();

  bool loading = false;

  Map<String, dynamic>? result;

  Future<void> generateExpense() async {
    setState(() => loading = true);

    /// TODO
    /// final result = await gemmaService.parseExpense(controller.text);

    await Future.delayed(const Duration(seconds: 2));

    result = {
      "description": "Dinner",
      "amount": 240,
      "paidBy": "Pushpa",
      "splitBetween": [
        "Tamilarasan",
        "Pushpa",
        "Vivek",
        "Nivetha",
      ]
    };

    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: ListView(
        padding: EdgeInsets.all(20.w),
        children: [
          100.verticalSpace,
          Icon(
            Icons.auto_awesome,
            color: AppColors.brass,
            size: 42.sp,
          ),
          20.verticalSpace,
          Text(
            "Describe your expense naturally",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24.sp,
              color: AppColors.paper,
              fontWeight: FontWeight.bold,
            ),
          ),
          28.verticalSpace,
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(color: AppColors.line),
            ),
            child: TextField(
              controller: controller,
              maxLines: 6,
              style: const TextStyle(color: AppColors.ink),
              decoration: InputDecoration(
                contentPadding: EdgeInsets.all(18.w),
                hintText: "Type your expense...",
                hintStyle: TextStyle(color: AppColors.slate),
                border: InputBorder.none,
              ),
            ),
          ),
          24.verticalSpace,
          SizedBox(
            height: 56.h,
            child: ElevatedButton.icon(
              onPressed: loading ? null : generateExpense,
              icon: loading
                  ? SizedBox(
                      width: 20.w,
                      height: 20.w,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.ink,
                      ),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(
                "Generate Expense",
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brass,
                foregroundColor: AppColors.ink,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18.r),
                ),
              ),
            ),
          ),
          SizedBox(height: 30.h),
          if (result != null)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24.r),
                border: Border.all(color: AppColors.line),
              ),
              padding: EdgeInsets.all(20.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "AI Preview",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.ink,
                      fontSize: 20.sp,
                    ),
                  ),
                  SizedBox(height: 20.h),
                  _tile(
                    Icons.receipt_long,
                    "Description",
                    result!["description"],
                  ),
                  _tile(
                    Icons.payments_outlined,
                    "Amount",
                    "${result!["amount"]} AED",
                  ),
                  _tile(
                    Icons.person,
                    "Paid By",
                    result!["paidBy"],
                  ),
                  Divider(color: AppColors.line),
                  Text(
                    "Split Between",
                    style: TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Wrap(
                    spacing: 8.w,
                    runSpacing: 8.h,
                    children: List.generate(
                      result!["splitBetween"].length,
                      (index) => Chip(
                        backgroundColor: AppColors.paperDim,
                        side: BorderSide.none,
                        avatar: CircleAvatar(
                          backgroundColor: AppColors.avatarColorFor(index),
                          child: Text(
                            result!["splitBetween"][index][0],
                            style: const TextStyle(
                              color: Colors.white,
                            ),
                          ),
                        ),
                        label: Text(result!["splitBetween"][index]),
                      ),
                    ),
                  ),
                  SizedBox(height: 24.h),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.ink,
                            side: const BorderSide(
                              color: AppColors.line,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14.r),
                            ),
                          ),
                          onPressed: () {
                            setState(() => result = null);
                          },
                          child: const Text("Cancel"),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.sage,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14.r),
                            ),
                          ),
                          onPressed: () {
                            /// Save to provider
                          },
                          child: const Text("Save"),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            )
        ],
      ),
    );
  }

  Widget _tile(IconData icon, String title, String value) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: AppColors.paperDim,
        child: Icon(icon, color: AppColors.brass),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.slate,
        ),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(
          color: AppColors.ink,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
