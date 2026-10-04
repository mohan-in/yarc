import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:yarc/models/comment.dart';
import 'package:yarc/models/vote_type.dart';
import 'package:yarc/notifiers/comments_notifier.dart';
import 'package:yarc/theme/theme.dart';
import 'package:yarc/widgets/comment_tile.dart';
import 'package:yarc/widgets/markdown_content.dart';

import '../helpers/mocks.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(
      Comment(
        id: 'fallback',
        author: '',
        body: '',
        ups: 0,
        createdUtc: DateTime.utc(2025),
      ),
    );
    registerFallbackValue(VoteType.none);
  });

  final testComment = Comment(
    id: '1',
    author: 'author',
    body: 'Test comment',
    createdUtc: DateTime.utc(2025),
    ups: 10,
    replies: [
      Comment(
        id: '2',
        author: 'reply_author',
        body: 'Nested reply',
        createdUtc: DateTime.utc(2025),
        ups: 3,
      ),
    ],
  );

  testWidgets('CommentTile uses appTheme', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Scaffold(
          body: CommentTile(comment: testComment),
        ),
      ),
    );

    final contentFinder = find.byType(MarkdownContent);
    expect(contentFinder, findsNWidgets(2)); // root comment + nested reply

    final markdownWidget = tester.widget<MarkdownContent>(contentFinder.first);
    expect(markdownWidget.style?.fontSize, 15.0);
  });

  testWidgets('CommentTile collapses on header tap', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Scaffold(
          body: CommentTile(comment: testComment),
        ),
      ),
    );

    // Tap header to collapse
    final headerFinder = find.text('u/author');
    expect(headerFinder, findsOneWidget);
    await tester.tap(headerFinder);
    await tester.pumpAndSettle();

    // After collapsing, replies count is shown
    expect(find.text('1 replies'), findsOneWidget);
  });

  testWidgets('CommentTile upvote button calls CommentsNotifier', (
    tester,
  ) async {
    final mockCommentsNotifier = MockCommentsNotifier();
    when(
      () => mockCommentsNotifier.voteComment(any(), any()),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Scaffold(
          body: ChangeNotifierProvider<CommentsNotifier>.value(
            value: mockCommentsNotifier,
            child: CommentTile(comment: testComment),
          ),
        ),
      ),
    );

    final upvoteButtons = find.byTooltip('Upvote comment');
    expect(upvoteButtons, findsWidgets);

    await tester.tap(upvoteButtons.first);
    await tester.pump();

    verify(
      () => mockCommentsNotifier.voteComment(
        testComment,
        VoteType.upvoted,
      ),
    ).called(1);
  });
}
