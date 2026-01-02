import 'package:draw/draw.dart' as sys;

/// A data model representing a Reddit post.
class Post {
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
  });

  factory Post.fromSubmission(sys.Submission submission) {
    String? imageUrl;
    List<String> images = [];

    // Attempt to find the main image URL
    final preview = submission.preview;
    if (preview.isNotEmpty) {
      final image = preview[0].source;
      imageUrl = image.url.toString().replaceAll('&amp;', '&');
    }

    // Check for direct URL if it's an image
    if (imageUrl == null) {
      final String url = submission.url.toString();
      if (url.endsWith('.jpg') ||
          url.endsWith('.jpeg') ||
          url.endsWith('.png') ||
          url.endsWith('.gif')) {
        imageUrl = url;
      }
    }

    // Gallery handling might be more complex with draw, checking mostly for media_metadata
    // draw might not expose raw json easily for everything, but we can try accessing data property if needed.
    // submission.data matches the raw map.
    if (submission.data != null) {
      final data = submission.data!;
      if (data['gallery_data'] != null && data['media_metadata'] != null) {
        final galleryData = data['gallery_data'];
        final metadata = data['media_metadata'];
        if (galleryData['items'] != null) {
          for (final item in galleryData['items']) {
            final mediaId = item['media_id'];
            if (metadata[mediaId] != null) {
              final mediaItem = metadata[mediaId];
              if (mediaItem['status'] == 'valid' && mediaItem['e'] == 'Image') {
                if (mediaItem['s'] != null && mediaItem['s']['u'] != null) {
                  String url = (mediaItem['s']['u'] as String).replaceAll(
                    '&amp;',
                    '&',
                  );
                  images.add(url);
                }
              }
            }
          }
        }
      }
    }

    if (images.isEmpty && imageUrl != null) {
      images.add(imageUrl);
    }

    return Post(
      id: submission.id ?? '',
      title: submission.title,
      author: submission.author,
      subreddit: submission.subreddit.displayName,
      ups: submission.upvotes,
      numComments: submission.numComments,
      thumbnail: submission.thumbnail.toString().startsWith('http')
          ? submission.thumbnail.toString()
          : null,
      imageUrl: imageUrl,
      permalink: submission.data!['permalink'] ?? '',
      content: submission.selftext ?? '',
      createdUtc: submission.createdUtc.millisecondsSinceEpoch / 1000,
      images: images,
    );
  }
}
