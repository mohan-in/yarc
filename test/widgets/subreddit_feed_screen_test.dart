import 'package:draw/draw.dart' as draw;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:yarc/models/feed_sort.dart';
import 'package:yarc/models/post.dart';
import 'package:yarc/models/subreddit.dart';
import 'package:yarc/notifiers/auth_notifier.dart';
import 'package:yarc/notifiers/search_notifier.dart';
import 'package:yarc/notifiers/settings_notifier.dart';
import 'package:yarc/repositories/post_repository.dart';
import 'package:yarc/screens/subreddit_feed_screen.dart';
import 'package:yarc/widgets/widgets.dart';

import '../helpers/mocks.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(FeedSort.hot);
    registerFallbackValue(draw.TimeFilter.all);
  });

  late MockPostRepository mockPostRepository;
  late MockSubredditRepository mockSubredditRepository;
  late MockUserRepository mockUserRepository;
  late MockSettingsNotifier mockSettingsNotifier;
  late MockAuthNotifier mockAuthNotifier;
  late SearchNotifier searchNotifier;

  setUp(() {
    mockPostRepository = MockPostRepository();
    mockSubredditRepository = MockSubredditRepository();
    mockUserRepository = MockUserRepository();
    mockSettingsNotifier = MockSettingsNotifier();
    mockAuthNotifier = MockAuthNotifier();

    when(() => mockSettingsNotifier.defaultSort).thenReturn(FeedSort.hot);
    when(() => mockSettingsNotifier.hideNsfw).thenReturn(false);
    when(() => mockSettingsNotifier.hideReadPosts).thenReturn(false);
    when(() => mockAuthNotifier.isLoggedIn).thenReturn(false);
    when(() => mockPostRepository.getReadPostIds()).thenReturn(<String>{});
    when(
      () => mockPostRepository.getPosts(
        subreddit: any(named: 'subreddit'),
        sort: any(named: 'sort'),
      ),
    ).thenAnswer((_) async => (posts: <Post>[], nextAfter: null));
    when(
      () => mockPostRepository.refresh(
        subreddit: any(named: 'subreddit'),
        sort: any(named: 'sort'),
      ),
    ).thenAnswer((_) async => (posts: <Post>[], nextAfter: null));
    when(
      () => mockPostRepository.getSubredditInfo(any()),
    ).thenAnswer((_) async => null);

    when(
      () => mockSubredditRepository.search(any()),
    ).thenAnswer((_) async => <Subreddit>[]);
    when(
      () => mockUserRepository.fetchUser(any()),
    ).thenAnswer((_) async => null);

    searchNotifier = SearchNotifier()
      ..setSubredditRepository(mockSubredditRepository)
      ..setUserRepository(mockUserRepository);
  });

  Widget buildTestScreen(Widget screen) {
    return MultiProvider(
      providers: [
        Provider<PostRepository>.value(value: mockPostRepository),
        ChangeNotifierProvider<SettingsNotifier>.value(
          value: mockSettingsNotifier,
        ),
        ChangeNotifierProvider<AuthNotifier>.value(
          value: mockAuthNotifier,
        ),
        ChangeNotifierProvider<SearchNotifier>.value(
          value: searchNotifier,
        ),
      ],
      child: MaterialApp(
        home: screen,
      ),
    );
  }

  testWidgets('SubredditFeedScreen displays search action button in AppBar', (
    tester,
  ) async {
    const sub = Subreddit(
      displayName: 'flutterdev',
      title: 'Flutter Dev',
      url: '/r/flutterdev',
      isOver18: false,
    );

    await tester.pumpWidget(
      buildTestScreen(const SubredditFeedScreen(subreddit: sub)),
    );
    await tester.pumpAndSettle();

    expect(find.text('r/flutterdev'), findsOneWidget);
    expect(find.byTooltip('Search'), findsOneWidget);
    expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    expect(
      find.byType(SearchBannerSliver, skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('SubredditFeedScreen.fromName displays search action button', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestScreen(const SubredditFeedScreen.fromName(name: 'dartlang')),
    );
    await tester.pumpAndSettle();

    expect(find.text('r/dartlang'), findsOneWidget);
    expect(find.byTooltip('Search'), findsOneWidget);
    expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    expect(
      find.byType(SearchBannerSliver, skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('tapping search button opens search delegate interface', (
    tester,
  ) async {
    const sub = Subreddit(
      displayName: 'flutterdev',
      title: 'Flutter Dev',
      url: '/r/flutterdev',
      isOver18: false,
    );

    await tester.pumpWidget(
      buildTestScreen(const SubredditFeedScreen(subreddit: sub)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();

    // In search delegate, search hint / label should show
    expect(
      find.text('Search in r/flutterdev or all Reddit'),
      findsOneWidget,
    );
  });

  testWidgets(
    'submitting scoped search shows search query banner in subreddit feed',
    (tester) async {
      when(
        () => mockPostRepository.searchSubredditPosts(
          query: any(named: 'query'),
          subredditName: any(named: 'subredditName'),
          sort: any(named: 'sort'),
          timeFilter: any(named: 'timeFilter'),
        ),
      ).thenAnswer((_) async => (posts: <Post>[], nextAfter: null));

      const sub = Subreddit(
        displayName: 'flutterdev',
        title: 'Flutter Dev',
        url: '/r/flutterdev',
        isOver18: false,
      );

      await tester.pumpWidget(
        buildTestScreen(const SubredditFeedScreen(subreddit: sub)),
      );
      await tester.pumpAndSettle();

      // Tap search in AppBar
      await tester.tap(find.byTooltip('Search'));
      await tester.pumpAndSettle();

      // Enter search query and submit
      await tester.enterText(find.byType(TextField), 'riverpod');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      // Verify search banner is displayed with the query
      expect(find.text('Results for "riverpod"'), findsOneWidget);
      expect(find.byTooltip('Clear search'), findsOneWidget);

      // Tap clear search button
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();

      // Search banner is cleared
      expect(find.text('Results for "riverpod"'), findsNothing);
    },
  );
}
