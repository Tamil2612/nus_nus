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
    final ownerName = user?.displayName ?? user?.email?.split('@').first ?? 'Someone';
    String selectedCurrency = 'AED';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          backgroundColor: AppColors.paper,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
          title: const Text('New Group',
              style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                autofocus: true,
                style: TextStyle(color: AppColors.ink, fontSize: 16.sp),
                decoration: AppTheme.inputDecoration('Group Name (e.g. Vacation)')
                    .copyWith(filled: false),
              ),
              16.verticalSpace,
              DropdownButtonFormField<String>(
                initialValue: selectedCurrency,
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
              child: const Text('Cancel', style: TextStyle(color: AppColors.slate)),
            ),
            ElevatedButton(
              onPressed: () {
                if (ctrl.text.trim().isNotEmpty) {
                  provider.addGroup(ctrl.text, ownerName: ownerName, currency: selectedCurrency);
                  Navigator.pop(ctx);
                }
              },
              style: AppTheme.solidButton.copyWith(
                padding: WidgetStateProperty.all(EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h)),
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SplitProvider>();

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
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
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
                  labelStyle: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
                  tabs: const [
                    Tab(text: 'My Spend'),
                    Tab(text: 'People'),
                  ],
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiExpenseScreen())),
        backgroundColor: AppColors.brass,
        foregroundColor: AppColors.ink,
        icon: Icon(Icons.auto_awesome, size: 20.sp),
        label: Text('Nus AI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp)),
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  final Function(BuildContext, SplitProvider, String, String, String) onRenamePersonal;
  final VoidCallback onAddGroup;

  const _HomeTab({required this.onRenamePersonal, required this.onAddGroup});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SplitProvider>();
    final personal = provider.personalGroup;
    final shared = provider.sharedGroups;

    return ListView(
      padding: EdgeInsets.all(20.w),
      children: [
        // Personal Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const _SectionHeader(title: 'PERSONAL SPENDING'),
            if (personal != null)
              IconButton(
                onPressed: () => onRenamePersonal(
                    context, provider, personal.id, personal.name, personal.currency),
                icon: Icon(Icons.edit_outlined, color: AppColors.brassSoft, size: 18.r),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
        12.verticalSpace,
        _PersonalCard(group: personal),
        
        32.verticalSpace,

        // Groups Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _SectionHeader(title: 'SHARED GROUPS'),
            IconButton(
              onPressed: onAddGroup,
              icon: Icon(Icons.add_circle_outline, color: AppColors.brass, size: 24.r),
            ),
          ],
        ),
        if (shared.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 40.h),
            child: Center(
              child: Text(
                'No shared groups yet.\nTap + to create one!',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.slate, fontSize: 14.sp),
              ),
            ),
          )
        else
          ...shared.map((g) => _GroupTile(group: g)),
        
        100.verticalSpace,
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 11.sp,
        fontWeight: FontWeight.w900,
        color: AppColors.brassSoft,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _PersonalCard extends StatelessWidget {
  final Group? group;
  const _PersonalCard({this.group});

  @override
  Widget build(BuildContext context) {
    final total = group?.expenses.fold(0.0, (sum, e) => sum + e.amount) ?? 0.0;

    return GestureDetector(
      onTap: () {
        if (group != null) {
          context.read<SplitProvider>().selectGroup(group!.id);
          Navigator.push(
              context, MaterialPageRoute(builder: (_) => const PersonalLedgerScreen()));
        }
      },
      child: Container(
        padding: EdgeInsets.all(24.w),
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(24.r),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 15,
                offset: const Offset(0, 8)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12.r),
              decoration:
                  BoxDecoration(color: AppColors.ink, shape: BoxShape.circle),
              child:
                  Icon(Icons.person_outline, color: AppColors.brass, size: 28.r),
            ),
            20.horizontalSpace,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('My Expenses',
                      style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink)),
                  4.verticalSpace,
                  Text('Track individual spending',
                      style: TextStyle(fontSize: 12.sp, color: AppColors.slate)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(fmtCurrency(total, group?.currency ?? 'AED'),
                    style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w900,
                        color: AppColors.ink)),
                Text('TOTAL',
                    style: TextStyle(
                        fontSize: 9.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.slate,
                        letterSpacing: 1)),
              ],
            ),
          ],
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
    return GestureDetector(
      onTap: () {
        context.read<SplitProvider>().selectGroup(group.id);
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const GroupDetailScreen()));
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 16.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .06),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: AppColors.line.withValues(alpha: .2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48.r,
              height: 48.r,
              decoration: BoxDecoration(
                color: AppColors.brass.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14.r),
              ),
              child: Icon(Icons.groups_rounded,
                  color: AppColors.brass, size: 24.r),
            ),
            16.horizontalSpace,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(group.name,
                      style: TextStyle(
                          color: AppColors.paper,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w800)),
                  Text('${group.members.length} members',
                      style: TextStyle(color: AppColors.slate, fontSize: 12.sp)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                color: AppColors.slate.withValues(alpha: 0.5), size: 14.r),
          ],
        ),
      ),
    );
  }
}


