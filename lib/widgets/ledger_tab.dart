import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../providers/split_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'common_atoms.dart';
import 'expense_form.dart';
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
      child: Container(
        padding:  EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle(title: 'People', trailing: '${people.length} added'),
            10.verticalSpace,
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: people.isEmpty
                  ? [const EmptyHint('No one added yet.')]
                  : people
                      .map((p) => PersonChip(
                            person: p,
                            onRemove: () => provider.removePerson(p.id),
                          ))
                      .toList(),
            ),
            12.verticalSpace,
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _personCtrl,
                    style: TextStyle(color: AppColors.ink, fontSize: 13.5.sp),
                    decoration:
                        AppTheme.inputDecoration('Add a person (e.g. Fatima)'),
                    onSubmitted: (_) => _addPerson(provider),
                  ),
                ),
                8.horizontalSpace,
                ElevatedButton(
                  onPressed: () => _addPerson(provider),
                  style: AppTheme.solidButton,
                  child: const Text('Add'),
                ),
              ],
            ),
             Padding(
              padding: EdgeInsets.symmetric(vertical: 16.h),
              child: Divider(color: AppColors.line, height: 1.h),
            ),
            const SectionTitle(title: 'New expense'),
            10.verticalSpace,
            const ExpenseForm(),
             Padding(
              padding: EdgeInsets.symmetric(vertical: 16.h),
              child: Divider(color: AppColors.line, height: 1.h),
            ),
            const SectionTitle(title: 'History'),
            4.verticalSpace,
            if (expenses.isEmpty)
              const EmptyHint('No expenses yet — add one above.')
            else
              ...expenses.reversed.map((e) {
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
              }),
          ],
        ),
      ),
    );
  }
}
