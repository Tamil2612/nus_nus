import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../models/person.dart';
import '../models/expense.dart';
import '../providers/split_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';
import '../screens/expense_detail_screen.dart';
import 'add_member_sheet.dart';

class LedgerTab extends StatefulWidget {
  const LedgerTab({super.key});

  @override
  State<LedgerTab> createState() => _LedgerTabState();
}

class _LedgerTabState extends State<LedgerTab> {
  Future<void> _confirmRemovePerson(
      BuildContext context, SplitProvider provider, Person person) async {
    final hasHistory = provider.expenses.any(
        (e) => e.payerId == person.id || e.splitMap.containsKey(person.id));

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.paper,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Text('Remove ${person.name}?',
            style: const TextStyle(
                color: AppColors.ink, fontWeight: FontWeight.bold)),
        content: Text(
          hasHistory
              ? '${person.name} has expense history in this group. They\'ll be hidden '
                  'from new expenses, but past activity and any balance '
                  'they still owe or are owed stays intact.'
              : '${person.name} has no expenses yet, so they\'ll be removed completely.',
          style: const TextStyle(color: AppColors.slate),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                const Text('Cancel', style: TextStyle(color: AppColors.slate)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: AppTheme.solidButton.copyWith(
              backgroundColor: WidgetStateProperty.all(AppColors.rust),
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final archived = provider.removePerson(person.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(archived
            ? '${person.name} removed from the active list — history kept.'
            : '${person.name} removed.'),
        backgroundColor: AppColors.inkSoft,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SplitProvider>();
    final expenses = provider.expenses; // Keep chronological for chat look

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.all(16.w),
            children: [
              // Activity Feed Title
              Padding(
                padding: EdgeInsets.symmetric(vertical: 16.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Activity Feed',
                      style: TextStyle(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.paper),
                    ),
                    Text(
                      '${expenses.length} splits',
                      style: TextStyle(
                          fontSize: 12.sp,
                          color: AppColors.slate,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),

              // Group Roster Section
              _GroupRoster(
                people: provider.people,
                isOwner: provider.isCurrentGroupOwner,
                onAdd: () => showAddRegisteredMemberSheet(context),
                onRemove: (p) => _confirmRemovePerson(context, provider, p),
              ),
              24.verticalSpace,

              if (expenses.isEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 100.h),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.receipt_long_outlined,
                            size: 64.r,
                            color: AppColors.slate.withValues(alpha: 0.3)),
                        16.verticalSpace,
                        Text(
                          'No activity yet.\nAdd a split to get started!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: AppColors.slate, fontSize: 14.sp),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...expenses.reversed.map((e) {
                  final payer = provider.personById(e.payerId);
                  return _ActivityExpenseCard(
                    expense: e,
                    payer: payer,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ExpenseDetailScreen(expense: e)),
                      );
                    },
                  );
                }),

              100.verticalSpace, // Bottom padding
            ],
          ),
        ),
      ],
    );
  }
}

class _ActivityExpenseCard extends StatelessWidget {
  final Expense expense;
  final Person? payer;
  final VoidCallback onTap;

  const _ActivityExpenseCard({
    required this.expense,
    required this.payer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 20.h),
        height: 100.h,
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16.r),
          child: Row(
            children: [
              // Vertical Ticket Side
              Container(
                width: 60.w,
                color: AppColors.brass,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      expense.isSettlement
                          ? Icons.handshake
                          : Icons.receipt_long,
                      color: AppColors.ink,
                      size: 24.r,
                    ),
                    8.verticalSpace,
                    Text(
                      'TAB',
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w900,
                        color: AppColors.ink,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              // Main Info
              Expanded(
                child: Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              expense.desc.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          Text(
                            fmtCurrency(
                                expense.amount,
                                context
                                    .read<SplitProvider>()
                                    .currentGroup!
                                    .currency),
                            style: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w900,
                              color: AppColors.ink,
                            ),
                          ),
                        ],
                      ),
                      4.verticalSpace,
                      Text(
                        'Paid by ${payer?.name ?? 'Someone'}',
                        style: TextStyle(
                          fontSize: 11.5.sp,
                          color: AppColors.slate,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      8.verticalSpace,
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _ParticipantCircles(expense: expense),
                          Text(
                            'VIEW DETAILS →',
                            style: TextStyle(
                              fontSize: 10.sp,
                              color: AppColors.brass,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParticipantCircles extends StatelessWidget {
  final Expense expense;

  const _ParticipantCircles({required this.expense});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<SplitProvider>();
    final ids = expense.splitWith.take(4).toList();

    return Row(
      children: [
        for (int i = 0; i < ids.length; i++)
          Transform.translate(
            offset: Offset(i * -8.w, 0),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.paper, width: 1.5.r),
              ),
              child: CircleAvatar(
                radius: 9.r,
                backgroundColor:
                    provider.personById(ids[i])?.color ?? AppColors.slate,
                child: Text(
                  provider.personById(ids[i])?.name[0].toUpperCase() ?? '?',
                  style: TextStyle(
                      fontSize: 7.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ),
            ),
          ),
        if (expense.splitWith.length > 4)
          Transform.translate(
            offset: Offset(-32.w, 0),
            child: Padding(
              padding: EdgeInsets.only(left: 36.w),
              child: Text(
                '+${expense.splitWith.length - 4}',
                style: TextStyle(
                    fontSize: 10.sp,
                    color: AppColors.slate,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }
}

class _GroupRoster extends StatelessWidget {
  final List<Person> people;
  final bool isOwner;
  final VoidCallback onAdd;
  final Function(Person)? onRemove;

  const _GroupRoster({
    required this.people,
    required this.isOwner,
    required this.onAdd,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'MEMBERS',
              style: TextStyle(
                fontSize: 10.sp,
                fontWeight: FontWeight.w900,
                color: AppColors.brassSoft,
                letterSpacing: 1.2,
              ),
            ),
            if (isOwner)
              GestureDetector(
                onTap: onAdd,
                child: Row(
                  children: [
                    Icon(Icons.add, size: 14.r, color: AppColors.brassSoft),
                    4.horizontalSpace,
                    Text(
                      'ADD MEMBER',
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w900,
                        color: AppColors.brassSoft,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        12.verticalSpace,
        SizedBox(
          height: 40.h,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: people.length,
            itemBuilder: (context, index) {
              final p = people[index];
              final isMe = p.linkedUserId == context.read<SplitProvider>().uid;

              return Padding(
                padding: EdgeInsets.only(right: 8.w),
                child: Container(
                  padding: EdgeInsets.only(
                      left: 12.w, right: (isOwner && !isMe) ? 4.w : 12.w),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 10.r,
                        backgroundColor: p.color,
                        child: Text(
                          p.name[0].toUpperCase(),
                          style: TextStyle(
                              fontSize: 8.sp,
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      8.horizontalSpace,
                      Text(
                        p.name,
                        style: TextStyle(
                            fontSize: 12.sp,
                            color: AppColors.paper,
                            fontWeight: FontWeight.w600),
                      ),
                      if (isOwner && !isMe) ...[
                        4.horizontalSpace,
                        InkWell(
                          onTap: () => onRemove?.call(p),
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4.w),
                            child: Icon(Icons.close_rounded,
                                size: 14.r, color: AppColors.slate),
                          ),
                        )
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
