import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yarc/models/subreddit.dart';
import 'package:yarc/repositories/subreddit_repository.dart';

import '../helpers/mocks.dart';

void main() {
  late MockRedditService mockReddit;
  late SubredditRepository repository;

  setUp(() {
    mockReddit = MockRedditService();
    repository = SubredditRepository(mockReddit);
  });

  group('SubredditRepository', () {
    test('getSubscribed returns sorted subreddits', () async {
      const subZ = Subreddit(
        displayName: 'zebra',
        title: 'Zebra Sub',
        url: '/r/zebra/',
        isOver18: false,
      );
      const subA = Subreddit(
        displayName: 'alpha',
        title: 'Alpha Sub',
        url: '/r/alpha/',
        isOver18: false,
      );

      when(
        () => mockReddit.fetchSubscribedSubreddits(),
      ).thenAnswer((_) async => [subZ, subA]);

      final result = await repository.getSubscribed();

      expect(result.first.displayName, 'alpha');
      expect(result.last.displayName, 'zebra');
    });

    test('search returns empty list when query is short', () async {
      final result = await repository.search('a');

      expect(result, isEmpty);
      verifyNever(() => mockReddit.searchSubreddits(any()));
    });

    test('subscribe and unsubscribe delegate to RedditService', () async {
      when(
        () => mockReddit.subscribeToSubreddit('flutter'),
      ).thenAnswer((_) async {});
      when(
        () => mockReddit.unsubscribeFromSubreddit('flutter'),
      ).thenAnswer((_) async {});

      await repository.subscribe('flutter');
      await repository.unsubscribe('flutter');

      verify(() => mockReddit.subscribeToSubreddit('flutter')).called(1);
      verify(() => mockReddit.unsubscribeFromSubreddit('flutter')).called(1);
    });
  });
}
