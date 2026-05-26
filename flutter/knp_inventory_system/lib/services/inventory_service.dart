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
    await _firestore
        .collection(collectionPath)
        .add(ingredient.toFirestore(updatedByUid: _updatedByUid));
  }

  Future<void> updateIngredient(Ingredient ingredient) async {
    _validateIngredient(ingredient);
    await _firestore.collection(collectionPath).doc(ingredient.id).update(
          ingredient.toFirestore(updatedByUid: _updatedByUid),
        );
  }

  Future<void> deleteIngredient(String id) async {
    await _firestore.collection(collectionPath).doc(id).delete();
  }

  /// Batch updates and deletes ingredients in a single transaction/batch commit.
  Future<void> batchSaveIngredients({
    required List<Ingredient> toUpdate,
    required Set<String> toDelete,
  }) async {
    final batch = _firestore.batch();
    final uid = _updatedByUid;

    for (final id in toDelete) {
      batch.delete(_firestore.collection(collectionPath).doc(id));
    }

    for (final ingredient in toUpdate) {
      _validateIngredient(ingredient);
      batch.update(
        _firestore.collection(collectionPath).doc(ingredient.id),
        ingredient.toFirestore(updatedByUid: uid),
      );
    }

    await batch.commit();
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
    await _firestore.collection(categoriesPath).add(category.toFirestore());
  }

  Future<void> updateCategory(CategoryModel category) async {
    _validateCategory(category);
    await _firestore
        .collection(categoriesPath)
        .doc(category.id)
        .update(category.toFirestore());
  }

  /// Deletes a category and moves all ingredients that belonged to it
  /// to the "Uncategorized" bucket.
  Future<void> deleteCategory(String categoryId, String categoryName) async {
    await _firestore.collection(categoriesPath).doc(categoryId).delete();

    final affected = await _firestore
        .collection(collectionPath)
        .where('classification', isEqualTo: categoryName)
        .get();

    final batch = _firestore.batch();
    final uid = _updatedByUid;
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

    await _firestore.collection(categoriesPath).doc(categoryId).update({
      'name': trimmedName,
      'iconString': iconString,
    });

    final affected = await _firestore
        .collection(collectionPath)
        .where('classification', isEqualTo: oldName)
        .get();

    final batch = _firestore.batch();
    final uid = _updatedByUid;
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
