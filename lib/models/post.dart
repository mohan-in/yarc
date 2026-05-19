import 'package:flutter/foundation.dart';

/// Represents a parsed segment of a flair, either text or a custom emoji.
@immutable
class FlairItem {
  const FlairItem({
    required this.isEmoji,
    this.text,
    this.emojiUrl,
  });

  final bool isEmoji;
  final String? text;
  final String? emojiUrl;
}

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
    this.authorFlairText,
    this.authorFlairRichtext,
    this.linkFlairText,
    this.linkFlairRichtext,
    this.totalAwardsReceived = 0,
    this.isSaved = false,
    this.isNsfw = false,
    this.isStickied = false,
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

  /// Whether this post is stickied (pinned) by a moderator.
  final bool isStickied;

  /// Whether the post is marked as NSFW.
  final bool isNsfw;

  /// The author's flair text (if any).
  final String? authorFlairText;

  /// The parsed richtext of the author's flair (if any).
  final List<FlairItem>? authorFlairRichtext;

  /// The post's flair text (if any).
  final String? linkFlairText;

  /// The parsed richtext of the post's flair (if any).
  final List<FlairItem>? linkFlairRichtext;

  /// The number of awards received.
  final int totalAwardsReceived;

  /// Whether the user has saved this post.
  final bool isSaved;

  List<Object?> get props => [
    id,
    title,
    author,
    subreddit,
    ups,
    numComments,
    createdUtc,
    thumbnail,
    url,
    permalink,
    content,
    images,
    isVideo,
    videoUrl,
    isYoutube,
    youtubeId,
    aspectRatio,
    crosspostParent,
    isNsfw,
    isStickied,
    authorFlairText,
    linkFlairText,
    totalAwardsReceived,
    isSaved,
  ];

  /// Returns a copy of this post with the specified fields replaced.
  Post copyWith({
    String? id,
    String? title,
    String? author,
    String? subreddit,
    int? ups,
    int? numComments,
    String? permalink,
    String? content,
    double? createdUtc,
    String? thumbnail,
    String? imageUrl,
    List<String>? images,
    String? url,
    bool? isVideo,
    String? videoUrl,
    bool? isYoutube,
    String? youtubeId,
    double? aspectRatio,
    Post? crosspostParent,
    String? authorFlairText,
    List<FlairItem>? authorFlairRichtext,
    String? linkFlairText,
    List<FlairItem>? linkFlairRichtext,
    int? totalAwardsReceived,
    bool? isSaved,
    bool? isNsfw,
    bool? isStickied,
  }) {
    return Post(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      subreddit: subreddit ?? this.subreddit,
      ups: ups ?? this.ups,
      numComments: numComments ?? this.numComments,
      permalink: permalink ?? this.permalink,
      content: content ?? this.content,
      createdUtc: createdUtc ?? this.createdUtc,
      thumbnail: thumbnail ?? this.thumbnail,
      imageUrl: imageUrl ?? this.imageUrl,
      images: images ?? this.images,
      url: url ?? this.url,
      isVideo: isVideo ?? this.isVideo,
      videoUrl: videoUrl ?? this.videoUrl,
      isYoutube: isYoutube ?? this.isYoutube,
      youtubeId: youtubeId ?? this.youtubeId,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      crosspostParent: crosspostParent ?? this.crosspostParent,
      authorFlairText: authorFlairText ?? this.authorFlairText,
      authorFlairRichtext: authorFlairRichtext ?? this.authorFlairRichtext,
      linkFlairText: linkFlairText ?? this.linkFlairText,
      linkFlairRichtext: linkFlairRichtext ?? this.linkFlairRichtext,
      totalAwardsReceived: totalAwardsReceived ?? this.totalAwardsReceived,
      isSaved: isSaved ?? this.isSaved,
      isNsfw: isNsfw ?? this.isNsfw,
      isStickied: isStickied ?? this.isStickied,
    );
  }
}
