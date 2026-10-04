import 'package:draw/draw.dart' as draw;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:yarc/models/feed_sort.dart';
import 'package:yarc/models/post.dart';
import 'package:yarc/notifiers/feed_notifier.dart';
import 'package:yarc/widgets/search_banner_sliver.dart';

import '../helpers/mocks.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(FeedSort.hot);
    registerFallbackValue(draw.TimeFilter.all);
  });

  late MockPostRepository mockPostRepository;
  late MockSettingsNotifier mockSettingsNotifier;
  late FeedNotifier feedNotifier;

  setUp(() {
    mockPostRepository = MockPostRepository();
    mockSettingsNotifier = MockSettingsNotifier();

    when(() => mockSettingsNotifier.defaultSort).thenReturn(FeedSort.hot);
    when(() => mockSettingsNotifier.hideNsfw).thenReturn(false);
    when(() => mockSettingsNotifier.hideReadPosts).thenReturn(false);
    when(() => mockPostRepository.getReadPostIds()).thenReturn({});
    when(
      () => mockPostRepository.getPosts(
        subreddit: any(named: 'subreddit'),
      ),
    ).thenAnswer((_) async => (posts: <Post>[], nextAfter: null));
    when(
      () => mockPostRepository.refresh(
        subreddit: any(named: 'subreddit'),
      ),
    ).thenAnswer((_) async => (posts: <Post>[], nextAfter: null));
    when(
      () => mockPostRepository.searchSubredditPosts(
        query: any(named: 'query'),
        subredditName: any(named: 'subredditName'),
      ),
    ).thenAnswer((_) async => (posts: <Post>[], nextAfter: null));
    when(
      () => mockPostRepository.getSubredditInfo(any()),
    ).thenAnswer((_) async => null);

    feedNotifier = FeedNotifier()
      ..setRepository(mockPostRepository)
      ..setSettings(mockSettingsNotifier);
  });

  Widget buildTestWidget() {
    return MaterialApp(
      home: Scaffold(
        body: ChangeNotifierProvider<FeedNotifier>.value(
          value: feedNotifier,
          child: const CustomScrollView(
            slivers: [
              SearchBannerSliver(),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('renders empty when no search query is active', (tester) async {
    await tester.pumpWidget(buildTestWidget());

    expect(find.byIcon(Icons.search), findsNothing);
    expect(find.byTooltip('Clear search'), findsNothing);
  });

  testWidgets('renders search query and clear button when search is active', (
    tester,
  ) async {
    feedNotifier.selectSubreddit('flutterdev');
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    await feedNotifier.searchInCurrentSubreddit('bloc');
    await tester.pumpAndSettle();

    expect(find.text('Results for "bloc"'), findsOneWidget);
    expect(find.byTooltip('Clear search'), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);
  });

  testWidgets('tapping clear button clears the search query', (tester) async {
    feedNotifier.selectSubreddit('flutterdev');
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    await feedNotifier.searchInCurrentSubreddit('bloc');
    await tester.pumpAndSettle();

    expect(find.text('Results for "bloc"'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();

    expect(find.text('Results for "bloc"'), findsNothing);
    expect(feedNotifier.searchQuery, isNull);
  });
}
