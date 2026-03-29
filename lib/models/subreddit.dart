import 'package:draw/draw.dart' as draw;
import 'package:flutter/foundation.dart';
import 'package:yarc/utils/html_utils.dart';

/// Represents a Reddit subreddit with its metadata.
///
/// Contains display information like name, title, icon, and subscriber count.
/// Used for displaying subreddit lists and info cards.
@immutable
class Subreddit {
  const Subreddit({
    required this.isOver18,
    required this.displayName,
    required this.title,
    required this.url,
    this.iconImg,
    this.subscriberCount,
    this.description,
    this.userIsSubscriber,
  });

  /// Creates a [Subreddit] from a DRAW library subreddit object.
  ///
  /// Extracts icon from either `iconImage` or `community_icon` fields,
  /// and parses subscriber count and description from raw data.
  factory Subreddit.fromDraw(draw.Subreddit sub) {
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

  /// The display name of the subreddit (e.g., "flutter").
  final String displayName;

  final String title;

  final String? iconImg;

  /// The URL path to the subreddit (e.g., "/r/flutter").
  final String url;

  final int? subscriberCount;

  final String? description;

  final bool? userIsSubscriber;

  final bool isOver18;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Subreddit && other.displayName == displayName);

  @override
  int get hashCode => displayName.hashCode;
}
