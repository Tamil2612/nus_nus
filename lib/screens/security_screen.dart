import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../data/account_deletion_repository.dart';
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_dialog.dart';
import 'edit_profile_screen.dart'
    show AccountDeletionChoice, AccountDeletionDialog;

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  final _newPasswordCtrl = TextEditingController();
  bool _isObscure = true;
  bool _isPreparingDeletion = false;

  @override
  void dispose() {
    _newPasswordCtrl.dispose();
    super.dispose();
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? AppColors.rust : AppColors.sage,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _updatePassword(AuthProvider auth) async {
    if (_newPasswordCtrl.text.length < 6) {
      _showSnack('Password must be at least 6 characters.', isError: true);
      return;
    }
    final currentPassword = await _promptForPassword();
    if (currentPassword == null) return;
    final error = await auth.updatePassword(
        _newPasswordCtrl.text.trim(), currentPassword);
    if (!mounted) return;
    if (error != null) {
      _showSnack(error, isError: true);
    } else {
      _newPasswordCtrl.clear();
      _showSnack('Password changed successfully!');
    }
  }

  Future<void> _deleteAccount(AuthProvider auth) async {
    if (_isPreparingDeletion || auth.isBusy) return;
    setState(() => _isPreparingDeletion = true);
    AccountDeletionPlan plan;
    try {
      plan = await AccountDeletionRepository.instance.getPlan();
    } catch (_) {
      if (mounted) {
        setState(() => _isPreparingDeletion = false);
        _showSnack('Could not load your groups. Please try again.',
            isError: true);
      }
      return;
    }
    if (!mounted) return;
    setState(() => _isPreparingDeletion = false);

    final choice = await showDialog<AccountDeletionChoice>(
      context: context,
      builder: (_) => AccountDeletionDialog(plan: plan),
    );
    if (choice == null || !mounted) return;
    final password = await _promptForPassword();
    if (password == null || !mounted) return;
    final error = await auth.deleteAccount(
      currentPassword: password,
      transfers: choice.transfers,
      deleteGroupIds: choice.deleteGroupIds,
      acknowledgeUnsettled: choice.acknowledgeUnsettled,
    );
    if (mounted && error != null) _showSnack(error, isError: true);
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
        title: Text('Security',
            style: TextStyle(
              color: AppColors.paper,
              fontWeight: FontWeight.bold,
              fontSize: 18.sp,
            )),
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
          child: ListView(
            padding: EdgeInsets.all(24.w),
            children: [
              _sectionTitle('CHANGE PASSWORD'),
              12.verticalSpace,
              _card([
                TextFormField(
                  controller: _newPasswordCtrl,
                  obscureText: _isObscure,
                  style: const TextStyle(color: AppColors.ink),
                  decoration: AppTheme.inputDecoration('New Password',
                          icon: Icons.lock_outline)
                      .copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                          _isObscure ? Icons.visibility_off : Icons.visibility,
                          color: AppColors.slate,
                          size: 18.r),
                      onPressed: () => setState(() => _isObscure = !_isObscure),
                    ),
                  ),
                ),
                12.verticalSpace,
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: auth.isBusy ? null : () => _updatePassword(auth),
                    style: _buttonStyle(),
                    child: const Text('Change Password'),
                  ),
                ),
              ]),
              28.verticalSpace,
              _sectionTitle('DANGER ZONE'),
              12.verticalSpace,
              _card([
                Text('Delete account',
                    style: TextStyle(
                      color: AppColors.rust,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w800,
                    )),
                8.verticalSpace,
                Text(
                  'Your personal ledger and profile will be deleted. Shared history will be kept and former-member names anonymized. You will choose who takes ownership of each group.',
                  style: TextStyle(
                      color: AppColors.slate, fontSize: 12.sp, height: 1.4),
                ),
                16.verticalSpace,
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: auth.isBusy || _isPreparingDeletion
                        ? null
                        : () => _deleteAccount(auth),
                    icon: _isPreparingDeletion
                        ? SizedBox(
                            width: 16.r,
                            height: 16.r,
                            child: const CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.rust),
                          )
                        : const Icon(Icons.delete_forever_outlined),
                    label: Text(
                        _isPreparingDeletion ? 'Preparing…' : 'Delete account'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.rust,
                      side: const BorderSide(color: AppColors.rust),
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r)),
                    ),
                  ),
                ),
              ]),
              if (auth.isBusy)
                Padding(
                  padding: EdgeInsets.only(top: 24.h),
                  child: const Center(
                      child: CircularProgressIndicator(color: AppColors.brass)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(title,
      style: TextStyle(
        color: AppColors.paper,
        fontSize: 11.sp,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.2,
      ));

  Widget _card(List<Widget> children) => Container(
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

  ButtonStyle _buttonStyle() => OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        side: const BorderSide(color: AppColors.line),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
        padding: EdgeInsets.symmetric(vertical: 12.h),
      );
}
