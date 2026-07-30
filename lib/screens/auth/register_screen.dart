import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/phone_input_field.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneKey = GlobalKey<PhoneInputFieldState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _emailFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _obscure = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _emailFocus.dispose();
    _phoneFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit(AuthProvider auth) async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final error = await auth.register(
      name: _nameCtrl.text,
      email: _emailCtrl.text,
      password: _passwordCtrl.text,
      phoneNumber: _phoneKey.currentState?.fullNumber ?? _phoneCtrl.text,
    );

    if (error != null && mounted) {
      _showError(error);
    } else if (mounted) {
      // Registration signs the account in automatically. AuthGate is
      // already swapping over to the home screen behind this route, so
      // popping just clears this form off the stack — the person lands
      // straight on Home instead of any extra setup step.
      Navigator.of(context).pop();
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.rust,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.4, -0.6),
            radius: 1.2,
            colors: [AppColors.inkSoft, AppColors.ink],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.all(8.w),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: AppColors.paper),
                      onPressed: auth.isBusy ? null : () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: 28.w),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 64.r,
                            height: 64.r,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.brass, width: 2.2),
                            ),
                            child: Icon(Icons.person_add_alt_1_rounded,
                                size: 28.r, color: AppColors.brass),
                          ),
                          16.verticalSpace,
                          Text(
                            'Create your account',
                            style: TextStyle(
                                fontSize: 22.sp,
                                fontWeight: FontWeight.w700,
                                color: AppColors.paper,
                                fontFamily: 'Georgia'),
                          ),
                          8.verticalSpace,
                          Text(
                            "You'll show up in others' member lists once you register.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.slate, fontSize: 12.5.sp),
                          ),
                          26.verticalSpace,
                          Container(
                            padding: EdgeInsets.all(22.w),
                            decoration: BoxDecoration(
                              color: AppColors.paper,
                              borderRadius: BorderRadius.circular(20.r),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.22),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _nameCtrl,
                                  enabled: !auth.isBusy,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [AutofillHints.name],
                                  style: TextStyle(color: AppColors.ink, fontSize: 14.sp),
                                  decoration: AppTheme.inputDecoration('Your name',
                                      icon: Icons.person_outline),
                                  validator: (v) => (v == null || v.trim().isEmpty)
                                      ? 'Enter your name.'
                                      : null,
                                  onFieldSubmitted: (_) =>
                                      FocusScope.of(context).requestFocus(_emailFocus),
                                ),
                                12.verticalSpace,
                                TextFormField(
                                  controller: _emailCtrl,
                                  focusNode: _emailFocus,
                                  enabled: !auth.isBusy,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [AutofillHints.email],
                                  style: TextStyle(color: AppColors.ink, fontSize: 14.sp),
                                  decoration: AppTheme.inputDecoration('Email',
                                      icon: Icons.mail_outline),
                                  validator: (v) {
                                    final value = v?.trim() ?? '';
                                    if (value.isEmpty) return 'Enter your email.';
                                    if (!value.contains('@') || !value.contains('.')) {
                                      return 'Enter a valid email.';
                                    }
                                    return null;
                                  },
                                  onFieldSubmitted: (_) =>
                                      FocusScope.of(context).requestFocus(_phoneFocus),
                                ),
                                12.verticalSpace,
                                PhoneInputField(
                                  key: _phoneKey,
                                  controller: _phoneCtrl,
                                  focusNode: _phoneFocus,
                                  enabled: !auth.isBusy,
                                  nextFocusNode: _passwordFocus,
                                ),
                                12.verticalSpace,
                                TextFormField(
                                  controller: _passwordCtrl,
                                  focusNode: _passwordFocus,
                                  enabled: !auth.isBusy,
                                  obscureText: _obscure,
                                  textInputAction: TextInputAction.done,
                                  autofillHints: const [AutofillHints.newPassword],
                                  style: TextStyle(color: AppColors.ink, fontSize: 14.sp),
                                  decoration: AppTheme.inputDecoration(
                                          'Password (min. 6 characters)',
                                          icon: Icons.lock_outline)
                                      .copyWith(
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscure
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                        size: 18.r,
                                        color: AppColors.slate,
                                      ),
                                      onPressed: () =>
                                          setState(() => _obscure = !_obscure),
                                    ),
                                  ),
                                  validator: (v) => (v == null || v.length < 6)
                                      ? 'Password should be at least 6 characters.'
                                      : null,
                                  onFieldSubmitted: (_) => _submit(auth),
                                ),
                                22.verticalSpace,
                                SizedBox(
                                  width: double.infinity,
                                  height: 50.h,
                                  child: ElevatedButton(
                                    onPressed:
                                        auth.isBusy ? null : () => _submit(auth),
                                    style: AppTheme.solidButton,
                                    child: auth.isBusy
                                        ? SizedBox(
                                            width: 20.r,
                                            height: 20.r,
                                            child: const CircularProgressIndicator(
                                                color: AppColors.paper,
                                                strokeWidth: 2),
                                          )
                                        : Text('Create account',
                                            style: TextStyle(fontSize: 14.sp)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          20.verticalSpace,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
