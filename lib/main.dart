import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/split_provider.dart';
import 'screens/auth_gate.dart';
import 'services/push_navigation.dart';
import 'widgets/app_loading_overlay.dart';
import 'theme/app_theme.dart';

// Use only for local/sideloaded builds when the Play Integrity provider cannot
// recognize the installation. Register the debug token in Firebase Console.
// Production builds must leave this unset and use Play Integrity.
const bool _useDebugAppCheck =
    bool.fromEnvironment('FIREBASE_APP_CHECK_DEBUG');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Install App Check before any Firebase callable requests are made.
  // Debug builds use the debug provider; register its token in Firebase
  // Console > App Check > Manage debug tokens. Release Android builds use
  // Play Integrity.
  await FirebaseAppCheck.instance.activate(
    providerWeb: ReCaptchaV3Provider('6LdDD20tAAAAAOzELBUSgYE3PKsBdzKprh8gJ5rv'),
    providerAndroid: (kDebugMode || _useDebugAppCheck)
        ? const AndroidDebugProvider()
        : const AndroidPlayIntegrityProvider(),
    providerApple: (kDebugMode || _useDebugAppCheck)
        ? const AppleDebugProvider()
        : const AppleDeviceCheckProvider(), // Or const AppleAppAttestWithDeviceCheckFallbackProvider()
  );

  // Lets notification taps open the right expense, and shows an in-app banner
  // for pushes that arrive while the app is open (Android).
  registerPushNavigation();

  runApp(const NusNusApp());
}

class NusNusApp extends StatelessWidget {
  const NusNusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => SplitProvider()),
      ],
      child: ScreenUtilInit(
        designSize: const Size(375, 812),
        minTextAdapt: true,
        splitScreenMode: true,
        child: MaterialApp(
          title: 'Nus-Nus',
          navigatorKey: appNavigatorKey,
          scaffoldMessengerKey: appMessengerKey,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          builder: (context, child) => AppLoadingOverlay.wrap(
            child ?? const SizedBox.shrink(),
          ),
          home: const AuthGate(),
        ),
      ),
    );
  }
}
