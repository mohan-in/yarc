import 'dart:developer';

import 'package:local_auth/local_auth.dart';
import 'package:yarc/utils/constants.dart';

/// Wraps [LocalAuthentication] to provide biometric auth capabilities.
///
/// Intentionally has no Flutter or BuildContext dependencies so it can live
/// in the service layer and be injected via the constructor.
class BiometricService {
  BiometricService() : _auth = LocalAuthentication();

  final LocalAuthentication _auth;

  /// Returns true if the device has **enrolled** biometrics (fingerprint /
  /// face) that can actually be used to authenticate right now.
  ///
  /// `canCheckBiometrics` only indicates hardware presence, not enrollment.
  /// `getAvailableBiometrics()` is the correct API: it returns the list of
  /// enrolled biometric types, so an empty list means "nothing to prompt".
  ///
  /// Does NOT include device credentials (PIN / pattern / password) since
  /// this service is biometric-only.
  Future<bool> isAvailable() async {
    try {
      final enrolled = await _auth.getAvailableBiometrics();
      return enrolled.isNotEmpty;
    } on Exception catch (e) {
      log('isAvailable error: $e', name: 'BiometricService');
      return false;
    }
  }

  /// Prompts the user to authenticate using biometrics only.
  ///
  /// Returns `true` on success.
  ///
  /// Throws [LocalAuthException] for all non-success outcomes so callers
  /// can distinguish error codes (lockout, no hardware, cancelled, etc.)
  /// from a genuine success.
  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: kBiometricNsfwReason,
        biometricOnly: true,
      );
    } on LocalAuthException {
      // Re-throw typed exceptions so BiometricLockNotifier can distinguish
      // hardware/enrollment errors from a simple false return (cancelled).
      rethrow;
    } on Exception catch (e) {
      log('authenticate error: $e', name: 'BiometricService');
      rethrow;
    }
  }
}
