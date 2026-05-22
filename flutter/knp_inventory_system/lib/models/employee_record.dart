import 'package:cloud_firestore/cloud_firestore.dart';

class EmployeeRecord {
  const EmployeeRecord({
    required this.id,
    required this.email,
    this.displayName,
    required this.active,
    this.addedAt,
  });

  final String id;
  final String email;
  final String? displayName;
  final bool active;
  final DateTime? addedAt;

  bool get isPending => !active;

  String get displayLabel {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    return email;
  }

  factory EmployeeRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final active = data['active'];
    return EmployeeRecord(
      id: doc.id,
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String?,
      active: active == true || active == 'true',
      addedAt: data['addedAt'] is Timestamp
          ? (data['addedAt'] as Timestamp).toDate()
          : null,
    );
  }
}
