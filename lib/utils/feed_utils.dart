import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/post.dart';
import '../utils/constants.dart';
import '../utils/image_utils.dart';

/// Utility class for feed-related operations.
class FeedUtils {
  /// Precaches images for upcoming posts to ensure smooth scrolling.
  ///
  /// This calculates which posts are likely to be visible soon based on the
  /// current scroll position and pre-fetches their images using [cached_network_image].
  static void precachePostImages(
    BuildContext context,
    List<Post> posts,
    double currentScrollPosition,
  ) {
    // Estimate which post is currently at the top of the screen
    final estimatedVisibleIndex =
        (currentScrollPosition / kEstimatedPostCardHeight).floor();

    // Determine the range of posts to prefetch
    // We start prefetching after the currently visible posts
    final startIndex = (estimatedVisibleIndex + kVisiblePostsBeforePrefetch)
        .clamp(0, posts.length);
    // We prefetch a fixed number of posts ahead
    final endIndex = (startIndex + kPrefetchPostCount).clamp(0, posts.length);

    for (var i = startIndex; i < endIndex; i++) {
      final post = posts[i];

      // Collect all image URLs for this post (carousel, single image, or thumbnail)
      final imagesToCache = <String>[];

      if (post.images.isNotEmpty) {
        imagesToCache.addAll(post.images);
      } else if (post.imageUrl != null) {
        imagesToCache.add(post.imageUrl!);
      } else if (post.thumbnail != null) {
        imagesToCache.add(post.thumbnail!);
      }

      for (final imageUrl in imagesToCache) {
        // Use Flutter's precacheImage with CachedNetworkImageProvider
        // This ensures the image is downloaded and stored in the disk cache
        precacheImage(
          CachedNetworkImageProvider(
            ImageUtils.getCorsUrl(imageUrl),
            headers: ImageUtils.authHeaders,
          ),
          context,
        ).catchError((_) {
          // Ignore errors during precaching (e.g. invalid URLs, network issues)
          // We don't want to crash or disrupt the user for background optimization
        });
      }
    }
  }
}
