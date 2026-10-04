import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:yarc/models/feed_sort.dart';
import 'package:yarc/models/post.dart';
import 'package:yarc/models/subreddit.dart';
import 'package:yarc/notifiers/auth_notifier.dart';
import 'package:yarc/notifiers/comments_notifier.dart';
import 'package:yarc/notifiers/feed_notifier.dart';
import 'package:yarc/notifiers/search_notifier.dart';
import 'package:yarc/notifiers/settings_notifier.dart';
import 'package:yarc/notifiers/subreddits_notifier.dart';
import 'package:yarc/screens/home_screen.dart';
import 'package:yarc/theme/theme.dart';

import '../helpers/mocks.dart';

void main() {
  setUpAll(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });
  late MockAuthNotifier mockAuthNotifier;
  late MockFeedNotifier mockFeedNotifier;
  late MockSubredditsNotifier mockSubredditsNotifier;
  late MockSettingsNotifier mockSettingsNotifier;
  late MockCommentsNotifier mockCommentsNotifier;
  late MockSearchNotifier mockSearchNotifier;

  final samplePost = Post(
    id: 'post_1',
    title: 'Test Post 1',
    author: 'author1',
    subreddit: 'flutter',
    ups: 10,
    numComments: 2,
    permalink: '/r/flutter/1',
    content: 'Content 1',
    createdUtc: DateTime.utc(2025),
  );

  setUp(() {
    mockAuthNotifier = MockAuthNotifier();
    mockFeedNotifier = MockFeedNotifier();
    mockSubredditsNotifier = MockSubredditsNotifier();
    mockSettingsNotifier = MockSettingsNotifier();
    mockCommentsNotifier = MockCommentsNotifier();
    mockSearchNotifier = MockSearchNotifier();

    when(() => mockAuthNotifier.init()).thenAnswer((_) async {});
    when(() => mockAuthNotifier.isLoggedIn).thenReturn(true);
    when(() => mockAuthNotifier.isInitialized).thenReturn(true);
    when(() => mockAuthNotifier.isUnauthenticated).thenReturn(false);

    when(() => mockFeedNotifier.loadPosts()).thenAnswer((_) async {});
    when(() => mockFeedNotifier.posts).thenReturn([samplePost]);
    when(() => mockFeedNotifier.visiblePosts).thenReturn([samplePost]);
    when(() => mockFeedNotifier.currentSubreddit).thenReturn(null);
    when(() => mockFeedNotifier.currentCustomFeedName).thenReturn(null);
    when(() => mockFeedNotifier.currentSort).thenReturn(FeedSort.best);
    when(() => mockFeedNotifier.searchQuery).thenReturn(null);
    when(() => mockFeedNotifier.isOffline).thenReturn(false);
    when(() => mockFeedNotifier.isLoading).thenReturn(false);
    when(() => mockFeedNotifier.errorMessage).thenReturn(null);
    when(() => mockFeedNotifier.readPostIds).thenReturn({});
    when(() => mockFeedNotifier.hideRead).thenReturn(false);
    when(() => mockFeedNotifier.markAsRead(any())).thenAnswer((_) async {});

    when(() => mockSubredditsNotifier.fetch()).thenAnswer((_) async {});
    when(() => mockSubredditsNotifier.subreddits).thenReturn(const [
      Subreddit(
        displayName: 'flutter',
        title: 'Flutter',
        url: '/r/flutter/',
        isOver18: false,
      ),
    ]);
    when(() => mockSubredditsNotifier.customFeeds).thenReturn([]);
    when(() => mockSubredditsNotifier.isLoading).thenReturn(false);
    when(() => mockSubredditsNotifier.errorMessage).thenReturn(null);

    when(() => mockSettingsNotifier.hideReadPosts).thenReturn(false);
    when(() => mockSettingsNotifier.autoPlayVideos).thenReturn(false);
    when(() => mockSettingsNotifier.muteVideosByDefault).thenReturn(true);
  });

  Widget buildTestableWidget({Size size = const Size(400, 800)}) {
    return MediaQuery(
      data: MediaQueryData(size: size),
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthNotifier>.value(value: mockAuthNotifier),
          ChangeNotifierProvider<FeedNotifier>.value(value: mockFeedNotifier),
          ChangeNotifierProvider<SubredditsNotifier>.value(
            value: mockSubredditsNotifier,
          ),
          ChangeNotifierProvider<SettingsNotifier>.value(
            value: mockSettingsNotifier,
          ),
          ChangeNotifierProvider<CommentsNotifier>.value(
            value: mockCommentsNotifier,
          ),
          ChangeNotifierProvider<SearchNotifier>.value(
            value: mockSearchNotifier,
          ),
        ],
        child: MaterialApp(
          theme: appTheme,
          home: const HomeScreen(),
        ),
      ),
    );
  }

  testWidgets('HomeScreen renders narrow layout by default', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildTestableWidget());
    await tester.pumpAndSettle();

    expect(find.text('Test Post 1'), findsOneWidget);
    expect(find.text('Select a post to read'), findsNothing);
  });

  testWidgets('HomeScreen renders two-pane master-detail on wide layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      buildTestableWidget(size: const Size(1200, 900)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Test Post 1'), findsOneWidget);
    expect(find.text('Select a post to read'), findsOneWidget);
  });

  testWidgets('HomeScreen displays offline banner when isOffline is true', (
    tester,
  ) async {
    when(() => mockFeedNotifier.isOffline).thenReturn(true);

    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildTestableWidget());
    await tester.pumpAndSettle();

    expect(
      find.text('Offline mode — showing cached posts'),
      findsOneWidget,
    );
  });
}
