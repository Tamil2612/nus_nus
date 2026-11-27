import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../models/expense.dart';
import '../models/expense_category.dart';
import '../data/monthly_budget_repository.dart';
import '../models/person.dart';
import '../providers/split_provider.dart';
import '../theme/app_colors.dart';
import '../utils/currency_formatter.dart';
import '../widgets/app_dialog.dart';
import '../widgets/expense_form_sheet.dart';

class MemberExpenseCategorySelector extends StatefulWidget {
  final String groupId;
  final String expenseId;
  final String uid;
  final String? originalCategoryId;
  const MemberExpenseCategorySelector({super.key, required this.groupId, required this.expenseId, required this.uid, required this.originalCategoryId});

  @override
  State<MemberExpenseCategorySelector> createState() => _MemberExpenseCategorySelectorState();
}

class _MemberExpenseCategorySelectorState extends State<MemberExpenseCategorySelector> {
  String? _selected;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.originalCategoryId;
    _load();
  }

  Future<void> _load() async {
    try {
      final value = await MonthlyBudgetRepository.instance.getMemberCategory(groupId: widget.groupId, expenseId: widget.expenseId, uid: widget.uid);
      if (!mounted) return;
      setState(() => _selected = value ?? widget.originalCategoryId);
    } catch (_) {
      // Keep original category as a usable fallback.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _tile({required String label, required IconData icon, required bool selected, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(14.r),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: selected ? AppColors.brass.withValues(alpha: 0.16) : AppColors.paperDim.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: selected ? AppColors.brass : AppColors.ink.withValues(alpha: 0.08), width: selected ? 1.6 : 1),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: selected ? AppColors.brass : AppColors.ink, size: 24.r),
          7.verticalSpace,
          Text(label, textAlign: TextAlign.center, style: TextStyle(color: AppColors.ink, fontSize: 10.sp, fontWeight: FontWeight.w800)),
          if (selected) ...[3.verticalSpace, Icon(Icons.check_circle_rounded, color: AppColors.brass, size: 14.r)],
        ]),
      ),
    );
  }

  Future<void> _choose() async {
    if (_saving || _loading) return;
    final messenger = ScaffoldMessenger.of(context);
    final picked = await showDialog<String>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: AppColors.paper,
        insetPadding: EdgeInsets.symmetric(horizontal: 24.w),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
        child: Padding(
          padding: EdgeInsets.all(20.w),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Choose a category', style: TextStyle(color: AppColors.ink, fontSize: 20.sp, fontWeight: FontWeight.w900)),
            5.verticalSpace,
            Text('This label is private to you.', style: TextStyle(color: AppColors.slate, fontSize: 12.sp)),
            16.verticalSpace,
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              mainAxisSpacing: 10.w,
              crossAxisSpacing: 10.w,
              childAspectRatio: 0.88,
              children: [
                _tile(label: 'Original', icon: Icons.auto_awesome_rounded, selected: _selected == widget.originalCategoryId, onTap: () => Navigator.pop(dialogContext, '__original__')),
                ...ExpenseCategory.all.map((cat) => _tile(label: cat.label, icon: cat.icon, selected: _selected == cat.id, onTap: () => Navigator.pop(dialogContext, cat.id))),
              ],
            ),
            12.verticalSpace,
            SizedBox(width: double.infinity, child: TextButton(onPressed: () => Navigator.pop(dialogContext, '__cancel__'), child: const Text('Cancel'))),
          ]),
        ),
      ),
    );
    if (!mounted || picked == null || picked == '__cancel__') return;
    final value = picked == '__original__' ? null : picked;
    final optimistic = value ?? widget.originalCategoryId;
    setState(() { _selected = optimistic; _saving = true; });
    try {
      await MonthlyBudgetRepository.instance.setMemberCategory(groupId: widget.groupId, expenseId: widget.expenseId, uid: widget.uid, categoryId: value);
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(behavior: SnackBarBehavior.floating, content: Text('Your category was saved.')));
    } catch (error) {
      if (!mounted) return;
      setState(() => _selected = _selected); // retain optimistic choice; reload authoritative value below
      messenger.showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text('Could not save category: $error')));
      await _load();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cat = ExpenseCategory.byId(_selected);
    return Container(
      margin: EdgeInsets.only(bottom: 18.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(color: AppColors.paper, borderRadius: BorderRadius.circular(18.r)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(Icons.label_rounded, color: AppColors.brass, size: 18.r), 8.horizontalSpace, Text('MY CATEGORY', style: TextStyle(color: AppColors.slate, fontSize: 10.sp, fontWeight: FontWeight.w900, letterSpacing: 1.2))]),
        12.verticalSpace,
        InkWell(
          borderRadius: BorderRadius.circular(14.r),
          onTap: _choose,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
            decoration: BoxDecoration(border: Border.all(color: AppColors.ink.withValues(alpha: 0.15)), borderRadius: BorderRadius.circular(14.r), color: AppColors.paperDim.withValues(alpha: 0.35)),
            child: Row(children: [
              Container(padding: EdgeInsets.all(10.r), decoration: BoxDecoration(color: AppColors.brass.withValues(alpha: 0.12), shape: BoxShape.circle), child: Icon(cat?.icon ?? Icons.auto_awesome_rounded, color: AppColors.brass, size: 22.r)),
              12.horizontalSpace,
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_loading ? 'Loading category...' : (cat?.label ?? 'Original category'), style: TextStyle(color: AppColors.ink, fontSize: 14.sp, fontWeight: FontWeight.w800)),
                3.verticalSpace,
                Text(_saving ? 'Saving...' : 'Tap to change', style: TextStyle(color: AppColors.slate, fontSize: 10.sp)),
              ])),
              if (_saving || _loading) SizedBox(width: 16.r, height: 16.r, child: const CircularProgressIndicator(strokeWidth: 2, color: AppColors.brass)) else Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.slate, size: 22.r),
            ]),
          ),
        ),
        10.verticalSpace,
        Text('Only you see this category. It does not change the group expense.', style: TextStyle(color: AppColors.slate, fontSize: 11.sp, height: 1.4)),
      ]),
    );
  }
}

class ExpenseDetailScreen extends StatelessWidget {
  /// The expense as it looked when this screen was opened — used only as
  /// a fallback while the live version resolves, and to know which id to
  /// look up. Everything actually shown comes from [_resolveLive], so
  /// edits (made here or by another member, live) are reflected instead
  /// of staying frozen at whatever this was when the screen opened.
  final Expense expense;

  const ExpenseDetailScreen({super.key, required this.expense});

  Future<void> _confirmDelete(
      BuildContext context, SplitProvider provider, Expense live) async {
    final isSettlement = live.isSettlement;
    if (!isSettlement && live.settledAmounts.values.any((v) => v > 0.005)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
              'This expense is part of a recorded settlement. Undo the '
              'settlement first (Balances → Settlement history), then delete it.'),
        ),
      );
      return;
    }
    final confirmed = await AppDialog.showConfirm(
      context,
      icon: isSettlement ? Icons.undo_rounded : Icons.delete_outline_rounded,
      iconColor: AppColors.rust,
      title: isSettlement ? 'Revert settlement?' : 'Delete this split?',
      message: isSettlement
          ? 'This will remove the payment record and restore the previous balances. This action cannot be undone.'
          : 'This will permanently remove this expense from the group record. This action cannot be undone.',
      confirmText: isSettlement ? 'Revert' : 'Delete',
      confirmColor: AppColors.rust,
    );

    if (confirmed == true) {
      final error = provider.removeExpense(live.id);
      if (!context.mounted) return;
      if (error != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(error)));
        return;
      }
      Navigator.pop(context);
    }
  }

  Widget _buildCategoryTile({required String label, required IconData icon, required bool selected, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(14.r),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: selected ? AppColors.brass.withValues(alpha: 0.15) : AppColors.paperDim.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: selected ? AppColors.brass : AppColors.ink.withValues(alpha: 0.08), width: selected ? 1.6 : 1),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: selected ? AppColors.brass : AppColors.ink, size: 24.r),
          8.verticalSpace,
          Text(label, textAlign: TextAlign.center, style: TextStyle(color: AppColors.ink, fontSize: 10.sp, fontWeight: FontWeight.w800)),
          if (selected) ...[4.verticalSpace, Icon(Icons.check_circle_rounded, color: AppColors.brass, size: 14.r)],
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SplitProvider>();

    // Re-resolve the live version of this expense on every rebuild, so an
    // edit made from this screen (or by another member, live) is reflected
    // here instead of staying frozen at whatever `expense` was when this
    // screen was first opened.
    Expense? live;
    for (final e in provider.expenses) {
      if (e.id == expense.id) {
        live = e;
        break;
      }
    }

    // The expense was deleted (by us just now, or by someone else while
    // this screen was open) — there's nothing left to show, so back out
    // instead of rendering stale/dead data.
    if (live == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted &&
            ModalRoute.of(context)?.isCurrent == true &&
            Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      });
      return const Scaffold(
        backgroundColor: AppColors.ink,
        body: SizedBox.shrink(),
      );
    }

    // Bind a guaranteed-non-null, never-reassigned local so every closure
    // below (the map() callbacks, the button handlers) can safely capture
    // it without relying on Dart's promotion-through-closures rules.
    final liveExpense = live;

    final payer = provider.personById(liveExpense.payerId);
    final myGroupMembers = provider.currentGroup!.members
        .where((p) => p.linkedUserId == provider.uid).toList();
    final splitParticipants = liveExpense.splitWith
        .map((id) => provider.personById(id))
        .where((p) => p != null)
        .toList()
        .cast<Person>();

    final totalParticipants = liveExpense.participantCount;
    final isAdder = liveExpense.addedBy == provider.uid;
    final isFullySettled = liveExpense.isFullySettled;
    final settledCount = liveExpense.settledCount;
    // Legacy settlement records can't be toggled per person.
    final canToggle =
        liveExpense.addedBy == provider.uid && !liveExpense.isSettlement;

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
                      icon:
                          const Icon(Icons.arrow_back, color: AppColors.paper),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Row(
                      children: [
                        if (isAdder) ...[
                          if (!liveExpense.isSettlement)
                            IconButton(
                              icon: const Icon(Icons.edit_outlined,
                                  color: AppColors.brassSoft),
                              onPressed: () => showExpenseFormSheet(context,
                                  existing: liveExpense),
                              tooltip: 'Edit',
                            ),
                          IconButton(
                            icon: Icon(
                                liveExpense.isSettlement
                                    ? Icons.undo
                                    : Icons.delete_outline,
                                color: AppColors.rust),
                            onPressed: () =>
                                _confirmDelete(context, provider, liveExpense),
                            tooltip: liveExpense.isSettlement
                                ? 'Revert Settlement'
                                : 'Delete',
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
                  padding: EdgeInsets.symmetric(horizontal: 24.w),
                  children: [
                    12.verticalSpace,

                    // Digital Receipt Hero Card
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.paper,
                        borderRadius: BorderRadius.circular(24.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Top Section: Icon & Category
                          Container(
                            padding: EdgeInsets.symmetric(vertical: 16.h),
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: AppColors.ink.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(24.r)),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(12.r),
                                  decoration: BoxDecoration(
                                    color: isFullySettled
                                        ? AppColors.sage.withValues(alpha: 0.15)
                                        : AppColors.brass
                                            .withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isFullySettled
                                        ? Icons.check_circle
                                        : Icons.receipt_long,
                                    color: isFullySettled
                                        ? AppColors.sage
                                        : AppColors.brass,
                                    size: 28.r,
                                  ),
                                ),
                                8.verticalSpace,
                                Text(
                                  isFullySettled
                                      ? 'FULLY SETTLED'
                                      : '$settledCount/$totalParticipants SETTLED',
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w900,
                                    color: isFullySettled
                                        ? AppColors.sage
                                        : AppColors.brass,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Middle Section: Desc & Amount
                          Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 24.w, vertical: 20.h),
                            child: Column(
                              children: [
                                Text(
                                  liveExpense.desc.toUpperCase(),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 18.sp,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.ink,
                                    fontFamily: 'Georgia',
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                8.verticalSpace,
                                Text(
                                  fmtCurrency(liveExpense.amount,
                                      provider.currentGroup!.currency),
                                  style: TextStyle(
                                    fontSize: 36.sp,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.ink,
                                    fontFamily: 'Georgia',
                                  ),
                                ),
                                12.verticalSpace,
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'ISSUED BY ',
                                      style: TextStyle(
                                        fontSize: 9.sp,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.slate,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                    Text(
                                      payer?.name.toUpperCase() ?? 'UNKNOWN',
                                      style: TextStyle(
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.ink,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Bottom Section: Decorative Perforation Look
                          Row(
                            children: List.generate(
                              15,
                              (index) => Expanded(
                                child: Container(
                                  margin: EdgeInsets.symmetric(horizontal: 2.w),
                                  height: 4.h,
                                  decoration: BoxDecoration(
                                    color:
                                        AppColors.ink.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(2.r),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          12.verticalSpace,
                        ],
                      ),
                    ),

                    24.verticalSpace,


                    if (!provider.currentGroup!.isPersonal &&
                        myGroupMembers.isNotEmpty &&
                        liveExpense.splitMap.containsKey(myGroupMembers.first.id))
                      MemberExpenseCategorySelector(
                        groupId: provider.currentGroup!.id,
                        expenseId: liveExpense.id,
                        uid: provider.uid!,
                        originalCategoryId: liveExpense.categoryId,
                      ),

                    // Breakdown Title
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'BREAKDOWN & SETTLEMENTS',
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w900,
                            color: AppColors.brassSoft,
                            letterSpacing: 1.5,
                          ),
                        ),
                        Text(
                          '$settledCount/$totalParticipants PAID',
                          style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w800,
                            color: AppColors.slate,
                          ),
                        ),
                      ],
                    ),
                    16.verticalSpace,

                    // Participant "Line Items" with Paid/Pending Status
                    ...splitParticipants.map((person) {
                      final isPayer = person.id == liveExpense.payerId;
                      final share = liveExpense.splitMap[person.id] ?? 0;
                      final isMe = person.linkedUserId == provider.uid;
                      final settledViaPair =
                          liveExpense.isShareCoveredByPairSettlement(person.id);
                      final isSettled = liveExpense.isPersonPaid(person.id);
                      final isPartial =
                          liveExpense.isPersonPartiallyPaid(person.id);
                      final canToggleThisShare = canToggle &&
                          !isPayer && !settledViaPair;

                      return GestureDetector(
                        onTap: canToggleThisShare
                            ? () {
                                provider.togglePersonSettlement(
                                    liveExpense.id, person.id);
                              }
                            : null,
                        child: Container(
                          margin: EdgeInsets.only(bottom: 12.h),
                          padding: EdgeInsets.all(16.w),
                          decoration: BoxDecoration(
                            color: isMe
                                ? AppColors.paper
                                : AppColors.paper.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(16.r),
                            border: isMe
                                ? Border.all(color: AppColors.brass, width: 1.5)
                                : null,
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18.r,
                                backgroundColor: person.color,
                                child: Text(
                                  person.name[0].toUpperCase(),
                                  style: TextStyle(
                                      fontSize: 13.sp,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              16.horizontalSpace,
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isMe ? 'YOU' : person.name.toUpperCase(),
                                      style: TextStyle(
                                          fontSize: 13.sp,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.ink),
                                    ),
                                    4.verticalSpace,
                                    Row(
                                      children: [
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 8.w, vertical: 2.h),
                                          decoration: BoxDecoration(
                                            color: isSettled
                                                ? AppColors.sage
                                                    .withValues(alpha: 0.15)
                                                : AppColors.brass
                                                    .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(6.r),
                                          ),
                                          child: Text(
                                            isSettled
                                                ? 'PAID'
                                                : (isPartial
                                                    ? 'PARTIAL'
                                                    : 'PENDING'),
                                            style: TextStyle(
                                              fontSize: 9.sp,
                                              fontWeight: FontWeight.w900,
                                              color: isSettled
                                                  ? AppColors.sage
                                                  : AppColors.brass,
                                            ),
                                          ),
                                        ),
                                        if (isPayer) ...[
                                          6.horizontalSpace,
                                          Text(
                                            '• PAID AMOUNT',
                                            style: TextStyle(
                                              fontSize: 9.sp,
                                              color: AppColors.slate,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    fmtCurrency(
                                        share, provider.currentGroup!.currency),
                                    style: TextStyle(
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.ink),
                                  ),
                                  if (settledViaPair || canToggleThisShare)
                                    Padding(
                                      padding: EdgeInsets.only(top: 4.h),
                                      child: Text(
                                        settledViaPair
                                            ? 'Pair settlement applied'
                                            : (isSettled
                                                ? 'Tap to mark pending'
                                                : 'Tap to mark paid'),
                                        style: TextStyle(
                                          fontSize: 8.sp,
                                          color: AppColors.slate,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                    40.verticalSpace,
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
