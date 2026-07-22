import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../data/member_directory_repository.dart';
import '../models/app_user.dart';
import '../providers/split_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Opens a bottom sheet listing every registered account, letting the user
/// pick one to add to the current group (linked via [Person.linkedUserId]
/// rather than just copying their name in as a free-text label).
void showAddRegisteredMemberSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _AddRegisteredMemberSheet(),
  );
}

class _AddRegisteredMemberSheet extends StatefulWidget {
  const _AddRegisteredMemberSheet();

  @override
  State<_AddRegisteredMemberSheet> createState() =>
      _AddRegisteredMemberSheetState();
}

class _AddRegisteredMemberSheetState
    extends State<_AddRegisteredMemberSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SplitProvider>();
    final alreadyLinked = provider.people
        .map((p) => p.linkedUserId)
        .whereType<String>()
        .toSet();

    return Container(
      height: 0.75.sh,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      child: Column(
        children: [
          16.verticalSpace,
          Container(
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: AppColors.line,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          16.verticalSpace,
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Text(
              'Add a registered member',
              style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.ink),
            ),
          ),
          16.verticalSpace,
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: TextField(
              controller: _searchCtrl,
              style: TextStyle(color: AppColors.ink, fontSize: 13.5.sp),
              decoration: AppTheme.inputDecoration('Search by name or email')
                  .copyWith(prefixIcon: const Icon(Icons.search, color: AppColors.slate)),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
          16.verticalSpace,
          Expanded(
            child: StreamBuilder<List<AppUser>>(
              stream: MemberDirectoryRepository.instance.watchAll(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.brass),
                  );
                }
                final users = (snapshot.data ?? [])
                    .where((u) =>
                        _query.isEmpty ||
                        u.name.toLowerCase().contains(_query) ||
                        u.email.toLowerCase().contains(_query))
                    .toList();

                if (users.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.w),
                      child: Text(
                        'No registered members found.',
                        style: TextStyle(color: AppColors.slate, fontSize: 13.sp),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  itemCount: users.length,
                  separatorBuilder: (_, __) =>
                      Divider(color: AppColors.line, height: 1.h),
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final alreadyInGroup = alreadyLinked.contains(user.uid);
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.brass,
                        child: Text(
                          user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(user.name,
                          style: TextStyle(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5.sp)),
                      subtitle: Text(user.email,
                          style:
                              TextStyle(color: AppColors.slate, fontSize: 11.5.sp)),
                      trailing: alreadyInGroup
                          ? Icon(Icons.check_circle, color: AppColors.sage, size: 20.r)
                          : Icon(Icons.add_circle_outline,
                              color: AppColors.brass, size: 20.r),
                      onTap: alreadyInGroup
                          ? null
                          : () {
                              provider.addPerson(user.name, linkedUserId: user.uid);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${user.name} added to the group.'),
                                  backgroundColor: AppColors.sage,
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                              Navigator.pop(context);
                            },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
