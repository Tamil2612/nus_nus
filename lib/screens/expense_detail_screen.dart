import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../models/expense.dart';
import '../models/person.dart';
import '../providers/split_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';
import '../widgets/expense_form_sheet.dart';

class ExpenseDetailScreen extends StatelessWidget {
  /// The expense as it looked when this screen was opened — used only as
  /// a fallback while the live version resolves, and to know which id to
  /// look up. Everything actually shown comes from [_resolveLive], so
  /// edits (made here or by another member, live) are reflected instead
  /// of staying frozen at whatever this was when the screen opened.
  final Expense expense;

  const ExpenseDetailScreen({super.key, required this.expense});

  Future<void> _confirmDelete(BuildContext context, SplitProvider provider, Expense live) async {
    final isSettlement = live.isSettlement;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.paper,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Text(isSettlement ? 'Revert settlement?' : 'Delete this split?',
            style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.bold)),
        content: Text(
          isSettlement
              ? 'This will remove the payment record and restore the previous balances. '
                  'This action cannot be undone.'
              : 'This will permanently remove this expense from the group record. '
                  'This action cannot be undone.',
          style: const TextStyle(color: AppColors.slate),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.slate)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: AppTheme.solidButton.copyWith(
              backgroundColor: WidgetStateProperty.all(AppColors.rust),
            ),
            child: Text(isSettlement ? 'Revert' : 'Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      provider.removeExpense(live.id);
      if (context.mounted) Navigator.pop(context); // Go back after delete
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SplitProvider>();

    // Re-resolve the live version of this expense on every rebuild, so an
    // edit made from this screen (or by another member, live) is reflected
    // here instead of staying frozen at whatever `expense` was when this
    // screen was first opened.
    Expense? live;
    for (final e in provider.expenses) {
      if (e.id == expense.id) {
        live = e;
        break;
      }
    }

    // The expense was deleted (by us just now, or by someone else while
    // this screen was open) — there's nothing left to show, so back out
    // instead of rendering stale/dead data.
    if (live == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.canPop(context)) Navigator.pop(context);
      });
      return const Scaffold(
        backgroundColor: AppColors.ink,
        body: SizedBox.shrink(),
      );
    }

    // Bind a guaranteed-non-null, never-reassigned local so every closure
    // below (the map() callbacks, the button handlers) can safely capture
    // it without relying on Dart's promotion-through-closures rules.
    final liveExpense = live;

    final payer = provider.personById(liveExpense.payerId);
    final splitParticipants = liveExpense.splitWith
        .map((id) => provider.personById(id))
        .where((p) => p != null)
        .toList()
        .cast<Person>();
    
    final totalParticipants = splitParticipants.length;
    final isAdder = liveExpense.addedBy == provider.uid;
    
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.5, -0.8),
            radius: 1.4,
            colors: [AppColors.inkSoft, AppColors.ink],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom AppBar
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: AppColors.paper),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Row(
                      children: [
                        if (isAdder) ...[
                          if (!liveExpense.isSettlement)
                            IconButton(
                              icon: const Icon(Icons.edit_outlined,
                                  color: AppColors.brassSoft),
                              onPressed: () => showExpenseFormSheet(context,
                                  existing: liveExpense),
                              tooltip: 'Edit',
                            ),
                          IconButton(
                            icon: Icon(
                                liveExpense.isSettlement
                                    ? Icons.undo
                                    : Icons.delete_outline,
                                color: AppColors.rust),
                            onPressed: () =>
                                _confirmDelete(context, provider, liveExpense),
                            tooltip: liveExpense.isSettlement
                                ? 'Revert Settlement'
                                : 'Delete',
                          ),
                        ],
                        12.horizontalSpace,
                      ],
                    ),
                  ],
                ),
              ),

              Expanded(
                child: ListView(
                  padding: EdgeInsets.symmetric(horizontal: 24.w),
                  children: [
                    12.verticalSpace,

                    // Digital Receipt Hero Card
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.paper,
                        borderRadius: BorderRadius.circular(24.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Top Section: Icon & Category
                          Container(
                            padding: EdgeInsets.symmetric(vertical: 16.h),
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: AppColors.ink.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(24.r)),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(12.r),
                                  decoration: BoxDecoration(
                                    color: AppColors.brass.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    liveExpense.isSettlement
                                        ? Icons.handshake
                                        : Icons.receipt_long,
                                    color: AppColors.brass,
                                    size: 28.r,
                                  ),
                                ),
                                8.verticalSpace,
                                Text(
                                  liveExpense.isSettlement
                                      ? 'SETTLEMENT RECORD'
                                      : 'SPLIT EXPENSE',
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.brass,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Middle Section: Desc & Amount
                          Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 24.w, vertical: 20.h),
                            child: Column(
                              children: [
                                Text(
                                  liveExpense.desc.toUpperCase(),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 18.sp,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.ink,
                                    fontFamily: 'Georgia',
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                8.verticalSpace,
                                Text(
                                  fmtCurrency(liveExpense.amount,
                                      provider.currentGroup!.currency),
                                  style: TextStyle(
                                    fontSize: 36.sp,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.ink,
                                    fontFamily: 'Georgia',
                                  ),
                                ),
                                12.verticalSpace,
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'ISSUED BY ',
                                      style: TextStyle(
                                        fontSize: 9.sp,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.slate,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                    Text(
                                      payer?.name.toUpperCase() ?? 'UNKNOWN',
                                      style: TextStyle(
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.ink,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Bottom Section: Decorative Perforation Look
                          Row(
                            children: List.generate(
                              15,
                              (index) => Expanded(
                                child: Container(
                                  margin: EdgeInsets.symmetric(horizontal: 2.w),
                                  height: 4.h,
                                  decoration: BoxDecoration(
                                    color: AppColors.ink.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(2.r),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          12.verticalSpace,
                        ],
                      ),
                    ),

                    24.verticalSpace,

                    // Breakdown Title
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'BREAKDOWN',
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w900,
                            color: AppColors.brassSoft,
                            letterSpacing: 1.5,
                          ),
                        ),
                        Text(
                          '$totalParticipants MEMBERS',
                          style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w800,
                            color: AppColors.slate,
                          ),
                        ),
                      ],
                    ),
                    16.verticalSpace,

                    // Participant "Line Items"
                    ...splitParticipants.map((person) {
                      final isPayer = person.id == liveExpense.payerId;
                      final share = liveExpense.splitMap[person.id] ?? 0;
                      final isMe = person.linkedUserId == provider.uid;

                      return Container(
                        margin: EdgeInsets.only(bottom: 12.h),
                        padding: EdgeInsets.all(16.w),
                        decoration: BoxDecoration(
                          color: isMe
                              ? AppColors.paper
                              : AppColors.paper.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(16.r),
                          border: isMe
                              ? Border.all(color: AppColors.brass, width: 1.5)
                              : null,
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18.r,
                              backgroundColor: person.color,
                              child: Text(
                                person.name[0].toUpperCase(),
                                style: TextStyle(
                                    fontSize: 13.sp,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            16.horizontalSpace,
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isMe ? 'YOU' : person.name.toUpperCase(),
                                    style: TextStyle(
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.ink),
                                  ),
                                  if (isPayer)
                                    Padding(
                                      padding: EdgeInsets.only(top: 2.h),
                                      child: Text(
                                        'PAID THE AMOUNT',
                                        style: TextStyle(
                                          fontSize: 9.sp,
                                          color: AppColors.brass,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Text(
                              fmtCurrency(share,
                                  provider.currentGroup!.currency),
                              style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.ink),
                            ),
                          ],
                        ),
                      );
                    }),
                    40.verticalSpace,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
