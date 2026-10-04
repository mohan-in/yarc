import 'package:draw/draw.dart' as draw;
import 'package:yarc/models/custom_feed.dart';

/// Parses DRAW [draw.Multireddit] objects into [CustomFeed] domain models.
class CustomFeedParser {
  /// Converts a DRAW [draw.Multireddit] into a domain [CustomFeed].
  static CustomFeed parse(draw.Multireddit multi) {
    return CustomFeed(
      displayName: multi.displayName,
      path: (multi.data?['path'] as String?) ?? '',
    );
  }
}
