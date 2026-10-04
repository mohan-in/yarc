import 'package:draw/draw.dart' as draw;
import 'package:yarc/models/subreddit.dart';
import 'package:yarc/utils/html_utils.dart';

/// Parses DRAW [draw.Subreddit] objects into [Subreddit] domain models.
class SubredditParser {
  /// Converts a DRAW [draw.Subreddit] into a domain [Subreddit].
  static Subreddit parse(draw.Subreddit sub) {
    final data = sub.data;

    // Resolve icon: prefer iconImage, fall back to community_icon
    var icon = sub.iconImage != null
        ? HtmlUtils.unescape(sub.iconImage.toString())
        : null;
    if (icon == null || icon.isEmpty) {
      final commIcon = data?['community_icon'];
      if (commIcon is String && commIcon.isNotEmpty) {
        icon = HtmlUtils.unescape(commIcon);
      }
    }
    if (icon != null && icon.isEmpty) {
      icon = null;
    }

    final subscribers = data?['subscribers'] as int?;
    final rawDescription = data?['public_description'] as String?;
    final description = (rawDescription != null && rawDescription.isNotEmpty)
        ? HtmlUtils.unescape(rawDescription)
        : null;
    final userIsSubscriber = data?['user_is_subscriber'] as bool?;
    final isOver18 = (data?['over18'] as bool?) ?? false;

    return Subreddit(
      displayName: sub.displayName,
      title: HtmlUtils.unescape(sub.title),
      iconImg: icon,
      url: sub.path,
      subscriberCount: subscribers,
      description: description,
      userIsSubscriber: userIsSubscriber,
      isOver18: isOver18,
    );
  }
}
