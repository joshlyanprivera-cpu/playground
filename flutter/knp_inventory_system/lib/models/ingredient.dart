import 'package:cloud_firestore/cloud_firestore.dart';

class Ingredient {
  final String id;
  final String name;
  final String classification;
  final String quantityClassification;
  final double quantity;
  final DateTime? lastUpdated;

  Ingredient({
    required this.id,
    required this.name,
    required this.classification,
    required this.quantityClassification,
    required this.quantity,
    this.lastUpdated,
  });

  factory Ingredient.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Ingredient(
      id: doc.id,
      name: data['name'] ?? '',
      classification: data['classification'] ?? '',
      quantityClassification: data['quantityClassification'] ?? '',
      quantity: (data['quantity'] ?? 0).toDouble(),
      lastUpdated: data['lastUpdated'] != null
          ? (data['lastUpdated'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore({String? updatedByUid}) {
    final data = <String, dynamic>{
      'name': name.trim(),
      'classification': classification.trim(),
      'quantityClassification': quantityClassification,
      'quantity': quantity,
      'lastUpdated': FieldValue.serverTimestamp(),
    };
    if (updatedByUid != null) {
      data['lastUpdatedBy'] = updatedByUid;
    }
    return data;
  }

  bool get isLowStock {
    switch (quantityClassification) {
      case 'number':
        return quantity <= 4;
      case 'mg':
        return quantity <= 1000;
      case 'kg':
        return quantity <= 1;
      case 'liters':
        return quantity <= 1;
      case 'milliliters':
        return quantity <= 1000;
      default:
        return quantity <= 5;
    }
  }
}
