import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'employee_service.dart';

class AuthException implements Exception {
  AuthException(this.message, {required this.notRegistered});

  final String message;
  final bool notRegistered;

  @override
  String toString() => message;
}

class AuthService {
  AuthService({
    FirebaseAuth? auth,
    EmployeeService? employeeService,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _employeeService = employeeService ?? EmployeeService();

  final FirebaseAuth _auth;
  final EmployeeService _employeeService;

  static const String notRegisteredMessage =
      'This account is not registered. Ask your administrator to create your account, then sign in again.';

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  static String authErrorMessage(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
        case 'admin-restricted-operation':
          return notRegisteredMessage;
        case 'wrong-password':
        case 'invalid-credential':
          return 'Incorrect email or password.';
        case 'user-disabled':
          return 'This account has been disabled. Contact your administrator.';
        case 'too-many-requests':
          return 'Too many attempts. Try again later.';
        default:
          return 'Sign-in failed. Please try again or contact your administrator.';
      }
    }
    if (error is AuthException) {
      return error.message;
    }
    if (error is Exception) {
      return error.toString().replaceFirst('Exception: ', '');
    }
    return 'Sign-in failed. Please try again or contact your administrator.';
  }

  static bool isNotRegisteredError(Object error) {
    if (error is AuthException) {
      return error.notRegistered;
    }
    if (error is FirebaseAuthException) {
      return error.code == 'user-not-found' ||
          error.code == 'admin-restricted-operation';
    }
    return false;
  }

  /// Verifies the user exists in `employees/{uid}` with `active: true`.
  Future<bool> checkIsEmployee(User user) async {
    return _employeeService.isActiveEmployee(user);
  }

  Future<EmployeeCheckStatus> checkEmployeeStatus(User user) async {
    return _employeeService.checkStatus(user);
  }

  /// Ensures a pending Firestore record exists, then returns eligibility status.
  Future<EmployeeCheckStatus> prepareEmployeeGate(User user) async {
    await _employeeService.ensurePendingRecord(user);
    return _employeeService.checkStatus(user);
  }

  Future<void> _clearGoogleSession() async {
    await _auth.signOut();
    if (!kIsWeb) {
      await GoogleSignIn().signOut();
    }
  }

  Never _throwAuthError(Object error) {
    final notRegistered = error is FirebaseAuthException &&
        (error.code == 'user-not-found' ||
            error.code == 'admin-restricted-operation');
    throw AuthException(
      authErrorMessage(error),
      notRegistered: notRegistered,
    );
  }

  Future<UserCredential?> signInWithEmail(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      _throwAuthError(e);
    } catch (e) {
      _throwAuthError(e);
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      UserCredential userCredential;
      if (kIsWeb) {
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');

        userCredential = await _auth.signInWithPopup(googleProvider);
      } else {
        final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

        if (googleUser == null) {
          return null;
        }

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        userCredential = await _auth.signInWithCredential(credential);
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'admin-restricted-operation' ||
          e.code == 'user-not-found') {
        await _clearGoogleSession();
      }
      _throwAuthError(e);
    } on AuthException {
      rethrow;
    } catch (e) {
      _throwAuthError(e);
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    if (!kIsWeb) {
      await GoogleSignIn().signOut();
    }
  }
}
