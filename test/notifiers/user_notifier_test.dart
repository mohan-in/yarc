import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yarc/models/redditor_info.dart';
import 'package:yarc/notifiers/user_notifier.dart';

import '../helpers/mocks.dart';

void main() {
  late MockUserRepository mockUserRepository;
  late UserNotifier userNotifier;

  setUp(() {
    mockUserRepository = MockUserRepository();
    userNotifier = UserNotifier()..setRepository(mockUserRepository);
  });

  group('UserNotifier', () {
    final sampleInfo = RedditorInfo(
      name: 'flutter_dev',
      commentKarma: 500,
      linkKarma: 1000,
      createdUtc: DateTime.utc(2021),
    );

    test('fetchUser updates userInfo and notifies listeners', () async {
      when(
        () => mockUserRepository.fetchUser('flutter_dev'),
      ).thenAnswer((_) async => sampleInfo);

      final result = await userNotifier.fetchUser('flutter_dev');

      expect(result?.name, 'flutter_dev');
      expect(userNotifier.userInfo?.name, 'flutter_dev');
      expect(userNotifier.isLoading, isFalse);
      expect(userNotifier.errorMessage, isNull);
    });

    test('fetchUser sets errorMessage on error', () async {
      when(
        () => mockUserRepository.fetchUser('unknown'),
      ).thenThrow(Exception('User not found'));

      final result = await userNotifier.fetchUser('unknown');

      expect(result, isNull);
      expect(userNotifier.userInfo, isNull);
      expect(userNotifier.errorMessage, contains('User not found'));
    });

    test('clear resets state', () async {
      when(
        () => mockUserRepository.fetchUser('flutter_dev'),
      ).thenAnswer((_) async => sampleInfo);
      await userNotifier.fetchUser('flutter_dev');

      userNotifier.clear();

      expect(userNotifier.userInfo, isNull);
      expect(userNotifier.errorMessage, isNull);
    });
  });
}
