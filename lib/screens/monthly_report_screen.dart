import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../data/monthly_budget_repository.dart';
import '../models/expense_category.dart';
import '../models/monthly_budget.dart';
import '../providers/split_provider.dart';
import '../services/monthly_spending_calculator.dart';
import '../theme/app_colors.dart';
import '../utils/currency_formatter.dart';

class MonthlyReportScreen extends StatefulWidget {
  const MonthlyReportScreen({super.key});

  @override
  State<MonthlyReportScreen> createState() => _MonthlyReportScreenState();
}

class _MonthlyReportScreenState extends State<MonthlyReportScreen> {
  DateTime _month = DateTime.now();
  Future<Map<String, String?>> _loadOverrides(SplitProvider provider) async {
    final uid = provider.uid;
    if (uid == null) return {};
    final entries = <String, String?>{};
    for (final group in provider.groups.where((g) => !g.isPersonal)) {
      for (final expense in group.expenses) {
        final category = await MonthlyBudgetRepository.instance.getMemberCategory(
          groupId: group.id, expenseId: expense.id, uid: uid);
        if (category != null) entries['${group.id}/${expense.id}'] = category;
      }
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SplitProvider>();
    final uid = provider.uid;
    final currency = provider.personalGroup?.currency ?? 'AED';
    final monthKey = MonthlyBudget.monthKey(_month);
    return Scaffold(
      backgroundColor: AppColors.ink,
      appBar: AppBar(
        backgroundColor: AppColors.ink,
        foregroundColor: AppColors.paper,
        title: const Text('Monthly report'),
      ),
      body: uid == null
          ? const Center(child: Text('Sign in to view reports'))
          : FutureBuilder<Map<String, String?>>(
              future: _loadOverrides(provider),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final spending = MonthlySpendingCalculator.calculate(
                  groups: provider.groups,
                  uid: uid,
                  month: _month,
                  currency: currency,
                  memberCategories: snapshot.data!,
                );
                final budgetFuture = MonthlyBudgetRepository.instance.getBudget(uid, monthKey);
                return FutureBuilder<MonthlyBudget?>(
                  future: budgetFuture,
                  builder: (context, budgetSnapshot) {
                    final budget = budgetSnapshot.data;
                    final total = spending.total;
                    final categories = spending.byCategory.entries.toList()
                      ..sort((a,b) => b.value.compareTo(a.value));
                    return ListView(
                      padding: EdgeInsets.all(18.w),
                      children: [
                        Row(children: [
                          IconButton(onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
                            icon: const Icon(Icons.chevron_left, color: AppColors.paper)),
                          Expanded(child: Center(child: Text(
                            '${_month.year}-${_month.month.toString().padLeft(2,'0')}',
                            style: TextStyle(color: AppColors.paper, fontSize: 17.sp, fontWeight: FontWeight.w800)))),
                          IconButton(onPressed: _month.year == DateTime.now().year && _month.month == DateTime.now().month
                              ? null : () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
                            icon: const Icon(Icons.chevron_right, color: AppColors.paper)),
                        ]),
                        _summaryCard('Total spending', fmtCurrency(total, currency)),
                        12.verticalSpace,
                        Row(children: [
                          Expanded(child: _summaryCard('Personal', fmtCurrency(spending.personal, currency))),
                          10.horizontalSpace,
                          Expanded(child: _summaryCard('Shared share', fmtCurrency(spending.shared, currency))),
                        ]),
                        12.verticalSpace,
                        _summaryCard('Expenses', '${spending.expenseCount}'),
                        20.verticalSpace,
                        Text('CATEGORY BREAKDOWN', style: TextStyle(color: AppColors.brassSoft,
                          fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 11.sp)),
                        10.verticalSpace,
                        if (categories.isEmpty)
                          const Text('No expenses recorded for this month.', style: TextStyle(color: AppColors.slate))
                        else
                          ...categories.map((entry) {
                            final category = ExpenseCategory.byId(entry.key);
                            final ratio = total <= 0 ? 0.0 : entry.value / total;
                            return Padding(
                              padding: EdgeInsets.only(bottom: 14.h),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  Icon(category?.icon ?? Icons.help_outline, color: AppColors.brassSoft, size: 17.r),
                                  8.horizontalSpace,
                                  Expanded(child: Text(category?.label ?? 'Uncategorized',
                                    style: const TextStyle(color: AppColors.paper))),
                                  Text(fmtCurrency(entry.value, currency),
                                    style: const TextStyle(color: AppColors.paper, fontWeight: FontWeight.w700)),
                                ]),
                                7.verticalSpace,
                                ClipRRect(borderRadius: BorderRadius.circular(8.r),
                                  child: LinearProgressIndicator(value: ratio, minHeight: 7.h,
                                    backgroundColor: Colors.white12, color: AppColors.brass)),
                              ]),
                            );
                          }),
                        20.verticalSpace,
                        Text('BUDGET VS ACTUAL', style: TextStyle(color: AppColors.brassSoft,
                          fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 11.sp)),
                        10.verticalSpace,
                        _summaryCard('Monthly budget', budget == null ? 'Not set' : fmtCurrency(budget.amount, budget.currency)),
                        if (budget != null) _summaryCard(
                          total > budget.amount ? 'Over budget' : 'Remaining',
                          fmtCurrency((budget.amount - total).abs(), currency)),
                      ],
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _summaryCard(String label, String value) => Container(
    margin: EdgeInsets.only(bottom: 8.h),
    padding: EdgeInsets.all(15.w),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: .07),
      borderRadius: BorderRadius.circular(15.r), border: Border.all(color: Colors.white12)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: AppColors.slate, fontSize: 11.sp)),
      5.verticalSpace,
      Text(value, style: TextStyle(color: AppColors.paper, fontSize: 18.sp, fontWeight: FontWeight.w800)),
    ]),
  );
}
