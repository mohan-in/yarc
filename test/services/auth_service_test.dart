import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yarc/services/auth_service.dart';

import '../helpers/mocks.dart';

void main() {
  late MockFlutterSecureStorage mockSecureStorage;
  late MockSharedPreferences mockPrefs;
  late AuthService authService;

  setUp(() {
    mockSecureStorage = MockFlutterSecureStorage();
    mockPrefs = MockSharedPreferences();
    authService = AuthService(
      secureStorage: mockSecureStorage,
      prefs: mockPrefs,
    );
  });

  group('AuthService', () {
    test(
      'init with no stored credentials sets authState to loggedOut',
      () async {
        when(
          () => mockSecureStorage.read(key: any(named: 'key')),
        ).thenAnswer((_) async => null);
        when(() => mockPrefs.getString(any())).thenReturn(null);

        final states = <AuthState>[];
        final sub = authService.authStateStream.listen(states.add);

        await authService.init();
        await Future<void>.delayed(Duration.zero);

        expect(states, contains(AuthState.loggedOut));
        await sub.cancel();
      },
    );

    test(
      'migrates credentials from SharedPreferences to secure storage',
      () async {
        when(
          () => mockSecureStorage.read(key: any(named: 'key')),
        ).thenAnswer((_) async => null);
        when(
          () => mockPrefs.getString('reddit_credentials'),
        ).thenReturn('{"refresh_token":"abc"}');
        when(
          () => mockSecureStorage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => mockPrefs.remove('reddit_credentials'),
        ).thenAnswer((_) async => true);

        await authService.init();

        verify(
          () => mockSecureStorage.write(
            key: 'reddit_credentials',
            value: '{"refresh_token":"abc"}',
          ),
        ).called(1);
        verify(() => mockPrefs.remove('reddit_credentials')).called(1);
      },
    );

    test('logout deletes credentials from secure storage and prefs', () async {
      when(
        () => mockSecureStorage.delete(key: any(named: 'key')),
      ).thenAnswer((_) async {});
      when(
        () => mockPrefs.remove('reddit_credentials'),
      ).thenAnswer((_) async => true);

      final states = <AuthState>[];
      final sub = authService.authStateStream.listen(states.add);

      await authService.logout();
      await Future<void>.delayed(Duration.zero);

      verify(
        () => mockSecureStorage.delete(key: 'reddit_credentials'),
      ).called(1);
      verify(() => mockPrefs.remove('reddit_credentials')).called(1);
      expect(authService.isLoggedIn, isFalse);
      expect(states, contains(AuthState.loggedOut));

      await sub.cancel();
    });
  });
}
