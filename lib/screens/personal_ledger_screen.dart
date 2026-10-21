import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../data/group_chat_repository.dart';
import '../models/expense.dart';
import '../models/group_message.dart';
import '../providers/split_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';
import '../widgets/expense_form_sheet.dart';
import '../widgets/branded_loader.dart';
import '../widgets/app_dialog.dart';

class PersonalLedgerScreen extends StatefulWidget {
  const PersonalLedgerScreen({super.key});

  @override
  State<PersonalLedgerScreen> createState() => _PersonalLedgerScreenState();
}

class _PersonalLedgerScreenState extends State<PersonalLedgerScreen> {
  final _noteController = TextEditingController();
  bool _sendingNote = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _sendNote(
      SplitProvider provider, String groupId, String senderName) async {
    final uid = provider.uid;
    final note = _noteController.text.trim();
    if (_sendingNote || uid == null || note.isEmpty) return;
    if (note.length > GroupChatRepository.maxMessageLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notes cannot exceed 1000 characters.')),
      );
      return;
    }

    setState(() => _sendingNote = true);
    try {
      await GroupChatRepository.instance.sendMessage(
        groupId: groupId,
        senderUid: uid,
        senderName: senderName,
        text: note,
      );
      if (mounted) _noteController.clear();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save note: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingNote = false);
    }
  }

  Future<void> _confirmDeleteNote(String groupId, GroupMessage message) async {
    final confirmed = await AppDialog.showConfirm(
      context,
      icon: Icons.delete_outline_rounded,
      iconColor: AppColors.rust,
      title: 'Delete this note?',
      message: 'This note will be removed from your personal ledger.',
      confirmText: 'Delete note',
      confirmColor: AppColors.rust,
    );
    if (confirmed != true || !mounted) return;

    try {
      await GroupChatRepository.instance.deleteMessage(
        groupId: groupId,
        messageId: message.id,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete note: $error')),
        );
      }
    }
  }

  Future<void> _confirmDeleteExpense(
      BuildContext context, SplitProvider provider, Expense expense) async {
    final confirmed = await AppDialog.showConfirm(
      context,
      icon: Icons.delete_outline_rounded,
      iconColor: AppColors.rust,
      title: 'Delete expense?',
      message: '“${expense.desc}” will be removed from your personal ledger.',
      confirmText: 'Delete',
      confirmColor: AppColors.rust,
    );
    if (confirmed != true || !context.mounted) return;
    final error = provider.removeExpense(expense.id);
    if (error != null && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SplitProvider>();
    final group = provider.personalGroup;

    if (group == null &&
        (provider.isLoading || provider.isEnsuringPersonalGroup)) {
      return const BrandedLoader(message: 'Opening your personal ledger…');
    }

    if (group == null) {
      return Scaffold(
        backgroundColor: AppColors.ink,
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(28.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.receipt_long_outlined,
                    color: AppColors.brassSoft, size: 42.r),
                14.verticalSpace,
                Text(
                  'Your personal ledger is unavailable.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.paper,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                16.verticalSpace,
                ElevatedButton(
                  onPressed: provider.retryPersonalGroupCreation,
                  style: AppTheme.solidButton,
                  child: const Text('Try again'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Back to groups'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final expenses = group.expenses.toList()
      ..sort((a, b) =>
          (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    final total = expenses
        .where((expense) => !expense.isSettlement)
        .fold<double>(0, (sum, expense) => sum + expense.amount);
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final senderName = group.ownerName.trim().isEmpty ? 'Me' : group.ownerName;

    return Scaffold(
      backgroundColor: AppColors.ink,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.paper),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Personal ledger',
            style: TextStyle(
                color: AppColors.paper,
                fontSize: 18.sp,
                fontWeight: FontWeight.bold)),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.5, -0.8),
            radius: 1.4,
            colors: [AppColors.inkSoft, AppColors.ink],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              if (!keyboardOpen) ...[
                Padding(
                  padding: EdgeInsets.fromLTRB(18.w, 8.h, 18.w, 18.h),
                  child: _PersonalSummaryCard(
                    total: total,
                    currency: group.currency,
                    expenseCount: expenses.where((e) => !e.isSettlement).length,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(22.w, 0, 18.w, 10.h),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Your activity',
                                style: TextStyle(
                                    color: AppColors.paper,
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w800)),
                            3.verticalSpace,
                            Text('Expenses and personal notes',
                                style: TextStyle(
                                    color: AppColors.slate, fontSize: 11.sp)),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 10.w, vertical: 6.h),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .07),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Text(
                            '${expenses.where((e) => !e.isSettlement).length} expenses',
                            style: TextStyle(
                                color: AppColors.paper,
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
              ],
              Expanded(
                child: StreamBuilder<List<GroupMessage>>(
                  stream: GroupChatRepository.instance.watchMessages(group.id),
                  builder: (context, snapshot) {
                    final messages = snapshot.data ?? const <GroupMessage>[];
                    final items = <_PersonalActivityItem>[
                      for (final expense in expenses)
                        _PersonalActivityItem.expense(expense),
                      for (final message in messages)
                        _PersonalActivityItem.note(message),
                    ]..sort((a, b) => b.timestamp.compareTo(a.timestamp));

                    return Column(
                      children: [
                        if (snapshot.hasError)
                          Padding(
                            padding: EdgeInsets.fromLTRB(18.w, 0, 18.w, 8.h),
                            child: Text('Notes are temporarily unavailable.',
                                style: TextStyle(
                                    color: AppColors.rust, fontSize: 11.sp)),
                          ),
                        Expanded(
                          child: items.isEmpty &&
                                  snapshot.connectionState ==
                                      ConnectionState.waiting
                              ? const Center(
                                  child: CircularProgressIndicator(
                                      color: AppColors.brassSoft),
                                )
                              : items.isEmpty
                                  ? const _PersonalEmptyState()
                                  : ListView.builder(
                                      reverse: true,
                                      padding: EdgeInsets.fromLTRB(
                                          18.w, 8.h, 18.w, 14.h),
                                      itemCount: items.length,
                                      itemBuilder: (context, index) {
                                        final item = items[index];
                                        if (item.expense != null) {
                                          final expense = item.expense!;
                                          return _PersonalExpenseEntry(
                                            expense: expense,
                                            currency: group.currency,
                                            onEdit: () => showExpenseFormSheet(
                                              context,
                                              existing: expense,
                                            ),
                                            onDelete: () =>
                                                _confirmDeleteExpense(
                                              context,
                                              provider,
                                              expense,
                                            ),
                                          );
                                        }
                                        return _PersonalNoteBubble(
                                          message: item.message!,
                                          isMine: item.message!.senderUid ==
                                              provider.uid,
                                          onLongPress:
                                              item.message!.senderUid ==
                                                      provider.uid
                                                  ? () => _confirmDeleteNote(
                                                      group.id, item.message!)
                                                  : null,
                                        );
                                      },
                                    ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              _PersonalNoteComposer(
                controller: _noteController,
                sending: _sendingNote,
                onSend: () => _sendNote(provider, group.id, senderName),
                onAddExpense: () => showExpenseFormSheet(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PersonalSummaryCard extends StatelessWidget {
  final double total;
  final String currency;
  final int expenseCount;

  const _PersonalSummaryCard({
    required this.total,
    required this.currency,
    required this.expenseCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(19.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.paper, AppColors.paperDim],
        ),
        borderRadius: BorderRadius.circular(23.r),
        border: Border.all(color: Colors.white.withValues(alpha: .65)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .17),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48.r,
            height: 48.r,
            decoration: BoxDecoration(
              color: AppColors.ink,
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Icon(Icons.account_balance_wallet_outlined,
                color: AppColors.brassSoft, size: 23.r),
          ),
          14.horizontalSpace,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TOTAL SPENT',
                    style: TextStyle(
                        color: AppColors.slate,
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1)),
                4.verticalSpace,
                Text(fmtCurrency(total, currency),
                    style: TextStyle(
                        color: AppColors.ink,
                        fontSize: 23.sp,
                        fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: AppColors.ink.withValues(alpha: .07),
              borderRadius: BorderRadius.circular(13.r),
            ),
            child: Column(
              children: [
                Text('$expenseCount',
                    style: TextStyle(
                        color: AppColors.ink,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w900)),
                Text('entries',
                    style: TextStyle(
                        color: AppColors.slate,
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonalExpenseEntry extends StatelessWidget {
  final Expense expense;
  final String currency;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PersonalExpenseEntry({
    required this.expense,
    required this.currency,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final date = expense.createdAt;
    final isAdjustment = expense.isSettlement;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 7.h),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(21.r),
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(21.r),
          child: Ink(
            padding: EdgeInsets.fromLTRB(15.w, 14.h, 8.w, 13.h),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.paper, AppColors.paperDim],
              ),
              borderRadius: BorderRadius.circular(21.r),
              border: Border.all(color: Colors.white.withValues(alpha: .7)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40.r,
                      height: 40.r,
                      decoration: BoxDecoration(
                        color: AppColors.brass.withValues(alpha: .2),
                        borderRadius: BorderRadius.circular(13.r),
                      ),
                      child: Icon(
                        isAdjustment
                            ? Icons.swap_horiz_rounded
                            : Icons.receipt_long_rounded,
                        color: AppColors.ink,
                        size: 20.r,
                      ),
                    ),
                    10.horizontalSpace,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isAdjustment ? 'ADJUSTMENT' : 'PERSONAL EXPENSE',
                            style: TextStyle(
                                color: AppColors.slate,
                                fontSize: 8.5.sp,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1),
                          ),
                          3.verticalSpace,
                          Text(
                            date == null
                                ? 'Date unavailable'
                                : _formatEntryDate(date),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: AppColors.slate, fontSize: 10.sp),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Entry actions',
                      padding: EdgeInsets.zero,
                      icon: Icon(Icons.more_horiz_rounded,
                          color: AppColors.slate, size: 21.r),
                      onSelected: (value) {
                        if (value == 'edit') onEdit();
                        if (value == 'delete') onDelete();
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit entry')),
                        PopupMenuItem(
                            value: 'delete', child: Text('Delete entry')),
                      ],
                    ),
                  ],
                ),
                12.verticalSpace,
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        expense.desc,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.ink,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                    ),
                    10.horizontalSpace,
                    Text(
                      fmtCurrency(expense.amount, currency),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          color: AppColors.ink,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
                12.verticalSpace,
                Divider(height: 1, color: AppColors.ink.withValues(alpha: .1)),
                8.verticalSpace,
                Row(
                  children: [
                    Icon(Icons.edit_outlined,
                        color: AppColors.slate, size: 13.r),
                    5.horizontalSpace,
                    Text('Tap to edit entry',
                        style: TextStyle(
                            color: AppColors.slate,
                            fontSize: 9.5.sp,
                            fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Icon(Icons.arrow_forward_rounded,
                        color: AppColors.ink.withValues(alpha: .55),
                        size: 15.r),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PersonalActivityItem {
  final DateTime timestamp;
  final Expense? expense;
  final GroupMessage? message;

  const _PersonalActivityItem._({
    required this.timestamp,
    this.expense,
    this.message,
  });

  factory _PersonalActivityItem.expense(Expense expense) =>
      _PersonalActivityItem._(
        timestamp: expense.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
        expense: expense,
      );

  factory _PersonalActivityItem.note(GroupMessage message) =>
      _PersonalActivityItem._(
        timestamp: message.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
        message: message,
      );
}

class _PersonalNoteBubble extends StatelessWidget {
  final GroupMessage message;
  final bool isMine;
  final VoidCallback? onLongPress;

  const _PersonalNoteBubble({
    required this.message,
    required this.isMine,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final time =
        message.createdAt == null ? '' : _formatEntryDate(message.createdAt!);
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .82),
        child: GestureDetector(
          onLongPress: onLongPress,
          child: Container(
            margin: EdgeInsets.symmetric(vertical: 5.h),
            padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 11.h),
            decoration: BoxDecoration(
              color: isMine
                  ? AppColors.brass.withValues(alpha: .2)
                  : Colors.white.withValues(alpha: .08),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(17.r),
                topRight: Radius.circular(17.r),
                bottomLeft: Radius.circular(isMine ? 17.r : 5.r),
                bottomRight: Radius.circular(isMine ? 5.r : 17.r),
              ),
              border: Border.all(
                  color: AppColors.brass.withValues(alpha: isMine ? .25 : .12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.sticky_note_2_outlined,
                        color: AppColors.brassSoft, size: 13.r),
                    5.horizontalSpace,
                    Text(isMine ? 'PERSONAL NOTE' : message.senderName,
                        style: TextStyle(
                            color: AppColors.brassSoft,
                            fontSize: 8.5.sp,
                            fontWeight: FontWeight.w900,
                            letterSpacing: .8)),
                  ],
                ),
                6.verticalSpace,
                Text(message.text,
                    style: TextStyle(
                        color: AppColors.paper, fontSize: 13.sp, height: 1.35)),
                if (time.isNotEmpty) ...[
                  5.verticalSpace,
                  Text('${message.isEdited ? 'Edited · ' : ''}$time',
                      style: TextStyle(
                          color: AppColors.slate,
                          fontSize: 9.5.sp,
                          fontWeight: FontWeight.w500)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PersonalNoteComposer extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onAddExpense;

  const _PersonalNoteComposer({
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.onAddExpense,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(10.w, 9.h, 12.w, 10.h),
      decoration: BoxDecoration(
        color: AppColors.ink.withValues(alpha: .85),
        border:
            Border(top: BorderSide(color: Colors.white.withValues(alpha: .08))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            tooltip: 'Add expense',
            onPressed: onAddExpense,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.brass.withValues(alpha: .16),
              foregroundColor: AppColors.brassSoft,
            ),
            icon: const Icon(Icons.receipt_long_outlined),
          ),
          7.horizontalSpace,
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.newline,
              style: TextStyle(color: AppColors.paper, fontSize: 13.sp),
              decoration: InputDecoration(
                hintText: 'Write a note…',
                hintStyle: TextStyle(color: AppColors.slate, fontSize: 12.sp),
                filled: true,
                fillColor: Colors.white.withValues(alpha: .07),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 15.w, vertical: 12.h),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20.r),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          7.horizontalSpace,
          IconButton.filled(
            tooltip: 'Save note',
            onPressed: sending ? null : onSend,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.brass,
              foregroundColor: AppColors.ink,
            ),
            icon: sending
                ? SizedBox(
                    width: 18.r,
                    height: 18.r,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded),
          ),
        ],
      ),
    );
  }
}

class _PersonalEmptyState extends StatelessWidget {
  const _PersonalEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(30.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72.r,
              height: 72.r,
              decoration: BoxDecoration(
                color: AppColors.brass.withValues(alpha: .14),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.receipt_long_outlined,
                  color: AppColors.brassSoft, size: 32.r),
            ),
            16.verticalSpace,
            Text('Your personal activity starts here',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.paper,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800)),
            7.verticalSpace,
            Text('Add an expense or write a note to start your journal.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.slate, fontSize: 12.sp, height: 1.4)),
          ],
        ),
      ),
    );
  }
}

String _formatEntryDate(DateTime date) {
  final now = DateTime.now();
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final period = date.hour < 12 ? 'AM' : 'PM';
  final time = '$hour:$minute $period';
  if (date.year == now.year && date.month == now.month && date.day == now.day) {
    return 'Today · $time';
  }
  final yesterday = now.subtract(const Duration(days: 1));
  if (date.year == yesterday.year &&
      date.month == yesterday.month &&
      date.day == yesterday.day) {
    return 'Yesterday · $time';
  }
  const months = [
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
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day} · $time';
}
