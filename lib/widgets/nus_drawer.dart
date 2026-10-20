import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../models/group.dart';
import '../providers/auth_provider.dart';
import 'app_loading_overlay.dart';
import '../providers/split_provider.dart';
import '../theme/app_colors.dart';
import '../screens/group_detail_screen.dart';
import '../screens/edit_profile_screen.dart';
import '../services/notification_service.dart';

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
    final notificationUid = context.watch<AuthProvider>().currentUser?.uid;

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
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EditProfileScreen(),
                        ),
                      );
                    },
                  ),
                  if (notificationUid != null)
                    _NotificationOptInTile(uid: notificationUid),
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
                        onRename: () => onRename(
                            context, provider, g.id, g.name, g.currency),
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
                      AppLoadingOverlay.show('Signing out…');
                      String? error;
                      try {
                        await context.read<AuthProvider>().signOut();
                      } catch (e) {
                        debugPrint('Sign out failed: $e');
                        error = 'Could not sign out. Please try again.';
                      } finally {
                        AppLoadingOverlay.hide();
                      }
                      if (error != null && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(error),
                            backgroundColor: AppColors.rust,
                            behavior: SnackBarBehavior.fixed,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.logout_rounded, size: 18),
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
                  'NUS·NUS v1.0.0',
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

class _NotificationOptInTile extends StatefulWidget {
  final String uid;

  const _NotificationOptInTile({required this.uid});

  @override
  State<_NotificationOptInTile> createState() => _NotificationOptInTileState();
}

class _NotificationOptInTileState extends State<_NotificationOptInTile> {
  late Future<NotificationEnableResult> _statusFuture;
  bool _isEnabling = false;
  NotificationEnableResult? _result;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  @override
  void didUpdateWidget(covariant _NotificationOptInTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid) _refreshStatus();
  }

  void _refreshStatus() {
    _result = null;
    _statusFuture = NotificationService.instance.statusFor(widget.uid);
  }

  Future<void> _enable() async {
    if (_isEnabling) return;
    setState(() => _isEnabling = true);
    // The service requests permission before awaiting anything else, preserving
    // Safari's user activation from this tap.
    final result =
        await NotificationService.instance.enableNotifications(widget.uid);
    if (!mounted) return;
    setState(() {
      _isEnabling = false;
      _result = result;
      _statusFuture = Future.value(result);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<NotificationEnableResult>(
      future: _statusFuture,
      builder: (context, snapshot) {
        final result = _result ?? snapshot.data;
        final status = result?.status;
        final loadingStatus = !snapshot.hasData && _result == null;
        final enabled = status == NotificationEnableStatus.enabled;
        final denied = status == NotificationEnableStatus.permissionDenied;
        final unsupported = status == NotificationEnableStatus.unsupported;
        final missingConfig =
            status == NotificationEnableStatus.missingConfiguration;

        String description;
        if (loadingStatus) {
          description = 'Checking notification availability…';
        } else if (enabled) {
          description = 'Notifications are enabled on this device.';
        } else if (denied) {
          description = kIsWeb
              ? 'Permission was denied. On iPhone, allow it in Settings → Notifications → Nus·Nus or Safari website settings, then check again.'
              : 'Permission was denied. Allow notifications in your device settings, then check again.';
        } else if (unsupported) {
          description = kIsWeb
              ? 'This browser does not support Web Push. On iPhone, use an installed Home Screen web app with iOS 16.4 or later.'
              : 'Notifications are not supported on this device.';
        } else if (missingConfig) {
          description =
              'Web Push is not configured for this build. Set FIREBASE_VAPID_KEY and rebuild.';
        } else if (result?.status ==
            NotificationEnableStatus.registrationFailed) {
          description = kIsWeb
              ? '${result?.message ?? 'Registration failed.'} On iPhone, launch the installed Home Screen app on iOS/iPadOS 16.4 or later.'
              : result?.message ??
                  'Registration failed. Check your connection and try again.';
        } else {
          description = 'Get updates about new group activity.';
        }

        final canEnable = !loadingStatus &&
            !enabled &&
            !unsupported &&
            !missingConfig &&
            !denied;

        return Container(
          margin: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .58),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    enabled
                        ? Icons.notifications_active_outlined
                        : Icons.notifications_none_outlined,
                    color: enabled ? AppColors.sage : AppColors.inkSoft,
                    size: 21.r,
                  ),
                  10.horizontalSpace,
                  Expanded(
                    child: Text(
                      'Notifications',
                      style: TextStyle(
                        color: AppColors.ink,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (enabled)
                    Icon(Icons.check_circle, color: AppColors.sage, size: 19.r),
                ],
              ),
              7.verticalSpace,
              Text(
                description,
                style: TextStyle(
                  color: AppColors.slate,
                  fontSize: 11.sp,
                  height: 1.35,
                ),
              ),
              if (_isEnabling) ...[
                12.verticalSpace,
                const LinearProgressIndicator(color: AppColors.brass),
              ] else if (canEnable) ...[
                10.verticalSpace,
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _enable,
                    icon: const Icon(Icons.notifications_active_outlined),
                    label: const Text('Enable notifications'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.ink,
                      foregroundColor: AppColors.paper,
                      padding: EdgeInsets.symmetric(vertical: 11.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                  ),
                ),
              ] else if (denied) ...[
                TextButton.icon(
                  onPressed: () => setState(_refreshStatus),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Check permission again'),
                ),
              ],
              if (kIsWeb)
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.only(bottom: 4.h),
                  title: Text(
                    'iPhone setup',
                    style: TextStyle(
                      color: AppColors.inkSoft,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  children: [
                    Text(
                      'On iOS/iPadOS 16.4 or later: open Nus·Nus in Safari, '
                      'tap Share → Add to Home Screen, enable “Open as Web App” '
                      'if shown, then launch the Home Screen app, sign in, and '
                      'tap Enable notifications. Installing it does not open '
                      'the permission prompt by itself.',
                      style: TextStyle(
                        color: AppColors.slate,
                        fontSize: 10.5.sp,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
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
