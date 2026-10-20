import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/split_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/balances_tab.dart';
import '../widgets/branded_loader.dart';
import '../widgets/ledger_tab.dart';
import '../widgets/group_chat_tab.dart';
import '../widgets/expense_form_sheet.dart';
import 'ai_expense_screen.dart';
import 'group_members_screen.dart';

class GroupDetailScreen extends StatefulWidget {
  const GroupDetailScreen({super.key});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late int _selectedTabIndex;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _selectedTabIndex = _tabController.index;
    _tabController.addListener(() {
      if (_tabController.index != _selectedTabIndex) {
        _selectedTabIndex = _tabController.index;
        setState(() {});
      }
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SplitProvider>();
    final currentGroup = provider.currentGroup;

    if (provider.isLoading) {
      return const BrandedLoader(message: 'Getting your groups ready…');
    }

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68.h,
        leadingWidth: 48.w,
        titleSpacing: 0,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          icon: Icon(Icons.arrow_back, color: AppColors.paper, size: 23.r),
          onPressed: () => Navigator.pop(context),
        ),
        title: currentGroup == null
            ? Text('Groups',
                style: TextStyle(color: AppColors.paper, fontSize: 20.sp))
            : InkWell(
                borderRadius: BorderRadius.circular(8.r),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GroupMembersScreen()),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 5.h),
                  child: Row(
                    children: [
                      Container(
                        width: 34.r,
                        height: 34.r,
                        decoration: BoxDecoration(
                          color: AppColors.brassSoft.withValues(alpha: .14),
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Icon(Icons.groups_2_outlined,
                            color: AppColors.brassSoft, size: 20.r),
                      ),
                      9.horizontalSpace,
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(currentGroup.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: AppColors.paper,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 19.sp)),
                            2.verticalSpace,
                            Text(
                              '${currentGroup.members.length} ${currentGroup.members.length == 1 ? 'member' : 'members'}',
                              style: TextStyle(
                                color: AppColors.paper.withValues(alpha: .72),
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        actions: [
          if (provider.isCurrentGroupOwner)
            IconButton(
              tooltip: 'Group members and settings',
              icon: const Icon(Icons.settings_outlined,
                  color: AppColors.brassSoft),
              onPressed: currentGroup == null
                  ? null
                  : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const GroupMembersScreen()),
                      ),
            ),
          12.horizontalSpace,
        ],
      ),
      floatingActionButton: _selectedTabIndex == 0
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.small(
                  heroTag: 'group_detail_fab_ai',
                  tooltip: 'Nus AI',
                  backgroundColor: AppColors.brass,
                  foregroundColor: AppColors.ink,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AiExpenseScreen()),
                    );
                  },
                  child: Image.asset(
                    'assets/icon/ai.png',
                    width: 18.w,
                    height: 18.w,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.auto_awesome, size: 18),
                  ),
                ),
                10.verticalSpace,
                FloatingActionButton.extended(
                  heroTag: 'group_detail_fab_add_split',
                  tooltip: 'Add Split',
                  backgroundColor: AppColors.brass,
                  foregroundColor: AppColors.ink,
                  onPressed: () => showExpenseFormSheet(context),
                  icon: const Icon(Icons.add),
                  label: Text(
                    'Add Split',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp),
                  ),
                ),
              ],
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
                      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 10.h),
                      child: Container(
                        padding: EdgeInsets.all(4.r),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.045),
                          borderRadius: BorderRadius.circular(16.r),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.09)),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          dividerColor: Colors.transparent,
                          indicatorSize: TabBarIndicatorSize.tab,
                          indicatorPadding: EdgeInsets.all(2.r),
                          indicator: BoxDecoration(
                            color: AppColors.brassSoft,
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          labelColor: AppColors.ink,
                          unselectedLabelColor:
                              AppColors.paper.withValues(alpha: .72),
                          overlayColor:
                              WidgetStateProperty.all(Colors.transparent),
                          labelPadding: EdgeInsets.zero,
                          tabs: [
                            _buildGroupTab('Chat', Icons.chat_bubble_outline),
                            _buildGroupTab(
                                'Expenses', Icons.receipt_long_outlined),
                            _buildGroupTab('Balances',
                                Icons.account_balance_wallet_outlined),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          const GroupChatTab(),
                          LedgerTab(),
                          BalancesTab(),
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

Widget _buildGroupTab(String label, IconData icon) {
  return Tab(
    height: 44.h,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17.r),
        5.horizontalSpace,
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10.5.sp, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
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
