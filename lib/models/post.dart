import 'package:draw/draw.dart' as sys;
import '../utils/html_utils.dart';

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

  /// Whether the post contains a video.
  final bool isVideo;

  /// The URL of the video, if available.
  final String? videoUrl;

  /// Whether the post is a YouTube video.
  final bool isYoutube;

  /// The YouTube video ID, if available.
  final String? youtubeId;

  /// The aspect ratio of the main image/video (width / height).
  final double? aspectRatio;

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

  factory Post.fromSubmission(sys.Submission submission) {
    String? imageUrl;
    final List<String> images = [];
    bool isVideo = submission.isVideo;
    String? videoUrl;
    bool isYoutube = false;
    String? youtubeId;
    double? aspectRatio;

    // Attempt to find the main image URL
    final preview = submission.preview;
    if (preview.isNotEmpty) {
      final image = preview[0].source;
      imageUrl = HtmlUtils.unescape(image.url.toString());
      if (image.width > 0 && image.height > 0) {
        aspectRatio = image.width / image.height;
      }
    }

    // Check for direct URL if it's an image
    // If imageUrl creates a static preview but url is a gif, prefer the gif!
    final String url = submission.url.toString();
    if (!isVideo) {
      if (url.endsWith('.gif')) {
        imageUrl = url; // Force use the GIF url
      } else if (imageUrl == null) {
        if (url.endsWith('.jpg') ||
            url.endsWith('.jpeg') ||
            url.endsWith('.png')) {
          imageUrl = url;
        }
      }
    }

    if (submission.data != null) {
      final data = submission.data!.cast<String, dynamic>();
      final galleryRatio = _parseGalleryData(data, images);
      if (aspectRatio == null && galleryRatio != null) {
        aspectRatio = galleryRatio;
      }

      // 1. Try extracting from main post data
      videoUrl = _extractVideoUrl(data);

      // If no video found yet, check for MP4 variant in preview (common for GIFs)
      if (videoUrl == null &&
          data['preview'] != null &&
          data['preview']['images'] != null &&
          (data['preview']['images'] as List).isNotEmpty) {
        final imageMap = data['preview']['images'][0] as Map;
        if (imageMap['variants'] != null &&
            imageMap['variants']['mp4'] != null) {
          final mp4Variant = imageMap['variants']['mp4'];
          if (mp4Variant['source'] != null &&
              mp4Variant['source']['url'] != null) {
            videoUrl = HtmlUtils.unescape(
              mp4Variant['source']['url'] as String,
            );
            isVideo = true;
          }
        }
      }

      // 2. If no video found, check if it's a crosspost
      if (data['crosspost_parent_list'] != null) {
        final List crossposts = data['crosspost_parent_list'];
        if (crossposts.isNotEmpty) {
          final parentData = crossposts[0] as Map;

          // Try to get video from parent
          videoUrl ??= _extractVideoUrl(parentData);

          if (videoUrl != null) {
            isVideo = true;
          }

          // If still no video, check parent for MP4 variant in preview
          if (videoUrl == null &&
              parentData['preview'] != null &&
              parentData['preview']['images'] != null &&
              (parentData['preview']['images'] as List).isNotEmpty) {
            final imageMap = parentData['preview']['images'][0] as Map;
            if (imageMap['variants'] != null &&
                imageMap['variants']['mp4'] != null) {
              final mp4Variant = imageMap['variants']['mp4'];
              if (mp4Variant['source'] != null &&
                  mp4Variant['source']['url'] != null) {
                videoUrl = HtmlUtils.unescape(
                  mp4Variant['source']['url'] as String,
                );
                isVideo = true;
              }
            }
          }

          // Try to extract images/gallery from parent if main post has none
          if (images.isEmpty && imageUrl == null) {
            final parentGalleryRatio = _parseGalleryData(
              parentData.cast<String, dynamic>(),
              images,
            );
            if (aspectRatio == null && parentGalleryRatio != null) {
              aspectRatio = parentGalleryRatio;
            }

            // Check parent URL for direct image
            if (parentData['url'] != null) {
              final String pUrl = parentData['url'].toString();
              if (pUrl.endsWith('.jpg') ||
                  pUrl.endsWith('.jpeg') ||
                  pUrl.endsWith('.png') ||
                  pUrl.endsWith('.gif')) {
                imageUrl = pUrl;
                // If checking parent URL, we should also check if it's a GIF
                // But generally if it's a GIF repost, we handled it as video via preview above
                // or we fall back to imageUrl here.
              }
            }

            // Check parent preview if still no image
            if (imageUrl == null &&
                parentData['preview'] != null &&
                parentData['preview']['images'] != null &&
                (parentData['preview']['images'] as List).isNotEmpty) {
              final imageMap = parentData['preview']['images'][0] as Map;
              if (imageMap['source'] != null &&
                  imageMap['source']['url'] != null) {
                imageUrl = HtmlUtils.unescape(
                  imageMap['source']['url'] as String,
                );
                final width = imageMap['source']['width'];
                final height = imageMap['source']['height'];
                if (width != null &&
                    height != null &&
                    width > 0 &&
                    height > 0) {
                  aspectRatio = width / height;
                }
              }
            }
          }
        }
      }

      if (videoUrl != null) {
        isVideo = true;
      }

      // Check for YouTube in main data
      if (!isVideo) {
        youtubeId = _extractYoutubeId(data);
        if (youtubeId != null) {
          isYoutube = true;
        } else if (data['crosspost_parent_list'] != null) {
          // Check for YouTube in crosspost parent
          final List crossposts = data['crosspost_parent_list'];
          if (crossposts.isNotEmpty) {
            final parentData = crossposts[0] as Map;
            youtubeId = _extractYoutubeId(parentData);
            if (youtubeId != null) {
              isYoutube = true;
            }
          }
        }
      }
    }

    if (images.isEmpty && imageUrl != null) {
      images.add(imageUrl);
    }

    // Extract image URLs from selftext content
    // This handles posts where high-res images are embedded in the text
    final String selftext = submission.selftext ?? '';
    if (selftext.isNotEmpty) {
      final imageUrlRegex = RegExp(
        r'https?://[^\s\)]+\.(?:jpg|jpeg|png|gif|webp)(?:\?[^\s\)]*)?',
        caseSensitive: false,
      );
      // Also match Reddit preview URLs that may not have file extensions
      final redditPreviewRegex = RegExp(
        r'https?://preview\.redd\.it/[^\s\)]+',
        caseSensitive: false,
      );

      for (final match in imageUrlRegex.allMatches(selftext)) {
        // HTML-unescape the URL so it matches the content after HtmlUtils.unescape()
        final url = HtmlUtils.unescape(match.group(0)!);
        if (!images.contains(url)) {
          images.add(url);
        }
      }
      for (final match in redditPreviewRegex.allMatches(selftext)) {
        // HTML-unescape the URL so it matches the content after HtmlUtils.unescape()
        final url = HtmlUtils.unescape(match.group(0)!);
        if (!images.contains(url)) {
          images.add(url);
        }
      }
    }

    // Only use thumbnail if no high-resolution images are available
    final String? thumbnailUrl =
        images.isEmpty && submission.thumbnail.toString().startsWith('http')
        ? submission.thumbnail.toString()
        : null;

    return Post(
      id: submission.id ?? '',
      title: submission.title,
      author: submission.author,
      subreddit: submission.subreddit.displayName,
      ups: submission.upvotes,
      numComments: submission.numComments,
      thumbnail: thumbnailUrl,
      imageUrl: imageUrl,
      permalink: submission.data!['permalink'] ?? '',
      content: submission.selftext ?? '',
      createdUtc: submission.createdUtc.millisecondsSinceEpoch / 1000,
      images: images,
      isVideo: isVideo && videoUrl != null,
      videoUrl: videoUrl,
      isYoutube: isYoutube,
      youtubeId: youtubeId,
      aspectRatio: aspectRatio,
    );
  }

  static double? _parseGalleryData(
    Map<String, dynamic> data,
    List<String> images,
  ) {
    double? firstAspectRatio;
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
                final url = HtmlUtils.unescape(mediaItem['s']['u'] as String);
                images.add(url);

                if (firstAspectRatio == null) {
                  final x = mediaItem['s']['x'];
                  final y = mediaItem['s']['y'];
                  if (x != null && y != null && x > 0 && y > 0) {
                    firstAspectRatio = x / y;
                  }
                }
              }
            }
          }
        }
      }
    }
    return firstAspectRatio;
  }

  static String? _extractVideoUrl(Map dataMap) {
    final data = dataMap.cast<String, dynamic>();
    String? url;
    if (data['secure_media'] != null &&
        data['secure_media']['reddit_video'] != null) {
      url =
          data['secure_media']['reddit_video']['hls_url'] ??
          data['secure_media']['reddit_video']['fallback_url'];
    } else if (data['media'] != null && data['media']['reddit_video'] != null) {
      url =
          data['media']['reddit_video']['hls_url'] ??
          data['media']['reddit_video']['fallback_url'];
    } else if (data['preview'] != null &&
        data['preview']['reddit_video_preview'] != null) {
      url =
          data['preview']['reddit_video_preview']['hls_url'] ??
          data['preview']['reddit_video_preview']['fallback_url'];
    } else if (data['url'] != null && data['url'].toString().endsWith('.mp4')) {
      url = data['url'];
    }
    return url != null ? HtmlUtils.unescape(url) : null;
  }

  static String? _extractYoutubeId(Map dataMap) {
    final data = dataMap.cast<String, dynamic>();
    if (data['domain'] == 'youtube.com' ||
        data['domain'] == 'youtu.be' ||
        data['domain'] == 'm.youtube.com' ||
        (data['url'] != null &&
            data['url'].toString().contains('youtube.com')) ||
        (data['url'] != null && data['url'].toString().contains('youtu.be'))) {
      final String url = HtmlUtils.unescape(data['url'].toString());
      final RegExp regExp = RegExp(
        r'^.*((youtu.be\/)|(v\/)|(\/u\/\w\/)|(embed\/)|(watch\?)|(shorts\/)|(live\/))\??v?=?([^#&?]*).*',
        caseSensitive: false,
      );
      final match = regExp.firstMatch(url);
      if (match != null && match.group(9) != null) {
        final id = match.group(9);
        if (id != null && id.length == 11) {
          return id;
        }
      }
    }
    return null;
  }
}
