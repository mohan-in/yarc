import 'package:app_links/app_links.dart';
import 'dart:async';

/// Parsed deep link result for navigation
class DeepLinkResult {
  final DeepLinkType type;
  final String? subreddit;
  final String? postId;
  final String? username;

  const DeepLinkResult({
    required this.type,
    this.subreddit,
    this.postId,
    this.username,
  });
}

enum DeepLinkType { subreddit, post, user, home, unknown }

/// Service for handling Reddit deep links
class DeepLinkService {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  Future<DeepLinkResult?> getInitialLink() async {
    final uri = await _appLinks.getInitialLink();
    if (uri != null) {
      return parseRedditUrl(uri);
    }
    return null;
  }

  Stream<DeepLinkResult> get linkStream {
    return _appLinks.uriLinkStream
        .map((uri) => parseRedditUrl(uri))
        .where((result) => result != null)
        .cast<DeepLinkResult>();
  }

  /// Parse a Reddit URL into a DeepLinkResult
  DeepLinkResult? parseRedditUrl(Uri uri) {
    final pathSegments = uri.pathSegments;

    if (pathSegments.isEmpty) {
      // Ignore auth callback if it somehow reaches here
      if (uri.host == 'callback') {
        return null; // Don't navigate
      }
      return const DeepLinkResult(type: DeepLinkType.home);
    }

    if (pathSegments.isNotEmpty && pathSegments[0] == 'r') {
      if (pathSegments.length >= 2) {
        final subreddit = pathSegments[1];

        if (pathSegments.length >= 4 && pathSegments[2] == 'comments') {
          final postId = pathSegments[3];
          return DeepLinkResult(
            type: DeepLinkType.post,
            subreddit: subreddit,
            postId: postId,
          );
        }

        return DeepLinkResult(
          type: DeepLinkType.subreddit,
          subreddit: subreddit,
        );
      }
    }

    if (pathSegments.isNotEmpty &&
        (pathSegments[0] == 'u' || pathSegments[0] == 'user')) {
      if (pathSegments.length >= 2) {
        return DeepLinkResult(
          type: DeepLinkType.user,
          username: pathSegments[1],
        );
      }
    }

    if (pathSegments.isNotEmpty && pathSegments[0] == 'comments') {
      if (pathSegments.length >= 2) {
        return DeepLinkResult(type: DeepLinkType.post, postId: pathSegments[1]);
      }
    }

    return const DeepLinkResult(type: DeepLinkType.unknown);
  }

  /// Dispose of any subscriptions
  void dispose() {
    _linkSubscription?.cancel();
  }
}
