/// A data model representing a Reddit post.
class Post {
  Post({
    required this.id,
    required this.title,
    required this.author,
    required this.subreddit,
    required this.ups,
    required this.numComments,
    this.thumbnail,
    this.imageUrl,
    required this.permalink,
    required this.content,
    required this.createdUtc,
    this.images = const [],
    this.isVideo = false,
    this.videoUrl,
    this.isYoutube = false,
    this.youtubeId,
    this.aspectRatio,
  });

  /// The unique ID of the post (e.g., "t3_12345").
  final String id;

  /// The title of the post.
  final String title;

  /// The username of the author (without "u/").
  final String author;

  /// The subreddit name (without "r/").
  final String subreddit;

  /// The number of upvotes.
  final int ups;

  /// The URL of the thumbnail image, if available.
  final String? thumbnail;

  /// The URL of the main image, if available.
  final String? imageUrl;

  /// The permalink path to the post (e.g., "/r/flutter/comments/...").
  final String permalink;

  /// The number of comments.
  final int numComments;

  /// The textual content of the post (selftext).
  final String content;

  /// The creation time in UTC seconds.
  final double createdUtc;

  /// A list of image URLs for gallery posts.
  final List<String> images;

  /// Whether the post contains a video.
  final bool isVideo;

  /// The URL of the video, if available.
  final String? videoUrl;

  /// Whether the post is a YouTube video.
  final bool isYoutube;

  /// The YouTube video ID, if available.
  final String? youtubeId;

  final double? aspectRatio;
}
