import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yarc/models/redditor_info.dart';
import 'package:yarc/repositories/user_repository.dart';

import '../helpers/mocks.dart';

void main() {
  late MockRedditService mockReddit;
  late UserRepository repository;

  setUp(() {
    mockReddit = MockRedditService();
    repository = UserRepository(mockReddit);
  });

  group('UserRepository', () {
    test('fetchUser delegates to RedditService', () async {
      final info = RedditorInfo(
        name: 'test_user',
        commentKarma: 100,
        linkKarma: 200,
        createdUtc: DateTime.utc(2020),
      );

      when(
        () => mockReddit.fetchUser('test_user'),
      ).thenAnswer((_) async => info);

      final result = await repository.fetchUser('test_user');

      expect(result?.name, 'test_user');
      expect(result?.commentKarma, 100);
      verify(() => mockReddit.fetchUser('test_user')).called(1);
    });
  });
}
