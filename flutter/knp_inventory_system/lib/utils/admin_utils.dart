import 'package:firebase_auth/firebase_auth.dart';

/// Admin access is determined by Firebase Auth email (also enforced in Firestore rules).
class AdminUtils {
  AdminUtils._();

  static const String adminEmail = 'admin@knp.com';

  static bool isAdmin(User? user) {
    return user?.email?.toLowerCase() == adminEmail;
  }
}
