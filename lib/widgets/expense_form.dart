import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../models/expense.dart';
import '../models/expense_category.dart';
import '../models/person.dart';
import '../providers/split_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';

class ExpenseForm extends StatefulWidget {
  final Expense? existingExpense;

  const ExpenseForm({super.key, this.existingExpense});

  bool get isEditing => existingExpense != null;

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
  bool _prefilled = false;
  String? _formError;
  String? _categoryId;

  @override
  void initState() {
    super.initState();
    _amountCtrl.addListener(_onAmountChanged);
    final existing = widget.existingExpense;
    if (existing != null) {
      _descCtrl.text = existing.desc;
      _amountCtrl.text = existing.amount.toStringAsFixed(2);
      _payerId = existing.payerId;
      _categoryId = existing.categoryId;
      _splitSelection.addAll(existing.splitMap.keys);
      final shares = existing.splitMap.values.toList();
      final allEqual = shares.isNotEmpty &&
          shares.every((s) => (s - shares.first).abs() < 0.02);
      _isEqualSplit = allEqual;
      if (!allEqual) {
        existing.splitMap.forEach((id, share) {
          final ctrl = TextEditingController(text: share.toStringAsFixed(2));
          ctrl.addListener(_onAmountChanged);
          _customSplitCtrls[id] = ctrl;
        });
      }
    }
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _amountCtrl.removeListener(_onAmountChanged);
    _amountCtrl.dispose();
    for (final ctrl in _customSplitCtrls.values) {
      ctrl.removeListener(_onAmountChanged);
      ctrl.dispose();
    }
    super.dispose();
  }

  void _onAmountChanged() {
    if (!mounted) return;
    setState(() => _formError = null);
  }

  void _syncSelectionWith(List<Person> people, SplitProvider provider) {
    final ids = people.map((p) => p.id).toSet();
    if (!widget.isEditing || _prefilled) {
      _splitSelection.removeWhere((id) => !ids.contains(id));
      if (_splitSelection.isEmpty && people.isNotEmpty && !widget.isEditing) {
        _splitSelection.addAll(ids);
      }
    }
    _prefilled = true;

    if (!widget.isEditing) {
      _payerId = provider.personByUid(provider.uid)?.id;
    }

    for (final id in _splitSelection) {
      if (!_customSplitCtrls.containsKey(id)) {
        final ctrl = TextEditingController();
        ctrl.addListener(_onAmountChanged);
        _customSplitCtrls[id] = ctrl;
      }
    }
  }

  double get _currentAllocatedSum {
    var sum = 0.0;
    for (final id in _splitSelection) {
      sum += double.tryParse(_customSplitCtrls[id]?.text ?? '') ?? 0.0;
    }
    return sum;
  }

  void _submit(SplitProvider provider) {
    Map<int, double>? customSplits;
    final totalAmount = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;

    if (!_isEqualSplit && provider.currentGroup?.isPersonal != true) {
      customSplits = {
        for (final id in _splitSelection)
          id: double.tryParse(_customSplitCtrls[id]?.text ?? '') ?? 0.0,
      };
    }

    final error = widget.isEditing
        ? provider.editExpense(
            id: widget.existingExpense!.id,
            desc: _descCtrl.text,
            amount: totalAmount,
            payerId: _payerId,
            splitWith: _splitSelection,
            customSplits: customSplits,
            categoryId: _categoryId,
            clearCategory: _categoryId == null && widget.existingExpense!.categoryId != null,
          )
        : provider.addExpense(
            desc: _descCtrl.text,
            amount: totalAmount,
            payerId: _payerId,
            splitWith: _splitSelection,
            customSplits: customSplits,
            categoryId: _categoryId,
          );

    if (error != null) {
      setState(() => _formError = error);
      return;
    }

    setState(() => _formError = null);
    if (!widget.isEditing) {
      _descCtrl.clear();
      _amountCtrl.clear();
      for (final ctrl in _customSplitCtrls.values) {
        ctrl.clear();
      }
      setState(() => _isEqualSplit = true);
    }

    if (Navigator.canPop(context)) Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(widget.isEditing
            ? 'Expense updated.'
            : 'Expense added successfully!'),
        backgroundColor: AppColors.sage,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Widget _sectionLabel(String title, {String? trailing}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: AppColors.slate,
              fontSize: 10.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.15,
            ),
          ),
          const Spacer(),
          if (trailing != null)
            Text(trailing,
                style: TextStyle(color: AppColors.slate, fontSize: 10.5.sp)),
        ],
      ),
    );
  }

  Widget _panel({required Widget child, EdgeInsets? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? EdgeInsets.all(13.w),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .72),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.line),
      ),
      child: child,
    );
  }

  Widget _buildValidationError() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: AppColors.rust.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.rust.withValues(alpha: .25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: AppColors.rust, size: 17.r),
          8.horizontalSpace,
          Expanded(
            child: Text(_formError!,
                style: TextStyle(color: AppColors.rust, fontSize: 12.sp)),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Description'),
        TextField(
          controller: _descCtrl,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
          style: TextStyle(color: AppColors.ink, fontSize: 14.sp),
          decoration: AppTheme.inputDecoration(
            'e.g. Dinner, groceries, taxi',
            icon: Icons.edit_note_rounded,
          ),
        ),
      ],
    );
  }

  Widget _buildAmountField(String currency, {bool prominent = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Amount'),
        TextField(
          controller: _amountCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.next,
          style: TextStyle(
            color: AppColors.ink,
            fontSize: prominent ? 23.sp : 16.sp,
            fontWeight: FontWeight.w800,
          ),
          decoration: AppTheme.inputDecoration('0.00',
            icon: Icons.payments_outlined).copyWith(
            suffixText: currency,
            suffixStyle: TextStyle(
              color: AppColors.slate,
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 14.w,
              vertical: prominent ? 17.h : 14.h,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPayer(String payerName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Paid by'),
        _panel(
          padding: EdgeInsets.symmetric(horizontal: 13.w, vertical: 12.h),
          child: Row(
            children: [
              Container(
                width: 34.r,
                height: 34.r,
                decoration: BoxDecoration(
                  color: AppColors.brass.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(11.r),
                ),
                child: Icon(Icons.person_rounded,
                    color: AppColors.ink, size: 18.r),
              ),
              10.horizontalSpace,
              Expanded(
                child: Text(payerName,
                    style: TextStyle(
                      color: AppColors.ink,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                    )),
              ),
              Icon(Icons.lock_outline_rounded,
                  size: 15.r, color: AppColors.slate),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSplitMode() {
    return Container(
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: AppColors.paperDim,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          _modeButton('Equally', true, Icons.call_split_rounded),
          _modeButton('Unequally', false, Icons.tune_rounded),
        ],
      ),
    );
  }

  Widget _modeButton(String label, bool equal, IconData icon) {
    final selected = _isEqualSplit == equal;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _isEqualSplit = equal;
          _formError = null;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(vertical: 10.h),
          decoration: BoxDecoration(
            color: selected ? AppColors.ink : Colors.transparent,
            borderRadius: BorderRadius.circular(9.r),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.ink.withValues(alpha: .12),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 15.r,
                  color: selected ? AppColors.paper : AppColors.slate),
              6.horizontalSpace,
              Text(label,
                  style: TextStyle(
                    color: selected ? AppColors.paper : AppColors.slate,
                    fontSize: 11.5.sp,
                    fontWeight: FontWeight.w700,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMemberChip(Person person, bool selected) {
    return GestureDetector(
      onTap: () => setState(() {
        if (selected) {
          _splitSelection.remove(person.id);
        } else {
          _splitSelection.add(person.id);
        }
        _formError = null;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: EdgeInsets.symmetric(horizontal: 11.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: selected ? AppColors.ink : AppColors.line,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              size: 14.r,
              color: selected ? AppColors.brassSoft : AppColors.slate,
            ),
            6.horizontalSpace,
            Text(
              person.name,
              style: TextStyle(
                color: selected ? AppColors.paper : AppColors.ink,
                fontSize: 11.5.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllocation(double allocated, double totalAmount,
      String currency, bool isSettled) {
    final remaining = totalAmount - allocated;
    final over = remaining < -0.009;
    final status = isSettled
        ? 'Amounts match'
        : over
            ? 'Over by ${fmtCurrency(remaining.abs(), currency)}'
            : 'Remaining ${fmtCurrency(remaining, currency)}';
    return _panel(
      padding: EdgeInsets.all(13.w),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Split allocation',
                    style: TextStyle(
                      color: AppColors.ink,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w800,
                    )),
              ),
              Text(status,
                  style: TextStyle(
                    color: isSettled
                        ? AppColors.sage
                        : over
                            ? AppColors.rust
                            : AppColors.slate,
                    fontSize: 10.5.sp,
                    fontWeight: FontWeight.w700,
                  )),
            ],
          ),
          10.verticalSpace,
          ClipRRect(
            borderRadius: BorderRadius.circular(20.r),
            child: LinearProgressIndicator(
              value: totalAmount > 0
                  ? (allocated / totalAmount).clamp(0.0, 1.0)
                  : 0,
              backgroundColor: AppColors.paperDim,
              color: isSettled
                  ? AppColors.sage
                  : over
                      ? AppColors.rust
                      : AppColors.brass,
              minHeight: 7.h,
            ),
          ),
          8.verticalSpace,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Allocated: ${fmtCurrency(allocated, currency)}',
                  style: TextStyle(
                      color: AppColors.slate, fontSize: 10.5.sp)),
              Text('Total: ${fmtCurrency(totalAmount, currency)}',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 10.5.sp,
                    fontWeight: FontWeight.w700,
                  )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomShareRow(Person person, int id) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 5.h),
      child: Row(
        children: [
          CircleAvatar(
            radius: 15.r,
            backgroundColor: person.color,
            child: Text(
              person.name.isNotEmpty ? person.name[0].toUpperCase() : '?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          9.horizontalSpace,
          Expanded(
            child: Text(person.name,
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                )),
          ),
          SizedBox(
            width: 112.w,
            child: TextField(
              controller: _customSplitCtrls[id],
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.right,
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
              ),
              decoration: AppTheme.inputDecoration('0.00').copyWith(
                contentPadding: EdgeInsets.symmetric(
                    horizontal: 10.w, vertical: 9.h),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildCategorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Category', trailing: 'Optional'),
        Wrap(
          spacing: 8.w,
          runSpacing: 8.h,
          children: [
            _categoryChip(null, 'None', Icons.remove_circle_outline_rounded),
            ...ExpenseCategory.all.map((category) =>
                _categoryChip(category.id, category.label, category.icon)),
          ],
        ),
      ],
    );
  }

  Widget _categoryChip(String? id, String label, IconData icon) {
    final selected = _categoryId == id;
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => setState(() => _categoryId = id),
      avatar: Icon(icon, size: 15.r,
          color: selected ? AppColors.paper : AppColors.slate),
      label: Text(label),
      labelStyle: TextStyle(
        color: selected ? AppColors.paper : AppColors.ink,
        fontSize: 10.5.sp,
        fontWeight: FontWeight.w700,
      ),
      selectedColor: AppColors.ink,
      backgroundColor: Colors.white,
      side: BorderSide(color: selected ? AppColors.ink : AppColors.line),
      showCheckmark: false,
      padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SplitProvider>();
    final people = provider.people;
    _syncSelectionWith(people, provider);

    final currency = provider.currentGroup?.currency ?? 'AED';
    final totalAmount = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
    final allocated = _currentAllocatedSum;
    final isSettled = (totalAmount - allocated).abs() < 0.01;
    final isPersonal = provider.currentGroup?.isPersonal == true;
    final payerName =
        provider.personById(_payerId ?? -1)?.name ?? 'You';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDescriptionField(),
              15.verticalSpace,
              _buildAmountField(currency, prominent: true),
              14.verticalSpace,
              _buildCategorySelector(),
            ],
          ),
        ),
        if (isPersonal) ...[
          12.verticalSpace,
          _panel(
            child: Row(
              children: [
                Icon(Icons.lock_outline_rounded,
                    color: AppColors.slate, size: 17.r),
                9.horizontalSpace,
                Expanded(
                  child: Text(
                    'Saved to your personal ledger only',
                    style: TextStyle(
                      color: AppColors.slate,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          16.verticalSpace,
          _buildPayer(payerName),
          16.verticalSpace,
          _sectionLabel('Split between',
              trailing: '${_splitSelection.length} selected'),
          _panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSplitMode(),
                13.verticalSpace,
                Wrap(
                  spacing: 7.w,
                  runSpacing: 8.h,
                  children: people
                      .map((person) => _buildMemberChip(
                          person, _splitSelection.contains(person.id)))
                      .toList(),
                ),
                if (people.isEmpty)
                  Text('Add people to this group to split expenses.',
                      style: TextStyle(
                          color: AppColors.slate, fontSize: 11.sp)),
              ],
            ),
          ),
          if (!_isEqualSplit) ...[
            14.verticalSpace,
            _buildAllocation(allocated, totalAmount, currency, isSettled),
            8.verticalSpace,
            _panel(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('Each person pays',
                            style: TextStyle(
                              color: AppColors.ink,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w800,
                            )),
                      ),
                      Text(currency,
                          style: TextStyle(
                              color: AppColors.slate, fontSize: 10.sp)),
                    ],
                  ),
                  8.verticalSpace,
                  ..._splitSelection.map((id) {
                    final person = people.firstWhere(
                      (p) => p.id == id,
                      orElse: () => provider.personById(id) ??
                          Person(id: id, name: '?', color: AppColors.slate),
                    );
                    return _buildCustomShareRow(person, id);
                  }),
                ],
              ),
            ),
          ],
        ],
        if (_formError != null) ...[
          14.verticalSpace,
          _buildValidationError(),
        ],
        18.verticalSpace,
        SizedBox(
          width: double.infinity,
          height: 52.h,
          child: ElevatedButton.icon(
            onPressed: () => _submit(provider),
            style: AppTheme.solidButton.copyWith(
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.r),
                ),
              ),
            ),
            icon: Icon(
              widget.isEditing
                  ? Icons.check_rounded
                  : Icons.add_rounded,
              size: 18.r,
            ),
            label: Text(
              widget.isEditing ? 'Save changes' : 'Add expense',
              style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w800),
            ),
          ),
        ),
        4.verticalSpace,
      ],
    );
  }
}
