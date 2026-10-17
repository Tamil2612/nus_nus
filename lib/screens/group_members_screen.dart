import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../models/person.dart';
import '../providers/split_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/add_member_sheet.dart';

/// Searchable roster opened by tapping a group's name in the app bar.
class GroupMembersScreen extends StatefulWidget {
  const GroupMembersScreen({super.key});

  @override
  State<GroupMembersScreen> createState() => _GroupMembersScreenState();
}

class _GroupMembersScreenState extends State<GroupMembersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SplitProvider>();
    final group = provider.currentGroup;
    final members = (group?.members ?? const <Person>[])
        .where((member) => !member.archived)
        .where((member) =>
            _query.isEmpty ||
            member.name.toLowerCase().contains(_query) ||
            (member.linkedUserId != null && 'registered member'.contains(_query)))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return Scaffold(
      backgroundColor: AppColors.ink,
      appBar: AppBar(
        backgroundColor: AppColors.ink,
        foregroundColor: AppColors.paper,
        title: Text(group?.name ?? 'Group members'),
      ),
      body: SafeArea(
        child: group == null
            ? const Center(
                child: Text('No group selected.',
                    style: TextStyle(color: AppColors.paper)),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(18.w, 16.h, 18.w, 10.h),
                    child: Container(
                      padding: EdgeInsets.all(16.r),
                      decoration: BoxDecoration(
                        color: AppColors.inkSoft,
                        borderRadius: BorderRadius.circular(18.r),
                        border: Border.all(color: AppColors.brass.withValues(alpha: .3)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48.r,
                            height: 48.r,
                            decoration: const BoxDecoration(
                              color: AppColors.brass,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.groups_2_outlined,
                                color: AppColors.ink, size: 25.r),
                          ),
                          14.horizontalSpace,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(group.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: AppColors.paper,
                                      fontSize: 17.sp,
                                      fontWeight: FontWeight.bold,
                                    )),
                                4.verticalSpace,
                                Text(
                                  '${members.length} active ${members.length == 1 ? 'member' : 'members'}',
                                  style: TextStyle(
                                      color: AppColors.brassSoft,
                                      fontSize: 12.sp),
                                ),
                              ],
                            ),
                          ),
                          if (provider.isCurrentGroupOwner)
                            IconButton.filled(
                              tooltip: 'Add members',
                              onPressed: () => showAddMemberSheet(context),
                              style: IconButton.styleFrom(
                                backgroundColor: AppColors.brass,
                                foregroundColor: AppColors.ink,
                              ),
                              icon: const Icon(Icons.person_add_alt_1),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(18.w, 8.h, 18.w, 12.h),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) =>
                          setState(() => _query = value.trim().toLowerCase()),
                      style: TextStyle(color: AppColors.paper, fontSize: 14.sp),
                      decoration: InputDecoration(
                        hintText: 'Search members',
                        hintStyle: const TextStyle(color: AppColors.slate),
                        prefixIcon: const Icon(Icons.search, color: AppColors.brass),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _query = '');
                                },
                                icon: const Icon(Icons.close, color: AppColors.slate),
                              ),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: .06),
                        contentPadding: EdgeInsets.symmetric(vertical: 14.h),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14.r),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: .08)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14.r),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: .08)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14.r),
                          borderSide: const BorderSide(color: AppColors.brass),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 8.h),
                    child: Text('GROUP MEMBERS',
                        style: TextStyle(
                          color: AppColors.slate,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        )),
                  ),
                  Expanded(
                    child: members.isEmpty
                        ? Center(
                            child: Padding(
                              padding: EdgeInsets.all(28.w),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.person_search_outlined,
                                      color: AppColors.slate, size: 42.r),
                                  12.verticalSpace,
                                  Text(
                                    _query.isEmpty
                                        ? 'No active members yet'
                                        : 'No members match “${_searchController.text}”',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: AppColors.paper, fontSize: 14.sp),
                                  ),
                                  if (_query.isEmpty && provider.isCurrentGroupOwner) ...[
                                    14.verticalSpace,
                                    OutlinedButton.icon(
                                      onPressed: () => showAddMemberSheet(context),
                                      icon: const Icon(Icons.person_add_alt_1),
                                      label: const Text('Add a member'),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: EdgeInsets.fromLTRB(18.w, 0, 18.w, 24.h),
                            itemCount: members.length,
                            separatorBuilder: (_, __) => Divider(
                              color: Colors.white.withValues(alpha: .07),
                              height: 1,
                            ),
                            itemBuilder: (context, index) {
                              final member = members[index];
                              final isOwner = member.linkedUserId == group.ownerId ||
                                  (member.linkedUserId == null &&
                                      member.name.trim().toLowerCase() ==
                                          group.ownerName.trim().toLowerCase());
                              final linked = member.linkedUserId != null;
                              return ListTile(
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 4.w, vertical: 5.h),
                                leading: CircleAvatar(
                                  radius: 23.r,
                                  backgroundColor: member.color,
                                  child: Text(
                                    member.name.isEmpty
                                        ? '?'
                                        : member.name.characters.first.toUpperCase(),
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15.sp),
                                  ),
                                ),
                                title: Text(member.name,
                                    style: TextStyle(
                                      color: AppColors.paper,
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w600,
                                    )),
                                subtitle: Text(
                                  isOwner
                                      ? 'Group owner'
                                      : linked
                                          ? 'Nus·Nus member'
                                          : 'Expense participant',
                                  style: TextStyle(
                                      color: isOwner
                                          ? AppColors.brassSoft
                                          : AppColors.slate,
                                      fontSize: 11.sp),
                                ),
                                trailing: Icon(
                                  isOwner
                                      ? Icons.workspace_premium_outlined
                                      : linked
                                          ? Icons.verified_user_outlined
                                          : Icons.person_outline,
                                  color: isOwner ? AppColors.brass : AppColors.slate,
                                  size: 20.r,
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}
