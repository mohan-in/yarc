import 'package:yarc/utils/html_utils.dart';

/// Helpers for extracting media (video, images) from Reddit post data maps.
abstract final class MediaExtractor {
  /// Matches Giphy CDN URLs that serve the actual animated GIF.
  static final _giphyMediaDomainRegex = RegExp(
    r'https?://(?:media|i)\.giphy\.com/',
    caseSensitive: false,
  );

  /// Matches YouTube video URLs across all common formats
  /// (watch, shorts, live, embed).
  static final _youtubeRegex = RegExp(
    r'^.*((youtu.be\/)|(v\/)|'
    r'(\/u\/\w\/)|(embed\/)|'
    r'(watch\?)|(shorts\/)|(live\/))'
    r'\??v?=?([^#&?]*).*',
    caseSensitive: false,
  );

  // ---------------------------------------------------------------------------
  // Image helpers
  // ---------------------------------------------------------------------------

  /// Resolves the direct image URL, preferring GIF/Giphy over static preview.
  ///
  /// Giphy CDN URLs (`[media|i].giphy.com`) serve animated GIFs, so they
  /// take precedence over a static Reddit preview.
  static String? resolveDirectImageUrl(String url, String? currentImageUrl) {
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

  /// Extracts image URL and aspect ratio from Reddit preview metadata.
  ///
  /// Respects Reddit's `enabled` flag: self-posts with `enabled: false` are
  /// typically generic link thumbnails that should be dropped.
  static ({String url, double? aspectRatio})? extractImageFromPreview(
    Map<String, dynamic> data,
  ) {
    if (data['preview'] == null) {
      return null;
    }
    final preview = data['preview'] as Map<String, dynamic>;

    final enabled = preview['enabled'] as bool? ?? false;
    final isSelf = data['is_self'] as bool? ?? false;
    if (!enabled && isSelf) {
      return null;
    }

    if (preview['images'] == null) {
      return null;
    }
    final imagesList = preview['images'] as List<dynamic>;
    if (imagesList.isEmpty) {
      return null;
    }
    final imageMap = imagesList[0] as Map<String, dynamic>;
    if (imageMap['source'] == null) {
      return null;
    }
    final source = imageMap['source'] as Map<String, dynamic>;
    if (source['url'] == null) {
      return null;
    }
    final url = HtmlUtils.unescape(source['url'] as String);
    double? ratio;
    final width = source['width'] as int?;
    final height = source['height'] as int?;
    if (width != null && height != null && width > 0 && height > 0) {
      ratio = width / height;
    }
    return (url: url, aspectRatio: ratio);
  }

  // ---------------------------------------------------------------------------
  // Video helpers
  // ---------------------------------------------------------------------------

  /// Extracts MP4 variant URL from preview data (e.g. GIF → MP4 conversion).
  static String? extractMp4FromPreview(Map<String, dynamic> data) {
    if (data['preview'] == null) {
      return null;
    }
    final preview = data['preview'] as Map<String, dynamic>;
    if (preview['images'] == null) {
      return null;
    }
    final imagesList = preview['images'] as List<dynamic>;
    if (imagesList.isEmpty) {
      return null;
    }
    final imageMap = imagesList[0] as Map<String, dynamic>;
    if (imageMap['variants'] == null) {
      return null;
    }
    final variants = imageMap['variants'] as Map<String, dynamic>;
    if (variants['mp4'] == null) {
      return null;
    }
    final mp4Variant = variants['mp4'] as Map<String, dynamic>;
    if (mp4Variant['source'] == null) {
      return null;
    }
    final source = mp4Variant['source'] as Map<String, dynamic>;
    if (source['url'] == null) {
      return null;
    }
    return HtmlUtils.unescape(source['url'] as String);
  }

  /// Extracts the HLS or fallback video URL from `secure_media`, `media`,
  /// or `preview.reddit_video_preview`.
  static String? extractVideoUrl(Map<String, dynamic> data) {
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

  /// Resolves video URL from main post data or preview, returning both the
  /// URL and a flag indicating whether a video was found.
  static ({String? url, bool isVideo}) resolveVideoUrl(
    Map<String, dynamic> data,
  ) {
    var videoUrl = extractVideoUrl(data);
    if (videoUrl != null) {
      return (url: videoUrl, isVideo: true);
    }
    videoUrl = extractMp4FromPreview(data);
    if (videoUrl != null) {
      return (url: videoUrl, isVideo: true);
    }
    return (url: null, isVideo: false);
  }

  // ---------------------------------------------------------------------------
  // YouTube helpers
  // ---------------------------------------------------------------------------

  /// Extracts a YouTube video ID from [data] if the post links to YouTube.
  /// Returns `null` if the post is not a YouTube link or the ID is malformed.
  static String? extractYoutubeId(Map<String, dynamic> data) {
    final domain = data['domain'] as String?;
    final urlStr = data['url']?.toString() ?? '';
    final isYoutubeDomain =
        domain == 'youtube.com' ||
        domain == 'youtu.be' ||
        domain == 'm.youtube.com' ||
        urlStr.contains('youtube.com') ||
        urlStr.contains('youtu.be');

    if (!isYoutubeDomain) {
      return null;
    }
    final url = HtmlUtils.unescape(urlStr);
    final match = _youtubeRegex.firstMatch(url);
    if (match == null || match.group(9) == null) {
      return null;
    }
    final id = match.group(9)!;
    return id.length == 11 ? id : null;
  }
}
