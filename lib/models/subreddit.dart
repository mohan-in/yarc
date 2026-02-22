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

    if (icon != null && icon.isEmpty) {
      icon = null;
    }

    int? subscribers;
    if (sub.data != null && sub.data!['subscribers'] != null) {
      subscribers = sub.data!['subscribers'] as int?;
    }

    String? description;
    if (sub.data != null && sub.data!['public_description'] != null) {
      description = sub.data!['public_description'] as String?;
      if (description != null && description.isEmpty) {
        description = null;
      }
    }

    bool? userIsSubscriber;
    if (sub.data != null && sub.data!['user_is_subscriber'] != null) {
      userIsSubscriber = sub.data!['user_is_subscriber'] as bool?;
    }

    return Subreddit(
      displayName: sub.displayName,
      title: HtmlUtils.unescape(sub.title),
      iconImg: icon,
      url: sub.path,
      subscriberCount: subscribers,
      description: description != null ? HtmlUtils.unescape(description) : null,
      userIsSubscriber: userIsSubscriber,
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Subreddit && other.displayName == displayName);

  @override
  int get hashCode => displayName.hashCode;
}
