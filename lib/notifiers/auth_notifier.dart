import 'package:flutter/foundation.dart';
import '../repositories/auth_repository.dart';

/// Notifier for managing authentication state.
class AuthNotifier extends ChangeNotifier {
  AuthRepository? _repository;

  bool _isLoggedIn = false;
  bool _isInitialized = false;

  bool get isLoggedIn => _isLoggedIn;
  bool get isInitialized => _isInitialized;

  void setRepository(AuthRepository repository) {
    _repository = repository;
  }

  /// Initializes auth and restores session if available.
  Future<void> init() async {
    if (_repository == null) return;
    await _repository!.init();
    _isLoggedIn = _repository!.isLoggedIn;
    _isInitialized = true;
    notifyListeners();
  }

  /// Initiates the login flow.
  /// Returns null on success, or an error message on failure.
  Future<String?> login() async {
    if (_repository == null) return 'Auth repository not initialized';
    final error = await _repository!.login();
    if (error == null) {
      _isLoggedIn = true;
      notifyListeners();
    }
    return error;
  }

  /// Logs out the user.
  Future<void> logout() async {
    if (_repository == null) return;
    await _repository!.logout();
    _isLoggedIn = false;
    notifyListeners();
  }
}
