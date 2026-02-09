import 'package:draw/draw.dart' as draw;
import '../utils/html_utils.dart';

/// Represents a Reddit subreddit with its metadata.
///
/// Contains display information like name, title, icon, and subscriber count.
/// Used for displaying subreddit lists and info cards.
class Subreddit {
  /// The display name of the subreddit (e.g., "flutter").
  final String displayName;

  /// The full title of the subreddit.
  final String title;

  /// URL to the subreddit's icon image, if available.
  final String? iconImg;

  /// The URL path to the subreddit (e.g., "/r/flutter").
  final String url;

  /// Number of subscribers, if available.
  final int? subscriberCount;

  /// Public description of the subreddit, if available.
  final String? description;

  Subreddit({
    required this.displayName,
    required this.title,
    this.iconImg,
    required this.url,
    this.subscriberCount,
    this.description,
  });

  /// Creates a [Subreddit] from a DRAW library subreddit object.
  ///
  /// Extracts icon from either `iconImage` or `community_icon` fields,
  /// and parses subscriber count and description from raw data.
  factory Subreddit.fromDraw(draw.Subreddit sub) {
    String? icon;
    final iconUri = sub.iconImage;
    if (iconUri != null) {
      icon = HtmlUtils.unescape(iconUri.toString());
    }

    if ((icon == null || icon.isEmpty) && sub.data != null) {
      final commIcon = sub.data!['community_icon'];
      if (commIcon != null && commIcon is String && commIcon.isNotEmpty) {
        icon = HtmlUtils.unescape(commIcon);
      }
    }

    if (icon != null && icon.isEmpty) icon = null;

    int? subscribers;
    if (sub.data != null && sub.data!['subscribers'] != null) {
      subscribers = sub.data!['subscribers'] as int?;
    }

    String? description;
    if (sub.data != null && sub.data!['public_description'] != null) {
      description = sub.data!['public_description'] as String?;
      if (description != null && description.isEmpty) description = null;
    }

    return Subreddit(
      displayName: sub.displayName,
      title: HtmlUtils.unescape(sub.title),
      iconImg: icon,
      url: sub.path,
      subscriberCount: subscribers,
      description: description != null ? HtmlUtils.unescape(description) : null,
    );
  }
}
