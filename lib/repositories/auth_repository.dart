import '../services/auth_service.dart';

/// Repository for authentication operations.
class AuthRepository {
  final AuthService _service;

  AuthRepository(this._service);

  /// Whether the user is currently logged in.
  bool get isLoggedIn => _service.isLoggedIn;

  /// Initializes the auth system and restores session if available.
  Future<void> init() async {
    await _service.init();
  }

  /// Initiates the login flow.
  /// Returns null on success, or an error message on failure.
  Future<String?> login() async {
    return await _service.authenticate();
  }

  /// Logs out the user.
  Future<void> logout() async {
    await _service.logout();
  }
}
