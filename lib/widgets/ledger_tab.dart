import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../providers/split_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'common_atoms.dart';
import 'add_member_sheet.dart';
import 'expense_form_sheet.dart';
import 'expense_tile.dart';
import 'person_chip.dart';

class LedgerTab extends StatefulWidget {
  const LedgerTab({super.key});

  @override
  State<LedgerTab> createState() => _LedgerTabState();
}

class _LedgerTabState extends State<LedgerTab> {
  final _personCtrl = TextEditingController();

  @override
  void dispose() {
    _personCtrl.dispose();
    super.dispose();
  }

  void _addPerson(SplitProvider provider) {
    provider.addPerson(_personCtrl.text);
    _personCtrl.clear();
  }

  Future<void> _confirmRemovePerson(
      BuildContext context, SplitProvider provider, int id, String name) async {
    final hasHistory = provider.expenses
        .any((e) => e.payerId == id || e.splitMap.containsKey(id));

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.paper,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Text('Remove $name?',
            style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.bold)),
        content: Text(
          hasHistory
              ? '$name has expense history in this group. They\'ll be hidden '
                  'from new expenses, but past activity and any balance '
                  'they still owe or are owed stays intact.'
              : '$name has no expenses yet, so they\'ll be removed completely.',
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
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final archived = provider.removePerson(id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(archived
            ? '$name removed from the active list — history kept.'
            : '$name removed.'),
        backgroundColor: AppColors.inkSoft,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SplitProvider>();
    final people = provider.people;
    final expenses = provider.expenses.reversed.toList();

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        children: [
          // People Section
          _panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionTitle(
                  title: 'Group Members',
                  trailing: '${people.length} members',
                ),
                12.verticalSpace,
                if (people.isEmpty)
                  const EmptyHint(
                      'No members yet. Add friends to start splitting!')
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: people
                        .map((p) => PersonChip(
                              person: p,
                              onRemove: () => _confirmRemovePerson(
                                  context, provider, p.id, p.name),
                            ))
                        .toList(),
                  ),
                16.verticalSpace,
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _personCtrl,
                        style:
                            TextStyle(color: AppColors.ink, fontSize: 13.5.sp),
                        decoration:
                            AppTheme.inputDecoration('Add name'),
                        onSubmitted: (_) => _addPerson(provider),
                      ),
                    ),
                    8.horizontalSpace,
                    ElevatedButton(
                      onPressed: () => _addPerson(provider),
                      style: AppTheme.solidButton.copyWith(
                        padding: WidgetStateProperty.all(
                            EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h)),
                      ),
                      child: const Text('Add'),
                    ),
                  ],
                ),
                8.verticalSpace,
                Center(
                  child: TextButton.icon(
                    onPressed: () => showAddRegisteredMemberSheet(context),
                    icon: Icon(Icons.person_search, size: 16.r, color: AppColors.brass),
                    label: Text(
                      'Or add from registered members',
                      style: TextStyle(
                          fontSize: 12.sp,
                          color: AppColors.brass,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),

          16.verticalSpace,

          // Activity Feed Section
          _panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionTitle(
                  title: 'Recent Activity',
                  trailing: provider.expenseCount == 0
                      ? ''
                      : '${provider.expenseCount} logged',
                ),
                12.verticalSpace,
                if (expenses.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 20.h),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.receipt_long_outlined,
                              size: 48.r, color: AppColors.slate.withValues(alpha: 0.5)),
                          8.verticalSpace,
                          const EmptyHint('No expenses yet. Tap "+" to add one.'),
                        ],
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: expenses.length,
                    separatorBuilder: (context, index) =>
                        Divider(color: AppColors.line, height: 1.h),
                    itemBuilder: (context, index) {
                      final e = expenses[index];
                      final payer = provider.personById(e.payerId);
                      final names = e.splitWith
                          .map((id) => provider.personById(id)?.name)
                          .whereType<String>()
                          .join(', ');
                      return ExpenseTile(
                        expense: e,
                        payer: payer,
                        splitNames: names,
                        onDelete: () => provider.removeExpense(e.id),
                        onEdit: e.isSettlement
                            ? null
                            : () => showExpenseFormSheet(context, existing: e),
                      );
                    },
                  ),
              ],
            ),
          ),
          80.verticalSpace,
        ],
      ),
    );
  }

  Widget _panel({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(14.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}
