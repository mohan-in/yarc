import 'package:draw/draw.dart' as sys;
import 'package:yarc/models/post.dart';
import 'package:yarc/utils/html_utils.dart';

/// Utility class for parsing Reddit submissions into Post models.
class PostParser {
  /// Matches direct image URLs (jpg/jpeg/png/gif/webp) with optional query strings.
  static final _imageUrlRegex = RegExp(
    r'https?://[^\s\)]+\.(?:jpg|jpeg|png|gif|webp)(?:\?[^\s\)]*)?',
    caseSensitive: false,
  );

  /// Matches Reddit custom subreddit emoji shortcodes, e.g. `::pepewoah::` or
  /// `:z100_2:`.  These are moderator-uploaded images that have no Unicode
  /// equivalent, so we strip them and collapse the surrounding whitespace when
  /// richtext rendering is not desired or the string falls back.
  static final _redditEmojiShortcodeRegex = RegExp(
    r':[\w.\-]+:',
  );

  /// Matches both Reddit-native and external preview CDN URLs.
  static final _redditPreviewRegex = RegExp(
    r'https?://(?:external-)?preview\.redd\.it/[^\s\)]+',
    caseSensitive: false,
  );

  /// Matches URLs that point to direct media files we render inline.
  static final _directMediaUrlRegex = RegExp(
    r'\.(?:jpg|jpeg|png|gif|webp|mp4)(?:\?.*)?$',
    caseSensitive: false,
  );

  /// Matches Reddit-hosted media domains (galleries, videos, images).
  /// Also includes Giphy domains so we don't show a redundant link chip
  /// when the GIF is already rendered via Reddit's preview image.
  static final _redditMediaDomainRegex = RegExp(
    r'(?:i\.redd\.it|v\.redd\.it|preview\.redd\.it|reddit\.com/gallery'
    r'|(?:media|i)\.giphy\.com|giphy\.com/gifs)',
    caseSensitive: false,
  );

  /// Matches Giphy CDN URLs that serve the actual animated GIF, so we
  /// can use them in place of Reddit's static preview.
  static final _giphyMediaDomainRegex = RegExp(
    r'https?://(?:media|i)\.giphy\.com/',
    caseSensitive: false,
  );

  /// Matches markdown image syntax: `![alt](url)`
  static final _markdownImageRegex = RegExp(r'!\[[^\]]*\]\(([^)]+)\)');

  /// Matches 3+ consecutive newlines for collapsing whitespace.
  static final _excessiveNewlinesRegex = RegExp(r'\n{3,}');

  /// Matches YouTube video URLs across all common formats
  /// (watch, shorts, live, embed).
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
    final isStickied = submission.data?['stickied'] as bool? ?? false;

    // Attempt to find the main image URL from preview.
    // Instead of relying on DRAW's `submission.preview`, extract manually
    // from `submission.data` to ensure we don't miss previews that DRAW might
    // drop.
    if (submission.data != null) {
      final data = submission.data!.cast<String, dynamic>();
      final previewResult = _extractImageFromPreview(data);
      if (previewResult != null) {
        final urlStr = previewResult.url;
        // Reddit sometimes gives a .gif extension but adds format=mp4.
        // It is actually a video.
        if (urlStr.contains('format=mp4')) {
          videoUrl = urlStr;
          isVideo = true;
        } else {
          imageUrl = urlStr;
          aspectRatio = previewResult.aspectRatio;
        }
      }
    }

    // Prefer GIF URL over static preview
    final url = submission.url.toString();
    if (!isVideo) {
      imageUrl = _resolveDirectImageUrl(url, imageUrl);
    }

    if (submission.data != null) {
      final data = submission.data!.cast<String, dynamic>();

      // Extract gallery images
      final galleryRatio = _parseGalleryData(data, images);
      aspectRatio ??= galleryRatio;

      // Extract video URL from main post or preview
      final videoResult = _resolveVideoUrl(data);
      videoUrl = videoResult.url;
      if (videoResult.isVideo) {
        isVideo = true;
      }

      // Check crosspost parent for additional media
      if (data['crosspost_parent_list'] != null) {
        final crosspostResult = _parseCrosspostMedia(
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

      // Check for YouTube in main data, then crosspost
      if (!isVideo) {
        youtubeId = _extractYoutubeId(data);
        if (youtubeId == null && data['crosspost_parent_list'] != null) {
          final crossposts = data['crosspost_parent_list'] as List<dynamic>;
          if (crossposts.isNotEmpty) {
            final parentData = (crossposts[0] as Map<dynamic, dynamic>)
                .cast<String, dynamic>();
            youtubeId = _extractYoutubeId(parentData);
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

    // Extract image URLs from selftext content
    _extractSelftextImages(submission.selftext, images);

    // Only use thumbnail if no high-res images
    final thumbnailUrl =
        images.isEmpty && submission.thumbnail.toString().startsWith('http')
        ? submission.thumbnail.toString()
        : null;

    // Capture external link URL for non-self posts.
    // Only skip if the URL itself is a direct media file or Reddit/YouTube
    // media domain that we already render inline.
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

    // Parse crosspost parent for repost display
    Post? crosspostParent;
    if (submission.data != null) {
      final data = submission.data!.cast<String, dynamic>();
      crosspostParent = _parseCrosspostParent(data);
    }

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
      content: _sanitizeContent(
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
      authorFlairText: submission.data?['author_flair_text'] != null
          ? _cleanFlairText(
              HtmlUtils.unescape(
                submission.data!['author_flair_text'] as String,
              ),
            )
          : null,
      authorFlairRichtext: _parseFlairRichtext(
        submission.data?['author_flair_richtext'] as List<dynamic>?,
      ),
      linkFlairText: submission.data?['link_flair_text'] != null
          ? _cleanFlairText(
              HtmlUtils.unescape(
                submission.data!['link_flair_text'] as String,
              ),
            )
          : null,
      linkFlairRichtext: _parseFlairRichtext(
        submission.data?['link_flair_richtext'] as List<dynamic>?,
      ),
      totalAwardsReceived:
          submission.data?['total_awards_received'] as int? ?? 0,
      isSaved: submission.saved,
      isNsfw: submission.over18,
      isStickied: isStickied,
    );
  }

  /// Parses the first crosspost parent into a lightweight Post.
  static Post? _parseCrosspostParent(Map<String, dynamic> data) {
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
    final createdUtc = (parent['created_utc'] as num?)?.toDouble() ?? 0;
    final isSelf = parent['is_self'] as bool? ?? true;
    final parentUrl = parent['url'] as String?;

    // Extract images and media natively for the original post
    final crosspostImages = <String>[];
    final mediaInfo = _parseCrosspostMedia(
      crossposts,
      images: crosspostImages,
      imageUrl: null,
      videoUrl: null,
      aspectRatio: null,
    );

    // Make sure we add the resolved image URL if gallery was empty
    if (crosspostImages.isEmpty && mediaInfo.imageUrl != null) {
      crosspostImages.add(mediaInfo.imageUrl!);
    }

    // Determine external URL for link-type parent posts
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
      content: _sanitizeContent(
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

  /// Parses Reddit's flair richtext array into FlairItem models.
  static List<FlairItem>? _parseFlairRichtext(List<dynamic>? richtextFields) {
    if (richtextFields == null || richtextFields.isEmpty) return null;
    final items = <FlairItem>[];
    for (final field in richtextFields) {
      if (field is! Map) continue;
      final e = field['e'] as String?;
      if (e == 'emoji') {
        final url = field['u'] as String?;
        if (url != null) {
          items.add(
            FlairItem(isEmoji: true, emojiUrl: HtmlUtils.unescape(url)),
          );
        }
      } else if (e == 'text') {
        final text = field['t'] as String?;
        if (text != null && text.isNotEmpty) {
          items.add(FlairItem(isEmoji: false, text: HtmlUtils.unescape(text)));
        }
      }
    }
    return items.isEmpty ? null : items;
  }

  /// Strips Reddit custom emoji shortcodes (`:name:`) from flair text and
  /// collapses surrounding whitespace.  Returns `null` when the resulting
  /// string is empty so callers can use null-aware guards.
  static String? _cleanFlairText(String text) {
    final cleaned = text
        .replaceAll(_redditEmojiShortcodeRegex, ' ')
        .trim()
        .replaceAll(RegExp(' {2,}'), ' ');
    return cleaned.isEmpty ? null : cleaned;
  }

  /// Removes known media URLs and cleans up whitespace
  static String _sanitizeContent(
    String content,
    List<String> images,
    String? thumbnail,
  ) {
    if (content.isEmpty) return content;

    var sanitized = content;
    final mediaUrls = <String>{...images};
    if (thumbnail != null) {
      mediaUrls.add(thumbnail);
    }

    // Build a set of all URL variants for fast lookup
    final allVariants = <String>{};
    for (final url in mediaUrls) {
      allVariants
        ..add(url)
        ..add(url.replaceAll('&amp;', '&'))
        ..add(url.replaceAll('&', '&amp;'))
        ..add(Uri.encodeFull(url));
    }

    // Remove only markdown images whose src matches a known media URL
    sanitized = sanitized.replaceAllMapped(_markdownImageRegex, (match) {
      final src = match.group(1) ?? '';
      return allVariants.contains(src) ? '' : match.group(0)!;
    });

    // Remove bare media URLs from text
    for (final variant in allVariants) {
      sanitized = sanitized.replaceAll(variant, '');
    }

    return sanitized.replaceAll(_excessiveNewlinesRegex, '\n\n').trim();
  }

  /// Resolves the direct image URL, preferring GIF over static preview.
  /// Giphy CDN URLs ([media|i].giphy.com) serve animated GIFs, so they
  /// take precedence over a static Reddit preview.
  static String? _resolveDirectImageUrl(String url, String? currentImageUrl) {
    if (url.endsWith('.gif') || _giphyMediaDomainRegex.hasMatch(url)) {
      return url;
    }
    if (currentImageUrl == null) {
      if (url.endsWith('.jpg') ||
          url.endsWith('.jpeg') ||
          url.endsWith('.png')) {
        return url;
      }
    }
    return currentImageUrl;
  }

  /// Resolves video URL from main post data or preview.
  static ({String? url, bool isVideo}) _resolveVideoUrl(
    Map<String, dynamic> data,
  ) {
    var videoUrl = _extractVideoUrl(data);
    if (videoUrl != null) {
      return (url: videoUrl, isVideo: true);
    }
    videoUrl = _extractMp4FromPreview(data);
    if (videoUrl != null) {
      return (url: videoUrl, isVideo: true);
    }
    return (url: null, isVideo: false);
  }

  /// Parses media from crosspost parent data.
  static ({
    String? videoUrl,
    bool isVideo,
    String? imageUrl,
    double? aspectRatio,
  })
  _parseCrosspostMedia(
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
      resolvedVideoUrl = _extractVideoUrl(parentData);
      if (resolvedVideoUrl != null) {
        isVideo = true;
      }
    }
    if (resolvedVideoUrl == null) {
      resolvedVideoUrl = _extractMp4FromPreview(parentData);
      if (resolvedVideoUrl != null) {
        isVideo = true;
      }
    }

    String? resolvedImageUrl;
    double? resolvedAspectRatio;

    // Always check for gallery from parent, as it's the source of truth
    final parentGalleryRatio = _parseGalleryData(parentData, images);
    if (parentGalleryRatio != null) {
      resolvedAspectRatio = parentGalleryRatio;
    }

    // Also extract images embedded directly inside the parent's markdown text
    if (parentData['selftext'] != null) {
      _extractSelftextImages(parentData['selftext'] as String, images);
    }

    // Checking parent for single image/preview if we still have no gallery images
    if (images.isEmpty) {
      // Check parent URL for direct image
      if (parentData['url'] != null) {
        final pUrl = parentData['url'].toString();
        if (pUrl.endsWith('.jpg') ||
            pUrl.endsWith('.jpeg') ||
            pUrl.endsWith('.png') ||
            pUrl.endsWith('.gif')) {
          resolvedImageUrl = pUrl;
        }
      }

      // Check parent preview only when Reddit has enabled it for this post.
      if (resolvedImageUrl == null) {
        final result = _extractImageFromPreview(parentData);
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

  /// Extracts image URLs from selftext content.
  static void _extractSelftextImages(String? selftext, List<String> images) {
    if (selftext == null || selftext.isEmpty) {
      return;
    }
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

  /// Extracts image URL and aspect ratio from preview, but only when Reddit
  /// Extract image from post preview metadata.
  static ({String url, double? aspectRatio})? _extractImageFromPreview(
    Map<String, dynamic> data,
  ) {
    if (data['preview'] == null) return null;
    final preview = data['preview'] as Map<String, dynamic>;

    // Respect Reddit's own decision about whether to show this preview,
    // but always allow it for link posts since it's their main thumbnail.
    // Self-posts with enabled=false are typically generic link thumbs we drop.
    final enabled = preview['enabled'] as bool? ?? false;
    final isSelf = data['is_self'] as bool? ?? false;
    if (!enabled && isSelf) return null;

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
