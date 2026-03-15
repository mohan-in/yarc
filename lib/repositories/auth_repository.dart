import 'package:yarc/services/auth_service.dart';

/// Repository for authentication operations.
class AuthRepository {
  AuthRepository(this._service);

  final AuthService _service;

  /// Whether the user is currently logged in.
  bool get isLoggedIn => _service.isLoggedIn;

  /// Stream to listen to auth state changes.
  Stream<AuthState> get authStateStream => _service.authStateStream;

  /// Initializes the auth system and restores session if available.
  Future<void> init() async {
    await _service.init();
  }

  /// Initiates the login flow.
  /// Returns null on success, or an error message on failure.
  Future<String?> login() async {
    return _service.authenticate();
  }

  /// Logs out the user.
  Future<void> logout() async {
    await _service.logout();
  }

  /// Attempts to restore the session using stored credentials.
  /// Returns true on success.
  Future<bool> tryRestoreSession() async {
    return _service.tryRestoreSession();
  }
}
