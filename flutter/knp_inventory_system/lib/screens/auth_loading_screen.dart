import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/employee_service.dart';
import '../utils/admin_utils.dart';
import 'main_layout.dart';

/// Verifies [employees] allowlist after Firebase Auth sign-in.
/// Builds [MainLayout] when allowed; signs out and shows denial otherwise.
class AuthLoadingScreen extends StatefulWidget {
  const AuthLoadingScreen({super.key});

  @override
  State<AuthLoadingScreen> createState() => _AuthLoadingScreenState();
}

class _AuthLoadingScreenState extends State<AuthLoadingScreen> {
  final AuthService _authService = AuthService();
  String _statusMessage = 'Verifying employee eligibility...';
  String? _uidHint;
  bool _hasError = false;
  bool? _isEmployee;

  static String _messageForStatus(EmployeeCheckStatus status) {
    switch (status) {
      case EmployeeCheckStatus.active:
        return '';
      case EmployeeCheckStatus.notOnAllowlist:
        return 'Access Denied\n\n'
            'Your account could not be registered. '
            'Sign in with an email address, or contact your administrator.';
      case EmployeeCheckStatus.inactive:
        return 'Access Denied\n\n'
            'Your account is pending approval. '
            'An administrator must activate your access before you can use the app.';
      case EmployeeCheckStatus.verificationFailed:
        return 'Access Denied\n\n'
            'Could not verify employee access (Firestore or App Check). '
            'If you are an administrator, ensure security rules are deployed '
            'and App Check debug tokens are registered for development.';
    }
  }

  @override
  void initState() {
    super.initState();
    _checkEligibility();
  }

  Future<void> _checkEligibility() async {
    final user = _authService.currentUser;
    if (user == null) {
      return;
    }

    try {
      await user.reload();
    } catch (_) {
      // Offline or transient — continue with cached user for employee check
    }

    final reloadedUser = _authService.currentUser ?? user;

    if (AdminUtils.isAdmin(reloadedUser)) {
      try {
        await _authService.prepareEmployeeGate(reloadedUser);
      } catch (_) {
        // Admin bypass still allows access if ensure fails
      }
      if (!mounted) return;
      setState(() => _isEmployee = true);
      return;
    }

    final status = await _authService.prepareEmployeeGate(reloadedUser);

    if (!mounted) return;

    if (status == EmployeeCheckStatus.active) {
      setState(() => _isEmployee = true);
      return;
    }

    setState(() {
      _isEmployee = false;
      _statusMessage = _messageForStatus(status);
      _uidHint = status == EmployeeCheckStatus.notOnAllowlist
          ? reloadedUser.uid
          : null;
      _hasError = true;
    });
    await _authService.signOut();
  }

  @override
  Widget build(BuildContext context) {
    if (_isEmployee == true) {
      return const MainLayout();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
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
                  fontSize: 15,
                  fontWeight: _hasError ? FontWeight.w600 : FontWeight.w400,
                  color: _hasError ? Colors.redAccent : null,
                  height: 1.35,
                ),
              ),
              if (_uidHint != null) ...[
                const SizedBox(height: 16),
                SelectableText(
                  'UID: $_uidHint',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: Colors.grey.shade600,
                  ),
                ),
                if (kDebugMode) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _uidHint!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('UID copied')),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy UID for admin'),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
