import 'package:yarc/utils/html_utils.dart';

/// Helpers for extracting and sanitizing post text content.
abstract final class ContentSanitizer {
  /// Matches markdown image syntax: `![alt](url)`
  static final _markdownImageRegex = RegExp(r'!\[[^\]]*\]\(([^)]+)\)');

  /// Matches 3+ consecutive newlines for collapsing whitespace.
  static final _excessiveNewlinesRegex = RegExp(r'\n{3,}');

  /// Matches direct image URLs (jpg/jpeg/png/gif/webp) with optional query
  /// strings.
  static final _imageUrlRegex = RegExp(
    r'https?://[^\s\)]+\.(?:jpg|jpeg|png|gif|webp)(?:\?[^\s\)]*)?',
    caseSensitive: false,
  );

  /// Matches both Reddit-native and external preview CDN URLs.
  static final _redditPreviewRegex = RegExp(
    r'https?://(?:external-)?preview\.redd\.it/[^\s\)]+',
    caseSensitive: false,
  );

  /// Removes known media URLs from [content] and collapses excess whitespace.
  static String sanitize(
    String content,
    List<String> images,
    String? thumbnail,
  ) {
    if (content.isEmpty) {
      return content;
    }

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

  /// Extracts image URLs embedded in [selftext] markdown and appends them to
  /// [images].
  static void extractSelftextImages(
    String? selftext,
    List<String> images,
  ) {
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
}
