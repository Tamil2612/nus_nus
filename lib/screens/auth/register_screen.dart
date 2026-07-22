import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(AuthProvider auth) async {
    FocusScope.of(context).unfocus();

    if (_nameCtrl.text.trim().isEmpty) {
      _showError('Enter your name.');
      return;
    }
    if (_passwordCtrl.text.length < 6) {
      _showError('Password should be at least 6 characters.');
      return;
    }

    final error = await auth.register(
      name: _nameCtrl.text,
      email: _emailCtrl.text,
      password: _passwordCtrl.text,
    );

    if (error != null && mounted) {
      _showError(error);
    } else if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.rust,
        behavior: SnackBarBehavior.floating,
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
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: 28.w),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
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
                        28.verticalSpace,
                        Container(
                          padding: EdgeInsets.all(20.w),
                          decoration: BoxDecoration(
                            color: AppColors.paper,
                            borderRadius: BorderRadius.circular(16.r),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              TextField(
                                controller: _nameCtrl,
                                style:
                                    TextStyle(color: AppColors.ink, fontSize: 14.sp),
                                decoration: AppTheme.inputDecoration('Your name'),
                              ),
                              12.verticalSpace,
                              TextField(
                                controller: _emailCtrl,
                                keyboardType: TextInputType.emailAddress,
                                style:
                                    TextStyle(color: AppColors.ink, fontSize: 14.sp),
                                decoration: AppTheme.inputDecoration('Email'),
                              ),
                              12.verticalSpace,
                              TextField(
                                controller: _passwordCtrl,
                                obscureText: _obscure,
                                style:
                                    TextStyle(color: AppColors.ink, fontSize: 14.sp),
                                decoration:
                                    AppTheme.inputDecoration('Password (min. 6 characters)')
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
                                onSubmitted: (_) => _submit(auth),
                              ),
                              20.verticalSpace,
                              SizedBox(
                                width: double.infinity,
                                height: 48.h,
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
                      ],
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
