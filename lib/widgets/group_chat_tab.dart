import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../data/group_chat_repository.dart';
import '../models/expense.dart';
import '../models/group_message.dart';
import '../providers/split_provider.dart';
import '../screens/ai_expense_screen.dart';
import '../screens/expense_detail_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
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
  final Map<String, List<GroupMessage>> _olderMessagesByGroup = {};
  final Map<String, bool> _hasMoreOlderByGroup = {};
  final Map<String, bool> _loadingOlderByGroup = {};

  Future<void> _loadOlderMessages(
      String groupId, List<GroupMessage> loadedMessages) async {
    if (_loadingOlderByGroup[groupId] == true ||
        _hasMoreOlderByGroup[groupId] == false) {
      return;
    }
    final eligible = loadedMessages.where((m) => m.createdAt != null).toList()
      ..sort((a, b) => a.createdAt!.compareTo(b.createdAt!));
    if (eligible.isEmpty) {
      setState(() => _hasMoreOlderByGroup[groupId] = false);
      return;
    }
    setState(() => _loadingOlderByGroup[groupId] = true);
    try {
      final page = await GroupChatRepository.instance.fetchOlderMessages(
        groupId: groupId,
        before: eligible.first,
      );
      if (!mounted) return;
      final byId = <String, GroupMessage>{
        for (final message in (_olderMessagesByGroup[groupId] ?? const <GroupMessage>[]))
          message.id: message,
        for (final message in page) message.id: message,
      };
      setState(() {
        _olderMessagesByGroup[groupId] = byId.values.toList();
        _hasMoreOlderByGroup[groupId] = page.length == GroupChatRepository.pageSize;
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load older messages: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingOlderByGroup[groupId] = false);
    }
  }

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
    if (text.length > GroupChatRepository.maxMessageLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Messages cannot exceed 1000 characters.')),
      );
      return;
    }

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

  Future<void> _pickAndSendImage(SplitProvider provider) async {
    final group = provider.currentGroup;
    final uid = provider.uid;
    if (group == null || uid == null) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.ink,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: AppColors.brassSoft),
              title: const Text('Choose from Gallery',
                  style: TextStyle(color: AppColors.paper)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined,
                  color: AppColors.brassSoft),
              title: const Text('Take a Photo',
                  style: TextStyle(color: AppColors.paper)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (!mounted || source == null) return;

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 75,
    );

    if (!mounted || pickedFile == null) return;

    setState(() => _sending = true);
    try {
      final bytes = await pickedFile.readAsBytes();
      if (!mounted) return;
      await GroupChatRepository.instance.sendImageMessage(
        groupId: group.id,
        senderUid: uid,
        senderName: _currentUserName(provider),
        bytes: bytes,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not send image: $error'),
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

  void _openNusAi() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AiExpenseScreen(),
      ),
    );
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
          margin: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 6.h),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: AppColors.brass.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(6.r),
                decoration: BoxDecoration(
                  color: AppColors.brass.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.groups_rounded,
                  color: AppColors.brassSoft,
                  size: 18.r,
                ),
              ),
              10.horizontalSpace,
              Expanded(
                child: Text(
                  '${provider.people.where((p) => !p.archived).length} members in chat',
                  style: TextStyle(
                    color: AppColors.paper,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: AppColors.brass.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'TOTAL ',
                      style: TextStyle(
                        color: AppColors.brassSoft,
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
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

              final streamedMessages = snapshot.data ?? const <GroupMessage>[];
              final messagesById = <String, GroupMessage>{
                for (final message in (_olderMessagesByGroup[group.id] ?? const <GroupMessage>[]))
                  message.id: message,
                for (final message in streamedMessages) message.id: message,
              };
              final messages = messagesById.values.toList()
                ..sort((a, b) {
                  final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                  final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                  final order = bTime.compareTo(aTime);
                  return order != 0 ? order : b.id.compareTo(a.id);
                });
              final hasMoreOlder = _hasMoreOlderByGroup[group.id] ??
                  streamedMessages.length >= GroupChatRepository.pageSize;
              final timeline = <_TimelineItem>[
                for (final message in messages) _TimelineItem.message(message),
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
                itemCount: timeline.length + (hasMoreOlder ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == timeline.length) {
                    final loading = _loadingOlderByGroup[group.id] == true;
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      child: Center(
                        child: TextButton(
                          onPressed: loading
                              ? null
                              : () => _loadOlderMessages(group.id, messages),
                          child: loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Load older messages'),
                        ),
                      ),
                    );
                  }
                  final item = timeline[index];
                  final currentDate = item.timestamp;

                  // In a reversed list, the older item in chronological order is at index + 1.
                  bool showDateHeader = false;
                  if (index == timeline.length - 1) {
                    showDateHeader = true; // Oldest item at very top of chat
                  } else {
                    final olderDate = timeline[index + 1].timestamp;
                    showDateHeader = !_isSameDay(currentDate, olderDate);
                  }

                  Widget contentWidget;
                  if (item.message != null) {
                    contentWidget = _MessageBubble(
                      message: item.message!,
                      isMine: item.message!.senderUid == uid,
                    );
                  } else {
                    contentWidget = _ExpenseTimelineCard(expense: item.expense!);
                  }

                  if (showDateHeader) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _DateHeaderChip(
                          dateText: _formatDateHeader(currentDate),
                        ),
                        contentWidget,
                      ],
                    );
                  }

                  return contentWidget;
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
          onOpenAi: _openNusAi,
          onSendImage: () => _pickAndSendImage(provider),
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

  Widget _buildImage(String url) {
    if (url.startsWith('groups/')) return _StorageChatImage(path: url, fit: BoxFit.cover);
    if (url.startsWith('data:image')) {
      final commaIndex = url.indexOf(',');
      final base64Str = commaIndex != -1 ? url.substring(commaIndex + 1) : url;
      return Image.memory(
        base64Decode(base64Str),
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.broken_image, color: AppColors.slate),
      );
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) =>
          const Icon(Icons.broken_image, color: AppColors.slate),
    );
  }

  void _showOptionsSheet(
      BuildContext context, String? groupId, bool isGroupOwner) {
    if (groupId == null || groupId.isEmpty) return;
    final isImage = (message.imagePath != null && message.imagePath!.isNotEmpty) || (message.imageUrl != null && message.imageUrl!.isNotEmpty);
    final canEdit = isMine && !isImage;
    final canDelete = isMine || isGroupOwner;

    if (!canEdit && !canDelete) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.ink,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 8.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: AppColors.paper.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              12.verticalSpace,
              if (canEdit)
                ListTile(
                  leading: Container(
                    padding: EdgeInsets.all(8.r),
                    decoration: BoxDecoration(
                      color: AppColors.brass.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.edit_outlined,
                        color: AppColors.brassSoft, size: 20.r),
                  ),
                  title: Text(
                    'Edit Message',
                    style: TextStyle(
                      color: AppColors.paper,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showEditDialog(context, groupId);
                  },
                ),
              if (canDelete)
                ListTile(
                  leading: Container(
                    padding: EdgeInsets.all(8.r),
                    decoration: BoxDecoration(
                      color: AppColors.rust.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.delete_outline,
                        color: AppColors.rust, size: 20.r),
                  ),
                  title: Text(
                    isImage ? 'Delete Image' : 'Delete Message',
                    style: TextStyle(
                      color: AppColors.rust,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmDeleteMessage(context, groupId, isImage);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, String groupId) {
    final controller = TextEditingController(text: message.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.paper,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        title: Text(
          'Edit Message',
          style: TextStyle(
            color: AppColors.ink,
            fontWeight: FontWeight.bold,
            fontSize: 18.sp,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          minLines: 1,
          maxLength: GroupChatRepository.maxMessageLength,
          style: TextStyle(color: AppColors.ink, fontSize: 15.sp),
          decoration: AppTheme.inputDecoration('Message…').copyWith(
            filled: false,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.slate)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newText = controller.text.trim();
              if (newText.length > GroupChatRepository.maxMessageLength) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Messages cannot exceed 1000 characters.')),
                );
                return;
              }
              if (newText.isNotEmpty && newText != message.text) {
                Navigator.pop(ctx);
                try {
                  await GroupChatRepository.instance.editMessage(
                    groupId: groupId,
                    messageId: message.id,
                    newText: newText,
                  );
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Could not edit message: $e'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              } else {
                Navigator.pop(ctx);
              }
            },
            style: AppTheme.solidButton.copyWith(
              padding: WidgetStateProperty.all(
                EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              ),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  Future<void> _confirmDeleteMessage(
      BuildContext context, String groupId, bool isImage) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.paper,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        title: Text(
          isImage ? 'Delete image?' : 'Delete message?',
          style: TextStyle(
            color: AppColors.ink,
            fontWeight: FontWeight.bold,
            fontSize: 18.sp,
          ),
        ),
        content: Text(
          isImage
              ? 'This photo will be permanently deleted from the group chat.'
              : 'This message will be permanently deleted from the group chat.',
          style: const TextStyle(color: AppColors.slate),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.slate)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: AppTheme.solidButton.copyWith(
              backgroundColor: WidgetStateProperty.all(AppColors.rust),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await GroupChatRepository.instance.deleteMessage(
          groupId: groupId,
          messageId: message.id,
        );
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not delete message: $e'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SplitProvider>();
    final groupId = provider.currentGroup?.id;
    final isGroupOwner = provider.isCurrentGroupOwner;

    final alignment =
        isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bubbleGradient = isMine
        ? const LinearGradient(
            colors: [AppColors.brass, AppColors.brassSoft],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : null;
    final bubbleColor = isMine ? null : AppColors.paper;
    final textColor = AppColors.ink;

    final initial = message.senderName.isNotEmpty
        ? message.senderName[0].toUpperCase()
        : 'M';

    final hasImage = (message.imagePath != null && message.imagePath!.isNotEmpty) || (message.imageUrl != null && message.imageUrl!.isNotEmpty);
    final imageSource = message.imagePath ?? message.imageUrl;
    final isMultiLine = message.text.contains('\n') || message.text.length > 32;

    final timeString = message.isEdited
        ? '${_formatTime(message.createdAt)} · edited'
        : _formatTime(message.createdAt);

    final timeWidget = Text(
      timeString,
      style: TextStyle(
        color: AppColors.ink.withValues(alpha: 0.62),
        fontSize: 10.sp,
        fontWeight: FontWeight.w500,
      ),
    );

    if (hasImage) {
      return Padding(
        padding: EdgeInsets.only(bottom: 14.h),
        child: Column(
          crossAxisAlignment: alignment,
          children: [
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FullScreenImageViewer(
                      imageUrl: imageSource,
                    ),
                  ),
                );
              },
              onLongPress: () =>
                  _showOptionsSheet(context, groupId, isGroupOwner),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 0.84.sw),
                child: Container(
                  padding: EdgeInsets.all(10.r),
                  decoration: BoxDecoration(
                    color: AppColors.paper,
                    borderRadius: BorderRadius.circular(20.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14.r),
                        child: Container(
                          constraints: BoxConstraints(
                            maxHeight: 320.h,
                            maxWidth: 0.80.sw,
                          ),
                          child: Stack(
                            children: [
                              _buildImage(imageSource!),
                              Positioned(
                                bottom: 8.h,
                                right: 8.w,
                                child: Container(
                                  padding: EdgeInsets.all(5.r),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.55),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.zoom_in_rounded,
                                    color: Colors.white,
                                    size: 15.r,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (message.text.isNotEmpty) ...[
                        8.verticalSpace,
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4.w),
                          child: Text(
                            message.text,
                            style: TextStyle(
                              color: AppColors.ink,
                              fontSize: 14.sp,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            4.verticalSpace,
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.w),
              child: Text(
                '${isMine ? 'You' : message.senderName} · ${_formatTime(message.createdAt)}',
                style: TextStyle(
                  color: AppColors.slate,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Row(
            mainAxisAlignment:
                isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMine) ...[
                CircleAvatar(
                  radius: 14.r,
                  backgroundColor: AppColors.brass.withValues(alpha: 0.3),
                  child: Text(
                    initial,
                    style: TextStyle(
                      color: AppColors.paper,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                6.horizontalSpace,
              ],
              GestureDetector(
                onLongPress: () =>
                    _showOptionsSheet(context, groupId, isGroupOwner),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 0.78.sw),
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      gradient: bubbleGradient,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16.r),
                        topRight: Radius.circular(16.r),
                        bottomLeft: Radius.circular(isMine ? 16.r : 4.r),
                        bottomRight: Radius.circular(isMine ? 4.r : 16.r),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: isMultiLine
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!isMine) ...[
                                Text(
                                  message.senderName,
                                  style: TextStyle(
                                    color: AppColors.inkSoft,
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                4.verticalSpace,
                              ],
                              Text(
                                message.text,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 14.sp,
                                  height: 1.35,
                                ),
                              ),
                              4.verticalSpace,
                              Align(
                                alignment: Alignment.bottomRight,
                                child: timeWidget,
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!isMine) ...[
                                Text(
                                  message.senderName,
                                  style: TextStyle(
                                    color: AppColors.inkSoft,
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                2.verticalSpace,
                              ],
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Flexible(
                                    child: Text(
                                      message.text,
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 14.sp,
                                        height: 1.25,
                                      ),
                                    ),
                                  ),
                                  8.horizontalSpace,
                                  Padding(
                                    padding: EdgeInsets.only(bottom: 1.h),
                                    child: timeWidget,
                                  ),
                                ],
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
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
    final currency = group?.currency ?? 'AED';
    final ratio = expense.participantCount > 0
        ? (expense.settledCount / expense.participantCount).clamp(0.0, 1.0)
        : 0.0;

    final accentColor = settled ? AppColors.sage : AppColors.brass;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10.h),
      child: Center(
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.paper,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.7),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20.r),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ExpenseDetailScreen(expense: expense),
                    ),
                  );
                },
                child: Column(
                  children: [
                    // Top Accent Banner / Receipt Header
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 10.h,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        border: Border(
                          bottom: BorderSide(
                            color: accentColor.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(4.r),
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  settled
                                      ? Icons.check_circle_rounded
                                      : Icons.receipt_long_rounded,
                                  color: accentColor,
                                  size: 14.r,
                                ),
                              ),
                              8.horizontalSpace,
                              Text(
                                settled ? 'FULLY SETTLED' : 'EXPENSE SPLIT',
                                style: TextStyle(
                                  color:
                                      settled ? AppColors.sage : AppColors.ink,
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            _formatDate(expense.createdAt),
                            style: TextStyle(
                              color: AppColors.slate,
                              fontSize: 10.5.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Main Content Section
                    Padding(
                      padding: EdgeInsets.all(16.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 20.r,
                                backgroundColor:
                                    payer?.color ?? AppColors.brass,
                                child: Text(
                                  (payer?.name ?? 'S')[0].toUpperCase(),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14.sp,
                                  ),
                                ),
                              ),
                              12.horizontalSpace,
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      expense.desc,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: AppColors.ink,
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w800,
                                        height: 1.2,
                                      ),
                                    ),
                                    4.verticalSpace,
                                    RichText(
                                      text: TextSpan(
                                        style: TextStyle(
                                          color: AppColors.slate,
                                          fontSize: 12.sp,
                                        ),
                                        children: [
                                          const TextSpan(text: 'Paid by '),
                                          TextSpan(
                                            text: payer?.name ?? 'Someone',
                                            style: const TextStyle(
                                              color: AppColors.ink,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              8.horizontalSpace,
                              Text(
                                fmtCurrency(expense.amount, currency),
                                style: TextStyle(
                                  color: AppColors.ink,
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),

                          14.verticalSpace,

                          // Settlement Progress Bar
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    settled
                                        ? 'All shares paid'
                                        : '${expense.settledCount} of ${expense.participantCount} settled',
                                    style: TextStyle(
                                      color: settled
                                          ? AppColors.sage
                                          : AppColors.slate,
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    '${(ratio * 100).round()}%',
                                    style: TextStyle(
                                      color: accentColor,
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                              6.verticalSpace,
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6.r),
                                child: LinearProgressIndicator(
                                  value: ratio,
                                  minHeight: 6.h,
                                  backgroundColor:
                                      AppColors.line.withValues(alpha: 0.6),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    accentColor,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          14.verticalSpace,

                          // Perforated Dashed Divider
                          _DashedDivider(
                            color: AppColors.line.withValues(alpha: 0.6),
                          ),

                          12.verticalSpace,

                          // View Details Action Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${expense.splitWith.length} people sharing',
                                style: TextStyle(
                                  color: AppColors.slate,
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    'VIEW SPLIT',
                                    style: TextStyle(
                                      color: AppColors.ink,
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                  4.horizontalSpace,
                                  Container(
                                    padding: EdgeInsets.all(3.r),
                                    decoration: BoxDecoration(
                                      color: AppColors.ink,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.arrow_forward_rounded,
                                      color: AppColors.paper,
                                      size: 11.r,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedDivider extends StatelessWidget {
  final Color color;

  const _DashedDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    const height = 1.0;
    const dashWidth = 5.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = constraints.maxWidth;
        final dashCount = (boxWidth / (2 * dashWidth)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(dashCount, (_) {
            return SizedBox(
              width: dashWidth,
              height: height,
              child: DecoratedBox(
                decoration: BoxDecoration(color: color),
              ),
            );
          }),
        );
      },
    );
  }
}

class _MessageComposer extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onAddSplit;
  final VoidCallback onOpenAi;
  final VoidCallback onSendImage;

  const _MessageComposer({
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.onAddSplit,
    required this.onOpenAi,
    required this.onSendImage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(10.w, 8.h, 12.w, 10.h),
      decoration: BoxDecoration(
        color: AppColors.ink,
        border: Border(
          top: BorderSide(color: AppColors.paper.withValues(alpha: 0.12)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _AnimatedMenuButton(
              onOpenAi: onOpenAi,
              onAddSplit: onAddSplit,
              onSendImage: onSendImage,
            ),
            8.horizontalSpace,
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
      ),
    );
  }
}

class _AnimatedMenuButton extends StatefulWidget {
  final VoidCallback onOpenAi;
  final VoidCallback onAddSplit;
  final VoidCallback onSendImage;

  const _AnimatedMenuButton({
    required this.onOpenAi,
    required this.onAddSplit,
    required this.onSendImage,
  });

  @override
  State<_AnimatedMenuButton> createState() => _AnimatedMenuButtonState();
}

class _AnimatedMenuButtonState extends State<_AnimatedMenuButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotateAnimation;
  bool _isOpen = false;
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      value: 0.0,
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _rotateAnimation = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _hideOverlay();
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isOpen = !_isOpen;
    });
    if (_isOpen) {
      _showOverlay();
      _controller.forward();
    } else {
      _controller.reverse().then((_) => _hideOverlay());
    }
  }

  void _close() {
    if (_isOpen) {
      setState(() {
        _isOpen = false;
      });
      _controller.reverse().then((_) => _hideOverlay());
    }
  }

  void _showOverlay() {
    _hideOverlay();
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final buttonCenter = Offset(
      offset.dx + size.width / 2,
      offset.dy + size.height / 2,
    );

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _close,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final opacity = _controller.value;
                  return BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: 5.0 * opacity,
                      sigmaY: 5.0 * opacity,
                    ),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.35 * opacity),
                    ),
                  );
                },
              ),
            ),
          ),
          _buildArcMenuItem(
            index: 2,
            angleDegrees: 90,
            icon: Image.asset(
              'assets/icon/ai.png',
              width: 20.r,
              height: 20.r,
              errorBuilder: (_, __, ___) => Icon(
                Icons.auto_awesome,
                size: 20.r,
                color: AppColors.ink,
              ),
            ),
            onTap: () {
              _close();
              widget.onOpenAi();
            },
            buttonCenter: buttonCenter,
            maxRadius: 108.r,
          ),
          _buildArcMenuItem(
            index: 1,
            angleDegrees: 52,
            icon: Icon(
              Icons.receipt_long_outlined,
              size: 22.r,
              color: AppColors.ink,
            ),
            onTap: () {
              _close();
              widget.onAddSplit();
            },
            buttonCenter: buttonCenter,
            maxRadius: 108.r,
          ),
          _buildArcMenuItem(
            index: 0,
            angleDegrees: 12,
            icon: Icon(
              Icons.image_outlined,
              size: 22.r,
              color: AppColors.ink,
            ),
            onTap: () {
              _close();
              widget.onSendImage();
            },
            buttonCenter: buttonCenter,
            maxRadius: 108.r,
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Widget _buildArcMenuItem({
    required int index,
    required double angleDegrees,
    required Widget icon,
    required VoidCallback onTap,
    required Offset buttonCenter,
    required double maxRadius,
  }) {
    final double start = (index * 0.08).clamp(0.0, 0.6);
    final double end = (start + 0.7).clamp(0.0, 1.0);
    final itemAnimation = CurvedAnimation(
      parent: _controller,
      curve: Interval(start, end, curve: Curves.easeOutBack),
    );

    final radians = angleDegrees * (math.pi / 180.0);

    return AnimatedBuilder(
      animation: itemAnimation,
      builder: (context, child) {
        final double progress = itemAnimation.value;
        final double currentRadius = maxRadius * progress;
        final double dx = currentRadius * math.cos(radians);
        final double dy = -currentRadius * math.sin(radians);

        final double itemCenterX = buttonCenter.dx + dx;
        final double itemCenterY = buttonCenter.dy + dy;
        final double itemSize = 46.r;

        return Positioned(
          left: itemCenterX - (itemSize / 2),
          top: itemCenterY - (itemSize / 2),
          child: Material(
            color: Colors.transparent,
            child: Opacity(
              opacity: progress.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: progress.clamp(0.0, 1.0),
                child: InkWell(
                  onTap: onTap,
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: itemSize,
                    height: itemSize,
                    decoration: BoxDecoration(
                      color: AppColors.brass,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(child: icon),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggle,
      child: Container(
        width: 42.r,
        height: 42.r,
        decoration: BoxDecoration(
          color: _isOpen
              ? AppColors.brass
              : AppColors.brass.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: AppColors.brass.withValues(alpha: 0.4),
          ),
          boxShadow: _isOpen
              ? [
                  BoxShadow(
                    color: AppColors.brass.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Center(
          child: RotationTransition(
            turns: _rotateAnimation,
            child: Icon(
              _isOpen ? Icons.close : Icons.add,
              color: _isOpen ? AppColors.ink : AppColors.brassSoft,
              size: 22.r,
            ),
          ),
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

String _formatDateHeader(DateTime? dateTime) {
  if (dateTime == null) return '';
  final local = dateTime.toLocal();
  final now = DateTime.now();
  final date = DateTime(local.year, local.month, local.day);
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));

  if (date == today) return 'Today';
  if (date == yesterday) return 'Yesterday';

  final months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  if (local.year == now.year) {
    return '${months[local.month - 1]} ${local.day}';
  }
  return '${months[local.month - 1]} ${local.day}, ${local.year}';
}

bool _isSameDay(DateTime a, DateTime b) {
  final localA = a.toLocal();
  final localB = b.toLocal();
  return localA.year == localB.year &&
      localA.month == localB.month &&
      localA.day == localB.day;
}

class _DateHeaderChip extends StatelessWidget {
  final String dateText;

  const _DateHeaderChip({required this.dateText});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 5.h),
          decoration: BoxDecoration(
            color: AppColors.paper.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: AppColors.paper.withValues(alpha: 0.15),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            dateText,
            style: TextStyle(
              color: AppColors.paper,
              fontSize: 11.sp,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ),
    );
  }
}

class _StorageChatImage extends StatefulWidget {
  final String path;
  final BoxFit fit;
  const _StorageChatImage({required this.path, required this.fit});

  @override
  State<_StorageChatImage> createState() => _StorageChatImageState();
}

class _StorageChatImageState extends State<_StorageChatImage> {
  late Future<Uint8List?> _future;
  @override
  void initState() {
    super.initState();
    _future = _load();
  }
  Future<Uint8List?> _load() => FirebaseStorage.instance
      .ref(widget.path).getData(GroupChatRepository.maxImageBytes);
  @override
  void didUpdateWidget(covariant _StorageChatImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) _future = _load();
  }
  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Icon(Icons.broken_image, color: AppColors.slate);
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(
              strokeWidth: 2, color: AppColors.brassSoft));
          }
          return Image.memory(snapshot.data!, fit: widget.fit,
            filterQuality: FilterQuality.high,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.broken_image, color: AppColors.slate));
        },
      );
}

class FullScreenImageViewer extends StatefulWidget {
  final String imageUrl;

  const FullScreenImageViewer({super.key, required this.imageUrl});

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  final TransformationController _transformationController =
      TransformationController();

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  Widget _buildImage(String url) {
    if (url.startsWith('groups/')) return _StorageChatImage(path: url, fit: BoxFit.contain);
    if (url.startsWith('data:image')) {
      final commaIndex = url.indexOf(',');
      final base64Str = commaIndex != -1 ? url.substring(commaIndex + 1) : url;
      return Image.memory(base64Decode(base64Str), fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.broken_image, color: AppColors.slate, size: 48)));
    }
    return Image.network(url, fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) => const Center(
        child: Icon(Icons.broken_image, color: AppColors.slate, size: 48)));
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Image Preview',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Reset zoom',
            onPressed: _resetZoom,
          ),
          12.horizontalSpace,
        ],
      ),
      body: SafeArea(
        child: GestureDetector(
          onDoubleTap: _resetZoom,
          child: Center(
            child: InteractiveViewer(
              transformationController: _transformationController,
              minScale: 0.8,
              maxScale: 5.0,
              clipBehavior: Clip.none,
              child: _buildImage(widget.imageUrl),
            ),
          ),
        ),
      ),
    );
  }
}

String _formatDate(DateTime? dateTime) {
  if (dateTime == null) return '';
  final local = dateTime.toLocal();
  final months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  return '${months[local.month - 1]} ${local.day}';
}
