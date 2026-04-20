import 'package:draw/draw.dart' as draw;
import 'package:yarc/models/post.dart';
import 'package:yarc/utils/html_utils.dart';
import 'package:yarc/utils/parsers/content_sanitizer.dart';
import 'package:yarc/utils/parsers/crosspost_parser.dart';
import 'package:yarc/utils/parsers/flair_parser.dart';
import 'package:yarc/utils/parsers/gallery_parser.dart';
import 'package:yarc/utils/parsers/media_extractor.dart';

/// Matches URLs that point to direct media files we render inline.
final _directMediaUrlRegex = RegExp(
  r'\.(?:jpg|jpeg|png|gif|webp|mp4)(?:\?.*)?$',
  caseSensitive: false,
);

/// Matches Reddit-hosted media domains (galleries, videos, images).
/// Also includes Giphy domains so we don't show a redundant link chip
/// when the GIF is already rendered via Reddit's preview image.
final _redditMediaDomainRegex = RegExp(
  r'(?:i\.redd\.it|v\.redd\.it|preview\.redd\.it|reddit\.com/gallery'
  r'|(?:media|i)\.giphy\.com|giphy\.com/gifs)',
  caseSensitive: false,
);

/// Converts a DRAW [draw.Submission] into a [Post] model.
///
/// All parsing sub-tasks are delegated to focused helpers in
/// `lib/utils/parsers/`:
///
/// - [MediaExtractor]   — video, image-from-preview, youtube
/// - [GalleryParser]    — gallery_data + media_metadata
/// - [CrosspostParser]  — crosspost parent reconstruction
/// - [FlairParser]      — flair richtext + text cleaning
/// - [ContentSanitizer] — selftext image extraction + sanitization
class PostParser {
  /// Parses [submission] into a [Post].
  static Post parse(draw.Submission submission) {
    String? imageUrl;
    final images = <String>[];
    var isVideo = submission.isVideo;
    String? videoUrl;
    var isYoutube = false;
    String? youtubeId;
    double? aspectRatio;
    final isStickied = submission.data?['stickied'] as bool? ?? false;

    // Extract image from preview (manual data access to avoid DRAW
    // dropping previews)
    if (submission.data != null) {
      final data = submission.data!.cast<String, dynamic>();
      final previewResult = MediaExtractor.extractImageFromPreview(data);
      if (previewResult != null) {
        final urlStr = previewResult.url;
        // Reddit sometimes gives a .gif extension but adds format=mp4
        // — it's a video
        if (urlStr.contains('format=mp4')) {
          videoUrl = urlStr;
          isVideo = true;
        } else {
          imageUrl = urlStr;
          aspectRatio = previewResult.aspectRatio;
        }
      }
    }

    // Prefer animated GIF URL over a static preview
    final url = submission.url.toString();
    if (!isVideo) {
      imageUrl = MediaExtractor.resolveDirectImageUrl(url, imageUrl);
    }

    if (submission.data != null) {
      final data = submission.data!.cast<String, dynamic>();

      // Gallery images
      final galleryRatio = GalleryParser.parse(data, images);
      aspectRatio ??= galleryRatio;

      // Video URL from main post
      final videoResult = MediaExtractor.resolveVideoUrl(data);
      videoUrl = videoResult.url;
      if (videoResult.isVideo) {
        isVideo = true;
      }

      // Crosspost media fallback
      if (data['crosspost_parent_list'] != null) {
        final crosspostResult = CrosspostParser.parseMedia(
          data['crosspost_parent_list'] as List<dynamic>,
          images: images,
          imageUrl: imageUrl,
          videoUrl: videoUrl,
          aspectRatio: aspectRatio,
        );
        videoUrl ??= crosspostResult.videoUrl;
        if (crosspostResult.isVideo) {
          isVideo = true;
        }
        imageUrl = crosspostResult.imageUrl ?? imageUrl;
        aspectRatio = crosspostResult.aspectRatio ?? aspectRatio;
      }

      if (videoUrl != null) {
        isVideo = true;
      }

      // YouTube check (main post, then crosspost parent)
      if (!isVideo) {
        youtubeId = MediaExtractor.extractYoutubeId(data);
        if (youtubeId == null && data['crosspost_parent_list'] != null) {
          final crossposts = data['crosspost_parent_list'] as List<dynamic>;
          if (crossposts.isNotEmpty) {
            final parentData = (crossposts[0] as Map<dynamic, dynamic>)
                .cast<String, dynamic>();
            youtubeId = MediaExtractor.extractYoutubeId(parentData);
          }
        }
        if (youtubeId != null) {
          isYoutube = true;
        }
      }
    }

    if (images.isEmpty && imageUrl != null) {
      images.add(imageUrl);
    }

    ContentSanitizer.extractSelftextImages(submission.selftext, images);

    final thumbnailUrl =
        images.isEmpty && submission.thumbnail.toString().startsWith('http')
        ? submission.thumbnail.toString()
        : null;

    // Only show an external link chip for non-self posts that aren't already
    // rendered as inline media.
    String? externalUrl;
    if (!submission.isSelf) {
      final postUrl = submission.url.toString();
      final isMediaUrl =
          isVideo ||
          _directMediaUrlRegex.hasMatch(postUrl) ||
          _redditMediaDomainRegex.hasMatch(postUrl) ||
          isYoutube;
      if (!isMediaUrl && postUrl.isNotEmpty) {
        externalUrl = postUrl;
      }
    }

    Post? crosspostParent;
    if (submission.data != null) {
      crosspostParent = CrosspostParser.parseParent(
        submission.data!.cast<String, dynamic>(),
      );
    }

    final rawAuthorFlair = submission.data?['author_flair_text'] as String?;
    final rawLinkFlair = submission.data?['link_flair_text'] as String?;

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
      content: ContentSanitizer.sanitize(
        submission.selftext != null
            ? HtmlUtils.resolveGiphyShortcodes(
                HtmlUtils.unescape(submission.selftext!),
              )
            : '',
        images,
        thumbnailUrl,
      ),
      createdUtc: submission.createdUtc.millisecondsSinceEpoch / 1000,
      images: images,
      isVideo: isVideo && videoUrl != null,
      videoUrl: videoUrl,
      isYoutube: isYoutube,
      youtubeId: youtubeId,
      aspectRatio: aspectRatio,
      url: crosspostParent != null ? null : externalUrl,
      crosspostParent: crosspostParent,
      authorFlairText: rawAuthorFlair != null
          ? FlairParser.cleanText(HtmlUtils.unescape(rawAuthorFlair))
          : null,
      authorFlairRichtext: FlairParser.parseRichtext(
        submission.data?['author_flair_richtext'] as List<dynamic>?,
      ),
      linkFlairText: rawLinkFlair != null
          ? FlairParser.cleanText(HtmlUtils.unescape(rawLinkFlair))
          : null,
      linkFlairRichtext: FlairParser.parseRichtext(
        submission.data?['link_flair_richtext'] as List<dynamic>?,
      ),
      totalAwardsReceived:
          submission.data?['total_awards_received'] as int? ?? 0,
      isSaved: submission.saved,
      isNsfw: submission.over18,
      isStickied: isStickied,
    );
  }
}
