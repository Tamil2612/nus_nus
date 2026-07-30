import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../theme/app_colors.dart';

class AiLoadingCard extends StatefulWidget {
  const AiLoadingCard({super.key});

  @override
  State<AiLoadingCard> createState() => _AiLoadingCardState();
}

class _AiLoadingCardState extends State<AiLoadingCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  final List<_ProcessingStep> _steps = [
    _ProcessingStep(
      icon: Icons.receipt_long_rounded,
      title: "Reading receipt",
      subtitle: "Extracting text using AI vision",
    ),
    _ProcessingStep(
      icon: Icons.people_alt_rounded,
      title: "Finding members",
      subtitle: "Matching names with your group",
    ),
    _ProcessingStep(
      icon: Icons.calculate_rounded,
      title: "Calculating split",
      subtitle: "Applying your instructions",
    ),
    _ProcessingStep(
      icon: Icons.check_circle_outline_rounded,
      title: "Preparing expense",
      subtitle: "Almost ready...",
    ),
  ];

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get currentStep {
    return (_controller.value * _steps.length)
        .floor()
        .clamp(0, _steps.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return Container(
          margin: EdgeInsets.symmetric(vertical: 24.h),
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .05),
            borderRadius: BorderRadius.circular(24.r),
            border: Border.all(
              color: AppColors.line.withValues(alpha: .25),
            ),
          ),
          child: Column(
            children: [

              /// AI Orb
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 82.r,
                height: 82.r,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      AppColors.brass,
                      AppColors.brassSoft,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.brass.withValues(
                        alpha: .25 +
                            (.15 * sin(_controller.value * pi * 6)),
                      ),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.ink,
                  size: 38.r,
                ),
              ),

              20.verticalSpace,

              Text(
                "Nus AI is analysing",
                style: TextStyle(
                  color: AppColors.paper,
                  fontWeight: FontWeight.bold,
                  fontSize: 20.sp,
                ),
              ),

              6.verticalSpace,

              Text(
                "Please wait while we understand your expense.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.paperDim,
                  fontSize: 13.sp,
                ),
              ),

              26.verticalSpace,

              ...List.generate(
                _steps.length,
                    (index) {
                  final completed = index < currentStep;
                  final active = index == currentStep;

                  return _StepTile(
                    step: _steps[index],
                    completed: completed,
                    active: active,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StepTile extends StatelessWidget {
  final _ProcessingStep step;
  final bool completed;
  final bool active;

  const _StepTile({
    required this.step,
    required this.completed,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      margin: EdgeInsets.only(bottom: 14.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: active
            ? AppColors.brass.withValues(alpha: .08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Row(
        children: [

          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 42.r,
            height: 42.r,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: completed
                  ? AppColors.sage
                  : active
                  ? AppColors.brass
                  : Colors.white12,
            ),
            child: Icon(
              completed
                  ? Icons.check
                  : step.icon,
              color: completed
                  ? Colors.white
                  : active
                  ? AppColors.ink
                  : AppColors.paper,
            ),
          ),

          SizedBox(width: 14.w),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [

                Text(
                  step.title,
                  style: TextStyle(
                    color: AppColors.paper,
                    fontWeight: FontWeight.bold,
                    fontSize: 15.sp,
                  ),
                ),

                SizedBox(height: 2.h),

                Text(
                  step.subtitle,
                  style: TextStyle(
                    color: AppColors.paperDim,
                    fontSize: 12.sp,
                  ),
                ),
              ],
            ),
          ),

          if (active)
            SizedBox(
              width: 18.r,
              height: 18.r,
              child: const CircularProgressIndicator(
                strokeWidth: 2,
              ),
            ),

          if (completed)
            Icon(
              Icons.check_circle,
              color: AppColors.sage,
            ),
        ],
      ),
    );
  }
}

class _ProcessingStep {
  final IconData icon;
  final String title;
  final String subtitle;

  const _ProcessingStep({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}