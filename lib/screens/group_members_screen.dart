import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../models/group.dart';
import '../models/person.dart';
import '../providers/split_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
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

  Future<void> _confirmRemovePerson(
    SplitProvider provider,
    Person person,
  ) async {
    final hasHistory = provider.expenses.any(
      (expense) =>
          expense.payerId == person.id ||
          expense.splitMap.containsKey(person.id),
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.paper,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: Text(
          'Remove ${person.name}?',
          style: const TextStyle(
            color: AppColors.ink,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          hasHistory
              ? '${person.name} has expense history. They will be removed from the active member list, while past expenses and balances stay intact.'
              : '${person.name} has no expense history and will be removed from the group.',
          style: const TextStyle(color: AppColors.slate),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: AppTheme.solidButton.copyWith(
              backgroundColor: WidgetStateProperty.all(AppColors.rust),
            ),
            child: const Text('Remove member'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final archived = provider.removePerson(person.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(archived
            ? '${person.name} removed. Their expense history is preserved.'
            : '${person.name} removed.'),
        backgroundColor: AppColors.inkSoft,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _leaveGroup(SplitProvider provider, Group group) async {
    final isOwner = group.ownerId == provider.uid;
    String? transferToUid;
    var shouldDeleteGroup = false;

    if (isOwner) {
      final candidates = group.members
          .where((member) =>
              !member.archived &&
              member.linkedUserId != null &&
              member.linkedUserId != provider.uid &&
              group.memberUids.contains(member.linkedUserId))
          .toList();
      final decision = await _ownerLeaveDialog(group, candidates);
      if (decision == null || !mounted) return;
      transferToUid = decision.transferToUid;
      shouldDeleteGroup = decision.deleteGroup;

      if (shouldDeleteGroup) {
        await _deleteGroup(group);
        return;
      }
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AppColors.paper,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
          title: Text(
            'Leave “${group.name}”?',
            style: const TextStyle(
                color: AppColors.ink, fontWeight: FontWeight.w800),
          ),
          content: const Text(
            'You will lose access to this group. Shared expenses and balances will remain, and your old member and chat names will show as “Former member”.',
            style: TextStyle(color: AppColors.slate, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.rust,
                foregroundColor: AppColors.paper,
              ),
              child: const Text('Leave group'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    try {
      await provider.leaveCurrentGroup(transferToUid: transferToUid);
      if (mounted) {
        // Leaving a shared group should return to the shared-groups view,
        // rather than dropping the user into their personal spend tab.
        provider.requestLandingTab(1);
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not leave the group. Please try again.'),
          backgroundColor: AppColors.rust,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<_OwnerLeaveDecision?> _ownerLeaveDialog(
    Group group,
    List<Person> candidates,
  ) async {
    String? selectedUid;
    var deleteGroup = false;
    return showDialog<_OwnerLeaveDecision>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: AppColors.paper,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
          title: Text(
            'Leave “${group.name}”?',
            style: const TextStyle(
                color: AppColors.ink, fontWeight: FontWeight.w800),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  candidates.isEmpty
                      ? 'As the owner, you cannot leave an ownerless group. No active registered member can take ownership.'
                      : 'Transfer ownership to an active member before leaving. Your access will be removed, while shared expenses and balances stay with the group.',
                  style: const TextStyle(color: AppColors.slate, height: 1.4),
                ),
                if (candidates.isNotEmpty) ...[
                  16.verticalSpace,
                  DropdownButtonFormField<String>(
                    initialValue: selectedUid,
                    isExpanded: true,
                    dropdownColor: AppColors.paper,
                    style: TextStyle(
                      color: AppColors.ink,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: AppTheme.inputDecoration('New group owner'),
                    items: candidates
                        .map((person) => DropdownMenuItem<String>(
                              value: person.linkedUserId,
                              child: Text(person.name,
                                  overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (uid) => setDialogState(() => selectedUid = uid),
                  ),
                ],
                12.verticalSpace,
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.rust.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                        color: AppColors.rust.withValues(alpha: 0.22)),
                  ),
                  child: CheckboxListTile(
                    value: deleteGroup,
                    activeColor: AppColors.rust,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(
                      'Delete group instead',
                      style: TextStyle(
                        color: AppColors.rust,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    subtitle: Text(
                      'Permanently remove its expenses, chat, and history.',
                      style: TextStyle(color: AppColors.slate, fontSize: 10.sp),
                    ),
                    onChanged: (value) => setDialogState(() {
                      deleteGroup = value ?? false;
                      if (deleteGroup) selectedUid = null;
                    }),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: deleteGroup || selectedUid != null
                  ? () => Navigator.pop(
                        dialogContext,
                        _OwnerLeaveDecision(
                          transferToUid: selectedUid,
                          deleteGroup: deleteGroup,
                        ),
                      )
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: deleteGroup ? AppColors.rust : AppColors.ink,
                foregroundColor: AppColors.paper,
                disabledBackgroundColor: AppColors.paperDim,
                disabledForegroundColor: AppColors.slate,
              ),
              child:
                  Text(deleteGroup ? 'Continue to delete' : 'Transfer & leave'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editGroup(Group group) async {
    const supportedCurrencies = [
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
    ];
    final currencies = supportedCurrencies.contains(group.currency)
        ? supportedCurrencies
        : [group.currency, ...supportedCurrencies];
    var selectedCurrency = group.currency;
    var editedName = group.name;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: AppColors.paper,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
          title: const Text('Edit group',
              style:
                  TextStyle(color: AppColors.ink, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: group.name,
                autofocus: true,
                style: TextStyle(color: AppColors.ink, fontSize: 15.sp),
                decoration: AppTheme.inputDecoration('Group name')
                    .copyWith(filled: false),
                onChanged: (value) => editedName = value,
              ),
              14.verticalSpace,
              DropdownButtonFormField<String>(
                initialValue: selectedCurrency,
                dropdownColor: AppColors.paper,
                style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600),
                decoration: AppTheme.inputDecoration('Currency').copyWith(
                  prefixIcon: Icon(Icons.payments_outlined,
                      color: AppColors.brass, size: 20.r),
                ),
                items: currencies
                    .map((currency) => DropdownMenuItem(
                          value: currency,
                          child: Text(currency),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => selectedCurrency = value);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = editedName.trim();
                if (name.isEmpty) return;
                context.read<SplitProvider>().renameGroup(
                      group.id,
                      name,
                      newCurrency: selectedCurrency,
                    );
                Navigator.pop(dialogContext);
              },
              style: AppTheme.solidButton,
              child: const Text('Save changes'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteGroup(Group group) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.paper,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: Text('Delete “${group.name}”?',
            style: const TextStyle(
                color: AppColors.ink, fontWeight: FontWeight.bold)),
        content: const Text(
          'This permanently deletes the group, chat, members, and expense history. This cannot be undone.',
          style: TextStyle(color: AppColors.slate),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: AppTheme.solidButton.copyWith(
              backgroundColor: WidgetStateProperty.all(AppColors.rust),
            ),
            child: const Text('Delete group'),
          ),
        ],
      ),
    );
    if (shouldDelete != true || !mounted) return;

    context.read<SplitProvider>().removeGroup(group.id);
    Navigator.pop(context);
  }

  bool _isOwner(Person member, Group group) =>
      member.linkedUserId == group.ownerId ||
      (member.linkedUserId == null &&
          member.name.trim().toLowerCase() ==
              group.ownerName.trim().toLowerCase());

  Widget _memberTile({
    required Person member,
    required bool isOwner,
    required bool isLinked,
    required bool canRemove,
    required VoidCallback onRemove,
  }) {
    final label = isOwner
        ? 'Group owner'
        : isLinked
            ? 'Registered Nus·Nus member'
            : 'Expense participant';
    return Container(
      margin: EdgeInsets.only(bottom: 9.h),
      decoration: BoxDecoration(
        color: AppColors.inkSoft,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: Colors.white.withValues(alpha: .06)),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 5.h),
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
              fontSize: 15.sp,
            ),
          ),
        ),
        title: Text(
          member.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.paper,
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Padding(
          padding: EdgeInsets.only(top: 4.h),
          child: Row(
            children: [
              Icon(
                isOwner
                    ? Icons.workspace_premium_outlined
                    : isLinked
                        ? Icons.verified_user_outlined
                        : Icons.person_outline,
                size: 13.r,
                color: isOwner ? AppColors.brassSoft : AppColors.slate,
              ),
              5.horizontalSpace,
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isOwner ? AppColors.brassSoft : AppColors.slate,
                    fontSize: 11.sp,
                  ),
                ),
              ),
            ],
          ),
        ),
        trailing: canRemove
            ? IconButton(
                tooltip: 'Remove member',
                onPressed: onRemove,
                icon: Icon(Icons.person_remove_alt_1_outlined,
                    color: AppColors.slate, size: 20.r),
              )
            : Icon(
                isOwner
                    ? Icons.workspace_premium_outlined
                    : Icons.check_circle_outline,
                color: isOwner ? AppColors.brass : AppColors.slate,
                size: 20.r,
              ),
      ),
    );
  }

  Widget _statChip(IconData icon, String label) => Container(
        padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 7.h),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .06),
          borderRadius: BorderRadius.circular(30.r),
          border: Border.all(color: Colors.white.withValues(alpha: .07)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.brassSoft, size: 14.r),
            5.horizontalSpace,
            Text(label,
                style: TextStyle(color: AppColors.paper, fontSize: 10.5.sp)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SplitProvider>();
    final group = provider.currentGroup;
    final allActiveMembers = (group?.members ?? const <Person>[])
        .where((member) => !member.archived)
        .toList();
    final members = allActiveMembers.where((member) {
      if (_query.isEmpty) return true;
      final isOwner = group != null && _isOwner(member, group);
      final role = isOwner
          ? 'group owner'
          : member.linkedUserId != null
              ? 'registered nus nus member'
              : 'expense participant';
      return member.name.toLowerCase().contains(_query) ||
          role.contains(_query);
    }).toList()
      ..sort((a, b) {
        if (group != null) {
          final ownerOrder = (_isOwner(a, group) ? 0 : 1)
              .compareTo(_isOwner(b, group) ? 0 : 1);
          if (ownerOrder != 0) return ownerOrder;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    final registeredCount =
        allActiveMembers.where((member) => member.linkedUserId != null).length;

    return Scaffold(
      backgroundColor: AppColors.ink,
      appBar: AppBar(
        backgroundColor: AppColors.ink,
        foregroundColor: AppColors.paper,
        title: Text(
          'Group members',
          style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w700),
        ),
        actions: [
          if (provider.canAddMembersToCurrentGroup)
            Padding(
              padding: EdgeInsets.only(right: 12.w),
              child: IconButton.filled(
                tooltip: 'Add member',
                onPressed: () => showAddMemberSheet(context),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.brass,
                  foregroundColor: AppColors.ink,
                ),
                icon: const Icon(Icons.person_add_alt_1),
              ),
            ),
        ],
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
                    padding: EdgeInsets.fromLTRB(18.w, 12.h, 18.w, 14.h),
                    child: Container(
                      padding: EdgeInsets.all(22.r),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.inkSoft, AppColors.ink],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22.r),
                        border: Border.all(
                            color: AppColors.brass.withValues(alpha: .25)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 62.r,
                                height: 62.r,
                                decoration: BoxDecoration(
                                  color: AppColors.brass.withValues(alpha: .18),
                                  borderRadius: BorderRadius.circular(15.r),
                                ),
                                child: Icon(Icons.groups_2_outlined,
                                    color: AppColors.brassSoft, size: 31.r),
                              ),
                              12.horizontalSpace,
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('GROUP ROSTER',
                                        style: TextStyle(
                                          color: AppColors.brassSoft,
                                          fontSize: 10.sp,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1.3,
                                        )),
                                    5.verticalSpace,
                                    Text(group.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: AppColors.paper,
                                          fontSize: 22.sp,
                                          fontWeight: FontWeight.bold,
                                        )),
                                    4.verticalSpace,
                                    Text('People sharing this group',
                                        style: TextStyle(
                                            color: AppColors.slate,
                                            fontSize: 11.sp)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          16.verticalSpace,
                          Row(
                            children: [
                              _statChip(Icons.people_outline,
                                  '${allActiveMembers.length} active'),
                              8.horizontalSpace,
                              _statChip(Icons.verified_user_outlined,
                                  '$registeredCount registered'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (provider.isCurrentGroupOwner)
                    Padding(
                      padding: EdgeInsets.fromLTRB(18.w, 0, 18.w, 12.h),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _editGroup(group),
                              icon: Icon(Icons.edit_outlined, size: 17.r),
                              label: const Text('Edit group'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.brassSoft,
                                side: BorderSide(
                                    color:
                                        AppColors.brass.withValues(alpha: .5)),
                                padding: EdgeInsets.symmetric(vertical: 12.h),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14.r),
                                ),
                              ),
                            ),
                          ),
                          10.horizontalSpace,
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _deleteGroup(group),
                              icon: Icon(Icons.delete_outline, size: 17.r),
                              label: const Text('Delete group'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.rust,
                                side: BorderSide(
                                    color:
                                        AppColors.rust.withValues(alpha: .5)),
                                padding: EdgeInsets.symmetric(vertical: 12.h),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14.r),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(18.w, 0, 18.w, 14.h),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) =>
                          setState(() => _query = value.trim().toLowerCase()),
                      style: TextStyle(color: AppColors.paper, fontSize: 14.sp),
                      decoration: InputDecoration(
                        hintText: 'Search by name or member type',
                        hintStyle:
                            TextStyle(color: AppColors.slate, fontSize: 13.sp),
                        prefixIcon: Icon(Icons.search,
                            color: AppColors.brassSoft, size: 21.r),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _query = '');
                                },
                                icon: Icon(Icons.close,
                                    color: AppColors.slate, size: 19.r),
                              ),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: .055),
                        contentPadding: EdgeInsets.symmetric(vertical: 14.h),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16.r),
                          borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: .08)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16.r),
                          borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: .08)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16.r),
                          borderSide: BorderSide(
                              color: AppColors.brass.withValues(alpha: .8)),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(22.w, 0, 22.w, 9.h),
                    child: Row(
                      children: [
                        Text('MEMBERS',
                            style: TextStyle(
                              color: AppColors.brassSoft,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.4,
                            )),
                        const Spacer(),
                        Text('${members.length}',
                            style: TextStyle(
                              color: AppColors.slate,
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
                            )),
                      ],
                    ),
                  ),
                  Expanded(
                    child: members.isEmpty
                        ? Center(
                            child: Container(
                              margin: EdgeInsets.all(22.w),
                              padding: EdgeInsets.all(24.r),
                              decoration: BoxDecoration(
                                color: AppColors.inkSoft,
                                borderRadius: BorderRadius.circular(22.r),
                                border: Border.all(
                                    color: Colors.white.withValues(alpha: .06)),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 58.r,
                                    height: 58.r,
                                    decoration: BoxDecoration(
                                      color: AppColors.brass
                                          .withValues(alpha: .14),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.person_search_outlined,
                                        color: AppColors.brassSoft, size: 28.r),
                                  ),
                                  14.verticalSpace,
                                  Text(
                                    _query.isEmpty
                                        ? 'No active members yet'
                                        : 'No members match “${_searchController.text}”',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: AppColors.paper,
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (_query.isEmpty &&
                                      provider.canAddMembersToCurrentGroup) ...[
                                    8.verticalSpace,
                                    Text(
                                      'Add registered people to start splitting together.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          color: AppColors.slate,
                                          fontSize: 12.sp),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.fromLTRB(18.w, 0, 18.w, 24.h),
                            itemCount: members.length,
                            itemBuilder: (context, index) {
                              final member = members[index];
                              final isOwner = _isOwner(member, group);
                              final isMe = member.linkedUserId != null &&
                                  member.linkedUserId == provider.uid;
                              return _memberTile(
                                member: member,
                                isOwner: isOwner,
                                isLinked: member.linkedUserId != null,
                                canRemove: provider.isCurrentGroupOwner &&
                                    !isOwner &&
                                    !isMe,
                                onRemove: () =>
                                    _confirmRemovePerson(provider, member),
                              );
                            },
                          ),
                  ),
                  if (!group.isPersonal)
                    Padding(
                      padding: EdgeInsets.fromLTRB(18.w, 12.h, 18.w, 18.h),
                      child: OutlinedButton.icon(
                        onPressed: () => _leaveGroup(provider, group),
                        icon: Icon(Icons.exit_to_app_rounded, size: 20.r),
                        label: Text(
                          'Leave group',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.rust,
                          side: BorderSide(
                              color: AppColors.rust.withValues(alpha: .55)),
                          minimumSize: Size(double.infinity, 54.h),
                          padding: EdgeInsets.symmetric(
                              horizontal: 20.w, vertical: 15.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _OwnerLeaveDecision {
  final String? transferToUid;
  final bool deleteGroup;

  const _OwnerLeaveDecision({
    required this.transferToUid,
    required this.deleteGroup,
  });
}
