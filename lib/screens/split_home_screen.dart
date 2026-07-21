import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../providers/split_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/balances_tab.dart';
import '../widgets/header_bar.dart';
import '../widgets/ledger_tab.dart';
import '../widgets/expense_form.dart';

class SplitHomeScreen extends StatelessWidget {
  const SplitHomeScreen({super.key});

  void _showAddGroup(BuildContext context, SplitProvider provider) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.paper,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: const Text('New Group', style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(color: AppColors.ink, fontSize: 16.sp),
          decoration: AppTheme.inputDecoration('Group Name (e.g. Vacation)').copyWith(
            filled: false,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.slate)),
          ),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                provider.addGroup(ctrl.text);
                Navigator.pop(ctx);
              }
            },
            style: AppTheme.solidButton.copyWith(
              padding: WidgetStateProperty.all(EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h)),
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showAddExpenseSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40.w,
                height: 4.h,
                margin: EdgeInsets.only(bottom: 20.h),
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              Text(
                'Add New Expense',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.ink,
                ),
              ),
              20.verticalSpace,
              const ExpenseForm(),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SplitProvider>();
    final currentGroup = provider.currentGroup;
    final totalSpent = provider.totalSpent;

    if (currentGroup == null) {
      return Scaffold(
        backgroundColor: AppColors.ink,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.account_balance_wallet_outlined, size: 80.r, color: AppColors.brass),
              24.verticalSpace,
              Text(
                'Welcome to Nus-Nus',
                style: TextStyle(color: AppColors.paper, fontSize: 24.sp, fontWeight: FontWeight.bold),
              ),
              8.verticalSpace,
              Text(
                'Track shared expenses without the hassle.',
                style: TextStyle(color: AppColors.slate, fontSize: 14.sp),
              ),
              32.verticalSpace,
              ElevatedButton.icon(
                onPressed: () => _showAddGroup(context, provider),
                style: AppTheme.solidButton,
                icon: const Icon(Icons.add),
                label: const Text('Create your first group'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      drawer: Drawer(
        backgroundColor: AppColors.paper,
        child: Column(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: AppColors.ink),
              margin: EdgeInsets.zero,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.bold, color: AppColors.paper),
                        children: [
                          const TextSpan(text: 'Nus'),
                          TextSpan(text: '·', style: TextStyle(color: AppColors.brass)),
                          const TextSpan(text: 'Nus'),
                        ],
                      ),
                    ),
                    4.verticalSpace,
                    Text('Your Split Groups', style: TextStyle(color: AppColors.slate, fontSize: 12.sp)),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  ...provider.groups.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final g = entry.value;
                    final isSelected = currentGroup.id == g.id;
                    return ListTile(
                      leading: Icon(Icons.group, color: isSelected ? AppColors.brass : AppColors.slate),
                      title: Text(
                        g.name,
                        style: TextStyle(
                          color: AppColors.ink,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      selected: isSelected,
                      selectedTileColor: AppColors.brass.withValues(alpha: 0.1),
                      onTap: () {
                        provider.selectGroup(idx);
                        Navigator.pop(context);
                      },
                    );
                  }),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showAddGroup(context, provider);
                  },
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text(
                    'Create New Group',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brass,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ),
            20.verticalSpace
          ],
        ),
      ),
      body: SafeArea(
        child: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              HeaderBar(totalSpent: totalSpent),
              TabBar(
                labelColor: AppColors.brass,
                unselectedLabelColor: AppColors.slate,
                indicatorColor: AppColors.brass,
                indicatorWeight: 3.h,
                labelStyle: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
                tabs: const [
                  Tab(text: 'Activity'),
                  Tab(text: 'Balances'),
                ],
              ),
              const Expanded(
                child: TabBarView(
                  children: [
                    LedgerTab(),
                    BalancesTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddExpenseSheet(context),
        backgroundColor: AppColors.paperDim,
        foregroundColor: AppColors.inkSoft,
        icon: const Icon(Icons.add),
        label: const Text('Add Split'),
      ),
    );
  }
}
