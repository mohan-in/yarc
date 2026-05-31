import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yarc/models/comment.dart';
import 'package:yarc/theme/theme.dart';
import 'package:yarc/widgets/comment_tile.dart';
import 'package:yarc/widgets/markdown_content.dart';

void main() {
  testWidgets('CommentTile uses appTheme', (tester) async {
    final comment = Comment(
      id: '1',
      author: 'author',
      body: 'Test comment',
      createdUtc: DateTime.now(),
      ups: 10,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Scaffold(
          body: CommentTile(comment: comment),
        ),
      ),
    );

    final contentFinder = find.byType(MarkdownContent);
    expect(contentFinder, findsOneWidget);

    final markdownWidget = tester.widget<MarkdownContent>(contentFinder);
    // bodyMedium is 15 in appTheme
    expect(markdownWidget.style?.fontSize, 15.0);

    // Check depth colors if possible (hard to verify purely via widget test
    // without deeper inspection)
    // But ensuring it builds without error confirms extension is found.
  });
}
