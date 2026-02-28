import 'package:flutter/foundation.dart';

/// A data model representing a Reddit post.
@immutable
class Post {
  const Post({
    required this.id,
    required this.title,
    required this.author,
    required this.subreddit,
    required this.ups,
    required this.numComments,
    required this.permalink,
    required this.content,
    required this.createdUtc,
    this.thumbnail,
    this.imageUrl,
    this.images = const [],
    this.url,
    this.isVideo = false,
    this.videoUrl,
    this.isYoutube = false,
    this.youtubeId,
    this.aspectRatio,
    this.crosspostParent,
  });

  /// The unique ID of the post (e.g., "t3_12345").
  final String id;

  final String title;

  /// The username of the author (without "u/").
  final String author;

  /// The subreddit name (without "r/").
  final String subreddit;

  final int ups;

  /// The URL of the thumbnail image, if available.
  final String? thumbnail;

  /// The URL of the main image, if available.
  final String? imageUrl;

  /// The permalink path to the post (e.g., "/r/flutter/comments/...").
  final String permalink;

  final int numComments;

  /// The textual content of the post (selftext).
  final String content;

  /// The creation time in UTC seconds.
  final double createdUtc;

  /// A list of image URLs for gallery posts.
  final List<String> images;

  final bool isVideo;

  final String? videoUrl;

  final bool isYoutube;

  final String? youtubeId;

  final double? aspectRatio;

  /// The external URL for link-type posts (non-self posts).
  final String? url;

  /// The original post for crossposts/reposts.
  final Post? crosspostParent;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Post && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
