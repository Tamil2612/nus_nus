import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../models/group.dart';
import '../providers/auth_provider.dart';
import '../providers/split_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/balances_tab.dart';
import '../widgets/branded_loader.dart';
import '../widgets/header_bar.dart';
import '../widgets/ledger_tab.dart';
import '../widgets/expense_form_sheet.dart';
import '../widgets/people_tab.dart';
import 'nus_ai_screen.dart';

class SplitHomeScreen extends StatefulWidget {
  const SplitHomeScreen({super.key});

  @override
  State<SplitHomeScreen> createState() => _SplitHomeScreenState();
}

class _SplitHomeScreenState extends State<SplitHomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // Rebuild to update HeaderBar
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _ownerNameFor(BuildContext context) {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return 'Someone';
    if (user.displayName?.isNotEmpty == true) return user.displayName!;
    return user.email ?? 'Someone';
  }

  void _showAddGroup(BuildContext context, SplitProvider provider) {
    final ctrl = TextEditingController();
    final ownerName = _ownerNameFor(context);
    String selectedCurrency = 'AED';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          backgroundColor: AppColors.paper,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
          title: const Text('New Group',
              style:
                  TextStyle(color: AppColors.ink, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                autofocus: true,
                style: TextStyle(color: AppColors.ink, fontSize: 16.sp),
                decoration: AppTheme.inputDecoration('Group Name (e.g. Vacation)')
                    .copyWith(
                  filled: false,
                ),
              ),
              16.verticalSpace,
              DropdownButtonFormField<String>(
                value: selectedCurrency,
                dropdownColor: AppColors.paper,
                style: TextStyle(color: AppColors.ink, fontSize: 16.sp, fontWeight: FontWeight.bold),
                decoration: AppTheme.inputDecoration('Currency').copyWith(
                  prefixIcon: Icon(Icons.payments_outlined, color: AppColors.brass, size: 20.r),
                ),
                items: ['AED', 'USD', 'EUR', 'GBP', 'INR', 'SAR', 'QAR', 'KWD', 'BHD', 'OMR']
                    .map((c) => DropdownMenuItem(
                      value: c, 
                      child: Text(c, style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.bold)),
                    ))
                    .toList(),
                onChanged: (v) => setDialogState(() => selectedCurrency = v!),
              ),
            ],
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
                  provider.addGroup(ctrl.text,
                      ownerName: ownerName, currency: selectedCurrency);
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
        );
      }),
    );
  }

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
          title: const Text('Rename Group',
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
                value: selectedCurrency,
                dropdownColor: AppColors.paper,
                style: TextStyle(color: AppColors.ink, fontSize: 16.sp, fontWeight: FontWeight.bold),
                decoration: AppTheme.inputDecoration('Currency').copyWith(
                  prefixIcon: Icon(Icons.payments_outlined, color: AppColors.brass, size: 20.r),
                ),
                items: ['AED', 'USD', 'EUR', 'GBP', 'INR', 'SAR', 'QAR', 'KWD', 'BHD', 'OMR']
                    .map((c) => DropdownMenuItem(
                      value: c, 
                      child: Text(c, style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.bold)),
                    ))
                    .toList(),
                onChanged: (v) => setDialogState(() => selectedCurrency = v!),
              ),
            ],
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
        width: 0.85.sw,
        child: Column(
          children: [
            // Immersive Header with Radial Gradient
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(20.w, 60.h, 20.w, 32.h),
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.5, -0.8),
                  radius: 1.5,
                  colors: [AppColors.inkSoft, AppColors.ink],
                ),
              ),
              child: Builder(builder: (context) {
                final user = context.watch<AuthProvider>().currentUser;
                final name = user?.displayName ??
                    user?.email?.split('@').first ??
                    'User';
                final email = user?.email ?? '';

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 32.r,
                      backgroundColor: AppColors.brass.withValues(alpha: 0.2),
                      child: CircleAvatar(
                        radius: 28.r,
                        backgroundColor: AppColors.brass,
                        child: Text(
                          name[0].toUpperCase(),
                          style: TextStyle(
                              fontSize: 24.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                      ),
                    ),
                    20.verticalSpace,
                    Text(
                      name,
                      style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w900,
                          color: AppColors.paper),
                    ),
                    Text(
                      email,
                      style: TextStyle(
                          fontSize: 12.sp,
                          color: AppColors.slate,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                );
              }),
            ),

            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(vertical: 20.h),
                children: [
                  if (provider.ownedGroups.isNotEmpty) ...[
                    _SectionHeader(title: 'MY GROUPS'),
                    ...provider.ownedGroups.map((g) => _GroupDrawerTile(
                          group: g,
                          isSelected: currentGroup?.id == g.id,
                          isOwned: true,
                          onTap: () {
                            provider.selectGroup(g.id);
                            Navigator.pop(context);
                          },
                          onRename: () => _showRenameGroup(
                              context, provider, g.id, g.name, g.currency),
                          onDelete: () => _confirmDeleteGroup(
                              context, provider, g.id, g.name),
                        )),
                    24.verticalSpace,
                  ],
                  if (provider.linkedGroups.isNotEmpty) ...[
                    _SectionHeader(title: 'SHARED WITH ME'),
                    ...provider.linkedGroups.map((g) => _GroupDrawerTile(
                          group: g,
                          isSelected: currentGroup?.id == g.id,
                          isOwned: false,
                          onTap: () {
                            provider.selectGroup(g.id);
                            Navigator.pop(context);
                          },
                        )),
                  ],
                  if (provider.groups.isEmpty)
                    Padding(
                      padding: EdgeInsets.all(40.w),
                      child: Text(
                        'No groups yet. Create one below to start splitting!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AppColors.slate,
                            fontSize: 13.sp,
                            height: 1.5),
                      ),
                    ),
                ],
              ),
            ),

            // Footer Actions
            Container(
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                color: AppColors.paperDim,
                border:
                    Border(top: BorderSide(color: AppColors.line, width: 1)),
              ),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showAddGroup(context, provider);
                      },
                      icon: const Icon(Icons.add_circle_outline, size: 20),
                      label: const Text('CREATE NEW GROUP'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.ink,
                        foregroundColor: AppColors.paper,
                        elevation: 4,
                        shadowColor: AppColors.ink.withValues(alpha: 0.4),
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r)),
                        textStyle: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1),
                      ),
                    ),
                  ),
                  12.verticalSpace,
                  TextButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      await context.read<AuthProvider>().signOut();
                    },
                    icon: const Icon(Icons.logout,
                        size: 18, color: AppColors.rust),
                    label: Text(
                      'SIGN OUT',
                      style: TextStyle(
                          color: AppColors.rust,
                          fontWeight: FontWeight.w900,
                          fontSize: 12.sp,
                          letterSpacing: 1),
                    ),
                  ),
                ],
              ),
            ),
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
              ? _EmptyGroupsBody(
                  onCreateGroup: () => _showAddGroup(context, provider))
              : Column(
                    children: [
                      HeaderBar(
                        totalSpent: totalSpent,
                        tabIndex: _tabController.index,
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: 16.w, vertical: 8.h),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: TabBar(
                            controller: _tabController,
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
                              Tab(text: 'People'),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            LedgerTab(),
                            BalancesTab(),
                            PeopleTab(),
                          ],
                        ),
                      ),
                    ],
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
                builder: (context) => InkWell(
                  onTap: () => Scaffold.of(context).openDrawer(),
                  child: Image.asset('assets/icon/menu.png', width: 26.w),
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

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 12.h),
      child: Text(
        title,
        style: TextStyle(
            fontSize: 10.sp,
            fontWeight: FontWeight.w900,
            color: AppColors.slate,
            letterSpacing: 1.2),
      ),
    );
  }
}

class _GroupDrawerTile extends StatelessWidget {
  final Group group;
  final bool isSelected;
  final bool isOwned;
  final VoidCallback onTap;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  const _GroupDrawerTile({
    required this.group,
    required this.isSelected,
    required this.isOwned,
    required this.onTap,
    this.onRename,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.ink : Colors.transparent,
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Row(
            children: [
              Icon(
                isOwned ? Icons.group : Icons.group_outlined,
                size: 20.r,
                color: isSelected ? AppColors.brass : AppColors.slate,
              ),
              16.horizontalSpace,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight:
                            isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? AppColors.paper : AppColors.ink,
                      ),
                    ),
                    if (!isOwned)
                      Text(
                        'Shared by ${group.ownerName}',
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: isSelected
                              ? AppColors.brassSoft
                              : AppColors.slate,
                        ),
                      ),
                  ],
                ),
              ),
              if (isOwned && isSelected) ...[
                if (onRename != null)
                  IconButton(
                    icon: Icon(Icons.edit_outlined,
                        size: 18.r, color: AppColors.brassSoft),
                    onPressed: onRename,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                if (onDelete != null) ...[
                  8.horizontalSpace,
                  IconButton(
                    icon: Icon(Icons.delete_outline,
                        size: 18.r, color: AppColors.brassSoft),
                    onPressed: onDelete,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
