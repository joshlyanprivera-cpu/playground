import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Mock employee check since we don't have a real KNP employee database
  Future<bool> checkIsEmployee(User user) async {
    // Firebase Auth handles the actual validation of whether the user exists.
    // If they successfully logged in, we assume they are eligible.
    return true;
  }

  Future<UserCredential?> signInWithEmail(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      rethrow;
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // ─── Web: Use Firebase Auth popup flow directly ───
        // This is the most reliable approach for web.
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');

        final userCredential = await _auth.signInWithPopup(googleProvider);

        // Check if Firebase just created this account
        if (userCredential.additionalUserInfo?.isNewUser ?? false) {
          await userCredential.user?.delete();
          await _auth.signOut();
          throw Exception('Access Denied: Your email is not registered. Please contact the administrator.');
        }

        return userCredential;
      }

      // ─── Mobile (Android/iOS): Native Google Sign-In flow ───
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      if (googleUser == null) {
        // The user canceled the sign-in
        return null;
      }

      // Obtain the auth details
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Once signed in, return the UserCredential
      final userCredential = await _auth.signInWithCredential(credential);

      // Check if Firebase just created this account
      if (userCredential.additionalUserInfo?.isNewUser ?? false) {
        // The user is not on your pre-approved list.
        // 1. Delete the unwanted account from Firebase
        await userCredential.user?.delete();
        // 2. Sign them out of Firebase
        await _auth.signOut();
        // 3. Clear the Google Sign-In cache so the account chooser appears next time
        await GoogleSignIn().signOut();
        // 4. Throw an error to show on the Login Screen
        throw Exception('Access Denied: Your email is not registered. Please contact the administrator.');
      }

      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    if (!kIsWeb) {
      // Only call GoogleSignIn().signOut() on mobile platforms
      await GoogleSignIn().signOut();
    }
  }
}
