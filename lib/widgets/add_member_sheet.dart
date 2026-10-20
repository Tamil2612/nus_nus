import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
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
    // Indian mobile numbers compare as the same 10-digit national number.
    if (digits.startsWith('91') &&
        digits.length == 12 &&
        RegExp(r'^[6-9]\d{9}$').hasMatch(digits.substring(2))) {
      return digits.substring(2);
    }
    if (digits.length == 11 &&
        digits.startsWith('0') &&
        RegExp(r'^[6-9]\d{9}$').hasMatch(digits.substring(1))) {
      return digits.substring(1);
    }
    if (RegExp(r'^[6-9]\d{9}$').hasMatch(digits)) return digits;
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
    setState(() {
      _lookupLoading = true;
      _lookupError = null;
    });
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('lookupRegisteredUserByPhone');
      final response =
          await callable.call(<String, dynamic>{'phoneNumber': phoneNumber});
      if (!mounted || sequence != _lookupSequence) return;
      final data = Map<String, dynamic>.from(response.data as Map);
      setState(() {
        _lookupLoading = false;
        _lookupAttempted = true;
        _ambiguousMatch = data['ambiguous'] == true;
        _registeredUser = data['found'] == true && data['user'] is Map
            ? Map<String, dynamic>.from(data['user'] as Map)
            : null;
      });
    } on FirebaseFunctionsException catch (error) {
      if (!mounted || sequence != _lookupSequence) return;
      setState(() {
        _lookupLoading = false;
        _lookupError = error.code == 'resource-exhausted'
            ? 'Too many searches. Wait a minute and try again.'
            : 'Could not search registered users. Please try again.';
      });
    } catch (_) {
      if (!mounted || sequence != _lookupSequence) return;
      setState(() {
        _lookupLoading = false;
        _lookupError = 'Could not search registered users. Please try again.';
      });
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
    if (!provider.canAddMembersToCurrentGroup) return;
    final uid = user['uid'] as String?;
    if (uid == null || uid.isEmpty) return;
    final name = (user['name'] as String?)?.trim().isNotEmpty == true
        ? (user['name'] as String).trim()
        : 'Nus·Nus user';
    final alreadyMember = provider.allPeople
        .any((person) => person.linkedUserId == uid && !person.archived);
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

  Future<void> _loadContacts() async {
    setState(() {
      _loading = true;
      _error = null;
      _permissionDenied = false;
    });
    try {
      final permission =
          await FlutterContacts.permissions.request(PermissionType.read);
      final granted = permission == PermissionStatus.granted ||
          permission == PermissionStatus.limited;
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
      final contacts = await FlutterContacts.getAll(
        properties: {ContactProperty.phone},
      );
      contacts.sort((a, b) => (a.displayName ?? '')
          .toLowerCase()
          .compareTo((b.displayName ?? '').toLowerCase()));
      if (mounted) {
        setState(() {
          _contacts = contacts.where((c) => c.phones.isNotEmpty).toList();
          _loaded = true;
        });
        await _matchLoadedContacts(_contacts);
        if (mounted) {
          setState(() => _loading = false);
        }
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

  Widget _sectionLabel(
    String label, {
    required IconData icon,
    required String caption,
    int? count,
  }) =>
      Padding(
        padding: EdgeInsets.fromLTRB(8.w, 14.h, 8.w, 8.h),
        child: Row(
          children: [
            Container(
              width: 34.r,
              height: 34.r,
              decoration: BoxDecoration(
                color: AppColors.brass.withValues(alpha: .16),
                borderRadius: BorderRadius.circular(11.r),
              ),
              child: Icon(icon, color: AppColors.inkSoft, size: 18.r),
            ),
            10.horizontalSpace,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: AppColors.ink,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  2.verticalSpace,
                  Text(
                    caption,
                    style: TextStyle(
                      color: AppColors.slate,
                      fontSize: 10.5.sp,
                    ),
                  ),
                ],
              ),
            ),
            if (count != null)
              Container(
                constraints: BoxConstraints(minWidth: 26.r, minHeight: 26.r),
                alignment: Alignment.center,
                padding: EdgeInsets.symmetric(horizontal: 7.w),
                decoration: BoxDecoration(
                  color: AppColors.paperDim,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: AppColors.inkSoft,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      );

  Widget _emptySearchResult(String message) => Container(
        constraints: BoxConstraints(minHeight: 112.h),
        padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 16.h),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .55),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38.r,
              height: 38.r,
              decoration: BoxDecoration(
                color: AppColors.paperDim,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(Icons.person_search_outlined,
                  color: AppColors.slate, size: 20.r),
            ),
            8.verticalSpace,
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.slate, fontSize: 12.sp),
            ),
          ],
        ),
      );

  Widget _memberTile({
    required String name,
    required String subtitle,
    required VoidCallback? onAdd,
    bool alreadyAdded = false,
  }) {
    final trimmedName = name.trim();
    return Container(
      margin: EdgeInsets.symmetric(vertical: 3.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.line),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 3.h),
        leading: CircleAvatar(
          radius: 22.r,
          backgroundColor: AppColors.inkSoft,
          child: Text(
            trimmedName.isEmpty
                ? '?'
                : trimmedName.characters.first.toUpperCase(),
            style: const TextStyle(
              color: AppColors.brassSoft,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          trimmedName.isEmpty ? 'Nus·Nus user' : trimmedName,
          style: TextStyle(
            color: AppColors.ink,
            fontWeight: FontWeight.w600,
            fontSize: 13.5.sp,
          ),
        ),
        subtitle: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: AppColors.slate, fontSize: 11.sp),
        ),
        trailing: alreadyAdded
            ? Tooltip(
                message: 'Already in this group',
                child:
                    Icon(Icons.check_circle, color: AppColors.sage, size: 22.r),
              )
            : onAdd != null
                ? IconButton.filledTonal(
                    tooltip: 'Add to group',
                    onPressed: onAdd,
                    style: IconButton.styleFrom(
                      foregroundColor: AppColors.ink,
                      backgroundColor: AppColors.brass.withValues(alpha: .2),
                    ),
                    icon: Icon(Icons.person_add_alt_1, size: 19.r),
                  )
                : Tooltip(
                    message: 'Only group members can add people',
                    child: Icon(Icons.lock_outline,
                        color: AppColors.slate, size: 20.r),
                  ),
        onTap: alreadyAdded ? null : onAdd,
      ),
    );
  }

  bool _isAlreadyGroupMember(Map<String, dynamic>? user) {
    final uid = user?['uid'] as String?;
    if (uid == null || uid.isEmpty) return false;
    return context
        .read<SplitProvider>()
        .allPeople
        .any((person) => person.linkedUserId == uid && !person.archived);
  }

  String _normaliseText(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp('\\s+'), ' ');

  bool _matchesSearch(Contact contact) {
    final query = _normaliseText(_query);
    if (query.isEmpty) return true;
    if (_normaliseText(contact.displayName ?? '').contains(query)) return true;

    // Ignore spaces, +, brackets and hyphens when searching phone numbers.
    final queryDigits = _digitsOnly(query);
    if (queryDigits.isEmpty) return false;

    // Normalize both sides so a +971 query matches a contact saved as 05...,
    // and a local UAE number matches a profile/contact saved as 971...
    final queryKey = _phoneKey(query);
    return contact.phones.any((phone) {
      final phoneDigits = _digitsOnly(phone.number);
      final phoneKey = _phoneKey(phone.number);
      if (queryKey.length >= 7 && queryKey == phoneKey) return true;
      return phoneDigits.contains(queryDigits) ||
          phoneKey.contains(queryKey) ||
          queryDigits.contains(phoneKey);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SplitProvider>();
    final media = MediaQuery.of(context);
    final bottomInset = media.viewInsets.bottom;
    final availableHeight =
        (media.size.height - bottomInset - media.padding.top - 8.h)
            .clamp(240.h, media.size.height);
    final registeredContacts = _contacts
        .where((contact) => _registeredContactFor(contact) != null)
        .toList();
    final filtered = registeredContacts.where(_matchesSearch).toList();

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: availableHeight.toDouble()),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.paper,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.max,
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
                          Text('Add people to group',
                              style: TextStyle(
                                  color: AppColors.ink,
                                  fontSize: 19.sp,
                                  fontWeight: FontWeight.bold)),
                          3.verticalSpace,
                          Text('Find registered Nus·Nus members',
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
                    hintText: 'Name or phone number',
                    hintStyle: const TextStyle(color: AppColors.slate),
                    prefixIcon:
                        const Icon(Icons.search, color: AppColors.slate),
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
                            icon:
                                const Icon(Icons.close, color: AppColors.slate),
                          ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: .72),
                    contentPadding:
                        EdgeInsets.symmetric(vertical: 17.h, horizontal: 16.w),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14.r),
                      borderSide: BorderSide(color: AppColors.line),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14.r),
                      borderSide: BorderSide(color: AppColors.line),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14.r),
                      borderSide: BorderSide(
                        color: AppColors.brass.withValues(alpha: .8),
                        width: 1.4,
                      ),
                    ),
                  ),
                ),
              ),
              if (_lookupLoading)
                Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 20.w, vertical: 4.h),
                    child:
                        const LinearProgressIndicator(color: AppColors.brass)),
              if (_lookupError != null)
                Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: Text(_lookupError!,
                        style:
                            TextStyle(color: AppColors.rust, fontSize: 12.sp))),
              if (_contactMatchError != null)
                Padding(
                  padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 8.h),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(_contactMatchError!,
                            style: TextStyle(
                                color: AppColors.rust, fontSize: 11.sp)),
                      ),
                      TextButton(
                        onPressed: _matchingContacts
                            ? null
                            : () => _matchLoadedContacts(_contacts),
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
                const Flexible(
                  fit: FlexFit.loose,
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.brass),
                  ),
                )
              else if (_permissionDenied)
                Flexible(
                  fit: FlexFit.loose,
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
                            style: TextStyle(
                                color: AppColors.slate, fontSize: 12.sp),
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
                Flexible(
                  fit: FlexFit.loose,
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
                            style: TextStyle(
                                color: AppColors.slate, fontSize: 12.sp),
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
              else
                Flexible(
                  fit: FlexFit.loose,
                  child: ListView(
                    shrinkWrap: false,
                    padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 18.h),
                    children: [
                      if (_digitsOnly(_query).length >= 7 &&
                          !_lookupLoading &&
                          (_lookupAttempted ||
                              _registeredUser != null ||
                              _lookupError != null)) ...[
                        _sectionLabel(
                          'From search',
                          icon: Icons.search,
                          caption: 'Phone number lookup',
                          count: _registeredUser == null ? 0 : 1,
                        ),
                        if (_registeredUser != null) ...[
                          _memberTile(
                            name: (_registeredUser!['name'] as String?) ??
                                'Nus·Nus user',
                            subtitle: 'Registered Nus·Nus account',
                            alreadyAdded:
                                _isAlreadyGroupMember(_registeredUser),
                            onAdd: provider.canAddMembersToCurrentGroup &&
                                    !_isAlreadyGroupMember(_registeredUser)
                                ? _addRegisteredUser
                                : null,
                          ),
                        ] else if (_lookupAttempted && !_ambiguousMatch)
                          Padding(
                            padding: EdgeInsets.fromLTRB(4.w, 8.h, 4.w, 12.h),
                            child: _emptySearchResult(
                              'No account is registered with this number.',
                            ),
                          )
                        else if (_lookupAttempted && _ambiguousMatch)
                          Padding(
                            padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 12.h),
                            child: _emptySearchResult(
                              'More than one account has this number. Ask the person to update their profile.',
                            ),
                          ),
                      ],
                      _sectionLabel(
                        'From contacts',
                        icon: Icons.contacts_outlined,
                        caption: 'Registered Nus·Nus users',
                        count: filtered.length,
                      ),
                      if (_matchingContacts)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppColors.brass,
                            ),
                          ),
                        )
                      else if (filtered.isEmpty)
                        Padding(
                          padding: EdgeInsets.fromLTRB(4.w, 4.h, 4.w, 8.h),
                          child: _emptySearchResult(
                            _contacts.isEmpty
                                ? 'No contacts with phone numbers were found.'
                                : _query.isEmpty
                                    ? 'No registered Nus·Nus contacts found.'
                                    : 'No matching registered contacts.',
                          ),
                        )
                      else
                        for (final contact in filtered) ...[
                          _memberTile(
                            name: contact.displayName ?? 'Unknown contact',
                            subtitle:
                                'Registered Nus·Nus account · ${contact.phones.first.number}',
                            alreadyAdded: _isAlreadyGroupMember(
                              _registeredContactFor(contact),
                            ),
                            onAdd: provider.canAddMembersToCurrentGroup &&
                                    !_isAlreadyGroupMember(
                                      _registeredContactFor(contact),
                                    )
                                ? () => _addContactUser(contact)
                                : null,
                          ),
                        ],
                    ],
                  ),
                ),
              Padding(
                padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 12.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shield_outlined,
                        color: AppColors.slate, size: 14.r),
                    6.horizontalSpace,
                    Flexible(
                      child: Text(
                        provider.canAddMembersToCurrentGroup
                            ? 'Only registered contacts are listed.'
                            : 'Only group members can add people.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AppColors.slate, fontSize: 10.5.sp),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
