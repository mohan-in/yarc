import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:yarc/models/feed_sort.dart';
import 'package:yarc/models/subreddit.dart';
import 'package:yarc/notifiers/feed_notifier.dart';
import 'package:yarc/notifiers/subreddits_notifier.dart';
import 'package:yarc/notifiers/top_subreddits_notifier.dart';
import 'package:yarc/screens/top_subreddits_screen.dart';

import '../helpers/mocks.dart';

void main() {
  late MockSubredditRepository mockSubredditRepository;
  late MockPostRepository mockPostRepository;
  late MockSettingsNotifier mockSettingsNotifier;

  setUp(() {
    mockSubredditRepository = MockSubredditRepository();
    mockPostRepository = MockPostRepository();
    mockSettingsNotifier = MockSettingsNotifier();

    when(() => mockSettingsNotifier.defaultSort).thenReturn(FeedSort.hot);
    when(() => mockSettingsNotifier.hideNsfw).thenReturn(false);
    when(() => mockSettingsNotifier.hideReadPosts).thenReturn(false);

    when(
      () => mockSubredditRepository.getSubscribed(),
    ).thenAnswer((_) async => []);
    when(
      () => mockSubredditRepository.getCustomFeeds(),
    ).thenAnswer((_) async => []);
  });

  testWidgets('TopSubredditsScreen numbers the subreddits list', (
    tester,
  ) async {
    const sub1 = Subreddit(
      displayName: 'AskReddit',
      title: 'Ask Reddit',
      url: '/r/AskReddit',
      isOver18: false,
    );
    const sub2 = Subreddit(
      displayName: 'funny',
      title: 'Funny',
      url: '/r/funny',
      isOver18: false,
    );

    when(
      () => mockSubredditRepository.getPopular(after: any(named: 'after')),
    ).thenAnswer((_) async => (subreddits: [sub1, sub2], nextAfter: null));

    final topNotifier = TopSubredditsNotifier()
      ..setRepository(mockSubredditRepository);
    final subredditsNotifier = SubredditsNotifier()
      ..setRepository(mockSubredditRepository);
    final feedNotifier = FeedNotifier()
      ..setRepository(mockPostRepository)
      ..setSettings(mockSettingsNotifier);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<TopSubredditsNotifier>.value(
            value: topNotifier,
          ),
          ChangeNotifierProvider<SubredditsNotifier>.value(
            value: subredditsNotifier,
          ),
          ChangeNotifierProvider<FeedNotifier>.value(
            value: feedNotifier,
          ),
        ],
        child: const MaterialApp(
          home: TopSubredditsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('r/AskReddit'), findsOneWidget);
    expect(find.text('r/funny'), findsOneWidget);
  });
}
