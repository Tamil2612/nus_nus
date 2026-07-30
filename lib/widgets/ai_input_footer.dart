import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_colors.dart';

class AiInputFooter extends StatelessWidget {
  final bool isAskMode;
  final bool loading;
  final TextEditingController controller;
  final VoidCallback onAction;

  const AiInputFooter({
    super.key,
    required this.isAskMode,
    required this.loading,
    required this.controller,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Container(
      padding: EdgeInsets.fromLTRB(
          20.w, 12.h, 20.w, isKeyboardOpen ? 12.h : (bottomPadding + 12.h)),
      decoration: BoxDecoration(
        color: AppColors.ink,
        border: Border(
          top: BorderSide(
            color: AppColors.line.withValues(alpha: .2),
            width: 1,
          ),
        ),
      ),
      child: isAskMode ? _buildChatInput() : _buildAnalyseButton(),
    );
  }

  Widget _buildAnalyseButton() {
    return SizedBox(
      height: 54.h,
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: loading ? null : onAction,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brass,
          foregroundColor: AppColors.ink,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
        ),
        icon: loading
            ? SizedBox(
                width: 18.r,
                height: 18.r,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.ink,
                ),
              )
            : Icon(Icons.auto_awesome, size: 20.r),
        label: Text(
          loading ? "Analysing..." : "Analyse Expense",
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildChatInput() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(24.r),
              border: Border.all(color: AppColors.line.withValues(alpha: 0.2)),
            ),
            child: TextField(
              controller: controller,
              style: TextStyle(color: AppColors.paper, fontSize: 14.sp),
              decoration: InputDecoration(
                hintText: "Ask anything...",
                hintStyle: TextStyle(color: AppColors.slate, fontSize: 14.sp),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12.h),
              ),
              onSubmitted: (_) => onAction(),
            ),
          ),
        ),
        12.horizontalSpace,
        GestureDetector(
          onTap: loading ? null : onAction,
          child: Container(
            width: 48.r,
            height: 48.r,
            decoration: BoxDecoration(
              color: AppColors.brass,
              shape: BoxShape.circle,
            ),
            child: loading
                ? Center(
                    child: SizedBox(
                      width: 18.r,
                      height: 18.r,
                      child: const CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.ink),
                    ),
                  )
                : Icon(Icons.send_rounded, color: AppColors.ink, size: 20.r),
          ),
        ),
      ],
    );
  }
}
