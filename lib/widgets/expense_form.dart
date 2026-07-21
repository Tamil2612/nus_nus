import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../models/person.dart';
import '../providers/split_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';

class ExpenseForm extends StatefulWidget {
  const ExpenseForm({super.key});

  @override
  State<ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<ExpenseForm> {
  final _descCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  int? _payerId;
  final Set<int> _splitSelection = {};
  bool _isEqualSplit = true;
  final Map<int, TextEditingController> _customSplitCtrls = {};

  @override
  void initState() {
    super.initState();
    _amountCtrl.addListener(_onAmountChanged);
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _amountCtrl.removeListener(_onAmountChanged);
    _amountCtrl.dispose();
    for (var ctrl in _customSplitCtrls.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _onAmountChanged() {
    setState(() {}); // Rebuild to update the sum indicator
  }

  void _syncSelectionWith(List<Person> people) {
    final ids = people.map((p) => p.id).toSet();
    _splitSelection.removeWhere((id) => !ids.contains(id));
    
    // Default: everyone in the group is part of the split if it's empty
    if (_splitSelection.isEmpty && people.isNotEmpty) {
      for (final p in people) {
        _splitSelection.add(p.id);
      }
    }

    _payerId ??= people.isNotEmpty ? people.first.id : null;
    if (_payerId != null && !ids.contains(_payerId)) {
      _payerId = people.isNotEmpty ? people.first.id : null;
    }

    // Ensure we have controllers for custom splits
    for (var id in _splitSelection) {
      if (!_customSplitCtrls.containsKey(id)) {
        final ctrl = TextEditingController();
        ctrl.addListener(_onAmountChanged);
        _customSplitCtrls[id] = ctrl;
      }
    }
  }

  double get _currentAllocatedSum {
    double sum = 0;
    for (var id in _splitSelection) {
      sum += double.tryParse(_customSplitCtrls[id]?.text ?? '') ?? 0.0;
    }
    return sum;
  }

  void _submit(SplitProvider provider) {
    Map<int, double>? customSplits;
    final totalAmount = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;

    if (!_isEqualSplit) {
      customSplits = {};
      for (var id in _splitSelection) {
        final val = double.tryParse(_customSplitCtrls[id]?.text ?? '') ?? 0.0;
        customSplits[id] = val;
      }
    }

    final error = provider.addExpense(
      desc: _descCtrl.text,
      amount: totalAmount,
      payerId: _payerId,
      splitWith: _splitSelection,
      customSplits: customSplits,
    );

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error, style: const TextStyle(color: Colors.white)), 
          backgroundColor: AppColors.rust,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    _descCtrl.clear();
    _amountCtrl.clear();
    for (var ctrl in _customSplitCtrls.values) {
      ctrl.clear();
    }
    setState(() {
      _isEqualSplit = true;
    });
    
    // Check if we are inside a bottom sheet/dialog and close it
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Expense added successfully!'),
        backgroundColor: AppColors.sage,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SplitProvider>();
    final people = provider.people;
    _syncSelectionWith(people);

    final totalAmount = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
    final allocated = _currentAllocatedSum;
    final diff = (totalAmount - allocated).abs();
    final isSettled = diff < 0.01;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _descCtrl,
          style: TextStyle(color: AppColors.ink, fontSize: 14.sp),
          decoration: AppTheme.inputDecoration(
              "What was it for? (e.g. Dinner at Zheng He's)"),
        ),
        10.verticalSpace,
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(color: AppColors.ink, fontSize: 14.sp),
                decoration: AppTheme.inputDecoration('Amount (AED)'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<int>(
                value: _payerId,
                decoration: AppTheme.inputDecoration('Paid by'),
                style: TextStyle(color: AppColors.ink, fontSize: 13.5.sp),
                dropdownColor: Colors.white,
                items: people
                    .map(
                      (p) => DropdownMenuItem(
                    value: p.id,
                    child: Text(
                      p.name,
                      style: TextStyle(fontSize: 13.sp, color: AppColors.ink),
                    ),
                  ),
                )
                    .toList(),
                onChanged: (v) => setState(() => _payerId = v),
              ),
            ),
          ],
        ),
        12.verticalSpace,
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'SPLIT BETWEEN',
              style: TextStyle(
                  fontSize: 10.5.sp,
                  letterSpacing: 1.2,
                  color: AppColors.slate,
                  fontWeight: FontWeight.w600),
            ),
            TextButton.icon(
              onPressed: () => setState(() => _isEqualSplit = !_isEqualSplit),
              icon: Icon(_isEqualSplit ? Icons.call_split : Icons.plus_one, size: 16.sp, color: AppColors.brass),
              label: Text(
                _isEqualSplit ? 'Split Unequally' : 'Split Equally',
                style: TextStyle(fontSize: 11.sp, color: AppColors.brass, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        8.verticalSpace,
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: people.map((p) {
            final on = _splitSelection.contains(p.id);
            return GestureDetector(
              onTap: () => setState(() {
                on ? _splitSelection.remove(p.id) : _splitSelection.add(p.id);
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                     EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: on ? AppColors.ink : Colors.white,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: on ? AppColors.ink : AppColors.line),
                  boxShadow: on ? [BoxShadow(color: AppColors.ink.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))] : null,
                ),
                child: Text(
                  p.name,
                  style: TextStyle(
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w600,
                    color: on ? AppColors.paper : AppColors.ink,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        if (!_isEqualSplit) ...[
          16.verticalSpace,
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: AppColors.paperDim,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Allocated: ${fmtAed(allocated)}', 
                      style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold, color: AppColors.ink)),
                    Text(isSettled ? 'Matches total!' : 'Remaining: ${fmtAed(totalAmount - allocated)}',
                      style: TextStyle(
                        fontSize: 12.sp, 
                        fontWeight: FontWeight.bold, 
                        color: isSettled ? AppColors.sage : (allocated > totalAmount ? AppColors.rust : AppColors.slate)
                      )),
                  ],
                ),
                8.verticalSpace,
                ClipRRect(
                  borderRadius: BorderRadius.circular(4.r),
                  child: LinearProgressIndicator(
                    value: totalAmount > 0 ? (allocated / totalAmount).clamp(0, 1.1) : 0,
                    backgroundColor: Colors.white,
                    color: isSettled ? AppColors.sage : (allocated > totalAmount ? AppColors.rust : AppColors.brass),
                    minHeight: 6.h,
                  ),
                ),
              ],
            ),
          ),
          12.verticalSpace,
          ..._splitSelection.map((id) {
            final person = people.firstWhere((p) => p.id == id);
            return Padding(
              padding: EdgeInsets.only(bottom: 10.h),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 12.r,
                    backgroundColor: person.color,
                    child: Text(person.name[0], style: TextStyle(color: Colors.white, fontSize: 10.sp, fontWeight: FontWeight.bold)),
                  ),
                  8.horizontalSpace,
                  Expanded(child: Text(person.name, style: TextStyle(color: AppColors.ink, fontSize: 13.sp, fontWeight: FontWeight.w500))),
                  SizedBox(
                    width: 120.w,
                    child: TextField(
                      controller: _customSplitCtrls[id],
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(fontSize: 13.sp, color: AppColors.ink),
                      textAlign: TextAlign.right,
                      decoration: AppTheme.inputDecoration('0.00').copyWith(
                        contentPadding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
        20.verticalSpace,
        SizedBox(
          width: double.infinity,
          height: 48.h,
          child: ElevatedButton(
            onPressed: () => _submit(provider),
            style: AppTheme.solidButton,
            child: Text('Add expense', style: TextStyle(fontSize: 14.sp)),
          ),
        ),
      ],
    );
  }
}
