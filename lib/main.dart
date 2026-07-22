import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gemma/core/api/flutter_gemma.dart';
import 'package:flutter_gemma_mediapipe/flutter_gemma_mediapipe.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'providers/split_provider.dart';
import 'screens/split_home_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await FlutterGemma.initialize(
    inferenceEngines: [
      MediaPipeEngine(),
    ],
  );

  runApp(const NusNusApp());
}
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
