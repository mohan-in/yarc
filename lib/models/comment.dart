import 'package:draw/draw.dart' as draw;

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
    List<Comment> replies = [];
    if (comment.replies != null) {
      // draw.CommentForest or similar. .toList() gives comments.
      // Filter out MoreComments objects if necessary, though draw might handle them or return them.
      // We only want actual comments.
      for (final reply in comment.replies!.comments) {
        if (reply is draw.Comment) {
          replies.add(Comment.fromDraw(reply));
        }
      }
    }

    return Comment(
      id: comment.id ?? '',
      author: comment.author,
      body: comment.body ?? '',
      ups: comment.upvotes,
      createdUtc: comment.createdUtc.millisecondsSinceEpoch / 1000,
      replies: replies,
    );
  }
}
