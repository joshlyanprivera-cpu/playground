import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/ingredient.dart';
import '../models/category_model.dart';

class InventoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String collectionPath = 'inventory';
  final String categoriesPath = 'categories';

  // ── Inventory ──────────────────────────────────────────────────────────────

  Stream<List<Ingredient>> getInventoryStream() {
    return _firestore.collection(collectionPath).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Ingredient.fromFirestore(doc)).toList();
    });
  }

  Future<void> addIngredient(Ingredient ingredient) async {
    await _firestore.collection(collectionPath).add(ingredient.toFirestore());
  }

  Future<void> updateIngredient(Ingredient ingredient) async {
    await _firestore
        .collection(collectionPath)
        .doc(ingredient.id)
        .update(ingredient.toFirestore());
  }

  Future<void> deleteIngredient(String id) async {
    await _firestore.collection(collectionPath).doc(id).delete();
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
    await _firestore.collection(categoriesPath).add(category.toFirestore());
  }

  Future<void> updateCategory(CategoryModel category) async {
    await _firestore
        .collection(categoriesPath)
        .doc(category.id)
        .update(category.toFirestore());
  }

  /// Deletes a category and moves all ingredients that belonged to it
  /// to the "Uncategorized" bucket.
  Future<void> deleteCategory(String categoryId, String categoryName) async {
    await _firestore
        .collection(categoriesPath)
        .doc(categoryId)
        .delete();

    // Move orphaned ingredients to "Uncategorized"
    final affected = await _firestore
        .collection(collectionPath)
        .where('classification', isEqualTo: categoryName)
        .get();

    final batch = _firestore.batch();
    for (final doc in affected.docs) {
      batch.update(doc.reference, {'classification': 'Uncategorized'});
    }
    await batch.commit();
  }

  /// Renames a category and batch-updates all ingredients using the old name.
  Future<void> renameCategory(
      String categoryId, String oldName, String newName, String iconString) async {
    await _firestore
        .collection(categoriesPath)
        .doc(categoryId)
        .update({'name': newName, 'iconString': iconString});

    final affected = await _firestore
        .collection(collectionPath)
        .where('classification', isEqualTo: oldName)
        .get();

    final batch = _firestore.batch();
    for (final doc in affected.docs) {
      batch.update(doc.reference, {'classification': newName});
    }
    await batch.commit();
  }
}
