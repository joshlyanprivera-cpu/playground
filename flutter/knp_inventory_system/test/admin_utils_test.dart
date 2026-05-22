import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knp_inventory_system/utils/admin_utils.dart';

class _FakeUser implements User {
  _FakeUser(this._email);

  final String? _email;

  @override
  String? get email => _email;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('isAdmin matches admin@knp.com case-insensitively', () {
    expect(
      AdminUtils.isAdmin(_FakeUser('admin@knp.com')),
      isTrue,
    );
    expect(
      AdminUtils.isAdmin(_FakeUser('Admin@KNP.com')),
      isTrue,
    );
    expect(
      AdminUtils.isAdmin(_FakeUser('staff@knp.com')),
      isFalse,
    );
    expect(AdminUtils.isAdmin(null), isFalse);
  });
}
