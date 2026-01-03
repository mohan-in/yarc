import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/image_utils.dart';
import 'full_screen_image_view.dart';

/// A reusable widget for displaying a single network image with loading,
/// error handling, disk/memory caching, and tap-to-fullscreen functionality.
class CachedImage extends StatelessWidget {
  final String imageUrl;
  final List<String>? fullScreenUrls;
  final BoxFit fit;
  final double? height;

  const CachedImage({
    super.key,
    required this.imageUrl,
    this.fullScreenUrls,
    this.fit = BoxFit.fitWidth,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                FullScreenImageView(imageUrls: fullScreenUrls ?? [imageUrl]),
          ),
        );
      },
      child: CachedNetworkImage(
        imageUrl: ImageUtils.getCorsUrl(imageUrl),
        httpHeaders: ImageUtils.authHeaders,
        width: double.infinity,
        fit: fit,
        placeholder: (context, url) => SizedBox(
          height: height ?? 200,
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (context, url, error) => SizedBox(
          height: height ?? 200,
          child: const Center(
            child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
          ),
        ),
      ),
    );
  }
}
