import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../theme/app_colors.dart';

class AiPromptInput extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback? onMicPressed;

  const AiPromptInput({
    super.key,
    required this.controller,
    this.onMicPressed,
  });

  @override
  State<AiPromptInput> createState() => _AiPromptInputState();
}

class _AiPromptInputState extends State<AiPromptInput> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Describe Expense",
          style: TextStyle(
            color: AppColors.paper,
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        12.verticalSpace,
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .06),
            borderRadius: BorderRadius.circular(28.r),
            border: Border.all(
              color: _isFocused 
                  ? AppColors.brass 
                  : AppColors.line.withValues(alpha: .3),
              width: _isFocused ? 1.5 : 1,
            ),
            boxShadow: _isFocused 
                ? [BoxShadow(color: AppColors.brass.withValues(alpha: 0.15), blurRadius: 15, spreadRadius: 2)]
                : [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
            children: [
              TextField(
                controller: widget.controller,
                focusNode: _focusNode,
                minLines: 5,
                maxLines: 6,
                style: TextStyle(
                  color: AppColors.paper,
                  fontSize: 15.sp,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: "Give the instructions here",
                  hintStyle: TextStyle(
                    color: AppColors.paperDim,
                    height: 1.5,
                  ),
                ),
              ),
              Divider(
                color: AppColors.line.withValues(alpha: .3),
              ),

            ],
          ),
        ),
        16.verticalSpace,
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: AppColors.brass.withValues(alpha: .06),
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: AppColors.brass.withValues(alpha: 0.1)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                color: AppColors.brass,
                size: 20.r,
              ),
              12.horizontalSpace,
              Expanded(
                child: Text(
                  "You can write naturally: \"Person A paid 120 for dinner. Person B and me split it equally.\"",
                  style: TextStyle(
                    color: AppColors.paper.withValues(alpha: 0.9),
                    height: 1.5,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}