import 'package:yarc/models/post.dart';
import 'package:yarc/utils/html_utils.dart';

/// Helpers for parsing Reddit flair richtext and plain-text flair labels.
abstract final class FlairParser {
  /// Strips Reddit custom emoji shortcodes (`:name:`) from flair text and
  /// collapses surrounding whitespace.  Returns `null` when the resulting
  /// string is empty so callers can use null-aware guards.
  static final _redditEmojiShortcodeRegex = RegExp(r':[\w.\-]+:');

  /// Parses Reddit's flair richtext array into [FlairItem] models.
  static List<FlairItem>? parseRichtext(List<dynamic>? richtextFields) {
    if (richtextFields == null || richtextFields.isEmpty) {
      return null;
    }
    final items = <FlairItem>[];
    for (final field in richtextFields) {
      if (field is! Map) {
        continue;
      }
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
          items.add(
            FlairItem(isEmoji: false, text: HtmlUtils.unescape(text)),
          );
        }
      }
    }
    return items.isEmpty ? null : items;
  }

  /// Strips emoji shortcodes from plain-text flair. Returns `null` if the
  /// cleaned string is empty.
  static String? cleanText(String text) {
    final cleaned = text
        .replaceAll(_redditEmojiShortcodeRegex, ' ')
        .trim()
        .replaceAll(RegExp(' {2,}'), ' ');
    return cleaned.isEmpty ? null : cleaned;
  }
}
