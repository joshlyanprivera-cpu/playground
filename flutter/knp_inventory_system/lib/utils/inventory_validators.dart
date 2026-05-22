/// Shared validation aligned with [firestore.rules].
class InventoryValidators {
  InventoryValidators._();

  static const int maxIngredientNameLength = 200;
  static const int maxCategoryNameLength = 100;
  static const int maxClassificationLength = 100;
  static const double maxQuantity = 1000000;
  static const double minQuantity = 0;

  static const List<String> quantityUnits = [
    'number',
    'mg',
    'kg',
    'liters',
    'milliliters',
  ];

  static String? validateIngredientName(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Required';
    }
    if (trimmed.length > maxIngredientNameLength) {
      return 'Name must be $maxIngredientNameLength characters or less';
    }
    return null;
  }

  static String? validateCategoryName(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Required';
    }
    if (trimmed.length > maxCategoryNameLength) {
      return 'Name must be $maxCategoryNameLength characters or less';
    }
    return null;
  }

  static String? validateClassification(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Select a category';
    }
    if (trimmed.length > maxClassificationLength) {
      return 'Category name too long';
    }
    return null;
  }

  static String? validateQuantityString(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }
    final parsed = double.tryParse(value.trim());
    if (parsed == null) {
      return 'Enter a valid number';
    }
    return validateQuantity(parsed);
  }

  static String? validateQuantity(double? value) {
    if (value == null) {
      return 'Enter a valid number';
    }
    if (value.isNaN || value.isInfinite) {
      return 'Enter a valid number';
    }
    if (value < minQuantity) {
      return 'Quantity cannot be negative';
    }
    if (value > maxQuantity) {
      return 'Quantity is too large';
    }
    return null;
  }

  static String? validateQuantityUnit(String? value) {
    if (value == null || value.isEmpty) {
      return 'Select a unit';
    }
    if (!quantityUnits.contains(value)) {
      return 'Invalid unit';
    }
    return null;
  }

  /// Parses quantity text; returns null if invalid (caller shows error).
  static double? parseQuantity(String text) {
    final parsed = double.tryParse(text.trim());
    if (parsed == null || parsed.isNaN || parsed.isInfinite) {
      return null;
    }
    if (validateQuantity(parsed) != null) {
      return null;
    }
    return parsed;
  }

  static String userSafeErrorMessage(Object error) {
    return 'Something went wrong. Please try again.';
  }
}
