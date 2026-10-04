/// Utility helpers for HTML/text processing of Reddit API content.
class HtmlUtils {
  static final _htmlEntityRegex = RegExp(
    '&(#(?:x[0-9a-fA-F]+|[0-9]+)|[a-zA-Z]+);',
  );

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

  static const _namedEntities = <String, String>{
    'amp': '&',
    'lt': '<',
    'gt': '>',
    'quot': '"',
    'apos': "'",
    'nbsp': '\u00A0',
    'ndash': '–',
    'mdash': '—',
    'lsquo': '‘',
    'rsquo': '’',
    'ldquo': '“',
    'rdquo': '”',
    'hellip': '…',
    'copy': '©',
    'reg': '®',
    'trade': '™',
    'bull': '•',
    'deg': '°',
    'plusmn': '±',
    'frac12': '½',
    'frac14': '¼',
    'frac34': '¾',
    'times': '×',
    'divide': '÷',
  };

  /// Decodes HTML entities (e.g. `&amp;`, `&lt;`, `&#39;`, `&#x2F;`) into
  /// their plain characters using pure Dart.
  static String unescape(String text) {
    if (!text.contains('&')) return text;
    return text.replaceAllMapped(_htmlEntityRegex, (match) {
      final entity = match.group(1)!;
      if (entity.startsWith('#x') || entity.startsWith('#X')) {
        final code = int.tryParse(entity.substring(2), radix: 16);
        return code != null ? String.fromCharCode(code) : match.group(0)!;
      } else if (entity.startsWith('#')) {
        final code = int.tryParse(entity.substring(1));
        return code != null ? String.fromCharCode(code) : match.group(0)!;
      }
      return _namedEntities[entity] ?? match.group(0)!;
    });
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
