import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:yarc/utils/constants.dart';

/// Utility class for image URL processing and CORS handling.
class ImageUtils {
  /// Returns a CORS-safe URL for the given image URL.
  ///
  /// On web platforms, wraps the URL through a CORS proxy (images.weserv.nl).
  /// On native platforms, returns the original URL unchanged.
  static String getCorsUrl(String url) {
    if (kIsWeb) {
      // Use images.weserv.nl as a CORS proxy/cache.
      // It is robust and handles SSL/CORS correctly for embedding.
      return 'https://images.weserv.nl/?url=${Uri.encodeComponent(url)}';
    }
    return url;
  }

  /// Converts bare image URLs in text to markdown image syntax.
  ///
  /// Detects URLs ending with image extensions (.jpg, .png, etc.)
  /// and wraps them in `![]()` markdown syntax for proper rendering.
  static String convertBareUrlsToMarkdownImages(String text) {
    final imageRegex = RegExp(
      r'(?<!\]\()((https?:www\.)|(https?:\/\/)|(www\.))[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9]{1,6}(\/[-a-zA-Z0-9()@:%_\+.~#?&\/=]*)?',
      caseSensitive: false,
    );

    return text.replaceAllMapped(imageRegex, (match) {
      final url = match.group(0)!;
      if (isImageExtension(url)) {
        return '![]($url)';
      }
      return url;
    });
  }

  /// Checks if the URL points to an image based on file extension.
  ///
  /// Returns true for .jpg, .jpeg, .png, .gif, and .webp extensions.
  static bool isImageExtension(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return false;
    }
    final path = uri.path.toLowerCase();
    return path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.png') ||
        path.endsWith('.gif') ||
        path.endsWith('.webp');
  }

  /// HTTP headers for authenticated image requests on native platforms.
  ///
  /// Returns null on web (CORS proxy handles auth), otherwise returns
  /// a User-Agent header for Reddit API compliance.
  static Map<String, String>? get authHeaders =>
      kIsWeb ? null : const {'User-Agent': kUserAgent};

  /// Opens the native file-save dialog so the user can choose where to save
  /// the image at [rawUrl].
  ///
  /// The image bytes are fetched from the disk cache (or network) first, then
  /// handed to FilePicker.saveFile which drives the SAF picker on Android.
  /// Returns `true` when the file was saved successfully, `false`
  /// when the user cancelled or an error occurred.
  static Future<bool> saveImageWithFilePicker(String rawUrl) async {
    final url = getCorsUrl(rawUrl);

    try {
      final file = await DefaultCacheManager().getSingleFile(
        url,
        headers: authHeaders,
      );
      final bytes = await file.readAsBytes();
      final defaultName = _extractFilename(rawUrl);

      final savedPath = await FilePicker.saveFile(
        dialogTitle: 'Save image',
        fileName: defaultName,
        type: FileType.image,
        bytes: bytes,
      );

      // null means the user dismissed the picker without saving.
      return savedPath != null;
    } on Exception catch (_) {
      return false;
    }
  }

  /// Derives a filename from [rawUrl], falling back to a timestamped name.
  static String _extractFilename(String rawUrl) {
    try {
      final uri = Uri.parse(rawUrl);
      final segments = uri.pathSegments;
      if (segments.isNotEmpty) {
        final last = segments.last;
        if (last.contains('.')) {
          return last;
        }
      }
    } on Exception catch (_) {
      // Fall through to default.
    }
    return 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';
  }
}
