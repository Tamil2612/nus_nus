import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../data/account_deletion_repository.dart';
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/phone_input_field.dart';
import '../widgets/app_dialog.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _phoneKey = GlobalKey<PhoneInputFieldState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool _discoverableByPhone = true;
  bool _discoverabilityChanged = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    auth.reloadUser(); // Refresh user state from server

    final user = auth.currentUser;
    final profile = auth.appUser;
    _nameCtrl.text = user?.displayName ?? '';
    _emailCtrl.text = user?.email ?? '';
    _phoneCtrl.text = profile?.phoneNumber ?? '';
    _discoverableByPhone = profile?.discoverableByPhone ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _updateBasicInfo(AuthProvider auth) async {
    final error = await auth.updateProfile(
      name: _nameCtrl.text.trim(),
      phoneNumber: _phoneKey.currentState?.fullNumber ?? _phoneCtrl.text.trim(),
      discoverableByPhone:
          _discoverabilityChanged ? _discoverableByPhone : null,
    );
    if (!mounted) return;
    if (error != null) {
      _showSnack(error, isError: true);
    } else {
      _showSnack('Profile updated successfully!');
    }
  }

  Future<void> _updateEmail(AuthProvider auth) async {
    final password = await _promptForPassword();
    if (password == null) return;

    final error = await auth.updateEmail(_emailCtrl.text.trim(), password);
    if (!mounted) return;
    if (error != null) {
      _showSnack(error, isError: true);
    } else {
      _showSnack('Verification email sent to new address!');
    }
  }

  Future<String?> _promptForPassword() async {
    final ctrl = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (ctx) => AppDialog(
        icon: Icons.lock_outline_rounded,
        iconColor: AppColors.ink,
        title: 'Confirm Identity',
        message: 'Please enter your current password to continue.',
        confirmText: 'Confirm',
        confirmColor: AppColors.ink,
        onConfirm: () => Navigator.pop(ctx, ctrl.text),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          autofocus: true,
          style: const TextStyle(color: AppColors.ink),
          decoration: AppTheme.inputDecoration('Current Password'),
        ),
      ),
    );
    ctrl.dispose();
    return password;
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.rust : AppColors.sage,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.ink,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.paper),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Edit Profile',
            style: TextStyle(
                color: AppColors.paper,
                fontWeight: FontWeight.bold,
                fontSize: 18.sp)),
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
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionTitle(title: 'PERSONAL INFO'),
                16.verticalSpace,
                _buildCard(
                  children: [
                    TextFormField(
                      controller: _nameCtrl,
                      style: const TextStyle(color: AppColors.ink),
                      decoration: AppTheme.inputDecoration('Full Name',
                          icon: Icons.person_outline),
                    ),
                    12.verticalSpace,
                    PhoneInputField(
                      key: _phoneKey,
                      controller: _phoneCtrl,
                      enabled: !auth.isBusy,
                      initialValue: auth.appUser?.phoneNumber,
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _discoverableByPhone,
                      activeTrackColor: AppColors.sage,
                      title: const Text('Let contacts find me'),
                      subtitle: const Text(
                        'People can find your account by matching your phone number.',
                      ),
                      onChanged: auth.isBusy
                          ? null
                          : (value) => setState(() {
                                _discoverabilityChanged = true;
                                _discoverableByPhone = value;
                              }),
                    ),
                    20.verticalSpace,
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            auth.isBusy ? null : () => _updateBasicInfo(auth),
                        style: AppTheme.solidButton,
                        child: const Text('Save Info'),
                      ),
                    ),
                  ],
                ),
                32.verticalSpace,
                _SectionTitle(title: 'EMAIL ADDRESS'),
                16.verticalSpace,
                _buildCard(
                  children: [
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: AppColors.ink),
                      decoration: AppTheme.inputDecoration('Email Address',
                          icon: Icons.mail_outline),
                    ),
                    12.verticalSpace,
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed:
                            auth.isBusy ? null : () => _updateEmail(auth),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.ink,
                          side: const BorderSide(color: AppColors.line),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r)),
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                        ),
                        child: const Text('Update Email'),
                      ),
                    ),
                  ],
                ),
                if (auth.isBusy)
                  Padding(
                    padding: EdgeInsets.only(top: 24.h),
                    child: const Center(
                        child:
                            CircularProgressIndicator(color: AppColors.brass)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: const [
          BoxShadow(
              color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
          color: AppColors.paper,
          fontSize: 11.sp,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2),
    );
  }
}

class AccountDeletionChoice {
  final Map<String, String> transfers;
  final List<String> deleteGroupIds;
  final bool acknowledgeUnsettled;

  const AccountDeletionChoice({
    required this.transfers,
    required this.deleteGroupIds,
    required this.acknowledgeUnsettled,
  });
}

class AccountDeletionDialog extends StatefulWidget {
  final AccountDeletionPlan plan;

  const AccountDeletionDialog({super.key, required this.plan});

  @override
  State<AccountDeletionDialog> createState() => _AccountDeletionDialogState();
}

class _AccountDeletionDialogState extends State<AccountDeletionDialog> {
  final Map<String, String> _transfers = {};
  final Set<String> _deleteGroupIds = {};
  bool _confirmed = false;
  bool _acknowledgeUnsettled = false;

  bool get _hasUnsettledDebt => widget.plan.groupBalances.any(
        (group) =>
            group.counterparties.any((balance) => balance.balance < -0.005),
      );

  bool get _hasUnsettledCredit => widget.plan.groupBalances.any(
        (group) =>
            group.counterparties.any((balance) => balance.balance > 0.005),
      );

  bool get _canContinue =>
      _confirmed &&
      !_hasUnsettledDebt &&
      (!_hasUnsettledCredit || _acknowledgeUnsettled) &&
      widget.plan.ownedGroups.every(
        (group) =>
            _deleteGroupIds.contains(group.id) ||
            _transfers.containsKey(group.id),
      );

  void _finish() {
    if (!_canContinue) return;
    Navigator.of(context).pop(
      AccountDeletionChoice(
        transfers: Map.of(_transfers),
        deleteGroupIds: _deleteGroupIds.toList(),
        acknowledgeUnsettled: _acknowledgeUnsettled,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final dialogWidth = (screen.width - 36).clamp(0.0, 480.0).toDouble();
    return Dialog(
      backgroundColor: AppColors.paper,
      surfaceTintColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 20.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
      child: SizedBox(
        width: dialogWidth,
        height: screen.height * 0.84,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 20.h, 14.w, 12.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44.r,
                    height: 44.r,
                    decoration: BoxDecoration(
                      color: AppColors.rust.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    child: Icon(Icons.person_remove_alt_1_outlined,
                        color: AppColors.rust, size: 23.r),
                  ),
                  12.horizontalSpace,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delete account',
                          style: TextStyle(
                            color: AppColors.ink,
                            fontSize: 19.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        4.verticalSpace,
                        Text(
                          'Review what happens to your shared groups.',
                          style: TextStyle(
                            color: AppColors.slate,
                            fontSize: 11.sp,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cancel',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: AppColors.slate, size: 21.r),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: AppColors.line),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(18.w, 14.h, 18.w, 10.h),
                children: [
                  Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: AppColors.brassSoft.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline,
                            color: AppColors.ink, size: 18.r),
                        9.horizontalSpace,
                        Expanded(
                          child: Text(
                            'Your account and personal ledger will be removed. Shared group history stays, with your old name shown as “Former member”.',
                            style: TextStyle(
                              color: AppColors.ink,
                              fontSize: 11.sp,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  16.verticalSpace,
                  if (widget.plan.groupBalances.isNotEmpty) ...[
                    Text(
                      'CURRENT GROUP BALANCES',
                      style: TextStyle(
                        color: AppColors.slate,
                        fontSize: 10.sp,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    4.verticalSpace,
                    for (final balance in widget.plan.groupBalances)
                      _buildBalanceRow(balance),
                    12.verticalSpace,
                  ],
                  if (widget.plan.ownedGroups.isEmpty)
                    _buildEmptyGroups()
                  else ...[
                    Text(
                      'GROUPS YOU OWN',
                      style: TextStyle(
                        color: AppColors.slate,
                        fontSize: 10.sp,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    4.verticalSpace,
                    for (final group in widget.plan.ownedGroups)
                      _buildGroupChoice(group),
                  ],
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(18.w, 10.h, 18.w, 16.h),
              decoration: BoxDecoration(
                color: AppColors.paper,
                border: Border(top: BorderSide(color: AppColors.line)),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(24.r),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(12.r),
                    onTap: () => setState(() => _confirmed = !_confirmed),
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 5.h),
                      child: Row(
                        children: [
                          Checkbox(
                            value: _confirmed,
                            activeColor: AppColors.rust,
                            side:
                                BorderSide(color: AppColors.slate, width: 1.5),
                            onChanged: (value) =>
                                setState(() => _confirmed = value ?? false),
                          ),
                          4.horizontalSpace,
                          Expanded(
                            child: Text(
                              'I understand this deletion is permanent.',
                              style: TextStyle(
                                color: AppColors.ink,
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_hasUnsettledCredit)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _acknowledgeUnsettled,
                      activeColor: AppColors.rust,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text('Acknowledge balances owed to me'),
                      subtitle: const Text(
                        'Account deletion will not settle these receivables.',
                      ),
                      onChanged: (value) => setState(
                        () => _acknowledgeUnsettled = value ?? false,
                      ),
                    ),
                  if (_hasUnsettledDebt)
                    Padding(
                      padding: EdgeInsets.only(top: 6.h),
                      child: Text(
                        'Settle balances you owe before continuing with account deletion.',
                        style: TextStyle(
                          color: AppColors.rust,
                          fontSize: 11.sp,
                          height: 1.35,
                        ),
                      ),
                    ),
                  8.verticalSpace,
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.ink,
                            side: BorderSide(color: AppColors.line),
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      10.horizontalSpace,
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _canContinue ? _finish : null,
                          icon: Icon(Icons.arrow_forward, size: 17.r),
                          label: const Text('Continue'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.ink,
                            foregroundColor: AppColors.paper,
                            disabledBackgroundColor: AppColors.paperDim,
                            disabledForegroundColor: AppColors.slate,
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupChoice(AccountDeletionGroup group) {
    final deleting = _deleteGroupIds.contains(group.id);
    return Container(
      margin: EdgeInsets.only(top: 10.h),
      padding: EdgeInsets.all(13.w),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.line, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32.r,
                height: 32.r,
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(Icons.groups_outlined,
                    color: AppColors.brassSoft, size: 17.r),
              ),
              10.horizontalSpace,
              Expanded(
                child: Text(
                  group.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.only(top: 10.h),
            child: Text(
              _balanceLabel(group.balance, group.currency),
              style: TextStyle(
                color: _balanceColor(group.balance),
                fontSize: 11.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (group.candidates.isNotEmpty) ...[
            12.verticalSpace,
            Text(
              'NEW GROUP OWNER',
              style: TextStyle(
                color: AppColors.slate,
                fontSize: 9.sp,
                letterSpacing: 0.7,
                fontWeight: FontWeight.w800,
              ),
            ),
            6.verticalSpace,
            _buildOwnerPicker(group, deleting),
          ] else ...[
            Container(
              margin: EdgeInsets.only(top: 10.h),
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: AppColors.brassSoft.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(11.r),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: AppColors.ink, size: 16.r),
                  7.horizontalSpace,
                  Expanded(
                    child: Text(
                      'No eligible member can take ownership. Delete this group or cancel account deletion.',
                      style: TextStyle(
                        color: AppColors.ink,
                        fontSize: 10.sp,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          10.verticalSpace,
          InkWell(
            borderRadius: BorderRadius.circular(12.r),
            onTap: () => _setDeleteChoice(group.id, !deleting),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: deleting
                    ? AppColors.rust.withValues(alpha: 0.10)
                    : AppColors.paperDim.withValues(alpha: 0.58),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: deleting
                      ? AppColors.rust.withValues(alpha: 0.45)
                      : AppColors.line,
                ),
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: deleting,
                    activeColor: AppColors.rust,
                    side: BorderSide(color: AppColors.slate, width: 1.4),
                    onChanged: (value) =>
                        _setDeleteChoice(group.id, value ?? false),
                  ),
                  4.horizontalSpace,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delete this group',
                          style: TextStyle(
                            color: AppColors.rust,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Permanently remove its history',
                          style: TextStyle(
                            color: AppColors.slate,
                            fontSize: 9.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.delete_outline, color: AppColors.rust, size: 18.r),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOwnerPicker(AccountDeletionGroup group, bool deleting) {
    final selectedUid = _transfers[group.id];
    final selected = group.candidates
        .where((candidate) => candidate.uid == selectedUid)
        .firstOrNull;
    return Opacity(
      opacity: deleting ? 0.48 : 1,
      child: PopupMenuButton<String>(
        enabled: !deleting,
        onSelected: (uid) => setState(() => _transfers[group.id] = uid),
        color: AppColors.paper,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14.r),
        ),
        itemBuilder: (context) => group.candidates
            .map((candidate) => PopupMenuItem<String>(
                  value: candidate.uid,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14.r,
                        backgroundColor: AppColors.ink,
                        child: Text(
                          candidate.name.isEmpty
                              ? '?'
                              : candidate.name.characters.first.toUpperCase(),
                          style: TextStyle(
                            color: AppColors.paper,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      10.horizontalSpace,
                      Expanded(
                        child: Text(
                          candidate.name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.ink,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ))
            .toList(),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: AppColors.paperDim,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: selected == null ? AppColors.line : AppColors.brass,
              width: selected == null ? 1 : 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.swap_horiz, color: AppColors.ink, size: 19.r),
              9.horizontalSpace,
              Expanded(
                child: Text(
                  selected?.name ?? 'Choose a group owner',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 12.sp,
                    fontWeight:
                        selected == null ? FontWeight.w500 : FontWeight.w700,
                  ),
                ),
              ),
              Icon(Icons.keyboard_arrow_down, color: AppColors.ink, size: 20.r),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyGroups() {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.paperDim,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Text(
        'You do not own any shared groups that need an ownership decision.',
        style: TextStyle(
          color: AppColors.ink,
          fontSize: 12.sp,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildBalanceRow(AccountDeletionBalance balance) {
    final deleting = widget.plan.ownedGroups.any((group) =>
        group.id == balance.id && _deleteGroupIds.contains(group.id));
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 5.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  balance.name + (deleting ? ' · will be deleted' : ''),
                  style: TextStyle(color: AppColors.ink, fontSize: 11.sp),
                ),
              ),
              Text(
                balance.counterparties.isEmpty
                    ? 'Settled'
                    : '${balance.counterparties.length} pair(s)',
                style: TextStyle(color: AppColors.slate, fontSize: 10.sp),
              ),
            ],
          ),
          if (balance.counterparties.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(left: 8.w, top: 2.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final pair in balance.counterparties)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 2.h),
                      child: Text(
                        pair.balance > 0
                            ? '${pair.personName} owes you ${pair.balance.toStringAsFixed(2)} ${balance.currency}'
                            : 'You owe ${pair.personName} ${(-pair.balance).toStringAsFixed(2)} ${balance.currency}',
                        style: TextStyle(
                          color: pair.balance < -0.005
                              ? AppColors.rust
                              : AppColors.ink,
                          fontSize: 10.sp,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _balanceLabel(double balance, String currency) {
    if (balance > 0.005) return 'Owed ${balance.toStringAsFixed(2)} $currency';
    if (balance < -0.005) {
      return 'You owe ${(-balance).toStringAsFixed(2)} $currency';
    }
    return 'Settled';
  }

  Color _balanceColor(double balance) => balance < -0.005
      ? AppColors.rust
      : balance > 0.005
          ? AppColors.ink
          : AppColors.slate;

  void _setDeleteChoice(String groupId, bool deleting) {
    setState(() {
      if (deleting) {
        _deleteGroupIds.add(groupId);
        _transfers.remove(groupId);
      } else {
        _deleteGroupIds.remove(groupId);
      }
    });
  }
}
