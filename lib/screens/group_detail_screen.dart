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
import '../utils/currency_formatter.dart';
import '../widgets/ledger_tab.dart';
import '../widgets/expense_form_sheet.dart';
import '../widgets/nus_drawer.dart';

import 'ai_expense_screen.dart';

class GroupDetailScreen extends StatefulWidget {
  const GroupDetailScreen({super.key});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {});
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
                decoration:
                    AppTheme.inputDecoration('Group Name (e.g. Vacation)')
                        .copyWith(
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
      key: _scaffoldKey,
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
            Text(
              currentGroup?.name ?? 'Group',
              style: TextStyle(
                color: AppColors.paper,
                fontWeight: FontWeight.bold,
                fontSize: 18.sp,
              ),
            ),
            if (currentGroup != null)
              Text(
                fmtCurrency(totalSpent, currentGroup.currency),
                style: TextStyle(
                  color: AppColors.brassSoft,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        actions: [
          if (provider.isCurrentGroupOwner)
            IconButton(
              icon: const Icon(Icons.settings_outlined,
                  color: AppColors.brassSoft),
              onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
            ),
          12.horizontalSpace,
        ],
      ),
      endDrawer: NusDrawer(
        currentGroupId: currentGroup?.id,
        onRename: _showRenameGroup,
        onDelete: _confirmDeleteGroup,
        onAddGroup: _showAddGroup,
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
                    Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
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
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.arrow_back,
                      color: AppColors.paper, size: 26.w),
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


