import 'package:yarc/models/post.dart';
import 'package:yarc/utils/html_utils.dart';
import 'package:yarc/utils/parsers/content_sanitizer.dart';
import 'package:yarc/utils/parsers/gallery_parser.dart';
import 'package:yarc/utils/parsers/media_extractor.dart';

/// Helpers for parsing a crosspost parent into a lightweight [Post].
abstract final class CrosspostParser {
  /// Parses media from a crosspost's parent data list.
  ///
  /// Populates [images] in place and returns video URL, video flag, image URL,
  /// and aspect ratio found in the parent.
  static ({
    String? videoUrl,
    bool isVideo,
    String? imageUrl,
    double? aspectRatio,
  })
  parseMedia(
    List<dynamic> crossposts, {
    required List<String> images,
    required String? imageUrl,
    required String? videoUrl,
    required double? aspectRatio,
  }) {
    if (crossposts.isEmpty) {
      return (
        videoUrl: null,
        isVideo: false,
        imageUrl: null,
        aspectRatio: null,
      );
    }

    final parentData = (crossposts[0] as Map<dynamic, dynamic>)
        .cast<String, dynamic>();

    // Try video from parent
    var resolvedVideoUrl = videoUrl;
    var isVideo = false;
    if (resolvedVideoUrl == null) {
      resolvedVideoUrl = MediaExtractor.extractVideoUrl(parentData);
      if (resolvedVideoUrl != null) {
        isVideo = true;
      }
    }
    if (resolvedVideoUrl == null) {
      resolvedVideoUrl = MediaExtractor.extractMp4FromPreview(parentData);
      if (resolvedVideoUrl != null) {
        isVideo = true;
      }
    }

    String? resolvedImageUrl;
    double? resolvedAspectRatio;

    // Gallery is the source of truth for images
    final parentGalleryRatio = GalleryParser.parse(parentData, images);
    if (parentGalleryRatio != null) {
      resolvedAspectRatio = parentGalleryRatio;
    }

    // Also pull images from the parent's selftext markdown
    if (parentData['selftext'] != null) {
      ContentSanitizer.extractSelftextImages(
        parentData['selftext'] as String,
        images,
      );
    }

    // Fall back to single image from URL or preview
    if (images.isEmpty) {
      if (parentData['url'] != null) {
        final pUrl = parentData['url'].toString();
        if (pUrl.endsWith('.jpg') ||
            pUrl.endsWith('.jpeg') ||
            pUrl.endsWith('.png') ||
            pUrl.endsWith('.gif')) {
          resolvedImageUrl = pUrl;
        }
      }
      if (resolvedImageUrl == null) {
        final result = MediaExtractor.extractImageFromPreview(parentData);
        if (result != null) {
          resolvedImageUrl = result.url;
          resolvedAspectRatio ??= result.aspectRatio;
        }
      }
    }

    return (
      videoUrl: resolvedVideoUrl != videoUrl ? resolvedVideoUrl : null,
      isVideo: isVideo,
      imageUrl: resolvedImageUrl,
      aspectRatio: resolvedAspectRatio,
    );
  }

  /// Builds a lightweight [Post] from the first crosspost parent in [data].
  /// Returns `null` if [data] has no `crosspost_parent_list`.
  static Post? parseParent(Map<String, dynamic> data) {
    if (data['crosspost_parent_list'] == null) {
      return null;
    }
    final crossposts = data['crosspost_parent_list'] as List<dynamic>;
    if (crossposts.isEmpty) {
      return null;
    }
    final parent = (crossposts[0] as Map<dynamic, dynamic>)
        .cast<String, dynamic>();

    final selftext = parent['selftext'] as String? ?? '';
    final title = parent['title'] as String? ?? '';
    final author = parent['author'] as String? ?? '';
    final subreddit = parent['subreddit'] as String? ?? '';
    final permalink = parent['permalink'] as String? ?? '';
    final ups = parent['ups'] as int? ?? 0;
    final numComments = parent['num_comments'] as int? ?? 0;
    final createdUtcRaw = (parent['created_utc'] as num?)?.toDouble() ?? 0;
    final createdUtc = DateTime.fromMillisecondsSinceEpoch(
      (createdUtcRaw * 1000).toInt(),
      isUtc: true,
    );
    final isSelf = parent['is_self'] as bool? ?? true;
    final parentUrl = parent['url'] as String?;

    final crosspostImages = <String>[];
    final mediaInfo = parseMedia(
      crossposts,
      images: crosspostImages,
      imageUrl: null,
      videoUrl: null,
      aspectRatio: null,
    );

    if (crosspostImages.isEmpty && mediaInfo.imageUrl != null) {
      crosspostImages.add(mediaInfo.imageUrl!);
    }

    String? externalUrl;
    if (!isSelf && parentUrl != null && parentUrl.isNotEmpty) {
      externalUrl = parentUrl;
    }

    return Post(
      id: parent['id'] as String? ?? '',
      title: HtmlUtils.unescape(title),
      author: author,
      subreddit: subreddit,
      ups: ups,
      numComments: numComments,
      permalink: permalink,
      content: ContentSanitizer.sanitize(
        HtmlUtils.unescape(selftext),
        crosspostImages,
        null,
      ),
      createdUtc: createdUtc,
      images: crosspostImages,
      imageUrl: mediaInfo.imageUrl,
      isVideo: mediaInfo.isVideo,
      videoUrl: mediaInfo.videoUrl,
      aspectRatio: mediaInfo.aspectRatio,
      url: externalUrl,
    );
  }
}
