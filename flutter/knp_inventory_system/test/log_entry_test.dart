import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knp_inventory_system/models/log_entry.dart';

// ignore: subtype_of_sealed_class
class _FakeDocumentSnapshot implements DocumentSnapshot {
  _FakeDocumentSnapshot(this._id, this._data);

  final String _id;
  final Map<String, dynamic> _data;

  @override
  String get id => _id;

  @override
  Object? data() => _data;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('LogEntry Tests', () {
    test('LogEntry.fromFirestore parses correct values', () {
      final now = DateTime.now();
      final fakeDoc = _FakeDocumentSnapshot('log_123', {
        'action': 'add',
        'targetType': 'ingredient',
        'itemName': 'Sugar',
        'categoryName': 'Baking',
        'quantityUnit': 'kg',
        'quantityChange': 5.0,
        'userIdentifier': 'test@knp.com',
        'timestamp': Timestamp.fromDate(now),
      });

      final entry = LogEntry.fromFirestore(fakeDoc);

      expect(entry.id, 'log_123');
      expect(entry.action, 'add');
      expect(entry.targetType, 'ingredient');
      expect(entry.itemName, 'Sugar');
      expect(entry.categoryName, 'Baking');
      expect(entry.quantityUnit, 'kg');
      expect(entry.quantityChange, 5.0);
      expect(entry.userIdentifier, 'test@knp.com');
      expect(entry.timestamp, now);
    });

    test('LogEntry.toFirestore serializes values correctly', () {
      final entry = LogEntry(
        id: '123',
        action: 'update',
        targetType: 'ingredient',
        itemName: 'Milk',
        categoryName: 'Dairy',
        quantityUnit: 'liters',
        quantityChange: -2.0,
        previousCategory: 'Liquid',
        newCategory: 'Dairy',
        userIdentifier: 'staff@knp.com',
        timestamp: DateTime.now(),
      );

      final map = entry.toFirestore();

      expect(map['action'], 'update');
      expect(map['targetType'], 'ingredient');
      expect(map['itemName'], 'Milk');
      expect(map['userIdentifier'], 'staff@knp.com');
      expect(map['categoryName'], 'Dairy');
      expect(map['quantityUnit'], 'liters');
      expect(map['quantityChange'], -2.0);
      expect(map['previousCategory'], 'Liquid');
      expect(map['newCategory'], 'Dairy');
      expect(map['timestamp'], isA<FieldValue>());
    });

    test('LogEntry.fromFirestore parses bulkDeletions and bulkUpdates', () {
      final now = DateTime.now();
      final fakeDoc = _FakeDocumentSnapshot('log_batch_123', {
        'action': 'batch',
        'targetType': 'ingredient',
        'itemName': 'batch',
        'userIdentifier': 'test@knp.com',
        'timestamp': Timestamp.fromDate(now),
        'bulkDeletions': [
          {
            'itemName': 'Sugar',
            'categoryName': 'Baking',
            'quantityUnit': 'kg',
          }
        ],
        'bulkUpdates': [
          {
            'itemName': 'Milk',
            'categoryName': 'Dairy',
            'quantityChange': -2.0,
            'quantityUnit': 'liters',
          }
        ],
      });

      final entry = LogEntry.fromFirestore(fakeDoc);

      expect(entry.id, 'log_batch_123');
      expect(entry.action, 'batch');
      expect(entry.targetType, 'ingredient');
      expect(entry.userIdentifier, 'test@knp.com');
      expect(entry.timestamp, now);
      expect(entry.bulkDeletions, isNotNull);
      expect(entry.bulkDeletions!.length, 1);
      expect(entry.bulkDeletions!.first['itemName'], 'Sugar');
      expect(entry.bulkUpdates, isNotNull);
      expect(entry.bulkUpdates!.length, 1);
      expect(entry.bulkUpdates!.first['itemName'], 'Milk');
      expect(entry.bulkUpdates!.first['quantityChange'], -2.0);
    });

    test('LogEntry.toFirestore serializes bulkDeletions and bulkUpdates', () {
      final entry = LogEntry(
        id: 'batch_123',
        action: 'batch',
        targetType: 'ingredient',
        itemName: 'batch',
        userIdentifier: 'staff@knp.com',
        timestamp: DateTime.now(),
        bulkDeletions: [
          {'itemName': 'Sugar'}
        ],
        bulkUpdates: [
          {'itemName': 'Milk', 'quantityChange': 1.0}
        ],
      );

      final map = entry.toFirestore();

      expect(map['action'], 'batch');
      expect(map['targetType'], 'ingredient');
      expect(map['itemName'], 'batch');
      expect(map['userIdentifier'], 'staff@knp.com');
      expect(map['bulkDeletions'], isNotNull);
      expect((map['bulkDeletions'] as List).length, 1);
      expect(map['bulkUpdates'], isNotNull);
      expect((map['bulkUpdates'] as List).length, 1);
    });
  });
}
