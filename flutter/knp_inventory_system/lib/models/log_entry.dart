import 'package:cloud_firestore/cloud_firestore.dart';

class LogEntry {
  final String id;
  final String action; // 'add', 'update', 'delete'
  final String targetType; // 'ingredient', 'category'
  final String itemName;
  final String? categoryName;
  final String? quantityUnit;
  final double? quantityChange;
  final String? previousCategory;
  final String? newCategory;
  final String? previousQuantityUnit;
  final String? newQuantityUnit;
  final String userIdentifier; // User email
  final DateTime timestamp;
  final List<Map<String, dynamic>>? bulkDeletions;
  final List<Map<String, dynamic>>? bulkUpdates;

  LogEntry({
    required this.id,
    required this.action,
    required this.targetType,
    required this.itemName,
    this.categoryName,
    this.quantityUnit,
    this.quantityChange,
    this.previousCategory,
    this.newCategory,
    this.previousQuantityUnit,
    this.newQuantityUnit,
    required this.userIdentifier,
    required this.timestamp,
    this.bulkDeletions,
    this.bulkUpdates,
  });

  factory LogEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LogEntry(
      id: doc.id,
      action: data['action'] ?? '',
      targetType: data['targetType'] ?? '',
      itemName: data['itemName'] ?? '',
      categoryName: data['categoryName'],
      quantityUnit: data['quantityUnit'],
      quantityChange: data['quantityChange'] != null
          ? (data['quantityChange'] as num).toDouble()
          : null,
      previousCategory: data['previousCategory'],
      newCategory: data['newCategory'],
      previousQuantityUnit: data['previousQuantityUnit'],
      newQuantityUnit: data['newQuantityUnit'],
      userIdentifier: data['userIdentifier'] ?? '',
      timestamp: data['timestamp'] != null
          ? (data['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      bulkDeletions: data['bulkDeletions'] != null
          ? (data['bulkDeletions'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList()
          : null,
      bulkUpdates: data['bulkUpdates'] != null
          ? (data['bulkUpdates'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    final data = <String, dynamic>{
      'action': action,
      'targetType': targetType,
      'itemName': itemName,
      'userIdentifier': userIdentifier,
      'timestamp': FieldValue.serverTimestamp(),
    };
    if (categoryName != null) data['categoryName'] = categoryName;
    if (quantityUnit != null) data['quantityUnit'] = quantityUnit;
    if (quantityChange != null) data['quantityChange'] = quantityChange;
    if (previousCategory != null) data['previousCategory'] = previousCategory;
    if (newCategory != null) data['newCategory'] = newCategory;
    if (previousQuantityUnit != null) data['previousQuantityUnit'] = previousQuantityUnit;
    if (newQuantityUnit != null) data['newQuantityUnit'] = newQuantityUnit;
    if (bulkDeletions != null) data['bulkDeletions'] = bulkDeletions;
    if (bulkUpdates != null) data['bulkUpdates'] = bulkUpdates;
    return data;
  }
}
