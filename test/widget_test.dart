import 'package:flutter_test/flutter_test.dart';
import 'package:billing_app/features/erp/domain/auth_service.dart';
import 'package:billing_app/features/erp/domain/erp_models.dart';

void main() {
  test('ADMIN can access accountant capabilities', () {
    final auth = AuthService();
    auth.signIn(const UserRecord(
      id: 'admin',
      name: 'Admin',
      email: 'admin@example.com',
      role: UserRole.admin,
    ));
    expect(auth.isAuthenticated, isTrue);
    expect(auth.can(UserRole.accountant), isTrue);
  });
}
