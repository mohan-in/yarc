import 'package:draw/draw.dart' as draw;
import 'package:yarc/models/comment.dart';
import 'package:yarc/models/vote_type.dart';
import 'package:yarc/utils/html_utils.dart';

/// Parses DRAW [draw.Comment] objects into [Comment] domain models.
class CommentParser {
  /// Converts a DRAW [draw.Comment] into a domain [Comment].
  static Comment parse(draw.Comment comment) {
    final replies = <Comment>[];
    if (comment.replies != null) {
      for (final reply in comment.replies!.comments) {
        if (reply is draw.Comment) {
          replies.add(parse(reply));
        }
      }
    }

    final likes = comment.data?['likes'] as bool?;
    final voteType = switch (likes) {
      true => VoteType.upvoted,
      false => VoteType.downvoted,
      null => VoteType.none,
    };

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
      voteType: voteType,
    );
  }
}
