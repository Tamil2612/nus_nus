import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../data/monthly_budget_repository.dart';
import '../models/expense_category.dart';
import '../models/monthly_budget.dart';
import '../theme/app_colors.dart';

class BudgetSetupScreen extends StatefulWidget {
  final String uid;
  final String currency;
  final MonthlyBudget? initialBudget;

  const BudgetSetupScreen({
    super.key,
    required this.uid,
    required this.currency,
    this.initialBudget,
  });

  @override
  State<BudgetSetupScreen> createState() => _BudgetSetupScreenState();
}

class _BudgetSetupScreenState extends State<BudgetSetupScreen> {
  late final TextEditingController _total;
  late final Map<String, TextEditingController> _allocations;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _total = TextEditingController(
      text: widget.initialBudget?.amount.toStringAsFixed(2) ?? '',
    );
    _allocations = {
      for (final category in ExpenseCategory.all)
        category.id: TextEditingController(
          text: widget.initialBudget?.categoryBudgets[category.id]
                  ?.toStringAsFixed(2) ?? '',
        ),
    };
  }

  @override
  void dispose() {
    _total.dispose();
    for (final controller in _allocations.values) {
      controller.dispose();
    }
    super.dispose();
  }

  double _read(TextEditingController controller) =>
      double.tryParse(controller.text.trim()) ?? 0;

  int get _allocatedCents => _allocations.values.fold<int>(
    0, (sum, controller) => sum + (_read(controller) * 100).round(),
  );

  int get _totalCents => (_read(_total) * 100).round();

  void _distributeEqually() {
    final total = _totalCents;
    if (total <= 0) {
      setState(() => _error = 'Enter the total monthly budget first.');
      return;
    }
    final count = ExpenseCategory.all.length;
    final each = total ~/ count;
    var remainder = total - each * count;
    setState(() {
      for (final category in ExpenseCategory.all) {
        final cents = each + (remainder-- > 0 ? 1 : 0);
        _allocations[category.id]!.text = (cents / 100).toStringAsFixed(2);
      }
      _error = null;
    });
  }

  Future<void> _save() async {
    final total = double.tryParse(_total.text.trim());
    if (total == null || !total.isFinite || total <= 0) {
      setState(() => _error = 'Enter a valid total monthly budget.');
      return;
    }
    for (final category in ExpenseCategory.all) {
      final raw = _allocations[category.id]!.text.trim();
      final amount = raw.isEmpty ? 0 : double.tryParse(raw);
      if (amount == null || !amount.isFinite || amount < 0) {
        setState(() => _error = 'Enter a valid amount for ${category.label}.');
        return;
      }
    }
    if (_allocatedCents != _totalCents) {
      setState(() => _error =
        'Your category allocations must total exactly ${widget.currency} ${total.toStringAsFixed(2)}.');
      return;
    }
    final values = <String, double>{
      for (final category in ExpenseCategory.all)
        if (_read(_allocations[category.id]!) > 0)
          category.id: (_read(_allocations[category.id]!) * 100).round() / 100,
    };
    setState(() { _saving = true; _error = null; });
    try {
      await MonthlyBudgetRepository.instance.saveBudget(
        uid: widget.uid,
        monthId: MonthlyBudget.monthKey(DateTime.now()),
        amount: total,
        currency: widget.currency,
        categoryBudgets: values,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      final message = error.toString();
      setState(() {
        _error = message.contains('permission-denied') ||
                message.contains('PERMISSION_DENIED')
            ? 'Firestore denied this save. Check that the latest Firestore security rules have been deployed for users/{uid}/budgets/{monthId}.'
            : 'Could not save your budget: $message';
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _totalCents;
    final allocated = _allocatedCents;
    final difference = total - allocated;
    return Scaffold(
      backgroundColor: AppColors.ink,
      appBar: AppBar(
        backgroundColor: AppColors.ink,
        foregroundColor: AppColors.paper,
        title: Text(widget.initialBudget == null ? 'Create monthly budget' : 'Edit monthly budget'),
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(18.w, 12.h, 18.w, 28.h),
          children: [
            Container(
              padding: EdgeInsets.all(18.w),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .06),
                borderRadius: BorderRadius.circular(18.r),
                border: Border.all(color: AppColors.brass.withValues(alpha: .35)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('TOTAL MONTHLY BUDGET', style: TextStyle(
                  color: AppColors.brassSoft, fontSize: 10.sp,
                  fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                10.verticalSpace,
                TextField(
                  controller: _total,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: AppColors.paper, fontSize: 25.sp,
                    fontWeight: FontWeight.w800),
                  decoration: InputDecoration(
                    prefixText: '${widget.currency} ',
                    prefixStyle: TextStyle(color: AppColors.brassSoft, fontSize: 18.sp),
                    hintText: '0.00',
                    hintStyle: TextStyle(color: AppColors.slate),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: AppColors.brass.withValues(alpha: .5))),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: AppColors.brass)),
                  ),
                  onChanged: (_) => setState(() => _error = null),
                ),
                8.verticalSpace,
                Text('Divide this amount among the categories below.',
                  style: TextStyle(color: AppColors.slate, fontSize: 11.sp)),
              ]),
            ),
            22.verticalSpace,
            Row(children: [
              Expanded(child: Text('CATEGORY ALLOCATIONS', style: TextStyle(
                color: AppColors.brassSoft, fontSize: 11.sp,
                fontWeight: FontWeight.w900, letterSpacing: 1.1))),
              TextButton(
                onPressed: _distributeEqually,
                child: const Text('Split equally'),
              ),
            ]),
            Text('Leave a category at 0 if you do not need a separate limit.',
              style: TextStyle(color: AppColors.slate, fontSize: 11.sp)),
            10.verticalSpace,
            ...ExpenseCategory.all.map((category) => Container(
              margin: EdgeInsets.only(bottom: 9.h),
              padding: EdgeInsets.symmetric(horizontal: 13.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .055),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: Colors.white.withValues(alpha: .08)),
              ),
              child: Row(children: [
                Container(
                  width: 37.r, height: 37.r,
                  decoration: BoxDecoration(
                    color: AppColors.brass.withValues(alpha: .13),
                    borderRadius: BorderRadius.circular(11.r)),
                  child: Icon(category.icon, color: AppColors.brassSoft, size: 19.r),
                ),
                12.horizontalSpace,
                Expanded(child: Text(category.label, style: TextStyle(
                  color: AppColors.paper, fontSize: 13.sp,
                  fontWeight: FontWeight.w700))),
                SizedBox(
                  width: 125.w,
                  child: TextField(
                    controller: _allocations[category.id],
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.end,
                    style: TextStyle(color: AppColors.paper, fontWeight: FontWeight.w700,
                      fontSize: 13.sp),
                    decoration: InputDecoration(
                      isDense: true, hintText: '0.00',
                      suffixText: widget.currency,
                      suffixStyle: TextStyle(color: AppColors.slate, fontSize: 9.sp),
                      enabledBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white24)),
                      focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: AppColors.brass)),
                    ),
                    onChanged: (_) => setState(() => _error = null),
                  ),
                ),
              ]),
            )),
            8.verticalSpace,
            Container(
              padding: EdgeInsets.all(15.w),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .07),
                borderRadius: BorderRadius.circular(15.r)),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Allocated', style: TextStyle(color: AppColors.slate, fontSize: 12.sp)),
                  Text('${(allocated / 100).toStringAsFixed(2)} / ${(total / 100).toStringAsFixed(2)} ${widget.currency}',
                    style: TextStyle(color: AppColors.paper, fontWeight: FontWeight.w800,
                      fontSize: 13.sp)),
                ]),
                8.verticalSpace,
                ClipRRect(borderRadius: BorderRadius.circular(8.r),
                  child: LinearProgressIndicator(
                    value: total <= 0 ? 0 : (allocated / total / 100).clamp(0.0, 1.0),
                    minHeight: 7.h, backgroundColor: Colors.white12,
                    color: difference == 0 ? AppColors.sage : AppColors.brass)),
                7.verticalSpace,
                Text(difference == 0 ? 'All of your budget is allocated'
                  : difference > 0
                    ? '${(difference / 100).toStringAsFixed(2)} ${widget.currency} left to allocate'
                    : '${(-difference / 100).toStringAsFixed(2)} ${widget.currency} over allocated',
                  style: TextStyle(
                    color: difference == 0 ? AppColors.sage : AppColors.rust,
                    fontSize: 11.sp, fontWeight: FontWeight.w700)),
              ]),
            ),
            if (_error != null) ...[
              12.verticalSpace,
              Text(_error!, style: TextStyle(color: AppColors.rust, fontSize: 12.sp)),
            ],
            18.verticalSpace,
            SizedBox(
              height: 52.h,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                  ? SizedBox(width: 18.r, height: 18.r,
                      child: const CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Saving...' : 'Save monthly budget'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brass,
                  foregroundColor: AppColors.ink,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
