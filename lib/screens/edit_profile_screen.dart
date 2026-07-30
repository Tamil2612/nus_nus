import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/phone_input_field.dart';

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
  final _newPasswordCtrl = TextEditingController();

  bool _isObscure = true;

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
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _newPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _updateBasicInfo(AuthProvider auth) async {
    final error = await auth.updateProfile(
      name: _nameCtrl.text.trim(),
      phoneNumber: _phoneKey.currentState?.fullNumber ?? _phoneCtrl.text.trim(),
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

  Future<void> _updatePassword(AuthProvider auth) async {
    if (_newPasswordCtrl.text.length < 6) {
      _showSnack('Password must be at least 6 characters.', isError: true);
      return;
    }

    final currentPassword = await _promptForPassword();
    if (currentPassword == null) return;

    final error =
        await auth.updatePassword(_newPasswordCtrl.text.trim(), currentPassword);
    if (!mounted) return;
    if (error != null) {
      _showSnack(error, isError: true);
    } else {
      _newPasswordCtrl.clear();
      _showSnack('Password changed successfully!');
    }
  }

  Future<String?> _promptForPassword() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.paper,
        title: const Text('Confirm Identity',
            style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please enter your current password to continue.',
                style: TextStyle(color: AppColors.slate)),
            16.verticalSpace,
            TextField(
              controller: ctrl,
              obscureText: true,
              style: const TextStyle(color: AppColors.ink),
              decoration: AppTheme.inputDecoration('Current Password'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.slate))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            style: AppTheme.solidButton,
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
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
                    20.verticalSpace,
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: auth.isBusy ? null : () => _updateBasicInfo(auth),
                        style: AppTheme.solidButton,
                        child: const Text('Save Info'),
                      ),
                    ),
                  ],
                ),
                32.verticalSpace,
                _SectionTitle(title: 'ACCOUNT SECURITY'),
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
                        onPressed: auth.isBusy ? null : () => _updateEmail(auth),
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
                    24.verticalSpace,
                    const Divider(color: AppColors.line),
                    24.verticalSpace,
                    TextFormField(
                      controller: _newPasswordCtrl,
                      obscureText: _isObscure,
                      style: const TextStyle(color: AppColors.ink),
                      decoration: AppTheme.inputDecoration('New Password',
                              icon: Icons.lock_outline)
                          .copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(
                              _isObscure
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: AppColors.slate,
                              size: 18.r),
                          onPressed: () =>
                              setState(() => _isObscure = !_isObscure),
                        ),
                      ),
                    ),
                    12.verticalSpace,
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: auth.isBusy ? null : () => _updatePassword(auth),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.ink,
                          side: const BorderSide(color: AppColors.line),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r)),
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                        ),
                        child: const Text('Change Password'),
                      ),
                    ),
                  ],
                ),
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
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
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
