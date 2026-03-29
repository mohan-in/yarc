import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:yarc/repositories/auth_repository.dart';
import 'package:yarc/services/auth_service.dart';

/// Notifier for managing authentication state.
///
/// Distinguishes between three states:
/// - **loggedIn**: User has valid credentials.
/// - **loggedOut**: No credentials stored (initial state or explicit logout).
/// - **unauthenticated**: Had credentials but the refresh token was
///   revoked/invalid. Shows a "session expired" UI with retry option.
class AuthNotifier extends ChangeNotifier {
  AuthRepository? _repository;
  StreamSubscription<AuthState>? _authSubscription;

  bool _isLoggedIn = false;
  bool _isInitialized = false;
  bool _isUnauthenticated = false;
  String? _currentUsername;

  bool get isLoggedIn => _isLoggedIn;
  bool get isInitialized => _isInitialized;
  String? get currentUsername => _currentUsername;

  /// True when the session has expired or the token was revoked.
  /// The user should see a "session expired" screen with Retry/Re-login.
  bool get isUnauthenticated => _isUnauthenticated;

  void setRepository(AuthRepository repository) {
    // Cancel any existing subscription before creating a new one.
    // ChangeNotifierProxyProvider calls this method every time the upstream
    // AuthRepository is recreated, so without this guard we accumulate
    // duplicate listeners on the same stream.
    unawaited(_authSubscription?.cancel());
    _repository = repository;
    _authSubscription = _repository!.authStateStream.listen(_onAuthState);
  }

  void _onAuthState(AuthState state) {
    switch (state) {
      case AuthState.loggedIn:
        _isLoggedIn = true;
        _isUnauthenticated = false;
        _currentUsername = _repository?.currentUsername;
      case AuthState.loggedOut:
        _isLoggedIn = false;
        _isUnauthenticated = false;
        _currentUsername = null;
      case AuthState.unauthenticated:
        _isLoggedIn = false;
        _isUnauthenticated = true;
        _currentUsername = null;
    }
    notifyListeners();
  }

  /// Initializes auth and restores session if available.
  Future<void> init() async {
    if (_repository == null) {
      return;
    }
    await _repository!.init();
    _isLoggedIn = _repository!.isLoggedIn;
    _currentUsername = _repository!.currentUsername;
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
      _isUnauthenticated = false;
      _currentUsername = _repository?.currentUsername;
      notifyListeners();
    }
    return error;
  }

  /// Attempts to restore the session using stored credentials.
  /// Returns true on success.
  Future<bool> tryReauthenticate() async {
    if (_repository == null) {
      return false;
    }
    return _repository!.tryRestoreSession();
  }

  Future<void> logout() async {
    if (_repository == null) {
      return;
    }
    await _repository!.logout();
    _isLoggedIn = false;
    _isUnauthenticated = false;
    _currentUsername = null;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_authSubscription?.cancel());
    super.dispose();
  }
}
