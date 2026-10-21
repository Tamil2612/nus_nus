import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../models/group.dart';
import '../providers/auth_provider.dart';
import '../providers/split_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';
import '../widgets/header_bar.dart';
import '../widgets/people_tab.dart';
import '../widgets/nus_drawer.dart';
import '../widgets/app_dialog.dart';
import 'ai_expense_screen.dart';
import 'group_detail_screen.dart';
import 'personal_ledger_screen.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
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

  void _showAddGroup(BuildContext context, SplitProvider provider) {
    final ctrl = TextEditingController();
    final user = context.read<AuthProvider>().currentUser;
    final ownerName =
        user?.displayName ?? user?.email?.split('@').first ?? 'Someone';
    String selectedCurrency = 'AED';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (context, setDialogState) {
        return AppDialog(
          icon: Icons.group_add_outlined,
          iconColor: AppColors.brass,
          title: 'New Group',
          confirmText: 'Create',
          confirmColor: AppColors.brass,
          onConfirm: () {
            if (ctrl.text.trim().isNotEmpty) {
              provider.addGroup(ctrl.text,
                  ownerName: ownerName, currency: selectedCurrency);
              Navigator.pop(ctx);
            }
          },
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                autofocus: true,
                style: TextStyle(color: AppColors.ink, fontSize: 15.sp),
                decoration:
                    AppTheme.inputDecoration('Group Name (e.g. Vacation)')
                        .copyWith(filled: false),
              ),
              16.verticalSpace,
              DropdownButtonFormField<String>(
                initialValue: selectedCurrency,
                dropdownColor: AppColors.paper,
                style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 15.sp,
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
        return AppDialog(
          icon: Icons.edit_outlined,
          iconColor: AppColors.brass,
          title: 'Rename Group',
          confirmText: 'Save',
          confirmColor: AppColors.brass,
          onConfirm: () {
            if (ctrl.text.trim().isNotEmpty) {
              provider.renameGroup(groupId, ctrl.text.trim(),
                  newCurrency: selectedCurrency);
              Navigator.pop(ctx);
            }
          },
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                autofocus: true,
                style: TextStyle(color: AppColors.ink, fontSize: 15.sp),
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
                    fontSize: 15.sp,
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
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SplitProvider>();
    final requestedTab = provider.takeLandingTabRequest();
    if (requestedTab != null && requestedTab != _tabController.index) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _tabController.animateTo(requestedTab);
      });
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.ink,
      drawer: NusDrawer(
        showGroups: false,
        onRename: (a, b, c, d, e) {},
        onDelete: (a, b, c, d) {},
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
        child: SafeArea(
          child: Column(
            children: [
              const HeaderBar(),
              Padding(
                padding: EdgeInsets.fromLTRB(18.w, 4.h, 18.w, 8.h),
                child: Container(
                  padding: EdgeInsets.all(4.r),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .055),
                    borderRadius: BorderRadius.circular(17.r),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: .09)),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    labelColor: AppColors.ink,
                    unselectedLabelColor:
                        AppColors.paper.withValues(alpha: .68),
                    indicator: BoxDecoration(
                      color: AppColors.brassSoft,
                      borderRadius: BorderRadius.circular(13.r),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicatorPadding: EdgeInsets.all(2.r),
                    dividerColor: Colors.transparent,
                    overlayColor: WidgetStatePropertyAll(
                        Colors.white.withValues(alpha: .04)),
                    labelStyle: TextStyle(
                        fontSize: 11.5.sp, fontWeight: FontWeight.w800),
                    unselectedLabelStyle: TextStyle(
                        fontSize: 11.5.sp, fontWeight: FontWeight.w600),
                    tabs: [
                      Tab(
                        height: 48.h,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.account_balance_wallet_outlined,
                                size: 18.r),
                            7.horizontalSpace,
                            const Text('My Spend'),
                          ],
                        ),
                      ),
                      Tab(
                        height: 48.h,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.groups_2_outlined, size: 19.r),
                            7.horizontalSpace,
                            const Text('People'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _HomeTab(
                      onRenamePersonal: _showRenameGroup,
                      onAddGroup: () => _showAddGroup(context, provider),
                    ),
                    const PeopleTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: MediaQuery.viewInsetsOf(context).bottom > 0
          ? null
          : FloatingActionButton.extended(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AiExpenseScreen())),
              backgroundColor: AppColors.brass,
              foregroundColor: AppColors.ink,
              icon: Icon(Icons.auto_awesome, size: 20.sp),
              label: Text('Nus AI',
                  style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp)),
            ),
    );
  }
}

class _HomeTab extends StatefulWidget {
  final Function(BuildContext, SplitProvider, String, String, String)
      onRenamePersonal;
  final VoidCallback onAddGroup;

  const _HomeTab({required this.onRenamePersonal, required this.onAddGroup});

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SplitProvider>();
    final user = context.watch<AuthProvider>().currentUser;
    final personal = provider.personalGroup;
    final shared = provider.sharedGroups;
    final firstName = user?.displayName?.trim().split(' ').first;
    final greeting = switch (DateTime.now().hour) {
      < 12 => 'Good morning',
      < 17 => 'Good afternoon',
      _ => 'Good evening',
    };

    return ListView(
      padding: EdgeInsets.fromLTRB(18.w, 12.h, 18.w, 104.h),
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(2.w, 0, 2.w, 20.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting${firstName == null || firstName.isEmpty ? '' : ', $firstName'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.paper,
                  fontSize: 21.sp,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.3,
                ),
              ),
              4.verticalSpace,
              Text(
                'Your spending, all in one place.',
                style: TextStyle(color: AppColors.slate, fontSize: 12.sp),
              ),
            ],
          ),
        ),
        _PersonalCard(
          group: personal,
          loading: provider.isLoading || provider.isEnsuringPersonalGroup,
          onEdit: personal == null
              ? null
              : () => widget.onRenamePersonal(context, provider, personal.id,
                  personal.name, personal.currency),
        ),
        28.verticalSpace,
        Row(
          children: [
            const Expanded(
              child: _SectionHeader(
                  title: 'Shared groups', subtitle: 'Spending together'),
            ),
            FilledButton.icon(
              onPressed: widget.onAddGroup,
              icon: Icon(Icons.add, size: 17.r),
              label: Text('New group', style: TextStyle(fontSize: 11.sp)),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brass.withValues(alpha: .18),
                foregroundColor: AppColors.brassSoft,
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 9.h),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13.r)),
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          ],
        ),
        14.verticalSpace,
        InkWell(
          borderRadius: BorderRadius.circular(17.r),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const _GroupSearchScreen()),
          ),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 15.h),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .055),
              borderRadius: BorderRadius.circular(17.r),
              border: Border.all(color: Colors.white.withValues(alpha: .1)),
            ),
            child: Row(
              children: [
                Icon(Icons.search_rounded,
                    color: AppColors.brassSoft, size: 21.r),
                11.horizontalSpace,
                Expanded(
                  child: Text('Search your groups',
                      style:
                          TextStyle(color: AppColors.slate, fontSize: 13.sp)),
                ),
                Icon(Icons.tune_rounded,
                    color: AppColors.slate.withValues(alpha: .8), size: 18.r),
              ],
            ),
          ),
        ),
        4.verticalSpace,
        if (shared.isEmpty)
          Padding(
            padding: EdgeInsets.only(top: 12.h),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 22.h),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .045),
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(color: Colors.white.withValues(alpha: .08)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44.r,
                    height: 44.r,
                    decoration: BoxDecoration(
                      color: AppColors.brass.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    child: Icon(Icons.groups_2_outlined,
                        color: AppColors.brassSoft, size: 23.r),
                  ),
                  14.horizontalSpace,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bring a group together',
                            style: TextStyle(
                                color: AppColors.paper,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w700)),
                        4.verticalSpace,
                        Text('Share costs and keep every split clear.',
                            style: TextStyle(
                                color: AppColors.slate, fontSize: 11.sp)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...shared.map((g) => _GroupTile(group: g)),
      ],
    );
  }
}

class _GroupSearchScreen extends StatefulWidget {
  const _GroupSearchScreen();

  @override
  State<_GroupSearchScreen> createState() => _GroupSearchScreenState();
}

class _GroupSearchScreenState extends State<_GroupSearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groups = context.watch<SplitProvider>().sharedGroups;
    final filtered = groups
        .where((group) => group.name.toLowerCase().contains(_query))
        .toList();

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.ink,
      appBar: AppBar(
        backgroundColor: AppColors.ink,
        foregroundColor: AppColors.paper,
        title: Text('Find a group',
            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(18.w, 10.h, 18.w, 16.h),
              child: TextField(
                autofocus: true,
                controller: _controller,
                onChanged: (value) =>
                    setState(() => _query = value.trim().toLowerCase()),
                style: TextStyle(color: AppColors.paper, fontSize: 14.sp),
                decoration: InputDecoration(
                  hintText: 'Search by group name',
                  hintStyle: TextStyle(color: AppColors.slate, fontSize: 13.sp),
                  prefixIcon: Icon(Icons.search_rounded,
                      color: AppColors.brassSoft, size: 22.r),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _controller.clear();
                            setState(() => _query = '');
                          },
                          icon: Icon(Icons.close_rounded,
                              color: AppColors.slate, size: 20.r),
                        ),
                  filled: true,
                  fillColor: AppColors.inkSoft,
                  contentPadding: EdgeInsets.symmetric(vertical: 16.h),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(17.r),
                    borderSide:
                        BorderSide(color: Colors.white.withValues(alpha: .1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(17.r),
                    borderSide: BorderSide(
                        color: AppColors.brass.withValues(alpha: .8),
                        width: 1.4),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(22.w, 0, 22.w, 8.h),
              child: Row(
                children: [
                  Text(_query.isEmpty ? 'YOUR GROUPS' : 'SEARCH RESULTS',
                      style: TextStyle(
                          color: AppColors.brassSoft,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2)),
                  const Spacer(),
                  Text('${filtered.length}',
                      style: TextStyle(
                          color: AppColors.slate,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Padding(
                        padding: EdgeInsets.all(28.w),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 60.r,
                              height: 60.r,
                              decoration: BoxDecoration(
                                color: AppColors.brass.withValues(alpha: .14),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                  _query.isEmpty
                                      ? Icons.groups_2_outlined
                                      : Icons.search_off_rounded,
                                  color: AppColors.brassSoft,
                                  size: 28.r),
                            ),
                            14.verticalSpace,
                            Text(
                              _query.isEmpty
                                  ? 'No groups yet'
                                  : 'No groups match “${_controller.text}”',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: AppColors.paper,
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w700),
                            ),
                            6.verticalSpace,
                            Text(
                              _query.isEmpty
                                  ? 'Create a group to start sharing expenses.'
                                  : 'Try another group name.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: AppColors.slate, fontSize: 12.sp),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.fromLTRB(18.w, 0, 18.w, 20.h),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) =>
                          _GroupTile(group: filtered[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _SectionHeader({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w800,
            color: AppColors.paper,
          ),
        ),
        if (subtitle != null) ...[
          3.verticalSpace,
          Text(subtitle!,
              style: TextStyle(color: AppColors.slate, fontSize: 10.5.sp)),
        ],
      ],
    );
  }
}

class _PersonalCard extends StatelessWidget {
  final Group? group;
  final bool loading;
  final VoidCallback? onEdit;

  const _PersonalCard({this.group, required this.loading, this.onEdit});

  @override
  Widget build(BuildContext context) {
    if (group == null) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 17.h),
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Row(
          children: [
            if (loading)
              SizedBox(
                width: 24.r,
                height: 24.r,
                child: const CircularProgressIndicator(
                  color: AppColors.brass,
                  strokeWidth: 2.5,
                ),
              )
            else
              Icon(Icons.receipt_long_outlined,
                  color: AppColors.slate, size: 24.r),
            14.horizontalSpace,
            Expanded(
              child: Text(
                loading
                    ? 'Preparing your personal ledger…'
                    : 'Your personal ledger is unavailable.',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (!loading)
              IconButton(
                tooltip: 'Retry',
                onPressed:
                    context.read<SplitProvider>().retryPersonalGroupCreation,
                icon: Icon(Icons.refresh_rounded,
                    color: AppColors.brass, size: 21.r),
              ),
          ],
        ),
      );
    }

    final total = group?.expenses.fold(0.0, (sum, e) => sum + e.amount) ?? 0.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22.r),
        onTap: () {
          context.read<SplitProvider>().selectGroup(group!.id);
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const PersonalLedgerScreen()));
        },
        child: Ink(
          padding: EdgeInsets.all(17.w),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.paper, AppColors.paperDim],
            ),
            borderRadius: BorderRadius.circular(22.r),
            border: Border.all(color: Colors.white.withValues(alpha: .62)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 18,
                  offset: const Offset(0, 7)),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 44.r,
                    height: 44.r,
                    decoration: BoxDecoration(
                      color: AppColors.ink,
                      borderRadius: BorderRadius.circular(15.r),
                    ),
                    child: Icon(Icons.person_outline,
                        color: AppColors.brassSoft, size: 24.r),
                  ),
                  12.horizontalSpace,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('PERSONAL LEDGER',
                            style: TextStyle(
                                fontSize: 9.sp,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.05,
                                color: AppColors.slate)),
                        3.verticalSpace,
                        Text('My expenses',
                            style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink)),
                      ],
                    ),
                  ),
                  if (onEdit != null)
                    Padding(
                      padding: EdgeInsets.only(right: 7.w),
                      child: Material(
                        color: AppColors.brass.withValues(alpha: .18),
                        borderRadius: BorderRadius.circular(13.r),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(13.r),
                          onTap: onEdit,
                          child: SizedBox(
                            width: 42.r,
                            height: 42.r,
                            child: Tooltip(
                              message: 'Edit personal ledger',
                              child: Icon(Icons.edit_rounded,
                                  color: AppColors.ink, size: 19.r),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Container(
                    width: 34.r,
                    height: 34.r,
                    decoration: BoxDecoration(
                      color: AppColors.ink.withValues(alpha: .07),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.arrow_outward_rounded,
                        color: AppColors.ink.withValues(alpha: .65),
                        size: 17.r),
                  ),
                ],
              ),
              14.verticalSpace,
              Divider(height: 1, color: AppColors.ink.withValues(alpha: .12)),
              12.verticalSpace,
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('TOTAL SPENT',
                            style: TextStyle(
                                color: AppColors.slate,
                                fontSize: 9.sp,
                                fontWeight: FontWeight.w800,
                                letterSpacing: .8)),
                        3.verticalSpace,
                        Text(fmtCurrency(total, group?.currency ?? 'AED'),
                            style: TextStyle(
                                fontSize: 22.sp,
                                fontWeight: FontWeight.w900,
                                color: AppColors.ink)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupTile extends StatelessWidget {
  final Group group;

  const _GroupTile({required this.group});

  @override
  Widget build(BuildContext context) {
    final total =
        group.expenses.fold<double>(0, (sum, expense) => sum + expense.amount);
    return GestureDetector(
      onTap: () {
        context.read<SplitProvider>().selectGroup(group.id);
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const GroupDetailScreen()));
      },
      child: Container(
        margin: EdgeInsets.only(top: 12.h),
        padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .055),
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(color: Colors.white.withValues(alpha: .09)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .1),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46.r,
              height: 46.r,
              decoration: BoxDecoration(
                color: AppColors.brass.withValues(alpha: .16),
                borderRadius: BorderRadius.circular(14.r),
              ),
              child: Icon(Icons.groups_rounded,
                  color: AppColors.brassSoft, size: 23.r),
            ),
            12.horizontalSpace,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(group.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: AppColors.paper,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w800)),
                  5.verticalSpace,
                  Row(
                    children: [
                      Icon(Icons.people_alt_outlined,
                          color: AppColors.slate, size: 13.r),
                      4.horizontalSpace,
                      Text('${group.members.length} members',
                          style: TextStyle(
                              color: AppColors.slate, fontSize: 10.5.sp)),
                    ],
                  ),
                ],
              ),
            ),
            8.horizontalSpace,
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(fmtCurrency(total, group.currency),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: AppColors.paper,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w800)),
                5.verticalSpace,
                Icon(Icons.arrow_forward_rounded,
                    color: AppColors.brassSoft, size: 16.r),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
