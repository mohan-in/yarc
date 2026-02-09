import 'package:draw/draw.dart' as draw;
import '../utils/html_utils.dart';

class Comment {
  final String id;
  final String author;
  final String body;
  final int ups;
  final double createdUtc;
  final List<Comment> replies;

  Comment({
    required this.id,
    required this.author,
    required this.body,
    required this.ups,
    required this.createdUtc,
    this.replies = const [],
  });

  factory Comment.fromDraw(draw.Comment comment) {
    final List<Comment> replies = [];
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
      body: comment.body != null ? HtmlUtils.unescape(comment.body!) : '',
      ups: comment.upvotes,
      createdUtc: comment.createdUtc.millisecondsSinceEpoch / 1000,
      replies: replies,
    );
  }
}
