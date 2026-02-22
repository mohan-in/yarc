import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yarc/models/post.dart';
import 'package:yarc/theme/theme.dart';
import 'package:yarc/widgets/markdown_content.dart';
import 'package:yarc/widgets/post_card.dart';

void main() {
  testWidgets('PostCard uses appTheme font sizes', (tester) async {
    final post = Post(
      id: '1',
      title: 'Test Title',
      author: 'author',
      subreddit: 'flutter',
      createdUtc: DateTime.now().millisecondsSinceEpoch / 1000,
      content: 'Test content',
      ups: 100,
      numComments: 10,
      permalink: '/r/flutter/comments/123/test',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Scaffold(
          body: PostCard(post: post),
        ),
      ),
    );

    final titleFinder = find.text('Test Title');
    final contentFinder = find.byType(MarkdownContent);

    expect(titleFinder, findsOneWidget);
    expect(contentFinder, findsOneWidget);

    final titleText = tester.widget<Text>(titleFinder);
    // titleMedium is 17 in appTheme
    expect(titleText.style?.fontSize, 17.0);

    // MarkdownContent should receive bodyMedium style
    final markdownWidget = tester.widget<MarkdownContent>(contentFinder);
    // bodyMedium is 15 in appTheme
    expect(markdownWidget.style?.fontSize, 15.0);
  });
}
