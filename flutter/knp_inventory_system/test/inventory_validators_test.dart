import 'package:flutter_test/flutter_test.dart';
import 'package:knp_inventory_system/utils/inventory_validators.dart';

void main() {
  group('InventoryValidators', () {
    test('rejects empty ingredient name', () {
      expect(InventoryValidators.validateIngredientName(''), isNotNull);
      expect(InventoryValidators.validateIngredientName('  '), isNotNull);
    });

    test('accepts valid ingredient name', () {
      expect(InventoryValidators.validateIngredientName('Milk'), isNull);
    });

    test('rejects negative and oversized quantity', () {
      expect(InventoryValidators.validateQuantity(-1), isNotNull);
      expect(InventoryValidators.validateQuantity(1000001), isNotNull);
      expect(InventoryValidators.validateQuantity(10), isNull);
    });

    test('parseQuantity rejects invalid strings', () {
      expect(InventoryValidators.parseQuantity('abc'), isNull);
      expect(InventoryValidators.parseQuantity('-5'), isNull);
      expect(InventoryValidators.parseQuantity('12.5'), 12.5);
    });

    test('validates quantity units', () {
      expect(InventoryValidators.validateQuantityUnit('kg'), isNull);
      expect(InventoryValidators.validateQuantityUnit('invalid'), isNotNull);
    });
  });
}
