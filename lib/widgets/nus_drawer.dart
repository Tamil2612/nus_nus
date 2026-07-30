import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../models/group.dart';
import '../providers/auth_provider.dart';
import '../providers/split_provider.dart';
import '../theme/app_colors.dart';
import '../screens/group_detail_screen.dart';

class NusDrawer extends StatelessWidget {
  final String? currentGroupId;
  final bool showGroups;
  final Function(BuildContext, SplitProvider, String, String, String) onRename;
  final Function(BuildContext, SplitProvider, String, String) onDelete;
  final Function(BuildContext, SplitProvider) onAddGroup;

  const NusDrawer({
    super.key,
    this.currentGroupId,
    this.showGroups = true,
    required this.onRename,
    required this.onDelete,
    required this.onAddGroup,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SplitProvider>();

    return Drawer(
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
              final name =
                  user?.displayName ?? user?.email?.split('@').first ?? 'User';
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
                if (!showGroups) ...[
                  _DrawerActionTile(
                    icon: Icons.person_outline,
                    label: 'EDIT PROFILE',
                    onTap: () {
                      // TODO: Implement profile edit
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Settings coming soon!')),
                      );
                    },
                  ),
                  _DrawerActionTile(
                    icon: Icons.notifications_none_outlined,
                    label: 'NOTIFICATIONS',
                    onTap: () => Navigator.pop(context),
                  ),
                  _DrawerActionTile(
                    icon: Icons.security_outlined,
                    label: 'SECURITY',
                    onTap: () => Navigator.pop(context),
                  ),
                ],
                if (showGroups && provider.allOwnedGroups.isNotEmpty) ...[
                  const _SectionHeader(title: 'MY GROUPS'),
                  ...provider.allOwnedGroups.map((g) => _GroupDrawerTile(
                        group: g,
                        isSelected: currentGroupId == g.id,
                        isOwned: true,
                        onTap: () {
                          provider.selectGroup(g.id);
                          Navigator.pop(context);
                          if (currentGroupId == null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const GroupDetailScreen(),
                              ),
                            );
                          }
                        },
                        onRename: () =>
                            onRename(context, provider, g.id, g.name, g.currency),
                        onDelete: () =>
                            onDelete(context, provider, g.id, g.name),
                      )),
                  24.verticalSpace,
                ],
                if (showGroups && provider.linkedGroups.isNotEmpty) ...[
                  const _SectionHeader(title: 'SHARED WITH ME'),
                  ...provider.linkedGroups.map((g) => _GroupDrawerTile(
                        group: g,
                        isSelected: currentGroupId == g.id,
                        isOwned: false,
                        onTap: () {
                          provider.selectGroup(g.id);
                          Navigator.pop(context);
                          if (currentGroupId == null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const GroupDetailScreen(),
                              ),
                            );
                          }
                        },
                      )),
                ],
              ],
            ),
          ),

          // Footer Actions
          Container(
            padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 32.h),
            decoration: BoxDecoration(
              color: AppColors.paperDim,
              border: Border(top: BorderSide(color: AppColors.line, width: 1)),
            ),
            child: Column(
              children: [
                if (showGroups) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        onAddGroup(context, provider);
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
                  16.verticalSpace,
                ],
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      await context.read<AuthProvider>().signOut();
                    },
                    icon:
                        const Icon(Icons.logout_rounded, size: 18),
                    label: Text(
                      'SIGN OUT',
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12.sp,
                          letterSpacing: 1.2),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.rust,
                      side: const BorderSide(color: AppColors.rust, width: 1.5),
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r)),
                    ),
                  ),
                ),
                24.verticalSpace,
                Text(
                  'نص نص • NUS·NUS v1.0.0',
                  style: TextStyle(
                    color: AppColors.slate.withValues(alpha: 0.6),
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DrawerActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(8.r),
        decoration: BoxDecoration(
          color: AppColors.brass.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Icon(icon, color: AppColors.brass, size: 20.r),
      ),
      title: Text(
        label,
        style: TextStyle(
          color: AppColors.ink,
          fontSize: 13.sp,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
      trailing: Icon(Icons.chevron_right_rounded,
          color: AppColors.slate.withValues(alpha: 0.4), size: 20.r),
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 4.h),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 12.h),
      child: Text(
        title,
        style: TextStyle(
            fontSize: 9.sp,
            fontWeight: FontWeight.w900,
            color: AppColors.slate.withValues(alpha: 0.8),
            letterSpacing: 1.5),
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
