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
  final Expense expense;

  const ExpenseDetailScreen({super.key, required this.expense});

  Future<void> _confirmDelete(BuildContext context, SplitProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.paper,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: const Text('Delete this split?',
            style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.bold)),
        content: const Text(
          'This will permanently remove this expense from the group record. '
          'This action cannot be undone.',
          style: TextStyle(color: AppColors.slate),
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      provider.removeExpense(expense.id);
      if (context.mounted) Navigator.pop(context); // Go back after delete
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SplitProvider>();
    final payer = provider.personById(expense.payerId);
    final splitParticipants = expense.splitWith
        .map((id) => provider.personById(id))
        .where((p) => p != null)
        .toList()
        .cast<Person>();
    
    final isOwner = provider.isCurrentGroupOwner;
    final totalParticipants = splitParticipants.length;
    
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
                        if (isOwner && !expense.isSettlement) ...[
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, color: AppColors.brassSoft),
                            onPressed: () => showExpenseFormSheet(context, existing: expense),
                            tooltip: 'Edit',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: AppColors.rust),
                            onPressed: () => _confirmDelete(context, provider),
                            tooltip: 'Delete',
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
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  children: [
                    20.verticalSpace,
                    Center(
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 35.r,
                            backgroundColor: payer?.color ?? AppColors.brass,
                            child: Text(
                              payer != null ? payer.name[0].toUpperCase() : '?',
                              style: TextStyle(fontSize: 28.sp, color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                          16.verticalSpace,
                          Text(
                            payer?.name ?? 'Someone',
                            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: AppColors.brassSoft),
                          ),
                          4.verticalSpace,
                          Text(
                            expense.desc.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.w900, color: AppColors.paper, letterSpacing: 0.5),
                          ),
                          16.verticalSpace,
                          Text(
                            fmtAed(expense.amount),
                            style: TextStyle(fontSize: 32.sp, fontWeight: FontWeight.w900, color: AppColors.paper),
                          ),
                        ],
                      ),
                    ),
                    32.verticalSpace,
                    const Divider(color: Colors.white12),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$totalParticipants participants',
                            style: TextStyle(fontSize: 14.sp, color: AppColors.slate, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            'TOTAL SPLIT',
                            style: TextStyle(fontSize: 11.sp, color: AppColors.slate, fontWeight: FontWeight.w900, letterSpacing: 1.1),
                          ),
                        ],
                      ),
                    ),
                    
                    ...splitParticipants.map((person) {
                      final isPayer = person.id == expense.payerId;
                      final share = expense.splitMap[person.id] ?? 0;
                      
                      return Container(
                        margin: EdgeInsets.only(bottom: 12.h),
                        padding: EdgeInsets.all(14.w),
                        decoration: BoxDecoration(
                          color: AppColors.paper,
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20.r,
                              backgroundColor: person.color,
                              child: Text(
                                person.name[0].toUpperCase(),
                                style: TextStyle(fontSize: 14.sp, color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                            16.horizontalSpace,
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    person.name,
                                    style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700, color: AppColors.ink),
                                  ),
                                  if (isPayer)
                                    Text(
                                      'Sent this request',
                                      style: TextStyle(fontSize: 12.sp, color: AppColors.brass, fontWeight: FontWeight.w600),
                                    ),
                                ],
                              ),
                            ),
                            Text(
                              fmtAed(share),
                              style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w900, color: AppColors.ink),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    20.verticalSpace,
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
