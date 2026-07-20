import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../models/person.dart';
import '../providers/split_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

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

  @override
  void dispose() {
    _descCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  void _syncSelectionWith(List<Person> people) {
    final ids = people.map((p) => p.id).toSet();
    _splitSelection.removeWhere((id) => !ids.contains(id));
    for (final p in people) {
      _splitSelection.add(p.id);
    }
    _payerId ??= people.isNotEmpty ? people.first.id : null;
    if (_payerId != null && !ids.contains(_payerId)) {
      _payerId = people.isNotEmpty ? people.first.id : null;
    }
  }

  void _submit(SplitProvider provider) {
    final error = provider.addExpense(
      desc: _descCtrl.text,
      amount: double.tryParse(_amountCtrl.text.trim()),
      payerId: _payerId,
      splitWith: _splitSelection,
    );
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.inkSoft),
      );
      return;
    }
    _descCtrl.clear();
    _amountCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SplitProvider>();
    final people = provider.people;
    _syncSelectionWith(people);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _descCtrl,
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
                decoration: AppTheme.inputDecoration('Amount (AED)'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: _payerId,
                decoration: AppTheme.inputDecoration('Paid by'),
                style: TextStyle(color: AppColors.ink, fontSize: 13.5.sp),
                dropdownColor: AppColors.paper,
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
        Text(
          'SPLIT BETWEEN',
          style: TextStyle(
              fontSize: 10.5.sp,
              letterSpacing: 1.2,
              color: AppColors.slate,
              fontWeight: FontWeight.w600),
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
              child: Container(
                padding:
                     EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: on ? AppColors.ink : Colors.white,
                  borderRadius: BorderRadius.circular(999.r),
                  border: Border.all(color: AppColors.line),
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
        14.verticalSpace,
        ElevatedButton(
          onPressed: () => _submit(provider),
          style: AppTheme.solidButton,
          child: const Text('Add expense'),
        ),
      ],
    );
  }
}
