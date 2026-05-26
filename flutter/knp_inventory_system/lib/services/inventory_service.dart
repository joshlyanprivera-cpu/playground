import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/ingredient.dart';
import '../models/category_model.dart';
import '../utils/inventory_validators.dart';

class InventoryValidationException implements Exception {
  InventoryValidationException(this.message);
  final String message;
  @override
  String toString() => message;
}

class InventoryService {
  InventoryService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final String collectionPath = 'inventory';
  final String categoriesPath = 'categories';

  String? get _updatedByUid => _auth.currentUser?.uid;
  String? get _updatedByEmail => _auth.currentUser?.email;

  void _validateIngredient(Ingredient ingredient) {
    if (InventoryValidators.validateIngredientName(ingredient.name) != null) {
      throw InventoryValidationException('Invalid ingredient name.');
    }
    if (InventoryValidators.validateClassification(ingredient.classification) !=
        null) {
      throw InventoryValidationException('Invalid category.');
    }
    if (InventoryValidators.validateQuantityUnit(
            ingredient.quantityClassification) !=
        null) {
      throw InventoryValidationException('Invalid quantity unit.');
    }
    if (InventoryValidators.validateQuantity(ingredient.quantity) != null) {
      throw InventoryValidationException('Invalid quantity.');
    }
  }

  void _validateCategory(CategoryModel category) {
    if (InventoryValidators.validateCategoryName(category.name) != null) {
      throw InventoryValidationException('Invalid category name.');
    }
    if (!CategoryModel.allowedIconKeys.contains(category.iconString)) {
      throw InventoryValidationException('Invalid category icon.');
    }
  }

  // ── Inventory ──────────────────────────────────────────────────────────────

  Stream<List<Ingredient>> getInventoryStream() {
    return _firestore.collection(collectionPath).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Ingredient.fromFirestore(doc)).toList();
    });
  }

  Future<void> addIngredient(Ingredient ingredient) async {
    _validateIngredient(ingredient);
    final batch = _firestore.batch();
    
    final docRef = _firestore.collection(collectionPath).doc();
    batch.set(docRef, ingredient.toFirestore(updatedByUid: _updatedByUid));
    
    final logRef = _firestore.collection('logs').doc();
    batch.set(logRef, {
      'action': 'add',
      'targetType': 'ingredient',
      'itemName': ingredient.name,
      'categoryName': ingredient.classification,
      'quantityUnit': ingredient.quantityClassification,
      'quantityChange': ingredient.quantity,
      'userIdentifier': _updatedByEmail ?? 'unknown',
      'timestamp': FieldValue.serverTimestamp(),
    });
    
    await batch.commit();
  }

  Future<void> updateIngredient(Ingredient ingredient) async {
    _validateIngredient(ingredient);
    
    final doc = await _firestore.collection(collectionPath).doc(ingredient.id).get();
    if (!doc.exists) {
      await _firestore.collection(collectionPath).doc(ingredient.id).update(
            ingredient.toFirestore(updatedByUid: _updatedByUid),
          );
      return;
    }
    
    final oldIngredient = Ingredient.fromFirestore(doc);
    final batch = _firestore.batch();
    batch.update(
      _firestore.collection(collectionPath).doc(ingredient.id),
      ingredient.toFirestore(updatedByUid: _updatedByUid),
    );
    
    final logData = _buildIngredientUpdateLog(oldIngredient, ingredient);
    if (logData != null) {
      final logRef = _firestore.collection('logs').doc();
      batch.set(logRef, logData);
    }
    await batch.commit();
  }

  Future<void> deleteIngredient(String id) async {
    final doc = await _firestore.collection(collectionPath).doc(id).get();
    if (!doc.exists) return;
    final ingredient = Ingredient.fromFirestore(doc);
    
    final batch = _firestore.batch();
    batch.delete(_firestore.collection(collectionPath).doc(id));
    
    final logRef = _firestore.collection('logs').doc();
    batch.set(logRef, {
      'action': 'delete',
      'targetType': 'ingredient',
      'itemName': ingredient.name,
      'categoryName': ingredient.classification,
      'quantityUnit': ingredient.quantityClassification,
      'userIdentifier': _updatedByEmail ?? 'unknown',
      'timestamp': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  /// Batch updates and deletes ingredients in a single transaction/batch commit.
  Future<void> batchSaveIngredients({
    required List<Ingredient> toUpdate,
    required List<Ingredient> toDelete,
  }) async {
    final batch = _firestore.batch();
    final uid = _updatedByUid;
    final userEmail = _updatedByEmail ?? 'unknown';

    final List<Map<String, dynamic>> deletedLogs = [];
    for (final ingredient in toDelete) {
      batch.delete(_firestore.collection(collectionPath).doc(ingredient.id));
      deletedLogs.add({
        'itemName': ingredient.name,
        'categoryName': ingredient.classification,
        'quantityUnit': ingredient.quantityClassification,
      });
    }

    final List<Map<String, dynamic>> updatedLogs = [];
    Map<String, dynamic>? singleUpdateLogData;

    for (final ingredient in toUpdate) {
      _validateIngredient(ingredient);
      
      final doc = await _firestore.collection(collectionPath).doc(ingredient.id).get();
      
      batch.update(
        _firestore.collection(collectionPath).doc(ingredient.id),
        ingredient.toFirestore(updatedByUid: uid),
      );

      if (doc.exists) {
        final oldIngredient = Ingredient.fromFirestore(doc);
        final logData = _buildIngredientUpdateLog(oldIngredient, ingredient);
        if (logData != null) {
          singleUpdateLogData = logData;
          final Map<String, dynamic> updateItem = {
            'itemName': logData['itemName'],
            'categoryName': logData['categoryName'],
          };
          if (logData.containsKey('quantityChange')) updateItem['quantityChange'] = logData['quantityChange'];
          if (logData.containsKey('quantityUnit')) updateItem['quantityUnit'] = logData['quantityUnit'];
          if (logData.containsKey('previousCategory')) updateItem['previousCategory'] = logData['previousCategory'];
          if (logData.containsKey('newCategory')) updateItem['newCategory'] = logData['newCategory'];
          if (logData.containsKey('previousQuantityUnit')) updateItem['previousQuantityUnit'] = logData['previousQuantityUnit'];
          if (logData.containsKey('newQuantityUnit')) updateItem['newQuantityUnit'] = logData['newQuantityUnit'];
          updatedLogs.add(updateItem);
        }
      }
    }

    final int totalChanges = deletedLogs.length + updatedLogs.length;

    if (totalChanges == 1) {
      final logRef = _firestore.collection('logs').doc();
      if (deletedLogs.length == 1) {
        final delItem = deletedLogs.first;
        batch.set(logRef, {
          'action': 'delete',
          'targetType': 'ingredient',
          'itemName': delItem['itemName'],
          'categoryName': delItem['categoryName'],
          'quantityUnit': delItem['quantityUnit'],
          'userIdentifier': userEmail,
          'timestamp': FieldValue.serverTimestamp(),
        });
      } else if (updatedLogs.length == 1 && singleUpdateLogData != null) {
        batch.set(logRef, singleUpdateLogData);
      }
    } else if (totalChanges > 1) {
      final logRef = _firestore.collection('logs').doc();
      final batchLogData = <String, dynamic>{
        'action': 'batch',
        'targetType': 'ingredient',
        'itemName': 'batch',
        'userIdentifier': userEmail,
        'timestamp': FieldValue.serverTimestamp(),
      };
      if (deletedLogs.isNotEmpty) {
        batchLogData['bulkDeletions'] = deletedLogs;
      }
      if (updatedLogs.isNotEmpty) {
        batchLogData['bulkUpdates'] = updatedLogs;
      }
      batch.set(logRef, batchLogData);
    }

    await batch.commit();
  }

  Map<String, dynamic>? _buildIngredientUpdateLog(Ingredient oldItem, Ingredient newItem) {
    final userEmail = _updatedByEmail ?? 'unknown';
    
    final bool qtyChanged = oldItem.quantity != newItem.quantity;
    final bool catChanged = oldItem.classification != newItem.classification;
    final bool unitChanged = oldItem.quantityClassification != newItem.quantityClassification;
    
    if (!qtyChanged && !catChanged && !unitChanged) {
      return null;
    }
    
    final logData = <String, dynamic>{
      'action': 'update',
      'targetType': 'ingredient',
      'itemName': newItem.name,
      'userIdentifier': userEmail,
      'timestamp': FieldValue.serverTimestamp(),
    };
    
    if (qtyChanged) {
      logData['quantityChange'] = newItem.quantity - oldItem.quantity;
      logData['quantityUnit'] = newItem.quantityClassification;
    }
    if (catChanged) {
      logData['previousCategory'] = oldItem.classification;
      logData['newCategory'] = newItem.classification;
    }
    if (unitChanged) {
      logData['previousQuantityUnit'] = oldItem.quantityClassification;
      logData['newQuantityUnit'] = newItem.quantityClassification;
    }
    
    logData['categoryName'] = newItem.classification;
    
    return logData;
  }

  // ── Categories ─────────────────────────────────────────────────────────────

  Stream<List<CategoryModel>> getCategoriesStream() {
    return _firestore
        .collection(categoriesPath)
        .orderBy('name')
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => CategoryModel.fromFirestore(d)).toList());
  }

  Future<void> addCategory(CategoryModel category) async {
    _validateCategory(category);
    final batch = _firestore.batch();
    
    final docRef = _firestore.collection(categoriesPath).doc();
    batch.set(docRef, category.toFirestore());
    
    final logRef = _firestore.collection('logs').doc();
    batch.set(logRef, {
      'action': 'add',
      'targetType': 'category',
      'itemName': category.name,
      'userIdentifier': _updatedByEmail ?? 'unknown',
      'timestamp': FieldValue.serverTimestamp(),
    });
    
    await batch.commit();
  }

  Future<void> updateCategory(CategoryModel category) async {
    _validateCategory(category);
    
    final doc = await _firestore.collection(categoriesPath).doc(category.id).get();
    if (!doc.exists) {
      await _firestore
          .collection(categoriesPath)
          .doc(category.id)
          .update(category.toFirestore());
      return;
    }
    
    final oldCategory = CategoryModel.fromFirestore(doc);
    final batch = _firestore.batch();
    batch.update(
      _firestore.collection(categoriesPath).doc(category.id),
      category.toFirestore(),
    );
    
    final logRef = _firestore.collection('logs').doc();
    batch.set(logRef, {
      'action': 'update',
      'targetType': 'category',
      'itemName': category.name,
      'previousCategory': oldCategory.name,
      'newCategory': category.name,
      'userIdentifier': _updatedByEmail ?? 'unknown',
      'timestamp': FieldValue.serverTimestamp(),
    });
    
    await batch.commit();
  }

  /// Deletes a category and moves all ingredients that belonged to it
  /// to the "Uncategorized" bucket.
  Future<void> deleteCategory(String categoryId, String categoryName) async {
    final batch = _firestore.batch();
    final uid = _updatedByUid;
    final userEmail = _updatedByEmail ?? 'unknown';

    batch.delete(_firestore.collection(categoriesPath).doc(categoryId));

    final logRef = _firestore.collection('logs').doc();
    batch.set(logRef, {
      'action': 'delete',
      'targetType': 'category',
      'itemName': categoryName,
      'userIdentifier': userEmail,
      'timestamp': FieldValue.serverTimestamp(),
    });

    final affected = await _firestore
        .collection(collectionPath)
        .where('classification', isEqualTo: categoryName)
        .get();

    for (final doc in affected.docs) {
      final data = Map<String, dynamic>.from(doc.data());
      data['classification'] = 'Uncategorized';
      data['lastUpdated'] = FieldValue.serverTimestamp();
      if (uid != null) {
        data['lastUpdatedBy'] = uid;
      }
      batch.update(doc.reference, data);
    }
    await batch.commit();
  }

  /// Renames a category and batch-updates all ingredients using the old name.
  Future<void> renameCategory(
    String categoryId,
    String oldName,
    String newName,
    String iconString,
  ) async {
    final trimmedName = newName.trim();
    if (InventoryValidators.validateCategoryName(trimmedName) != null) {
      throw InventoryValidationException('Invalid category name.');
    }
    if (!CategoryModel.allowedIconKeys.contains(iconString)) {
      throw InventoryValidationException('Invalid category icon.');
    }

    final batch = _firestore.batch();
    final uid = _updatedByUid;
    final userEmail = _updatedByEmail ?? 'unknown';

    batch.update(_firestore.collection(categoriesPath).doc(categoryId), {
      'name': trimmedName,
      'iconString': iconString,
    });

    final logRef = _firestore.collection('logs').doc();
    batch.set(logRef, {
      'action': 'update',
      'targetType': 'category',
      'itemName': trimmedName,
      'previousCategory': oldName,
      'newCategory': trimmedName,
      'userIdentifier': userEmail,
      'timestamp': FieldValue.serverTimestamp(),
    });

    final affected = await _firestore
        .collection(collectionPath)
        .where('classification', isEqualTo: oldName)
        .get();

    for (final doc in affected.docs) {
      final data = Map<String, dynamic>.from(doc.data());
      data['classification'] = trimmedName;
      data['lastUpdated'] = FieldValue.serverTimestamp();
      if (uid != null) {
        data['lastUpdatedBy'] = uid;
      }
      batch.update(doc.reference, data);
    }
    await batch.commit();
  }
}
