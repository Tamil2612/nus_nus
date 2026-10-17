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
  int _lookupSequence = 0;
  final Map<String, Map<String, dynamic>> _registeredContacts = {};
  final Set<String> _ambiguousContactPhones = {};
  bool _matchingContacts = false;
  String? _contactMatchError;

  @override
  void initState() {
    super.initState();
    // Load local contacts once when the picker opens so name search works
    // immediately; typed-number lookup works independently of permission.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadContacts();
    });
  }

  @override
  void dispose() {
    _lookupDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  String _digitsOnly(String value) => value.replaceAll(RegExp('[^0-9]'), '');

  // Keep this in sync with functions/phone_lookup.js. Contact matching keys
  // are canonical only in memory; raw contact data is not stored remotely.
  String _phoneKey(String value) {
    var digits = _digitsOnly(value);
    if (digits.startsWith('00')) digits = digits.substring(2);
    if (digits.startsWith('971')) {
      final national = digits.substring(3);
      return national.startsWith('0') ? national : '0$national';
    }
    if (digits.length == 9 && digits.startsWith('5')) return '0$digits';
    return digits;
  }

  Future<void> _matchLoadedContacts(List<Contact> contacts) async {
    final phoneNumbers = <String>{};
    for (final contact in contacts) {
      for (final phone in contact.phones) {
        final raw = phone.number.trim();
        final key = _phoneKey(raw);
        if (key.length >= 7 && key.length <= 15) phoneNumbers.add(raw);
      }
    }

    if (phoneNumbers.isEmpty) {
      if (mounted) {
        setState(() {
          _registeredContacts.clear();
          _ambiguousContactPhones.clear();
          _matchingContacts = false;
          _contactMatchError = null;
        });
      }
      return;
    }

    // Send a bounded batch. The backend compares canonical phone values
    // against private users/{uid}.phoneNumber fields and returns only matches.
    final batch = phoneNumbers.take(500).toList();
    if (mounted) {
      setState(() {
        _matchingContacts = true;
        _contactMatchError = null;
      });
    }
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('lookupRegisteredUsersByPhones');
      final response = await callable.call(<String, dynamic>{
        'phoneNumbers': batch,
      });
      if (!mounted) return;
      final data = Map<String, dynamic>.from(response.data as Map);
      final rawMatches = data['matches'];
      final rawAmbiguous = data['ambiguous'];
      setState(() {
        _registeredContacts.clear();
        _ambiguousContactPhones.clear();
        if (rawMatches is Map) {
          for (final entry in rawMatches.entries) {
            if (entry.value is Map) {
              _registeredContacts[entry.key.toString()] =
                  Map<String, dynamic>.from(entry.value as Map);
            }
          }
        }
        if (rawAmbiguous is List) {
          _ambiguousContactPhones
              .addAll(rawAmbiguous.map((item) => item.toString()));
        }
        _matchingContacts = false;
        _contactMatchError = null;
      });
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      setState(() {
        _matchingContacts = false;
        _contactMatchError = error.code == 'not-found'
            ? 'Contact matching is not deployed yet. Deploy the latest Cloud Functions and retry.'
            : 'Could not match contacts. Check your connection and retry.';
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _matchingContacts = false;
          _contactMatchError =
              'Could not match contacts. Check your connection and retry.';
        });
      }
    }
  }

  Map<String, dynamic>? _registeredContactFor(Contact contact) {
    for (final phone in contact.phones) {
      final user = _registeredContacts[_phoneKey(phone.number)];
      if (user != null) return user;
    }
    return null;
  }

  bool _hasAmbiguousContactPhone(Contact contact) => contact.phones
      .any((phone) => _ambiguousContactPhones.contains(_phoneKey(phone.number)));

  void _onSearchChanged(String value) {
    setState(() {
      _query = value.trim().toLowerCase();
      _lookupDebounce?.cancel();
      _lookupSequence++;
      _registeredUser = null;
      _lookupError = null;
      _lookupAttempted = false;
      _ambiguousMatch = false;
      _lookupLoading = false;
    });
    if (_digitsOnly(value).length < 7) return;
    final sequence = _lookupSequence;
    _lookupDebounce = Timer(const Duration(milliseconds: 400), () {
      _lookupRegisteredUser(value, sequence);
    });
  }

  Future<void> _lookupRegisteredUser(String phoneNumber, int sequence) async {
    if (!mounted) return;
    setState(() { _lookupLoading = true; _lookupError = null; });
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1').httpsCallable('lookupRegisteredUserByPhone');
      final response = await callable.call(<String, dynamic>{'phoneNumber': phoneNumber});
      if (!mounted || sequence != _lookupSequence) return;
      final data = Map<String, dynamic>.from(response.data as Map);
      setState(() {
        _lookupLoading = false;
        _lookupAttempted = true;
        _ambiguousMatch = data['ambiguous'] == true;
        _registeredUser = data['found'] == true && data['user'] is Map ? Map<String, dynamic>.from(data['user'] as Map) : null;
      });
    } on FirebaseFunctionsException catch (error) {
      if (!mounted || sequence != _lookupSequence) return;
      setState(() { _lookupLoading = false; _lookupError = error.code == 'resource-exhausted' ? 'Too many searches. Wait a minute and try again.' : 'Could not search registered users. Please try again.'; });
    } catch (_) {
      if (!mounted || sequence != _lookupSequence) return;
      setState(() { _lookupLoading = false; _lookupError = 'Could not search registered users. Please try again.'; });
    }
  }

  void _addRegisteredUser() {
    final user = _registeredUser;
    if (user == null) return;
    _addUserToGroup(user);
  }

  void _addContactUser(Contact contact) {
    final user = _registeredContactFor(contact);
    if (user == null) return;
    _addUserToGroup(user);
  }

  void _addUserToGroup(Map<String, dynamic> user) {
    final provider = context.read<SplitProvider>();
    if (!provider.isCurrentGroupOwner) return;
    final uid = user['uid'] as String?;
    if (uid == null || uid.isEmpty) return;
    final name = (user['name'] as String?)?.trim().isNotEmpty == true
        ? (user['name'] as String).trim()
        : 'Nus·Nus user';
    final alreadyMember =
        provider.allPeople.any((person) => person.linkedUserId == uid && !person.archived);
    if (alreadyMember) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name is already in this group.')),
      );
      return;
    }
    provider.addPerson(name, linkedUserId: uid);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added $name to the group.')),
    );
  }

  Future<void> _shareTypedInvite() async {
    final group = context.read<SplitProvider>().currentGroup;
    if (group == null || _digitsOnly(_searchController.text).length < 7) return;
    final label = group.name.trim().isEmpty ? '' : ' for ${group.name}';
    await Share.share('Join me on Nus·Nus so we can track shared expenses$label!\nOpen Nus·Nus: https://nus-nus.web.app\n\nAfter registering, ask me to add you to the group.', subject: 'Nus·Nus invitation');
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
        _matchLoadedContacts(_contacts);
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
    final registeredContacts = _contacts.where((contact) => _registeredContactFor(contact) != null).toList();
    final filtered = registeredContacts.where(_matchesSearch).toList();

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
                hintText: 'Search by name or phone number',
                hintStyle: const TextStyle(color: AppColors.slate),
                prefixIcon: const Icon(Icons.search, color: AppColors.slate),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _lookupDebounce?.cancel();
                          _lookupSequence++;
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
          if (_contactMatchError != null)
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 8.h),
              child: Row(
                children: [
                  Expanded(
                    child: Text(_contactMatchError!,
                        style: TextStyle(color: AppColors.rust, fontSize: 11.sp)),
                  ),
                  TextButton(
                    onPressed: _matchingContacts ? null : () => _matchLoadedContacts(_contacts),
                    child: const Text('Retry'),
                  ),
                ],
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
          else if (filtered.isEmpty && _digitsOnly(_query).length >= 7)
            const Expanded(child: SizedBox.shrink())
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
                    subtitle: Text(
                      contact.phones.first.number,
                      style: TextStyle(color: AppColors.slate, fontSize: 11.5.sp),
                    ),
                    trailing: provider.isCurrentGroupOwner
                        ? Icon(Icons.person_add_alt_1,
                            color: AppColors.brass, size: 20.r)
                        : Icon(Icons.verified_outlined,
                            color: Colors.green.shade700, size: 20.r),
                    onTap: provider.isCurrentGroupOwner
                        ? () => _addContactUser(contact)
                        : null,
                  );
                },
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 16.h),
            child: Text(
              provider.isCurrentGroupOwner
                  ? 'Only registered contacts are listed. Search also accepts UAE numbers with or without +971.'
                  : 'Only the group owner can add members.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.slate, fontSize: 10.5.sp),
            ),
          ),
        ],
      ),
    );
  }
}
