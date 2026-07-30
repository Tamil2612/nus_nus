import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../theme/app_colors.dart';

class AiHeader extends StatefulWidget {
  const AiHeader({super.key});

  @override
  State<AiHeader> createState() => _AiHeaderState();
}

class _AiHeaderState extends State<AiHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final glow = 0.75 + (sin(_controller.value * pi * 2) * 0.25);

        return Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.ink,
                AppColors.inkSoft,
              ],
            ),
            border: Border(
              bottom: BorderSide(
                color: AppColors.line.withValues(alpha: .3),
                width: 1,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 54.r,
                    height: 54.r,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.brass.withValues(alpha: glow * .35),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                      gradient: LinearGradient(
                        colors: [
                          AppColors.brass,
                          AppColors.brassSoft,
                        ],
                      ),
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      color: AppColors.ink,
                      size: 28.r,
                    ),
                  ),
                  16.horizontalSpace,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              "Nus AI",
                              style: TextStyle(
                                color: AppColors.paper,
                                fontSize: 26.sp,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'Georgia',
                                letterSpacing: -0.5,
                              ),
                            ),
                            8.horizontalSpace,
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10.w,
                                vertical: 2.h,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.sage.withValues(alpha: .15),
                                borderRadius: BorderRadius.circular(20.r),
                                border: Border.all(
                                  color: AppColors.sage.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                "BETA",
                                style: TextStyle(
                                  color: AppColors.sage,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 8.sp,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          "Your intelligent expense companion.",
                          style: TextStyle(
                            color: AppColors.paperDim,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close_rounded,
                      color: AppColors.paper.withValues(alpha: 0.6),
                      size: 26.r,
                    ),
                  ),
                ],
              ),
              18.verticalSpace,
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    const _FeatureChip(
                      icon: Icons.receipt_long,
                      label: "Receipt OCR",
                    ),
                    8.horizontalSpace,
                    const _FeatureChip(
                      icon: Icons.groups,
                      label: "Smart Split",
                    ),
                    8.horizontalSpace,
                    const _FeatureChip(
                      icon: Icons.calculate_outlined,
                      label: "Natural Split",
                    ),
                    20.horizontalSpace,
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 14.w,
        vertical: 8.h,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(30.r),
        border: Border.all(
          color: AppColors.line.withValues(alpha: .2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: AppColors.brass,
            size: 14.r,
          ),
          8.horizontalSpace,
          Text(
            label,
            style: TextStyle(
              color: AppColors.paper.withValues(alpha: 0.9),
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
