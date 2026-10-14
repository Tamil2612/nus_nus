import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../data/group_chat_repository.dart';
import '../models/expense.dart';
import '../models/group_message.dart';
import '../providers/split_provider.dart';
import '../screens/expense_detail_screen.dart';
import '../theme/app_colors.dart';
import '../utils/currency_formatter.dart';
import 'expense_form_sheet.dart';

/// Group conversation timeline containing ordinary messages and live
/// expense cards. Financial records remain in the existing expenses
/// subcollection and are never duplicated as chat messages.
class GroupChatTab extends StatefulWidget {
  const GroupChatTab({super.key});

  @override
  State<GroupChatTab> createState() => _GroupChatTabState();
}

class _GroupChatTabState extends State<GroupChatTab> {
  final TextEditingController _messageController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  String _currentUserName(SplitProvider provider) {
    final uid = provider.uid;
    if (uid != null) {
      for (final person in provider.people) {
        if (person.linkedUserId == uid && !person.archived) {
          return person.name;
        }
      }
    }
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) return displayName;
    final email = user?.email?.trim();
    if (email != null && email.isNotEmpty) return email;
    return 'Member';
  }

  Future<void> _sendMessage(SplitProvider provider) async {
    final group = provider.currentGroup;
    final uid = provider.uid;
    final text = _messageController.text.trim();
    if (_sending || group == null || uid == null || text.isEmpty) return;

    setState(() => _sending = true);
    try {
      await GroupChatRepository.instance.sendMessage(
        groupId: group.id,
        senderUid: uid,
        senderName: _currentUserName(provider),
        text: text,
      );
      if (mounted) _messageController.clear();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not send message: $error'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _addSplit() {
    showExpenseFormSheet(context);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SplitProvider>();
    final group = provider.currentGroup;
    final uid = provider.uid;

    if (group == null || uid == null) {
      return const Center(
        child: Text(
          'Choose a group to start chatting.',
          style: TextStyle(color: AppColors.slate),
        ),
      );
    }

    return Column(
      children: [
        Container(
          margin: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 4.h),
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: AppColors.paper.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: AppColors.paper.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              Icon(Icons.people_alt_outlined,
                  color: AppColors.brassSoft, size: 19.r),
              8.horizontalSpace,
              Expanded(
                child: Text(
                  '${provider.people.where((p) => !p.archived).length} members',
                  style: TextStyle(
                    color: AppColors.paper,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                fmtCurrency(provider.totalSpent, group.currency),
                style: TextStyle(
                  color: AppColors.brassSoft,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<GroupMessage>>(
            stream: GroupChatRepository.instance.watchMessages(group.id),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.w),
                    child: Text(
                      'Could not load group chat. Check your connection and group permissions.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.paper, fontSize: 13.sp),
                    ),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.brassSoft),
                );
              }

              final messages = snapshot.data ?? const <GroupMessage>[];
              final timeline = <_TimelineItem>[
                for (final message in messages)
                  _TimelineItem.message(message),
                for (final expense in provider.expenses)
                  _TimelineItem.expense(expense),
              ]..sort((a, b) => b.timestamp.compareTo(a.timestamp));

              if (timeline.isEmpty) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32.w),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 68.r,
                          height: 68.r,
                          decoration: BoxDecoration(
                            color: AppColors.brass.withValues(alpha: 0.13),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.forum_outlined,
                              color: AppColors.brassSoft, size: 32.r),
                        ),
                        16.verticalSpace,
                        Text(
                          'This is your group space',
                          style: TextStyle(
                            color: AppColors.paper,
                            fontWeight: FontWeight.bold,
                            fontSize: 17.sp,
                          ),
                        ),
                        8.verticalSpace,
                        Text(
                          'Say hello or add the first split. Messages and expenses will appear here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.slate,
                            fontSize: 13.sp,
                            height: 1.4,
                          ),
                        ),
                        18.verticalSpace,
                        OutlinedButton.icon(
                          onPressed: _addSplit,
                          icon: const Icon(Icons.add),
                          label: const Text('Add first split'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.brassSoft,
                            side: const BorderSide(color: AppColors.brass),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // reverse:true places the newest (index 0) item at the bottom.
              return ListView.builder(
                reverse: true,
                padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 16.h),
                itemCount: timeline.length,
                itemBuilder: (context, index) {
                  final item = timeline[index];
                  if (item.message != null) {
                    final message = item.message!;
                    return _MessageBubble(
                      message: message,
                      isMine: message.senderUid == uid,
                    );
                  }
                  return _ExpenseTimelineCard(expense: item.expense!);
                },
              );
            },
          ),
        ),
        _MessageComposer(
          controller: _messageController,
          sending: _sending,
          onSend: () => _sendMessage(provider),
          onAddSplit: _addSplit,
        ),
      ],
    );
  }
}

class _TimelineItem {
  final DateTime timestamp;
  final GroupMessage? message;
  final Expense? expense;

  const _TimelineItem._({
    required this.timestamp,
    this.message,
    this.expense,
  });

  factory _TimelineItem.message(GroupMessage message) => _TimelineItem._(
        timestamp: message.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
        message: message,
      );

  factory _TimelineItem.expense(Expense expense) => _TimelineItem._(
        timestamp: expense.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
        expense: expense,
      );
}

class _MessageBubble extends StatelessWidget {
  final GroupMessage message;
  final bool isMine;

  const _MessageBubble({required this.message, required this.isMine});

  @override
  Widget build(BuildContext context) {
    final alignment = isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bubbleColor = isMine ? AppColors.brass : AppColors.paper;
    final textColor = AppColors.ink;

    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 5.w),
            child: Text(
              '${isMine ? 'You' : message.senderName} · ${_formatTime(message.createdAt)}',
              style: TextStyle(
                color: AppColors.slate,
                fontSize: 10.5.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          4.verticalSpace,
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 0.82.sw),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 13.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16.r),
                  topRight: Radius.circular(16.r),
                  bottomLeft: Radius.circular(isMine ? 16.r : 4.r),
                  bottomRight: Radius.circular(isMine ? 4.r : 16.r),
                ),
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: textColor,
                  fontSize: 14.sp,
                  height: 1.35,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseTimelineCard extends StatelessWidget {
  final Expense expense;

  const _ExpenseTimelineCard({required this.expense});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SplitProvider>();
    final group = provider.currentGroup;
    final payer = provider.personById(expense.payerId);
    final settled = expense.isFullySettled;

    return Padding(
      padding: EdgeInsets.only(bottom: 14.h),
      child: Center(
        child: Material(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(16.r),
          child: InkWell(
            borderRadius: BorderRadius.circular(16.r),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ExpenseDetailScreen(expense: expense),
                ),
              );
            },
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(
                  color: settled ? AppColors.sage : AppColors.brass,
                  width: 1.1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38.r,
                        height: 38.r,
                        decoration: BoxDecoration(
                          color: AppColors.brass.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(11.r),
                        ),
                        child: Icon(
                          settled ? Icons.check_circle_outline : Icons.receipt_long,
                          color: settled ? AppColors.sage : AppColors.ink,
                          size: 21.r,
                        ),
                      ),
                      10.horizontalSpace,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${payer?.name ?? 'Someone'} added a split',
                              style: TextStyle(
                                color: AppColors.slate,
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            3.verticalSpace,
                            Text(
                              expense.desc,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.ink,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      8.horizontalSpace,
                      Text(
                        fmtCurrency(expense.amount, group?.currency ?? 'AED'),
                        style: TextStyle(
                          color: AppColors.ink,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  12.verticalSpace,
                  Row(
                    children: [
                      Icon(
                        settled ? Icons.verified_outlined : Icons.people_outline,
                        color: settled ? AppColors.sage : AppColors.slate,
                        size: 16.r,
                      ),
                      6.horizontalSpace,
                      Expanded(
                        child: Text(
                          settled
                              ? 'All shares settled'
                              : '${expense.participantCount} participants · ${expense.settledCount} settled',
                          style: TextStyle(
                            color: settled ? AppColors.sage : AppColors.slate,
                            fontSize: 11.sp,
                          ),
                        ),
                      ),
                      Text(
                        'VIEW SPLIT  ›',
                        style: TextStyle(
                          color: AppColors.inkSoft,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageComposer extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onAddSplit;

  const _MessageComposer({
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.onAddSplit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(12.w, 9.h, 12.w, 10.h),
      decoration: BoxDecoration(
        color: AppColors.ink,
        border: Border(
          top: BorderSide(color: AppColors.paper.withValues(alpha: 0.12)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Add split',
                  onPressed: onAddSplit,
                  icon: Icon(Icons.add_circle_outline,
                      color: AppColors.brassSoft, size: 26.r),
                ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 1000,
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => onSend(),
                    style: TextStyle(color: AppColors.paper, fontSize: 14.sp),
                    decoration: InputDecoration(
                      hintText: 'Message the group…',
                      hintStyle: TextStyle(
                        color: AppColors.slate.withValues(alpha: 0.95),
                        fontSize: 13.sp,
                      ),
                      counterText: '',
                      filled: true,
                      fillColor: AppColors.paper.withValues(alpha: 0.08),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 14.w,
                        vertical: 10.h,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24.r),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                8.horizontalSpace,
                SizedBox(
                  width: 42.r,
                  height: 42.r,
                  child: IconButton.filled(
                    tooltip: 'Send message',
                    onPressed: sending ? null : onSend,
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.brass,
                      foregroundColor: AppColors.ink,
                      disabledBackgroundColor: AppColors.slate,
                    ),
                    icon: sending
                        ? SizedBox(
                            width: 17.r,
                            height: 17.r,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.ink,
                            ),
                          )
                        : Icon(Icons.send_rounded, size: 19.r),
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(left: 58.w, top: 4.h),
                child: Text(
                  'Tap + to add an expense split',
                  style: TextStyle(
                    color: AppColors.slate,
                    fontSize: 10.sp,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatTime(DateTime? dateTime) {
  if (dateTime == null) return 'just now';
  final local = dateTime.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $period';
}
