import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yarc/models/custom_feed.dart';
import 'package:yarc/models/subreddit.dart';
import 'package:yarc/notifiers/subreddits_notifier.dart';

import '../helpers/mocks.dart';

void main() {
  late MockSubredditRepository mockSubredditRepository;
  late SubredditsNotifier subredditsNotifier;

  setUp(() {
    mockSubredditRepository = MockSubredditRepository();
    subredditsNotifier = SubredditsNotifier()
      ..setRepository(mockSubredditRepository);
  });

  group('SubredditsNotifier', () {
    const subFlutter = Subreddit(
      displayName: 'Flutter',
      title: 'Flutter Dev',
      url: '/r/Flutter/',
      isOver18: false,
    );
    const customFeed = CustomFeed(
      displayName: 'Tech News',
      path: '/user/dev/m/tech',
    );

    test('fetch loads subreddits and custom feeds', () async {
      when(
        () => mockSubredditRepository.getSubscribed(),
      ).thenAnswer((_) async => [subFlutter]);
      when(
        () => mockSubredditRepository.getCustomFeeds(),
      ).thenAnswer((_) async => [customFeed]);

      await subredditsNotifier.fetch();

      expect(subredditsNotifier.subreddits.length, 1);
      expect(subredditsNotifier.customFeeds.length, 1);
      expect(subredditsNotifier.isSubscribed('flutter'), isTrue);
      expect(subredditsNotifier.isLoading, isFalse);
    });

    test('toggleSubscription subscribes when not subscribed', () async {
      when(
        () => mockSubredditRepository.getSubscribed(),
      ).thenAnswer((_) async => []);
      when(
        () => mockSubredditRepository.getCustomFeeds(),
      ).thenAnswer((_) async => []);
      when(
        () => mockSubredditRepository.subscribe('Flutter'),
      ).thenAnswer((_) async {});

      await subredditsNotifier.fetch();
      await subredditsNotifier.toggleSubscription(subFlutter);

      expect(subredditsNotifier.isSubscribed('flutter'), isTrue);
      verify(() => mockSubredditRepository.subscribe('Flutter')).called(1);
    });

    test('toggleSubscription unsubscribes when already subscribed', () async {
      when(
        () => mockSubredditRepository.getSubscribed(),
      ).thenAnswer((_) async => [subFlutter]);
      when(
        () => mockSubredditRepository.getCustomFeeds(),
      ).thenAnswer((_) async => []);
      when(
        () => mockSubredditRepository.unsubscribe('Flutter'),
      ).thenAnswer((_) async {});

      await subredditsNotifier.fetch();
      await subredditsNotifier.toggleSubscription(subFlutter);

      expect(subredditsNotifier.isSubscribed('flutter'), isFalse);
      verify(() => mockSubredditRepository.unsubscribe('Flutter')).called(1);
    });

    test('clear resets state', () async {
      when(
        () => mockSubredditRepository.getSubscribed(),
      ).thenAnswer((_) async => [subFlutter]);
      when(
        () => mockSubredditRepository.getCustomFeeds(),
      ).thenAnswer((_) async => [customFeed]);

      await subredditsNotifier.fetch();
      subredditsNotifier.clear();

      expect(subredditsNotifier.subreddits, isEmpty);
      expect(subredditsNotifier.customFeeds, isEmpty);
    });
  });
}
