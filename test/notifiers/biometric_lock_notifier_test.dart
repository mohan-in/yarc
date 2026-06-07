import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yarc/notifiers/biometric_lock_notifier.dart';
import '../helpers/mocks.dart';

void main() {
  late BiometricLockNotifier notifier;
  late MockBiometricRepository mockRepository;

  setUp(() {
    mockRepository = MockBiometricRepository();
    notifier = BiometricLockNotifier();
    when(() => mockRepository.isAvailable()).thenAnswer((_) async => true);
  });

  group('BiometricLockNotifier', () {
    test('initial state is unlocked and not authenticating', () {
      expect(notifier.isLocked, false);
      expect(notifier.isAuthenticating, false);
      expect(notifier.errorMessage, null);
    });

    test('requestLock locks the notifier', () {
      notifier.requestLock();
      expect(notifier.isLocked, false); // Guarded - repository is null

      notifier
        ..setRepository(mockRepository)
        ..requestLock();
      expect(notifier.isLocked, true);
      expect(notifier.errorMessage, null);
    });

    test('clearLock unlocks and resets state', () {
      notifier
        ..setRepository(mockRepository)
        ..requestLock()
        ..clearLock();
      expect(notifier.isLocked, false);
      expect(notifier.isAuthenticating, false);
      expect(notifier.errorMessage, null);
    });

    test('setRepository fetches and caches availability', () async {
      when(() => mockRepository.isAvailable()).thenAnswer((_) async => true);

      notifier.setRepository(mockRepository);

      // Wait for the unawaited async availability check to complete.
      await Future<void>.delayed(Duration.zero);

      verify(
        () => mockRepository.isAvailable(),
      ).called(1);
    });

    test(
      'requestLockIfAvailable locks when biometrics are available',
      () async {
        when(() => mockRepository.isAvailable()).thenAnswer((_) async => true);
        notifier.setRepository(mockRepository);
        await Future<void>.delayed(Duration.zero);

        notifier.requestLockIfAvailable();
        expect(notifier.isLocked, true);
      },
    );

    test(
      'requestLockIfAvailable does not lock when biometrics are unavailable',
      () async {
        when(() => mockRepository.isAvailable()).thenAnswer((_) async => false);
        notifier.setRepository(mockRepository);
        await Future<void>.delayed(Duration.zero);

        notifier.requestLockIfAvailable();
        expect(notifier.isLocked, false);
      },
    );

    test('authenticate sets isAuthenticating and unlocks on success', () async {
      notifier
        ..setRepository(mockRepository)
        ..requestLock();
      when(() => mockRepository.authenticate()).thenAnswer((_) async => true);
      when(() => mockRepository.isAvailable()).thenAnswer((_) async => true);
      await Future<void>.delayed(Duration.zero);

      final authFuture = notifier.authenticate();
      expect(notifier.isAuthenticating, true);

      await authFuture;
      expect(notifier.isLocked, false);
      expect(notifier.isAuthenticating, false);
      expect(notifier.errorMessage, null);
    });

    test('authenticate does not unlock on failure', () async {
      notifier
        ..setRepository(mockRepository)
        ..requestLock();
      when(() => mockRepository.authenticate()).thenAnswer((_) async => false);

      await notifier.authenticate();
      expect(notifier.isLocked, true);
      expect(notifier.isAuthenticating, false);
      expect(notifier.errorMessage, 'Authentication failed. Please try again.');
    });

    test(
      'authenticate handles LocalAuthException and maps error messages',
      () async {
        notifier
          ..setRepository(mockRepository)
          ..requestLock();
        when(() => mockRepository.authenticate()).thenThrow(
          const LocalAuthException(
            code: LocalAuthExceptionCode.biometricLockout,
            description: 'Lockout',
          ),
        );

        await notifier.authenticate();
        expect(notifier.isLocked, true);
        expect(
          notifier.errorMessage,
          'Too many failed attempts. Please wait and try again.',
        );
      },
    );

    test(
      'justAuthenticated flag prevents immediate re-lock on resume',
      () async {
        when(() => mockRepository.isAvailable()).thenAnswer((_) async => true);
        notifier.setRepository(mockRepository);
        await Future<void>.delayed(Duration.zero);

        // Lock it initially.
        notifier.requestLock();

        // Authenticate successfully.
        when(() => mockRepository.authenticate()).thenAnswer((_) async => true);
        await notifier.authenticate();
        expect(notifier.isLocked, false);

        // Spurious resumed event occurs. requestLockIfAvailable should consume
        // the flag and not lock.
        notifier.requestLockIfAvailable();
        expect(notifier.isLocked, false);

        // The next resumed event should lock normally.
        notifier.requestLockIfAvailable();
        expect(notifier.isLocked, true);
      },
    );
  });
}
