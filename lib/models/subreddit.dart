import 'package:draw/draw.dart' as draw;

class Subreddit {
  final String displayName;
  final String title;
  final String? iconImg;
  final String url;

  Subreddit({
    required this.displayName,
    required this.title,
    this.iconImg,
    required this.url,
  });

  factory Subreddit.fromDraw(draw.Subreddit sub) {
    // draw Subreddit might not have explicit fields populated without fetching,
    // but user.subreddits() returns populated ones usually.
    // sub.data is the raw map.

    String? icon;
    final iconUri = sub.iconImage;
    if (iconUri != null) {
      icon = iconUri.toString().replaceAll('&amp;', '&');
    }

    if ((icon == null || icon.isEmpty) && sub.data != null) {
      final commIcon = sub.data!['community_icon'];
      if (commIcon != null && commIcon is String && commIcon.isNotEmpty) {
        icon = commIcon.replaceAll('&amp;', '&');
      }
    }

    if (icon != null && icon.isEmpty) icon = null;

    return Subreddit(
      displayName: sub.displayName,
      title: sub.title,
      iconImg: icon,
      url: sub.path,
    );
  }
}
