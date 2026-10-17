import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/split_provider.dart';
import '../theme/app_colors.dart';

/// Opens a privacy-conscious contact picker. Contact data stays on-device;
/// no address-book upload or unverified phone-number matching is performed.
void showAddMemberSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _AddMemberSheet(),
  );
}

class _AddMemberSheet extends StatefulWidget {
  const _AddMemberSheet();

  @override
  State<_AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends State<_AddMemberSheet> {
  final _searchController = TextEditingController();
  List<Contact> _contacts = [];
  String _query = '';
  bool _loading = false;
  bool _permissionDenied = false;
  bool _loaded = false;
  String? _error;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    setState(() {
      _loading = true;
      _error = null;
      _permissionDenied = false;
    });
    try {
      final granted = await FlutterContacts.requestPermission(readonly: true);
      if (!granted) {
        if (mounted) {
          setState(() {
            _permissionDenied = true;
            _loading = false;
            _loaded = true;
          });
        }
        return;
      }
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );
      contacts.sort((a, b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
      if (mounted) {
        setState(() {
          _contacts = contacts.where((c) => c.phones.isNotEmpty).toList();
          _loading = false;
          _loaded = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error =
              'Could not read contacts. You can still share an invitation.';
          _loading = false;
          _loaded = true;
        });
      }
    }
  }

  Future<void> _shareInvite(Contact contact) async {
    final group = context.read<SplitProvider>().currentGroup;
    if (group == null) return;
    final groupLabel = group.name.trim().isEmpty ? '' : ' for “${group.name}”';
    final message = 'Join me on Nus·Nus so we can track shared expenses'
        '$groupLabel!\n'
        'Open Nus·Nus: https://nus-nus.web.app\n\n'
        'After registering, ask me to add you to the group.';
    try {
      await Share.share(message, subject: 'Nus·Nus invitation');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the share menu.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SplitProvider>();
    final filtered = _contacts.where((contact) {
      final name = contact.displayName.toLowerCase();
      final numbers =
          contact.phones.map((p) => p.number.toLowerCase()).join(' ');
      return _query.isEmpty ||
          name.contains(_query) ||
          numbers.contains(_query);
    }).toList();

    return Container(
      height: 0.82.sh,
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: Column(
        children: [
          14.verticalSpace,
          Container(
            width: 42.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: AppColors.line,
              borderRadius: BorderRadius.circular(3.r),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 8.h),
            child: Row(
              children: [
                Container(
                  width: 44.r,
                  height: 44.r,
                  decoration: BoxDecoration(
                    color: AppColors.brass.withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  child: Icon(Icons.person_add_alt_1,
                      color: AppColors.ink, size: 23.r),
                ),
                12.horizontalSpace,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Add people',
                          style: TextStyle(
                              color: AppColors.ink,
                              fontSize: 19.sp,
                              fontWeight: FontWeight.bold)),
                      3.verticalSpace,
                      Text('Invite someone to your group',
                          style: TextStyle(
                              color: AppColors.slate, fontSize: 11.5.sp)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 12.h),
            child: TextField(
              controller: _searchController,
              onChanged: (value) =>
                  setState(() => _query = value.trim().toLowerCase()),
              style: TextStyle(color: AppColors.ink, fontSize: 14.sp),
              decoration: InputDecoration(
                hintText: 'Search contacts by name or number',
                hintStyle: const TextStyle(color: AppColors.slate),
                prefixIcon: const Icon(Icons.search, color: AppColors.slate),
                filled: true,
                fillColor: Colors.white.withValues(alpha: .55),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14.r),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Text(_error!,
                  style: TextStyle(color: AppColors.rust, fontSize: 12.sp)),
            ),
          if (_loading)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(color: AppColors.brass),
              ),
            )
          else if (_permissionDenied)
            Expanded(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(26.w),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.contacts_outlined,
                          size: 42.r, color: AppColors.slate),
                      12.verticalSpace,
                      Text('Contact access is off',
                          style: TextStyle(
                              color: AppColors.ink,
                              fontWeight: FontWeight.bold,
                              fontSize: 15.sp)),
                      8.verticalSpace,
                      Text(
                        'Allow contact access to choose someone. Your address book is not uploaded.',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(color: AppColors.slate, fontSize: 12.sp),
                      ),
                      12.verticalSpace,
                      OutlinedButton(
                        onPressed: _loadContacts,
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (!_loaded)
            Expanded(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(24.w),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.contacts_outlined,
                          size: 44.r, color: AppColors.slate),
                      12.verticalSpace,
                      Text('Choose from your contacts',
                          style: TextStyle(
                              color: AppColors.ink,
                              fontSize: 15.sp,
                              fontWeight: FontWeight.bold)),
                      8.verticalSpace,
                      Text(
                        'Only the contact you choose is used. Nus·Nus will not upload your address book.',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(color: AppColors.slate, fontSize: 12.sp),
                      ),
                      14.verticalSpace,
                      ElevatedButton.icon(
                        onPressed: _loadContacts,
                        icon: const Icon(Icons.contacts_outlined),
                        label: const Text('Choose contact'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brass,
                          foregroundColor: AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (filtered.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  _contacts.isEmpty
                      ? 'No contacts with phone numbers were found.'
                      : 'No matching contacts',
                  style: TextStyle(color: AppColors.slate, fontSize: 13.sp),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 18.h),
                itemCount: filtered.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: AppColors.line),
                itemBuilder: (context, index) {
                  final contact = filtered[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.inkSoft,
                      child: Text(
                        contact.displayName.isEmpty
                            ? '?'
                            : contact.displayName.characters.first
                                .toUpperCase(),
                        style: const TextStyle(
                            color: AppColors.brassSoft,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(contact.displayName,
                        style: TextStyle(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5.sp)),
                    subtitle: Text(contact.phones.first.number,
                        style: TextStyle(
                            color: AppColors.slate, fontSize: 11.5.sp)),
                    trailing: Icon(Icons.share_outlined,
                        color: AppColors.brass, size: 20.r),
                    onTap: () => _shareInvite(contact),
                  );
                },
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 16.h),
            child: Text(
              provider.isCurrentGroupOwner
                  ? 'Phone verification and account matching will be added later. Sharing an invite does not add the person to this group.'
                  : 'Only the group owner can add members. You can still share the app with a contact.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.slate, fontSize: 10.5.sp),
            ),
          ),
        ],
      ),
    );
  }
}
