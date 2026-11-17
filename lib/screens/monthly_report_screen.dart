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
    final groups = provider.groups.where((g) => !g.isPersonal);
    final requests = <Future<MapEntry<String, String?>>>[];
    for (final group in groups) {
      for (final expense in group.expenses.where((e) =>
          e.createdAt != null && e.createdAt!.year == _month.year &&
          e.createdAt!.month == _month.month)) {
        requests.add(() async {
          try {
            final category = await MonthlyBudgetRepository.instance.getMemberCategory(
              groupId: group.id, expenseId: expense.id, uid: uid);
            return MapEntry('${group.id}/${expense.id}', category);
          } catch (_) {
            return MapEntry('${group.id}/${expense.id}', null);
          }
        }());
      }
    }
    final loaded = await Future.wait(requests);
    return {for (final entry in loaded) if (entry.value != null) entry.key: entry.value};
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
                if (snapshot.hasError) {
                  return const Center(child: Text('Could not load category details. Please try again.', style: TextStyle(color: AppColors.paper)));
                }
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

                final weekly = List<double>.filled(5, 0);
                for (final group in provider.groups) {
                  if (group.currency.toUpperCase() != currency.toUpperCase()) continue;
                  final mine = group.members.where((p) => p.linkedUserId == uid).toList();
                  final myId = mine.isNotEmpty ? mine.first.id : (group.isPersonal ? 1 : null);
                  if (myId == null) continue;
                  for (final expense in group.expenses) {
                    final date = expense.createdAt;
                    if (expense.isSettlement || date == null ||
                        date.year != _month.year || date.month != _month.month) continue;
                    final amount = group.isPersonal ? expense.amount : (expense.splitMap[myId] ?? 0);
                    final week = ((date.day - 1) ~/ 7).clamp(0, 4).toInt();
                    weekly[week] += amount;
                  }
                }
                final maxWeek = weekly.fold<double>(0, (a, b) => a > b ? a : b);
                    final categories = spending.byCategory.entries.toList()
                      ..sort((a,b) => b.value.compareTo(a.value));
                    final averageDaily = total / DateTime(_month.year, _month.month + 1, 0).day;
                    final topCategory = categories.isEmpty ? null : categories.first;
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
                        Row(children: [
                          Expanded(child: _summaryCard('Expenses', '${spending.expenseCount}')),
                          10.horizontalSpace,
                          Expanded(child: _summaryCard('Daily average', fmtCurrency(averageDaily, currency))),
                        ]),
                        if (topCategory != null)
                          _summaryCard('Highest category', ExpenseCategory.byId(topCategory.key)?.label ?? 'Uncategorized'),

                        20.verticalSpace,
                        Text('WEEKLY SPENDING', style: TextStyle(color: AppColors.brassSoft,
                          fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 11.sp)),
                        12.verticalSpace,
                        Container(
                          padding: EdgeInsets.all(14.w),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: .07),
                            borderRadius: BorderRadius.circular(15.r)),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: List.generate(5, (index) => Expanded(
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4.w),
                                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                                  Text(fmtCurrency(weekly[index], currency),
                                    style: TextStyle(color: AppColors.slate, fontSize: 8.sp)),
                                  6.verticalSpace,
                                  Container(height: maxWeek == 0 ? 4.h : (90 * weekly[index] / maxWeek).clamp(4, 90).h,
                                    decoration: BoxDecoration(color: AppColors.brass,
                                      borderRadius: BorderRadius.circular(6.r))),
                                  6.verticalSpace,
                                  Text('W${index + 1}', style: TextStyle(color: AppColors.paper, fontSize: 9.sp)),
                                ]),
                              ),
                            )),
                          ),
                        ),
                        if (provider.groups.any((g) => g.currency.toUpperCase() != currency.toUpperCase()))
                          Padding(
                            padding: EdgeInsets.only(top: 12.h),
                            child: Text('Groups using a different currency are excluded from this report. Currency conversion is not enabled yet.',
                              style: TextStyle(color: AppColors.slate, fontSize: 10.sp)),
                          ),
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

                        if (budget != null) ...[
                          12.verticalSpace,
                          Text('CATEGORY BUDGET VS ACTUAL', style: TextStyle(
                            color: AppColors.brassSoft, fontWeight: FontWeight.w900,
                            letterSpacing: 1.1, fontSize: 11.sp)),
                          10.verticalSpace,
                          ...ExpenseCategory.all.where((category) =>
                            (budget.categoryBudgets[category.id] ?? 0) > 0).map((category) {
                            final allocation = budget.categoryBudgets[category.id] ?? 0;
                            final actual = spending.byCategory[category.id] ?? 0;
                            final over = actual > allocation;
                            final ratio = allocation > 0 ? (actual / allocation).clamp(0.0, 1.0) : 0.0;
                            return Padding(
                              padding: EdgeInsets.only(bottom: 12.h),
                              child: Column(children: [
                                Row(children: [
                                  Expanded(child: Text(category.label,
                                    style: const TextStyle(color: AppColors.paper))),
                                  Text('${fmtCurrency(actual, currency)} / ${fmtCurrency(allocation, currency)}',
                                    style: TextStyle(color: over ? AppColors.rust : AppColors.paper,
                                      fontSize: 10.sp, fontWeight: FontWeight.w700)),
                                ]),
                                6.verticalSpace,
                                ClipRRect(borderRadius: BorderRadius.circular(8.r),
                                  child: LinearProgressIndicator(value: ratio, minHeight: 6.h,
                                    backgroundColor: Colors.white12,
                                    color: over ? AppColors.rust : AppColors.brass)),
                              ]),
                            );
                          }),
                        ],
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
