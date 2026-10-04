import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:yarc/models/comment.dart';
import 'package:yarc/models/post.dart';
import 'package:yarc/notifiers/comments_notifier.dart';
import 'package:yarc/notifiers/feed_notifier.dart';
import 'package:yarc/screens/post_detail_screen.dart';
import 'package:yarc/theme/theme.dart';

import '../helpers/mocks.dart';

void main() {
  late MockCommentsNotifier mockCommentsNotifier;
  late MockFeedNotifier mockFeedNotifier;

  final samplePost = Post(
    id: 'post_100',
    title: 'Detail Post Title',
    author: 'author100',
    subreddit: 'flutter',
    ups: 15,
    numComments: 1,
    permalink: '/r/flutter/comments/100',
    content: 'Detail post content',
    createdUtc: DateTime.utc(2025),
  );

  final sampleComment = Comment(
    id: 'comment_1',
    author: 'commenter',
    body: 'Great post!',
    ups: 3,
    createdUtc: DateTime.utc(2025),
  );

  setUp(() {
    mockCommentsNotifier = MockCommentsNotifier();
    mockFeedNotifier = MockFeedNotifier();
  });

  Widget buildTestableWidget({required Future<List<Comment>> commentsFuture}) {
    when(
      () => mockCommentsNotifier.loadComments('post_100'),
    ).thenAnswer((_) => commentsFuture);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<CommentsNotifier>.value(
          value: mockCommentsNotifier,
        ),
        ChangeNotifierProvider<FeedNotifier>.value(
          value: mockFeedNotifier,
        ),
      ],
      child: MaterialApp(
        theme: appTheme,
        home: PostDetailScreen(post: samplePost),
      ),
    );
  }

  testWidgets('PostDetailScreen renders post and loaded comments', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestableWidget(
        commentsFuture: Future.value([sampleComment]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Detail Post Title'), findsOneWidget);
    expect(find.text('Comments'), findsOneWidget);
    expect(find.text('u/commenter'), findsOneWidget);
  });

  testWidgets('PostDetailScreen shows error text when comments fail', (
    tester,
  ) async {
    final future = Future<List<Comment>>.error(
      Exception('Failed to load comments'),
    )..ignore();

    await tester.pumpWidget(
      buildTestableWidget(commentsFuture: future),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Error: Exception: Failed to load comments'),
      findsOneWidget,
    );
  });
}
