import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:yarc/repositories/biometric_repository.dart';

/// Tracks whether the app is currently showing the biometric lock screen.
///
/// A lock is requested via [requestLock]. Calling [authenticate] invokes the
/// device biometric prompt and clears the lock on success.
class BiometricLockNotifier extends ChangeNotifier {
  BiometricRepository? _repository;

  bool _isLocked = false;
  bool _isAuthenticating = false;

  /// Cached result of the last [BiometricRepository.isAvailable] call.
  ///
  /// Populated eagerly in [setRepository] and refreshed after each successful
  /// authentication so [requestLockIfAvailable] can run synchronously —
  /// ensuring the lock is applied before Flutter schedules the first frame
  /// after app resume, preventing any flash of NSFW content.
  bool _biometricsAvailable = false;

  /// Set to true after a successful authentication. Consumed (set back to
  /// false) by the very next [requestLockIfAvailable] call to absorb the
  /// spurious `AppLifecycleState.resumed` event fired when the
  /// `BiometricPrompt` dialog dismisses after a successful scan. Without
  /// this, the app would immediately re-lock itself after the user
  /// authenticates.
  bool _justAuthenticated = false;

  String? _errorMessage;

  bool get isLocked => _isLocked;
  bool get isAuthenticating => _isAuthenticating;
  String? get errorMessage => _errorMessage;

  /// Called whenever [BiometricRepository] is (re-)created by the DI layer.
  ///
  /// Resets in-progress auth state and kicks off an async availability
  /// check so that [requestLockIfAvailable] can run synchronously on the
  /// first app-resume after startup.
  void setRepository(BiometricRepository repository) {
    _repository = repository;
    _isAuthenticating = false;
    unawaited(_refreshAvailability());
  }

  /// Queries and caches whether biometrics are enrolled on the device.
  Future<void> _refreshAvailability() async {
    if (_repository == null) return;
    _biometricsAvailable = await _repository!.isAvailable();
  }

  /// Locks the app. Has no effect if already locked.
  void requestLock() {
    if (_repository == null) return;
    if (_isLocked) return;
    _isLocked = true;
    _errorMessage = null;
    notifyListeners();
  }

  /// Locks the app synchronously if enrolled biometrics are available.
  ///
  /// This is intentionally synchronous — it is called from
  /// `didChangeAppLifecycleState`, which runs before Flutter schedules the
  /// next frame. Setting `_isLocked = true` here means the lock overlay is
  /// already visible on the very first frame after resume; no NSFW content
  /// is ever shown while waiting for an async platform-channel result.
  ///
  /// Biometric availability is pre-fetched in [setRepository] and refreshed
  /// after each [authenticate] call, so no async work is needed here.
  ///
  /// Also skips locking once after a successful authentication, to absorb
  /// the `AppLifecycleState.resumed` event that fires when `BiometricPrompt`
  /// dismisses — preventing an immediate re-lock after a successful scan.
  void requestLockIfAvailable() {
    if (_repository == null) return;
    if (_isLocked || !_biometricsAvailable) return;

    // Consume the one-shot flag set by a successful authenticate() call.
    // This absorbs the resumed event fired by BiometricPrompt dismissal.
    if (_justAuthenticated) {
      _justAuthenticated = false;
      return;
    }

    requestLock();
  }

  /// Clears the lock without authentication (e.g., user navigated away from
  /// the NSFW subreddit before unlocking).
  void clearLock() {
    if (_repository == null) return;
    if (!_isLocked) return;
    _isLocked = false;
    _isAuthenticating = false;
    _errorMessage = null;
    notifyListeners();
  }

  /// Invokes the system biometric prompt.
  ///
  /// Only a successful authentication (`true` return from the platform)
  /// clears the lock. Every other outcome — exceptions, cancellation, or
  /// errors — keeps the lock engaged and surfaces an actionable message.
  ///
  /// IMPORTANT: no exception path must set [_isLocked] = false. Access is
  /// only granted on genuine biometric confirmation.
  Future<void> authenticate() async {
    if (_repository == null || !_isLocked || _isAuthenticating) return;

    _isAuthenticating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _repository!.authenticate();
      // Only grant access on an explicit true — false means the user
      // cancelled/failed the prompt, so keep the lock.
      if (success) {
        _isLocked = false;
        _justAuthenticated = true;
        _errorMessage = null;
        // Refresh availability cache for the next lock cycle.
        unawaited(_refreshAvailability());
      } else {
        _errorMessage = 'Authentication failed. Please try again.';
      }
    } on LocalAuthException catch (e) {
      // Map typed error codes to user-facing messages.
      // None of these cases unlock the app — the lock stays engaged.
      switch (e.code) {
        case LocalAuthExceptionCode.biometricLockout:
        case LocalAuthExceptionCode.temporaryLockout:
          _errorMessage =
              'Too many failed attempts. Please wait and try again.';
        case LocalAuthExceptionCode.userCanceled:
        case LocalAuthExceptionCode.systemCanceled:
          _errorMessage = 'Authentication cancelled. Please try again.';
        case LocalAuthExceptionCode.noBiometricHardware:
        case LocalAuthExceptionCode.noBiometricsEnrolled:
        case LocalAuthExceptionCode.noCredentialsSet:
          _errorMessage =
              'No biometrics available. Please enroll a fingerprint in '
              'device Settings, then try again.';
        case LocalAuthExceptionCode.uiUnavailable:
          _errorMessage = 'Could not show biometric prompt. Please try again.';
        case LocalAuthExceptionCode.authInProgress:
          _errorMessage = 'Authentication already in progress.';
        case LocalAuthExceptionCode.timeout:
          _errorMessage = 'Authentication timed out. Please try again.';
        case LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable:
          _errorMessage =
              'Biometric hardware temporarily unavailable. Please try again.';
        case LocalAuthExceptionCode.userRequestedFallback:
        case LocalAuthExceptionCode.deviceError:
        case LocalAuthExceptionCode.unknownError:
          _errorMessage = 'Biometric authentication unavailable.';
      }
    } on Exception catch (e) {
      _errorMessage = 'Authentication error: $e';
    } finally {
      _isAuthenticating = false;
      notifyListeners();
    }
  }
}
