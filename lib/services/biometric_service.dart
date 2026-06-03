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

  /// Returns true if the device has enrolled biometrics (fingerprint / face).
  ///
  /// Does NOT include device credentials (PIN / pattern / password) since
  /// this service is biometric-only.
  Future<bool> isAvailable() async {
    try {
      return await _auth.canCheckBiometrics;
    } on Exception catch (e) {
      log('isAvailable error: $e', name: 'BiometricService');
      return false;
    }
  }

  /// Prompts the user to authenticate using biometrics only.
  ///
  /// PIN / pattern / password fallback is intentionally disabled.
  /// Returns `true` on success, `false` if the user cancelled or failed.
  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: kBiometricNsfwReason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } on Exception catch (e) {
      log('authenticate error: $e', name: 'BiometricService');
      return false;
    }
  }
}
