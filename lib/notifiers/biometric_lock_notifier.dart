import 'package:flutter/foundation.dart';
import 'package:yarc/services/biometric_service.dart';

/// Tracks whether the app is currently showing the biometric lock screen.
///
/// A lock is requested via [requestLock]. Calling [authenticate] invokes the
/// device biometric prompt and clears the lock on success.
class BiometricLockNotifier extends ChangeNotifier {
  BiometricService? _service;

  bool _isLocked = false;
  bool _isAuthenticating = false;
  String? _errorMessage;

  bool get isLocked => _isLocked;
  bool get isAuthenticating => _isAuthenticating;
  String? get errorMessage => _errorMessage;

  /// Called whenever [BiometricService] is (re-)created by the DI layer.
  ///
  /// Also resets any in-progress authentication state so a stale prompt
  /// from the previous service instance does not linger.
  void setService(BiometricService service) {
    _service = service;
    _isAuthenticating = false;
  }

  /// Locks the app. Has no effect if already locked.
  void requestLock() {
    if (_isLocked) return;
    _isLocked = true;
    _errorMessage = null;
    notifyListeners();
  }

  /// Clears the lock without authentication (e.g., user navigated away from
  /// the NSFW subreddit before unlocking).
  void clearLock() {
    if (!_isLocked) return;
    _isLocked = false;
    _isAuthenticating = false;
    _errorMessage = null;
    notifyListeners();
  }

  /// Invokes the system biometric prompt.
  ///
  /// Sets [isAuthenticating] during the prompt so the UI can show a spinner.
  /// Clears the lock on success; surfaces [errorMessage] on failure.
  Future<void> authenticate() async {
    if (_service == null || !_isLocked || _isAuthenticating) return;

    _isAuthenticating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _service!.authenticate();
      if (success) {
        _isLocked = false;
        _errorMessage = null;
      } else {
        _errorMessage = 'Authentication failed. Please try again.';
      }
    } on Exception catch (e) {
      _errorMessage = 'Authentication error: $e';
    } finally {
      _isAuthenticating = false;
      notifyListeners();
    }
  }
}
