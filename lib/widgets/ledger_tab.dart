import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../providers/split_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'common_atoms.dart';
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SplitProvider>();
    final people = provider.people;
    final expenses = provider.expenses;

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        children: [
          // People Section
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionTitle(
                  title: 'Group Members', 
                  trailing: '${people.length} members'
                ),
                12.verticalSpace,
                if (people.isEmpty)
                  const EmptyHint('No members yet. Add friends to start splitting!')
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: people
                        .map((p) => PersonChip(
                              person: p,
                              onRemove: () => provider.removePerson(p.id),
                            ))
                        .toList(),
                  ),
                16.verticalSpace,
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _personCtrl,
                        style: TextStyle(color: AppColors.ink, fontSize: 13.5.sp),
                        decoration: AppTheme.inputDecoration('Add name (e.g. Fatima)'),
                        onSubmitted: (_) => _addPerson(provider),
                      ),
                    ),
                    8.horizontalSpace,
                    ElevatedButton(
                      onPressed: () => _addPerson(provider),
                      style: AppTheme.solidButton.copyWith(
                        padding: WidgetStateProperty.all(EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h)),
                      ),
                      child: const Text('Add'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          16.verticalSpace,

          // Activity Feed Section
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle(title: 'Recent Activity'),
                12.verticalSpace,
                if (expenses.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 20.h),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 48.r, color: AppColors.slate.withOpacity(0.5)),
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
                    separatorBuilder: (context, index) => Divider(color: AppColors.line, height: 1.h),
                    itemBuilder: (context, index) {
                      final e = expenses.reversed.toList()[index];
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
}
