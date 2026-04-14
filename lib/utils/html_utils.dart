import 'package:html_unescape/html_unescape.dart';

/// Utility helpers for HTML/text processing of Reddit API content.
class HtmlUtils {
  static final HtmlUnescape _unescape = HtmlUnescape();

  /// Matches Reddit's Giphy comment embed shorthand, e.g.
  /// `[giphy:abc123XYZ:downsized](http://...)` or `[giphy:abc123XYZ](http://...)`.
  /// Group 1 captures the Giphy GIF ID.
  static final _giphyShortcodeRegex = RegExp(
    r'\[giphy:([\w-]+)(?::[\w-]+)?\]\([^)]*\)',
    caseSensitive: false,
  );

  /// Matches Reddit's markdown Giphy snippet, e.g.
  /// `![gif](giphy|abc123XYZ|downsized)`.
  /// Group 1 captures the Giphy GIF ID.
  static final _giphyMarkdownRegex = RegExp(
    r'!\[.*?\]\(giphy\|([\w-]+)(?:\|[\w-]+)?\)',
    caseSensitive: false,
  );

  static String unescape(String text) {
    return _unescape.convert(text);
  }

  /// Converts Reddit's proprietary Giphy embed shorthand into standard
  /// markdown image syntax so it renders as an inline GIF.
  ///
  /// Handles both `[giphy:GIF_ID:size](url)` and `![gif](giphy|GIF_ID|size)`.
  static String resolveGiphyShortcodes(String text) {
    final resolved = text.replaceAllMapped(_giphyShortcodeRegex, (match) {
      final gifId = match.group(1)!;
      return '![](https://media.giphy.com/media/$gifId/giphy.gif)';
    });

    return resolved.replaceAllMapped(_giphyMarkdownRegex, (match) {
      final gifId = match.group(1)!;
      return '![](https://media.giphy.com/media/$gifId/giphy.gif)';
    });
  }
}
