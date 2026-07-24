import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/split_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/balances_tab.dart';
import '../widgets/branded_loader.dart';
import '../widgets/header_bar.dart';
import '../widgets/ledger_tab.dart';
import '../widgets/expense_form_sheet.dart';
import '../widgets/overview_tab.dart';
import 'nus_ai_screen.dart';

class SplitHomeScreen extends StatelessWidget {
  const SplitHomeScreen({super.key});

  String _ownerNameFor(BuildContext context) {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return 'Someone';
    if (user.displayName?.isNotEmpty == true) return user.displayName!;
    return user.email ?? 'Someone';
  }

  void _showAddGroup(BuildContext context, SplitProvider provider) {
    final ctrl = TextEditingController();
    final ownerName = _ownerNameFor(context);
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
                provider.addGroup(ctrl.text, ownerName: ownerName);
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
      String groupId, String name) async {
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
      return const BrandedLoader(message: 'Getting your groups ready…');
    }

    return Scaffold(
      drawer: Drawer(
        backgroundColor: AppColors.paper,
        child: Column(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: AppColors.paperDim),
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
                            color: AppColors.ink),
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
                              color: AppColors.brass,
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
              child: provider.groups.isEmpty
                  ? Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.w),
                        child: Text(
                          'No groups yet — create one below, or ask a '
                          'friend to add you to theirs.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: AppColors.slate, fontSize: 12.5.sp),
                        ),
                      ),
                    )
                  : ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        ...provider.groups.map((g) {
                          final owned = g.ownerId ==
                              context.read<AuthProvider>().currentUser?.uid;
                          final isSelected = currentGroup?.id == g.id;
                          return ListTile(
                            leading: Icon(
                                owned ? Icons.group : Icons.group_outlined,
                                color: isSelected
                                    ? AppColors.brass
                                    : AppColors.slate),
                            title: Text(
                              g.name,
                              style: TextStyle(
                                color: AppColors.ink,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            subtitle: owned
                                ? null
                                : Text(
                                    'Shared by ${g.ownerName.isEmpty ? 'a member' : g.ownerName}',
                                    style: TextStyle(
                                        color: AppColors.slate, fontSize: 10.5.sp),
                                  ),
                            trailing: owned
                                ? IconButton(
                                    icon: Icon(Icons.delete_outline,
                                        size: 20.r, color: AppColors.slate),
                                    onPressed: () => _confirmDeleteGroup(
                                        context, provider, g.id, g.name),
                                    tooltip: 'Delete group',
                                  )
                                : Icon(Icons.visibility_outlined,
                                    size: 18.r, color: AppColors.slate),
                            selected: isSelected,
                            selectedTileColor:
                                AppColors.brass.withValues(alpha: 0.1),
                            onTap: () {
                              provider.selectGroup(g.id);
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
          child: currentGroup == null
              ? _EmptyGroupsBody(onCreateGroup: () => _showAddGroup(context, provider))
              : DefaultTabController(
                  length: 3,
                  child: Column(
                    children: [
                      HeaderBar(totalSpent: totalSpent),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
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
                      Expanded(
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
      floatingActionButton: currentGroup == null
          ? null
          : Column(
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

/// Shown as the *body* of the normal Home scaffold (drawer, sign-out and
/// all) when the signed-in user has no groups of their own and hasn't
/// been linked into anyone else's yet — rather than a dead-end screen
/// with only one button on it.
class _EmptyGroupsBody extends StatelessWidget {
  final VoidCallback onCreateGroup;
  const _EmptyGroupsBody({required this.onCreateGroup});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(4.w, 12.h, 16.w, 0),
          child: Row(
            children: [
              Builder(
                builder: (context) => IconButton(
                  icon: Icon(Icons.menu, color: AppColors.ink, size: 26.r),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
            ],
          ),
        ),
        Expanded(
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
                          color: AppColors.ink,
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
                    "You're all set. Create a group when you're ready — "
                    "or if a friend adds you to theirs, it'll show up "
                    'here automatically.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.slate, fontSize: 14.sp),
                  ),
                  32.verticalSpace,
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onCreateGroup,
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
      ],
    );
  }
}
