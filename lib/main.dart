import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'providers/split_provider.dart';
import 'screens/split_home_screen.dart';
import 'theme/app_theme.dart';

void main() => runApp(const NusNusApp());

class NusNusApp extends StatelessWidget {
  const NusNusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SplitProvider(),
      child: ScreenUtilInit(
        designSize: const Size(375, 812),
        minTextAdapt: true,
        splitScreenMode: true,
        child: MaterialApp(
          title: 'Nus-Nus',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          home: const SplitHomeScreen(),
        ),
      ),
    );
  }
}
