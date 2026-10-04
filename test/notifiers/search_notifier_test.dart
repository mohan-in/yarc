import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yarc/models/redditor_info.dart';
import 'package:yarc/models/subreddit.dart';
import 'package:yarc/notifiers/search_notifier.dart';

import '../helpers/mocks.dart';

void main() {
  late MockSubredditRepository mockSubredditRepository;
  late MockUserRepository mockUserRepository;
  late SearchNotifier searchNotifier;

  setUp(() {
    mockSubredditRepository = MockSubredditRepository();
    mockUserRepository = MockUserRepository();
    searchNotifier = SearchNotifier()
      ..setSubredditRepository(mockSubredditRepository)
      ..setUserRepository(mockUserRepository);
  });

  group('SearchNotifier', () {
    test('search returns empty when query < 2 chars', () async {
      await searchNotifier.search('a');

      expect(searchNotifier.results, isEmpty);
      expect(searchNotifier.isLoading, isFalse);
      verifyNever(() => mockSubredditRepository.search(any()));
    });

    test('search updates results for valid query', () async {
      final subs = [
        const Subreddit(
          displayName: 'flutterhelp',
          title: 'Flutter Help',
          url: '/r/flutterhelp/',
          isOver18: false,
        ),
        const Subreddit(
          displayName: 'flutterdev',
          title: 'Flutter Dev',
          url: '/r/flutterdev/',
          isOver18: false,
        ),
      ];
      when(
        () => mockSubredditRepository.search('flutter'),
      ).thenAnswer((_) async => subs);

      await searchNotifier.search('flutter');

      expect(searchNotifier.results.length, 2);
      expect(searchNotifier.isLoading, isFalse);
    });

    test('searchUser updates userResult and userSearched flag', () async {
      final info = RedditorInfo(
        name: 'flutter_guru',
        commentKarma: 10,
        linkKarma: 20,
        createdUtc: DateTime.utc(2022),
      );
      when(
        () => mockUserRepository.fetchUser('flutter_guru'),
      ).thenAnswer((_) async => info);

      await searchNotifier.searchUser('flutter_guru');

      expect(searchNotifier.userResult?.name, 'flutter_guru');
      expect(searchNotifier.userSearched, isTrue);
      expect(searchNotifier.isUserLoading, isFalse);
    });

    test('clear resets all search state', () async {
      searchNotifier.clear();

      expect(searchNotifier.query, isEmpty);
      expect(searchNotifier.results, isEmpty);
      expect(searchNotifier.userResult, isNull);
      expect(searchNotifier.userSearched, isFalse);
    });
  });
}
