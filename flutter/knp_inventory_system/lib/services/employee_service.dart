import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import '../models/employee_record.dart';

/// Result of checking the Firestore employee allowlist.
enum EmployeeCheckStatus {
  /// `employees/{uid}` exists and `active` is true.
  active,

  /// Signed in to Auth but no `employees/{uid}` document (should be rare after auto-pending).
  notOnAllowlist,

  /// Document exists but `active` is false — awaiting admin approval.
  inactive,

  /// Firestore read failed (rules, App Check, network, etc.).
  verificationFailed,
}

/// Reads and manages the `employees/{uid}` allowlist in Firestore.
class EmployeeService {
  EmployeeService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  static const String collectionPath = 'employees';

  /// Creates a pending employee record on first sign-in if missing.
  Future<void> ensurePendingRecord(User user) async {
    final ref = _firestore.collection(collectionPath).doc(user.uid);
    final existing = await ref.get();
    if (existing.exists) {
      return;
    }

    final email = user.email?.trim();
    if (email == null || email.isEmpty) {
      if (kDebugMode) {
        debugPrint(
          'ensurePendingRecord: skipped for ${user.uid} — no email on account',
        );
      }
      return;
    }

    await ref.set({
      'email': email,
      if (user.displayName != null && user.displayName!.trim().isNotEmpty)
        'displayName': user.displayName!.trim(),
      'active': false,
      'addedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<EmployeeRecord>> watchAllEmployees() {
    return _firestore
        .collection(collectionPath)
        .orderBy('email')
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => EmployeeRecord.fromFirestore(d)).toList());
  }

  Future<void> setEmployeeActive(String uid, bool active) async {
    await _firestore.collection(collectionPath).doc(uid).update({
      'active': active,
    });
  }

  Future<EmployeeCheckStatus> checkStatus(User user) async {
    try {
      final doc =
          await _firestore.collection(collectionPath).doc(user.uid).get();

      if (!doc.exists) {
        if (kDebugMode) {
          debugPrint(
            'Employee check: no document at employees/${user.uid}',
          );
        }
        return EmployeeCheckStatus.notOnAllowlist;
      }

      final data = doc.data();
      if (data == null) {
        return EmployeeCheckStatus.notOnAllowlist;
      }

      final active = data['active'];
      if (active == true || active == 'true') {
        return EmployeeCheckStatus.active;
      }

      if (kDebugMode) {
        debugPrint('Employee check: employees/${user.uid} has active=$active');
      }
      return EmployeeCheckStatus.inactive;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Employee check failed for ${user.uid}: $e\n$st');
      }
      return EmployeeCheckStatus.verificationFailed;
    }
  }

  /// Returns true only if `employees/{uid}` exists and `active == true`.
  Future<bool> isActiveEmployee(User user) async {
    final status = await checkStatus(user);
    return status == EmployeeCheckStatus.active;
  }
}
