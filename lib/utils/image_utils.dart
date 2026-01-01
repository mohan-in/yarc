import 'package:flutter/foundation.dart';

class ImageUtils {
  static String getCorsUrl(String url) {
    if (kIsWeb) {
      // Use images.weserv.nl as a CORS proxy/cache.
      // It is robust and handles SSL/CORS correctly for embedding.
      // Remove 'https://' from the url for weserv (it expects the host directly or encoded)
      // Standard format: https://images.weserv.nl/?url=example.com/image.jpg
      return 'https://images.weserv.nl/?url=${Uri.encodeComponent(url)}';
    }
    return url;
  }

  static String convertBareUrlsToMarkdownImages(String text) {
    // 1. Convert bare image URLs to markdown image syntax
    // Regex for bare URLs that end with image extensions
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

  static bool isImageExtension(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    final path = uri.path.toLowerCase();
    return path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.png') ||
        path.endsWith('.gif') ||
        path.endsWith('.webp');
  }
}
