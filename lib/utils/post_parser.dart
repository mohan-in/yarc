import 'package:draw/draw.dart' as sys;
import 'package:yarc/models/post.dart';
import 'package:yarc/utils/html_utils.dart';

/// Utility class for parsing Reddit submissions into Post models.
class PostParser {
  static final _imageUrlRegex = RegExp(
    r'https?://[^\s\)]+\.(?:jpg|jpeg|png|gif|webp)(?:\?[^\s\)]*)?',
    caseSensitive: false,
  );

  static final _redditPreviewRegex = RegExp(
    r'https?://preview\.redd\.it/[^\s\)]+',
    caseSensitive: false,
  );

  static final _youtubeRegex = RegExp(
    r'^.*((youtu.be\/)|(v\/)|'
    r'(\/u\/\w\/)|(embed\/)|'
    r'(watch\?)|(shorts\/)|(live\/))'
    r'\??v?=?([^#&?]*).*',
    caseSensitive: false,
  );

  /// Parses a DRAW Submission object into a Post model.
  static Post parse(sys.Submission submission) {
    String? imageUrl;
    final images = <String>[];
    var isVideo = submission.isVideo;
    String? videoUrl;
    var isYoutube = false;
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
    // If imageUrl creates a static preview but url is a gif,
    // prefer the gif!
    final url = submission.url.toString();
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

      // If no video found yet, check for MP4 variant
      // in preview (common for GIFs)
      if (videoUrl == null) {
        videoUrl = _extractMp4FromPreview(data);
        if (videoUrl != null) isVideo = true;
      }

      // 2. If no video found, check crosspost
      if (data['crosspost_parent_list'] != null) {
        final crossposts = data['crosspost_parent_list'] as List<dynamic>;
        if (crossposts.isNotEmpty) {
          final parentData = (crossposts[0] as Map<dynamic, dynamic>)
              .cast<String, dynamic>();

          // Try to get video from parent
          videoUrl ??= _extractVideoUrl(parentData);

          if (videoUrl != null) {
            isVideo = true;
          }

          // Check parent for MP4 variant in preview
          if (videoUrl == null) {
            videoUrl = _extractMp4FromPreview(parentData);
            if (videoUrl != null) isVideo = true;
          }

          // Try to extract images/gallery from parent
          if (images.isEmpty && imageUrl == null) {
            final parentGalleryRatio = _parseGalleryData(parentData, images);
            if (aspectRatio == null && parentGalleryRatio != null) {
              aspectRatio = parentGalleryRatio;
            }

            // Check parent URL for direct image
            if (parentData['url'] != null) {
              final pUrl = parentData['url'].toString();
              if (pUrl.endsWith('.jpg') ||
                  pUrl.endsWith('.jpeg') ||
                  pUrl.endsWith('.png') ||
                  pUrl.endsWith('.gif')) {
                imageUrl = pUrl;
              }
            }

            // Check parent preview if still no image
            if (imageUrl == null) {
              final result = _extractImageFromPreview(
                parentData,
              );
              if (result != null) {
                imageUrl = result.url;
                aspectRatio ??= result.aspectRatio;
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
          final crossposts = data['crosspost_parent_list'] as List<dynamic>;
          if (crossposts.isNotEmpty) {
            final parentData = (crossposts[0] as Map<dynamic, dynamic>)
                .cast<String, dynamic>();
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
    final selftext = submission.selftext ?? '';
    if (selftext.isNotEmpty) {
      for (final match in _imageUrlRegex.allMatches(selftext)) {
        final matchUrl = HtmlUtils.unescape(match.group(0)!);
        if (!images.contains(matchUrl)) {
          images.add(matchUrl);
        }
      }
      for (final match in _redditPreviewRegex.allMatches(selftext)) {
        final matchUrl = HtmlUtils.unescape(match.group(0)!);
        if (!images.contains(matchUrl)) {
          images.add(matchUrl);
        }
      }
    }

    // Only use thumbnail if no high-res images
    final thumbnailUrl =
        images.isEmpty && submission.thumbnail.toString().startsWith('http')
        ? submission.thumbnail.toString()
        : null;

    return Post(
      id: submission.id ?? '',
      title: HtmlUtils.unescape(submission.title),
      author: submission.author,
      subreddit: submission.subreddit.displayName,
      ups: submission.upvotes,
      numComments: submission.numComments,
      thumbnail: thumbnailUrl,
      imageUrl: imageUrl,
      permalink: (submission.data!['permalink'] as String?) ?? '',
      content: submission.selftext != null
          ? HtmlUtils.unescape(submission.selftext!)
          : '',
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
      final galleryData = data['gallery_data'] as Map<String, dynamic>;
      final metadata = data['media_metadata'] as Map<String, dynamic>;
      if (galleryData['items'] != null) {
        final items = galleryData['items'] as List<dynamic>;
        for (final item in items) {
          final itemMap = item as Map<String, dynamic>;
          final mediaId = itemMap['media_id'] as String?;
          if (mediaId != null && metadata[mediaId] != null) {
            final mediaItem = metadata[mediaId] as Map<String, dynamic>;
            if (mediaItem['status'] == 'valid' && mediaItem['e'] == 'Image') {
              final s = mediaItem['s'] as Map<String, dynamic>?;
              if (s != null && s['u'] != null) {
                final url = HtmlUtils.unescape(
                  s['u'] as String,
                );
                images.add(url);

                if (firstAspectRatio == null) {
                  final x = s['x'] as int?;
                  final y = s['y'] as int?;
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

  /// Extracts MP4 variant URL from preview data.
  static String? _extractMp4FromPreview(
    Map<String, dynamic> data,
  ) {
    if (data['preview'] == null) return null;
    final preview = data['preview'] as Map<String, dynamic>;
    if (preview['images'] == null) return null;
    final imagesList = preview['images'] as List<dynamic>;
    if (imagesList.isEmpty) return null;
    final imageMap = imagesList[0] as Map<String, dynamic>;
    if (imageMap['variants'] == null) return null;
    final variants = imageMap['variants'] as Map<String, dynamic>;
    if (variants['mp4'] == null) return null;
    final mp4Variant = variants['mp4'] as Map<String, dynamic>;
    if (mp4Variant['source'] == null) return null;
    final source = mp4Variant['source'] as Map<String, dynamic>;
    if (source['url'] == null) return null;
    return HtmlUtils.unescape(source['url'] as String);
  }

  /// Extracts image URL and aspect ratio from preview.
  static ({String url, double? aspectRatio})? _extractImageFromPreview(
    Map<String, dynamic> data,
  ) {
    if (data['preview'] == null) return null;
    final preview = data['preview'] as Map<String, dynamic>;
    if (preview['images'] == null) return null;
    final imagesList = preview['images'] as List<dynamic>;
    if (imagesList.isEmpty) return null;
    final imageMap = imagesList[0] as Map<String, dynamic>;
    if (imageMap['source'] == null) return null;
    final source = imageMap['source'] as Map<String, dynamic>;
    if (source['url'] == null) return null;
    final url = HtmlUtils.unescape(source['url'] as String);
    double? ratio;
    final width = source['width'] as int?;
    final height = source['height'] as int?;
    if (width != null && height != null && width > 0 && height > 0) {
      ratio = width / height;
    }
    return (url: url, aspectRatio: ratio);
  }

  static String? _extractVideoUrl(
    Map<String, dynamic> data,
  ) {
    String? url;
    if (data['secure_media'] != null) {
      final secureMedia = data['secure_media'] as Map<String, dynamic>;
      if (secureMedia['reddit_video'] != null) {
        final video = secureMedia['reddit_video'] as Map<String, dynamic>;
        url =
            (video['hls_url'] as String?) ?? (video['fallback_url'] as String?);
      }
    }
    if (url == null && data['media'] != null) {
      final media = data['media'] as Map<String, dynamic>;
      if (media['reddit_video'] != null) {
        final video = media['reddit_video'] as Map<String, dynamic>;
        url =
            (video['hls_url'] as String?) ?? (video['fallback_url'] as String?);
      }
    }
    if (url == null && data['preview'] != null) {
      final preview = data['preview'] as Map<String, dynamic>;
      if (preview['reddit_video_preview'] != null) {
        final video = preview['reddit_video_preview'] as Map<String, dynamic>;
        url =
            (video['hls_url'] as String?) ?? (video['fallback_url'] as String?);
      }
    }
    if (url == null &&
        data['url'] != null &&
        data['url'].toString().endsWith('.mp4')) {
      url = data['url'] as String?;
    }
    return url != null ? HtmlUtils.unescape(url) : null;
  }

  static String? _extractYoutubeId(
    Map<String, dynamic> data,
  ) {
    if (data['domain'] == 'youtube.com' ||
        data['domain'] == 'youtu.be' ||
        data['domain'] == 'm.youtube.com' ||
        (data['url'] != null &&
            data['url'].toString().contains('youtube.com')) ||
        (data['url'] != null && data['url'].toString().contains('youtu.be'))) {
      final url = HtmlUtils.unescape(data['url'].toString());
      final match = _youtubeRegex.firstMatch(url);
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
