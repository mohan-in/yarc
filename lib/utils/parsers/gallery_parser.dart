import 'package:yarc/utils/html_utils.dart';

/// Helpers for parsing Reddit gallery posts (gallery_data + media_metadata).
abstract final class GalleryParser {
  /// Populates [images] with the source URLs from [data]'s gallery and
  /// returns the aspect ratio of the first image, or `null` if the post has
  /// no gallery.
  static double? parse(Map<String, dynamic> data, List<String> images) {
    if (data['gallery_data'] == null || data['media_metadata'] == null) {
      return null;
    }
    final galleryData = data['gallery_data'] as Map<String, dynamic>;
    final metadata = data['media_metadata'] as Map<String, dynamic>;
    final items = galleryData['items'];
    if (items == null) {
      return null;
    }

    double? firstAspectRatio;
    for (final item in items as List<dynamic>) {
      final itemMap = item as Map<String, dynamic>;
      final mediaId = itemMap['media_id'] as String?;
      if (mediaId == null || metadata[mediaId] == null) {
        continue;
      }
      final mediaItem = metadata[mediaId] as Map<String, dynamic>;
      if (mediaItem['status'] != 'valid' || mediaItem['e'] != 'Image') {
        continue;
      }
      final s = mediaItem['s'] as Map<String, dynamic>?;
      if (s == null || s['u'] == null) {
        continue;
      }
      final url = HtmlUtils.unescape(s['u'] as String);
      images.add(url);

      if (firstAspectRatio == null) {
        final x = s['x'] as int?;
        final y = s['y'] as int?;
        if (x != null && y != null && x > 0 && y > 0) {
          firstAspectRatio = x / y;
        }
      }
    }
    return firstAspectRatio;
  }
}
