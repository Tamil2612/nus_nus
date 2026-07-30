import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../providers/split_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';
import '../widgets/ledger_tab.dart';
import '../widgets/expense_form_sheet.dart';
import '../widgets/nus_drawer.dart';

class PersonalLedgerScreen extends StatefulWidget {
  const PersonalLedgerScreen({super.key});

  @override
  State<PersonalLedgerScreen> createState() => _PersonalLedgerScreenState();
}

class _PersonalLedgerScreenState extends State<PersonalLedgerScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _showRenameGroup(BuildContext context, SplitProvider provider,
      String groupId, String currentName, String currentCurrency) {
    final ctrl = TextEditingController(text: currentName);
    String selectedCurrency = currentCurrency;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          backgroundColor: AppColors.paper,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
          title: const Text('Group Settings',
              style:
                  TextStyle(color: AppColors.ink, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                autofocus: true,
                style: TextStyle(color: AppColors.ink, fontSize: 16.sp),
                decoration: AppTheme.inputDecoration('Group Name').copyWith(
                  filled: false,
                ),
              ),
              16.verticalSpace,
              DropdownButtonFormField<String>(
                initialValue: selectedCurrency,
                dropdownColor: AppColors.paper,
                style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold),
                decoration: AppTheme.inputDecoration('Currency').copyWith(
                  prefixIcon: Icon(Icons.payments_outlined,
                      color: AppColors.brass, size: 20.r),
                ),
                items: [
                  'AED',
                  'USD',
                  'EUR',
                  'GBP',
                  'INR',
                  'SAR',
                  'QAR',
                  'KWD',
                  'BHD',
                  'OMR'
                ]
                    .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c,
                              style: const TextStyle(
                                  color: AppColors.ink,
                                  fontWeight: FontWeight.bold)),
                        ))
                    .toList(),
                onChanged: (v) => setDialogState(() => selectedCurrency = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.slate)),
            ),
            ElevatedButton(
              onPressed: () {
                if (ctrl.text.trim().isNotEmpty) {
                  provider.renameGroup(groupId, ctrl.text.trim(),
                      newCurrency: selectedCurrency);
                  Navigator.pop(ctx);
                }
              },
              style: AppTheme.solidButton.copyWith(
                padding: WidgetStateProperty.all(
                    EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h)),
              ),
              child: const Text('Save'),
            ),
          ],
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SplitProvider>();
    final group = provider.personalGroup;

    if (group == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final total = group.expenses.fold(0.0, (sum, e) => sum + e.amount);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.ink,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.paper),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('My Expenses',
                style: TextStyle(
                    color: AppColors.paper,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold)),
            Text(fmtCurrency(total, group.currency),
                style: TextStyle(
                    color: AppColors.brassSoft,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          IconButton(
            icon:
                const Icon(Icons.settings_outlined, color: AppColors.brassSoft),
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
          12.horizontalSpace,
        ],
      ),
      endDrawer: NusDrawer(
        currentGroupId: group.id,
        onRename: _showRenameGroup,
        onDelete: (a, b, c, d) {}, // Personal group shouldn't be deleted easily
        onAddGroup: (a, b) {},
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.5, -0.8),
            radius: 1.4,
            colors: [AppColors.inkSoft, AppColors.ink],
          ),
        ),
        child: const LedgerTab(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showExpenseFormSheet(context),
        backgroundColor: AppColors.brass,
        foregroundColor: AppColors.ink,
        icon: const Icon(Icons.add),
        label: Text('Add My Expense',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp)),
      ),
    );
  }
}
