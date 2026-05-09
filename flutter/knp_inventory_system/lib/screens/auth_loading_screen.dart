import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'main_layout.dart';
import 'login_screen.dart';

class AuthLoadingScreen extends StatefulWidget {
  const AuthLoadingScreen({super.key});

  @override
  State<AuthLoadingScreen> createState() => _AuthLoadingScreenState();
}

class _AuthLoadingScreenState extends State<AuthLoadingScreen> {
  final AuthService _authService = AuthService();
  String _statusMessage = 'Verifying employee eligibility...';
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _checkEligibility();
  }

  Future<void> _checkEligibility() async {
    final user = _authService.currentUser;
    if (user == null) {
      _goToLogin();
      return;
    }

    try {
      // Force refresh profile data from Firebase to ensure display name/photo are loaded
      await user.reload();
    } catch (_) {
      // Ignore if offline
    }
    
    // Briefly show the loading screen for UX
    await Future.delayed(const Duration(seconds: 1));

    final isEmployee = await _authService.checkIsEmployee(user);
    if (isEmployee) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainLayout()),
        );
      }
    } else {
      if (mounted) {
        setState(() {
          _statusMessage =
              'Access Denied\n\nThis account is not registered as a KNP employee. Please contact your administrator.';
          _hasError = true;
        });
        await _authService.signOut();
        await Future.delayed(const Duration(seconds: 3));
        if (mounted) _goToLogin();
      }
    }
  }

  void _goToLogin() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Show the KNP logo while loading
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Image.asset('images/knp_logo.png', height: 80),
              ),
              const SizedBox(height: 32),
              if (!_hasError)
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              else
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withAlpha(25),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.error_outline,
                      color: Colors.redAccent, size: 48),
                ),
              const SizedBox(height: 24),
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: _hasError ? 16 : 15,
                  fontWeight: _hasError ? FontWeight.w600 : FontWeight.w400,
                  color: _hasError ? Colors.redAccent : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
