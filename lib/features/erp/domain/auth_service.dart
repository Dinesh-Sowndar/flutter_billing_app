import 'erp_models.dart';

class AuthService {
  UserRecord? _session;

  UserRecord? get session => _session;

  void signIn(UserRecord user) {
    if (!user.active) {
      throw StateError('Inactive users cannot sign in');
    }
    _session = user;
  }

  void signOut() => _session = null;

  bool can(UserRole requiredRole) {
    final user = _session;
    return user != null &&
        (user.role == UserRole.admin || user.role == requiredRole);
  }

  bool get isAuthenticated => _session != null;
}
