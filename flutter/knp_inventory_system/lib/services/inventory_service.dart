import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/ingredient.dart';

class InventoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String collectionPath = 'inventory';

  Stream<List<Ingredient>> getInventoryStream() {
    return _firestore.collection(collectionPath).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Ingredient.fromFirestore(doc)).toList();
    });
  }

  Future<void> addIngredient(Ingredient ingredient) async {
    await _firestore.collection(collectionPath).add(ingredient.toFirestore());
  }

  Future<void> updateIngredient(Ingredient ingredient) async {
    await _firestore.collection(collectionPath).doc(ingredient.id).update(ingredient.toFirestore());
  }

  Future<void> deleteIngredient(String id) async {
    await _firestore.collection(collectionPath).doc(id).delete();
  }
}
