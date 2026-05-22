import 'package:flutter/foundation.dart'
    show debugPrint, kDebugMode, kIsWeb, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'services/auth_service.dart';
import 'screens/auth_loading_screen.dart';
import 'screens/login_screen.dart';

/// reCAPTCHA v3 site key for web App Check — set in Firebase Console → App Check.
const String _webRecaptchaSiteKey = String.fromEnvironment(
  'FIREBASE_APP_CHECK_WEB_SITE_KEY',
  defaultValue: 'REPLACE_WITH_RECAPTCHA_V3_SITE_KEY',
);

Future<void> _activateAppCheck() async {
  if (kIsWeb) {
    await FirebaseAppCheck.instance.activate(
      providerWeb: ReCaptchaV3Provider(_webRecaptchaSiteKey),
    );
    return;
  }

  await FirebaseAppCheck.instance.activate(
    providerAndroid: kReleaseMode
        ? const AndroidPlayIntegrityProvider()
        : const AndroidDebugProvider(),
    providerApple: kReleaseMode
        ? const AppleAppAttestProvider()
        : const AppleDebugProvider(),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  try {
    await _activateAppCheck();
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('App Check activation failed (configure in Firebase Console): $e\n$st');
    }
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const KNPInventoryApp(),
    ),
  );
}

class KNPInventoryApp extends StatelessWidget {
  const KNPInventoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'KNP Inventory System',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          home: const AuthGate(),
        );
      },
    );
  }
}

/// Routes by [AuthService.authStateChanges]; re-checks employee on sign-in.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snapshot.data;
        if (user == null) {
          return const LoginScreen();
        }
        return const AuthLoadingScreen();
      },
    );
  }
}
