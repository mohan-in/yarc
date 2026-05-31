import 'package:draw/draw.dart' as draw;
import 'package:flutter/foundation.dart';
import 'package:yarc/utils/html_utils.dart';

@immutable
class Comment {
  const Comment({
    required this.id,
    required this.author,
    required this.body,
    required this.ups,
    required this.createdUtc,
    this.replies = const [],
  });

  factory Comment.fromDraw(draw.Comment comment) {
    final replies = <Comment>[];
    if (comment.replies != null) {
      for (final reply in comment.replies!.comments) {
        if (reply is draw.Comment) {
          replies.add(Comment.fromDraw(reply));
        }
      }
    }

    return Comment(
      id: comment.id ?? '',
      author: comment.author,
      body: comment.body != null
          ? HtmlUtils.resolveGiphyShortcodes(HtmlUtils.unescape(comment.body!))
          : '',
      ups: comment.upvotes,
      createdUtc: DateTime.fromMillisecondsSinceEpoch(
        comment.createdUtc.millisecondsSinceEpoch,
        isUtc: true,
      ),
      replies: replies,
    );
  }

  final String id;
  final String author;
  final String body;
  final int ups;
  final DateTime createdUtc;
  final List<Comment> replies;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Comment && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
