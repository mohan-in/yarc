import 'package:flutter/foundation.dart';

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

  Subreddit copyWith({
    String? displayName,
    String? title,
    String? iconImg,
    String? url,
    int? subscriberCount,
    String? description,
    bool? userIsSubscriber,
    bool? isOver18,
  }) {
    return Subreddit(
      displayName: displayName ?? this.displayName,
      title: title ?? this.title,
      iconImg: iconImg ?? this.iconImg,
      url: url ?? this.url,
      subscriberCount: subscriberCount ?? this.subscriberCount,
      description: description ?? this.description,
      userIsSubscriber: userIsSubscriber ?? this.userIsSubscriber,
      isOver18: isOver18 ?? this.isOver18,
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
