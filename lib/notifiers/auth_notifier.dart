import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:yarc/repositories/auth_repository.dart';
import 'package:yarc/services/auth_service.dart';

/// Notifier for managing authentication state.
class AuthNotifier extends ChangeNotifier {
  AuthRepository? _repository;
  StreamSubscription<AuthState>? _authSubscription;

  bool _isLoggedIn = false;
  bool _isInitialized = false;

  bool get isLoggedIn => _isLoggedIn;
  bool get isInitialized => _isInitialized;

  void setRepository(AuthRepository repository) {
    // Cancel any existing subscription before creating a new one.
    // ChangeNotifierProxyProvider calls this method every time the upstream
    // AuthRepository is recreated, so without this guard we accumulate
    // duplicate listeners on the same stream.
    _authSubscription?.cancel();
    _repository = repository;
    _authSubscription = _repository!.authStateStream.listen((state) {
      if (state == AuthState.loggedIn) {
        _isLoggedIn = true;
      } else {
        _isLoggedIn = false;
      }
      notifyListeners();
    });
  }

  /// Initializes auth and restores session if available.
  Future<void> init() async {
    if (_repository == null) {
      return;
    }
    await _repository!.init();
    _isLoggedIn = _repository!.isLoggedIn;
    _isInitialized = true;
    notifyListeners();
  }

  /// Initiates the login flow.
  /// Returns null on success, or an error message on failure.
  Future<String?> login() async {
    if (_repository == null) {
      return 'Auth repository not initialized';
    }
    final error = await _repository!.login();
    if (error == null) {
      _isLoggedIn = true;
      notifyListeners();
    }
    return error;
  }

  Future<void> logout() async {
    if (_repository == null) {
      return;
    }
    await _repository!.logout();
    _isLoggedIn = false;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_authSubscription?.cancel());
    super.dispose();
  }
}
