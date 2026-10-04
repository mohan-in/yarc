import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:yarc/models/post.dart';
import 'package:yarc/models/vote_type.dart';
import 'package:yarc/notifiers/feed_notifier.dart';
import 'package:yarc/theme/theme.dart';
import 'package:yarc/widgets/markdown_content.dart';
import 'package:yarc/widgets/post_card.dart';

import '../helpers/mocks.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(
      Post(
        id: 'fallback',
        title: '',
        author: '',
        subreddit: '',
        ups: 0,
        numComments: 0,
        permalink: '',
        content: '',
        createdUtc: DateTime.utc(2025),
      ),
    );
    registerFallbackValue(VoteType.none);
  });

  final testPost = Post(
    id: '1',
    title: 'Test Title',
    author: 'author',
    subreddit: 'flutter',
    createdUtc: DateTime.utc(2025),
    content: 'Test content',
    ups: 100,
    numComments: 10,
    permalink: '/r/flutter/comments/123/test',
  );

  testWidgets('PostCard uses appTheme font sizes', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Scaffold(
          body: ChangeNotifierProvider<FeedNotifier>(
            create: (_) => FeedNotifier(),
            child: PostCard(post: testPost),
          ),
        ),
      ),
    );

    final titleFinder = find.text('Test Title');
    final contentFinder = find.byType(MarkdownContent);

    expect(titleFinder, findsOneWidget);
    expect(contentFinder, findsOneWidget);

    final titleText = tester.widget<Text>(titleFinder);
    expect(titleText.style?.fontSize, 17.0);

    final markdownWidget = tester.widget<MarkdownContent>(contentFinder);
    expect(markdownWidget.style?.fontSize, 15.0);
  });

  testWidgets('PostCard upvote button calls FeedNotifier.vote', (tester) async {
    final mockFeedNotifier = MockFeedNotifier();
    when(() => mockFeedNotifier.vote(any(), any())).thenAnswer((_) async {});

    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Scaffold(
          body: ChangeNotifierProvider<FeedNotifier>.value(
            value: mockFeedNotifier,
            child: PostCard(post: testPost),
          ),
        ),
      ),
    );

    final upvoteButton = find.byTooltip('Upvote');
    expect(upvoteButton, findsOneWidget);

    await tester.tap(upvoteButton);
    await tester.pump();

    verify(
      () => mockFeedNotifier.vote(
        testPost,
        VoteType.upvoted,
      ),
    ).called(1);
  });

  testWidgets('PostCard downvote button calls FeedNotifier.vote', (
    tester,
  ) async {
    final mockFeedNotifier = MockFeedNotifier();
    when(() => mockFeedNotifier.vote(any(), any())).thenAnswer((_) async {});

    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Scaffold(
          body: ChangeNotifierProvider<FeedNotifier>.value(
            value: mockFeedNotifier,
            child: PostCard(post: testPost),
          ),
        ),
      ),
    );

    final downvoteButton = find.byTooltip('Downvote');
    expect(downvoteButton, findsOneWidget);

    await tester.tap(downvoteButton);
    await tester.pump();

    verify(
      () => mockFeedNotifier.vote(
        testPost,
        VoteType.downvoted,
      ),
    ).called(1);
  });
}
