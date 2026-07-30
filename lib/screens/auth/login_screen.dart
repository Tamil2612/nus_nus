import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit(AuthProvider auth) async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final error = await auth.signIn(
      email: _emailCtrl.text,
      password: _passwordCtrl.text,
    );
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: AppColors.rust,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
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
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 24.h),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 76.r,
                      height: 76.r,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.brass, width: 2.4),
                      ),
                      child: Icon(Icons.receipt_long_rounded,
                          size: 34.r, color: AppColors.brass),
                    ),
                    18.verticalSpace,
                    RichText(
                      text: TextSpan(
                        style: TextStyle(
                            fontSize: 32.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.paper,
                            fontFamily: 'Georgia'),
                        children: [
                          const TextSpan(text: 'Nus'),
                          TextSpan(text: '·', style: TextStyle(color: AppColors.brass)),
                          const TextSpan(text: 'Nus'),
                        ],
                      ),
                    ),
                    6.verticalSpace,
                    Text(
                      'Welcome back — sign in to split the tab.',
                      style: TextStyle(color: AppColors.slate, fontSize: 13.sp),
                    ),
                    32.verticalSpace,
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Sign in',
                              style: TextStyle(
                                  color: AppColors.ink,
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w700)),
                          14.verticalSpace,
                          TextFormField(
                            controller: _emailCtrl,
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
                                FocusScope.of(context).requestFocus(_passwordFocus),
                          ),
                          12.verticalSpace,
                          TextFormField(
                            controller: _passwordCtrl,
                            focusNode: _passwordFocus,
                            enabled: !auth.isBusy,
                            obscureText: _obscure,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.password],
                            style: TextStyle(color: AppColors.ink, fontSize: 14.sp),
                            decoration: AppTheme.inputDecoration('Password',
                                    icon: Icons.lock_outline)
                                .copyWith(
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscure ? Icons.visibility_off : Icons.visibility,
                                  size: 18.r,
                                  color: AppColors.slate,
                                ),
                                onPressed: () => setState(() => _obscure = !_obscure),
                              ),
                            ),
                            validator: (v) => (v == null || v.isEmpty)
                                ? 'Enter your password.'
                                : null,
                            onFieldSubmitted: (_) => _submit(auth),
                          ),
                          22.verticalSpace,
                          SizedBox(
                            width: double.infinity,
                            height: 50.h,
                            child: ElevatedButton(
                              onPressed: auth.isBusy ? null : () => _submit(auth),
                              style: AppTheme.solidButton,
                              child: auth.isBusy
                                  ? SizedBox(
                                      width: 20.r,
                                      height: 20.r,
                                      child: const CircularProgressIndicator(
                                          color: AppColors.paper, strokeWidth: 2),
                                    )
                                  : Text('Sign in', style: TextStyle(fontSize: 14.sp)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    22.verticalSpace,
                    TextButton(
                      onPressed: auth.isBusy
                          ? null
                          : () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const RegisterScreen()),
                              );
                            },
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(color: AppColors.slate, fontSize: 13.sp),
                          children: [
                            const TextSpan(text: "Don't have an account? "),
                            TextSpan(
                              text: 'Register',
                              style: TextStyle(
                                  color: AppColors.brass, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
