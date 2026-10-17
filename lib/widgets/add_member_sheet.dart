import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/split_provider.dart';
import '../theme/app_colors.dart';

/// Opens a privacy-conscious contact picker. Contact data stays on-device;
/// no address-book upload is performed. Typed phone numbers are looked up against stored profiles.
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
  Timer? _lookupDebounce;
  bool _lookupLoading = false;
  bool _lookupAttempted = false;
  String? _lookupError;
  Map<String, dynamic>? _registeredUser;
  bool _ambiguousMatch = false;

  @override
  void dispose() {
    _lookupDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  String _digitsOnly(String value) => value.replaceAll(RegExp('[^0-9]'), '');

  void _onSearchChanged(String value) {
    setState(() {
      _query = value.trim().toLowerCase();
      _lookupDebounce?.cancel();
      _registeredUser = null;
      _lookupError = null;
      _lookupAttempted = false;
      _ambiguousMatch = false;
      _lookupLoading = false;
    });
    if (_digitsOnly(value).length < 7) return;
    _lookupDebounce = Timer(const Duration(milliseconds: 450), () {
      _lookupRegisteredUser(value);
    });
  }

  Future<void> _lookupRegisteredUser(String phoneNumber) async {
    if (!mounted) return;
    setState(() { _lookupLoading = true; _lookupError = null; });
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1').httpsCallable('lookupRegisteredUserByPhone');
      final response = await callable.call(<String, dynamic>{'phoneNumber': phoneNumber});
      if (!mounted) return;
      final data = Map<String, dynamic>.from(response.data as Map);
      setState(() {
        _lookupLoading = false;
        _lookupAttempted = true;
        _ambiguousMatch = data['ambiguous'] == true;
        _registeredUser = data['found'] == true && data['user'] is Map ? Map<String, dynamic>.from(data['user'] as Map) : null;
      });
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      setState(() { _lookupLoading = false; _lookupError = error.code == 'resource-exhausted' ? 'Too many searches. Wait a minute and try again.' : 'Could not search registered users. Please try again.'; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _lookupLoading = false; _lookupError = 'Could not search registered users. Please try again.'; });
    }
  }

  void _addRegisteredUser() {
    final user = _registeredUser;
    if (user == null) return;
    if (!context.read<SplitProvider>().isCurrentGroupOwner) return;
    final name = user['name'] as String? ?? 'Nus·Nus user';
    context.read<SplitProvider>().addPerson(name, linkedUserId: user['uid'] as String);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added ' + name + ' if not already a member.')));
  }

  Future<void> _shareTypedInvite() async {
    final group = context.read<SplitProvider>().currentGroup;
    if (group == null || _digitsOnly(_searchController.text).length < 7) return;
    final label = group.name.trim().isEmpty ? '' : ' for ' + group.name;
    await Share.share('Join me on Nus·Nus so we can track shared expenses' + label + '!\nOpen Nus·Nus: https://nus-nus.web.app\n\nAfter registering, ask me to add you to the group.', subject: 'Nus·Nus invitation');
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

  String _normaliseText(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp('\\s+'), ' ');

  bool _matchesSearch(Contact contact) {
    final query = _normaliseText(_query);
    if (query.isEmpty) return true;
    if (_normaliseText(contact.displayName).contains(query)) return true;

    // Ignore spaces, +, brackets and hyphens when searching phone numbers.
    final queryDigits = _digitsOnly(query);
    if (queryDigits.isEmpty) return false;
    return contact.phones.any(
      (phone) => _digitsOnly(phone.number).contains(queryDigits),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SplitProvider>();
    final filtered = _contacts.where(_matchesSearch).toList();

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
              onChanged: _onSearchChanged,
              style: TextStyle(color: AppColors.ink, fontSize: 14.sp),
              decoration: InputDecoration(
                hintText: 'Search registered users by phone number',
                hintStyle: const TextStyle(color: AppColors.slate),
                prefixIcon: const Icon(Icons.search, color: AppColors.slate),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _lookupDebounce?.cancel();
                          _searchController.clear();
                          setState(() {
                            _query = '';
                            _registeredUser = null;
                            _lookupAttempted = false;
                            _lookupError = null;
                            _ambiguousMatch = false;
                          });
                        },
                        icon: const Icon(Icons.close, color: AppColors.slate),
                      ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: .55),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14.r),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          if (_lookupLoading)
            Padding(padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 4.h), child: const LinearProgressIndicator(color: AppColors.brass)),
          if (_registeredUser != null)
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 10.h),
              child: Card(child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                title: Text((_registeredUser!['name'] as String?) ?? 'Nus·Nus user'),
                subtitle: const Text('Registered Nus·Nus account'),
                trailing: provider.isCurrentGroupOwner ? IconButton(tooltip: 'Add to group', icon: const Icon(Icons.person_add_alt_1), onPressed: _addRegisteredUser) : null,
              )),
            ),
          if (_lookupAttempted && _registeredUser == null)
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 10.h),
              child: Row(children: [
                Expanded(child: Text(_ambiguousMatch ? 'More than one account has this number. Ask the person to update their profile.' : 'No registered account found for this number.', style: TextStyle(color: AppColors.slate, fontSize: 12.sp))),
                if (!_ambiguousMatch) TextButton.icon(onPressed: _shareTypedInvite, icon: const Icon(Icons.share_outlined), label: const Text('Invite')),
              ]),
            ),
          if (_lookupError != null)
            Padding(padding: EdgeInsets.symmetric(horizontal: 20.w), child: Text(_lookupError!, style: TextStyle(color: AppColors.rust, fontSize: 12.sp))),
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
                  ? 'Phone numbers are matched against existing account profiles; a match does not verify ownership of that number.'
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
