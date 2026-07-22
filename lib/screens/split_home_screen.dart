import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/split_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/balances_tab.dart';
import '../widgets/header_bar.dart';
import '../widgets/ledger_tab.dart';
import '../widgets/expense_form_sheet.dart';
import '../widgets/overview_tab.dart';
import 'nus_ai_screen.dart';

class SplitHomeScreen extends StatelessWidget {
  const SplitHomeScreen({super.key});

  void _showAddGroup(BuildContext context, SplitProvider provider) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.paper,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: const Text('New Group',
            style:
                TextStyle(color: AppColors.ink, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(color: AppColors.ink, fontSize: 16.sp),
          decoration:
              AppTheme.inputDecoration('Group Name (e.g. Vacation)').copyWith(
            filled: false,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Cancel', style: TextStyle(color: AppColors.slate)),
          ),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                provider.addGroup(ctrl.text);
                Navigator.pop(ctx);
              }
            },
            style: AppTheme.solidButton.copyWith(
              padding: WidgetStateProperty.all(
                  EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h)),
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteGroup(BuildContext context, SplitProvider provider,
      int groupId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.paper,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Text('Delete "$name"?',
            style: const TextStyle(
                color: AppColors.ink, fontWeight: FontWeight.bold)),
        content: const Text(
          'This permanently deletes the group along with all its members '
          'and expense history. This can\'t be undone.',
          style: TextStyle(color: AppColors.slate),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                const Text('Cancel', style: TextStyle(color: AppColors.slate)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: AppTheme.solidButton.copyWith(
              backgroundColor: WidgetStateProperty.all(AppColors.rust),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      provider.removeGroup(groupId);
      if (context.mounted) Navigator.pop(context); // close the drawer
    }
  }

  void _showAddExpenseSheet(BuildContext context) {
    showExpenseFormSheet(context);
  }

  void _openNusAi(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AiExpenseScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SplitProvider>();
    final currentGroup = provider.currentGroup;
    final totalSpent = provider.totalSpent;

    if (provider.isLoading) {
      return const Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-0.4, -0.6),
              radius: 1.2,
              colors: [AppColors.inkSoft, AppColors.ink],
            ),
          ),
          child: Center(
            child: CircularProgressIndicator(color: AppColors.brass),
          ),
        ),
      );
    }

    if (currentGroup == null) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-0.4, -0.6),
              radius: 1.2,
              colors: [AppColors.inkSoft, AppColors.ink],
            ),
          ),
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 32.w),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 96.r,
                    height: 96.r,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.brass, width: 3),
                    ),
                    child: Icon(Icons.account_balance_wallet_outlined,
                        size: 44.r, color: AppColors.brass),
                  ),
                  24.verticalSpace,
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                          fontSize: 28.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.paper,
                          fontFamily: 'Georgia'),
                      children: [
                        const TextSpan(text: 'Nus'),
                        TextSpan(
                            text: '·',
                            style: TextStyle(color: AppColors.brass)),
                        const TextSpan(text: 'Nus'),
                      ],
                    ),
                  ),
                  8.verticalSpace,
                  Text(
                    'Track shared expenses without the hassle.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.slate, fontSize: 14.sp),
                  ),
                  32.verticalSpace,
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showAddGroup(context, provider),
                      style: AppTheme.solidButton.copyWith(
                        backgroundColor:
                            WidgetStateProperty.all(AppColors.brass),
                        padding: WidgetStateProperty.all(
                            EdgeInsets.symmetric(vertical: 16.h)),
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('Create your first group'),
                    ),
                  ),
                ],
              ),
            ),
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
                        style: TextStyle(
                            fontSize: 24.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.paper),
                        children: [
                          const TextSpan(text: 'Nus'),
                          TextSpan(
                              text: '·',
                              style: TextStyle(color: AppColors.brass)),
                          const TextSpan(text: 'Nus'),
                        ],
                      ),
                    ),
                    4.verticalSpace,
                    Text('Your Split Groups',
                        style:
                            TextStyle(color: AppColors.slate, fontSize: 12.sp)),
                    Builder(builder: (context) {
                      final user = context.watch<AuthProvider>().currentUser;
                      if (user == null) return const SizedBox.shrink();
                      return Padding(
                        padding: EdgeInsets.only(top: 8.h),
                        child: Text(
                          user.displayName?.isNotEmpty == true
                              ? user.displayName!
                              : (user.email ?? ''),
                          style: TextStyle(
                              color: AppColors.brassSoft,
                              fontSize: 11.5.sp,
                              fontWeight: FontWeight.w600),
                        ),
                      );
                    }),
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
                      leading: Icon(Icons.group,
                          color:
                              isSelected ? AppColors.brass : AppColors.slate),
                      title: Text(
                        g.name,
                        style: TextStyle(
                          color: AppColors.ink,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.delete_outline,
                            size: 20.r, color: AppColors.slate),
                        onPressed: () => _confirmDeleteGroup(
                            context, provider, g.id, g.name),
                        tooltip: 'Delete group',
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
            const Divider(color: AppColors.line, height: 1),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.rust),
              title: const Text(
                'Sign out',
                style: TextStyle(color: AppColors.rust, fontWeight: FontWeight.w600),
              ),
              onTap: () async {
                Navigator.pop(context);
                await context.read<AuthProvider>().signOut();
              },
            ),
            20.verticalSpace
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.5, -0.8),
            radius: 1.4,
            colors: [AppColors.inkSoft, AppColors.ink],
          ),
        ),
        child: SafeArea(
          child: DefaultTabController(
            length: 3,
            child: Column(
              children: [
                HeaderBar(totalSpent: totalSpent),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: TabBar(
                      labelColor: AppColors.ink,
                      unselectedLabelColor: AppColors.slate,
                      indicator: BoxDecoration(
                        color: AppColors.brassSoft,
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicatorPadding: EdgeInsets.all(4.r),
                      dividerColor: Colors.transparent,
                      labelStyle: TextStyle(
                          fontSize: 12.5.sp, fontWeight: FontWeight.bold),
                      tabs: const [
                        Tab(text: 'Activity'),
                        Tab(text: 'Balances'),
                        Tab(text: 'Overview'),
                      ],
                    ),
                  ),
                ),
                8.verticalSpace,
                const Expanded(
                  child: TabBarView(
                    children: [
                      LedgerTab(),
                      BalancesTab(),
                      OverviewTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(
            height: 45.h,
            child: FloatingActionButton.extended(
              heroTag: null,
              onPressed: () => _openNusAi(context),
              backgroundColor: AppColors.brass,
              foregroundColor: AppColors.ink,
              elevation: 4,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              extendedPadding: EdgeInsets.symmetric(horizontal: 12.w),
              icon: Image.asset(
                'assets/icon/ai.png',
                width: 18.w,
                height: 18.w,
              ),
              label: Text(
                'Nus Ai',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.sp,
                ),
              ),
            ),
          ),
          12.verticalSpace,
          SizedBox(
            height: 45.h,
            child: FloatingActionButton.extended(
              onPressed: () => _showAddExpenseSheet(context),
              heroTag: null,
              backgroundColor: AppColors.brass,
              foregroundColor: AppColors.ink,
              elevation: 4,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              extendedPadding: EdgeInsets.symmetric(horizontal: 12.w),
              icon: Icon(Icons.add, size: 18.sp),
              label: Text(
                'Add Split',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
