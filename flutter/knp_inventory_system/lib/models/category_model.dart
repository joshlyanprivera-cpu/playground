import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CategoryModel {
  final String id;
  final String name;
  final String iconString;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.iconString,
  });

  factory CategoryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CategoryModel(
      id: doc.id,
      name: data['name'] ?? '',
      iconString: data['iconString'] ?? 'inventory_2',
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'iconString': iconString,
  };

  IconData get icon => CategoryModel.iconFromString(iconString);

  static IconData iconFromString(String key) {
    return _iconMap[key] ?? Icons.inventory_2_outlined;
  }

  /// Curated set of professional Material icons for categories.
  static const Map<String, IconData> iconMap = _iconMap;

  /// Icon keys allowed by [firestore.rules].
  static Set<String> get allowedIconKeys => _iconMap.keys.toSet();
}

const Map<String, IconData> _iconMap = {
  'inventory_2':      Icons.inventory_2_outlined,
  'coffee':           Icons.coffee_outlined,
  'fastfood':         Icons.fastfood_outlined,
  'local_cafe':       Icons.local_cafe_outlined,
  'lunch_dining':     Icons.lunch_dining_outlined,
  'set_meal':         Icons.set_meal_outlined,
  'cake':             Icons.cake_outlined,
  'icecream':         Icons.icecream_outlined,
  'local_bar':        Icons.local_bar_outlined,
  'liquor':           Icons.liquor_outlined,
  'water_drop':       Icons.water_drop_outlined,
  'blender':          Icons.blender_outlined,
  'kitchen':          Icons.kitchen_outlined,
  'microwave':        Icons.microwave_outlined,
  'grain':            Icons.grain_outlined,
  'spa':              Icons.spa_outlined,
  'eco':              Icons.eco_outlined,
  'grass':            Icons.grass_outlined,
  'local_florist':    Icons.local_florist_outlined,
  'bakery_dining':    Icons.bakery_dining_outlined,
  'breakfast_dining': Icons.breakfast_dining_outlined,
  'bubble_chart':     Icons.bubble_chart_outlined,
  'category':         Icons.category_outlined,
  'star':             Icons.star_outline,
  'bookmark':         Icons.bookmark_outline,
  'label':            Icons.label_outline,
  'widgets':          Icons.widgets_outlined,
  'storage':          Icons.storage_outlined,
  'science':          Icons.science_outlined,
  'local_grocery_store': Icons.local_grocery_store_outlined,
};
