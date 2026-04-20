import 'package:draw/draw.dart' as draw;
import 'package:flutter/foundation.dart';

/// Represents a Reddit custom feed (multireddit).
@immutable
class CustomFeed {
  const CustomFeed({
    required this.displayName,
    required this.path,
  });

  /// Creates a [CustomFeed] from a DRAW library multireddit object.
  factory CustomFeed.fromDraw(draw.Multireddit multi) {
    return CustomFeed(
      displayName: multi.displayName,
      path: (multi.data?['path'] as String?) ?? '',
    );
  }

  /// The display name of the custom feed.
  final String displayName;

  /// The full path to the multireddit (e.g., "/user/username/m/custom").
  final String path;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CustomFeed && other.path == path);

  @override
  int get hashCode => path.hashCode;
}
