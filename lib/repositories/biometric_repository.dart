import 'package:yarc/services/biometric_service.dart';

/// Repository for biometric authentication operations.
class BiometricRepository {
  BiometricRepository(this._service);

  final BiometricService _service;

  /// Returns true if the device has enrolled biometrics.
  Future<bool> isAvailable() => _service.isAvailable();

  /// Prompts the user to authenticate using biometrics.
  Future<bool> authenticate() => _service.authenticate();
}
