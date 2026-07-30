import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_colors.dart';
import 'typing_indicator.dart';

class AiGeneralMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  AiGeneralMessage({required this.text, required this.isUser})
      : timestamp = DateTime.now();
}

class AiChatView extends StatelessWidget {
  final List<AiGeneralMessage> messages;
  final bool isLoading;
  final ScrollController scrollController;

  const AiChatView({
    super.key,
    required this.messages,
    required this.isLoading,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 64.r,
              color: AppColors.slate.withValues(alpha: 0.3),
            ),
            16.verticalSpace,
            Text(
              "Ask me anything about your expenses!\nTry: 'How much did I spend in total?'",
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.slate, fontSize: 14.sp),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
      itemCount: messages.length + (isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == messages.length) {
          return Padding(
            padding: EdgeInsets.only(top: 10.h),
            child: const TypingIndicator(),
          );
        }

        final msg = messages[index];
        return _ChatBubble(message: msg);
      },
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final AiGeneralMessage message;
  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: 16.h),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        constraints: BoxConstraints(maxWidth: 0.8.sw),
        decoration: BoxDecoration(
          color: message.isUser ? AppColors.brass : AppColors.paper,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16.r),
            topRight: Radius.circular(16.r),
            bottomLeft: Radius.circular(message.isUser ? 16.r : 4.r),
            bottomRight: Radius.circular(message.isUser ? 4.r : 16.r),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: AppColors.ink,
            fontSize: 14.sp,
            fontWeight: message.isUser ? FontWeight.w700 : FontWeight.w500,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}
