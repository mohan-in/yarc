import 'package:draw/draw.dart' as draw;
import 'package:flutter/foundation.dart';
import 'package:yarc/models/comment.dart';
import 'package:yarc/models/post.dart';
import 'package:yarc/models/subreddit.dart';
import 'package:yarc/models/types.dart';
import 'package:yarc/services/auth_service.dart';
import 'package:yarc/utils/constants.dart';
import 'package:yarc/utils/post_parser.dart';

/// Service for Reddit API calls.
class RedditService {
  RedditService(this._authService);

  final AuthService _authService;

  draw.Reddit? get _reddit => _authService.reddit;

  /// A wrapper that catches authentication errors
  /// (e.g. 401 Unauthorized or 403 Forbidden)
  /// and attempts to refresh the session and retry the [action].
  Future<T> _withAuthRetry<T>(
    String actionName,
    Future<T> Function() action,
  ) async {
    try {
      final result = await action();
      await _authService.persistCredentials();
      return result;
    } on Exception catch (e) {
      final isAuthError =
          e.toString().contains('401') ||
          e.toString().contains('403') ||
          e is draw.DRAWAuthenticationError ||
          (e is draw.DRAWUnknownResponseException &&
              (e.status == 401 || e.status == 403));

      if (isAuthError) {
        try {
          debugPrint('Auth error in $actionName, refreshing session...');
          await _authService.refreshSession();
          // Retry the action after successful refresh
          final retryResult = await action();
          await _authService.persistCredentials();
          return retryResult;
        } on Exception catch (refreshError) {
          debugPrint('Failed to refresh in $actionName: $refreshError');
          // If refresh fails or retry fails, rethrow
          rethrow;
        }
      }
      debugPrint('Failed in $actionName: $e');
      rethrow;
    }
  }

  Future<PostsResult> fetchPosts({
    String? subreddit,
    String? after,
  }) async {
    final reddit = _reddit;
    if (reddit == null) {
      throw Exception('Reddit client not initialized or logged out');
    }

    try {
      return await _withAuthRetry('fetchPosts', () async {
        final params = <String, String>{'limit': '$kDefaultPostLimit'};
        if (after != null) {
          params['after'] = after;
        }

        final stream = subreddit != null
            ? reddit
                  .subreddit(subreddit)
                  .hot(limit: kDefaultPostLimit, params: params)
            : reddit.front.best(limit: kDefaultPostLimit, params: params);

        final posts = <Post>[];
        String? nextAfterToken;

        await for (final content in stream) {
          if (content is draw.Submission) {
            posts.add(PostParser.parse(content));
            nextAfterToken = content.fullname;
          }
        }
        return (posts: posts, nextAfter: nextAfterToken);
      });
    } on Exception catch (_) {
      return (posts: <Post>[], nextAfter: null);
    }
  }

  /// Fetches comments for a post, with automatic retry handling.
  Future<List<Comment>> fetchComments(String postId) async {
    final reddit = _reddit;
    if (reddit == null) {
      throw Exception('Reddit client not initialized or logged out');
    }

    try {
      return await _withAuthRetry('fetchComments', () async {
        final ref = reddit.submission(id: postId);
        final submission = await ref.populate();

        if (submission.comments != null) {
          return submission.comments!.comments
              .whereType<draw.Comment>()
              .map(Comment.fromDraw)
              .toList();
        }
        return <Comment>[];
      });
    } catch (e) {
      throw Exception('Failed to load comments: $e');
    }
  }

  /// Fetches a single post by ID, with automatic retry handling.
  Future<Post?> fetchPost(String postId) async {
    final reddit = _reddit;
    if (reddit == null) {
      return null;
    }

    try {
      return await _withAuthRetry('fetchPost', () async {
        final ref = reddit.submission(id: postId);
        final submission = await ref.populate();
        return PostParser.parse(submission);
      });
    } on Exception catch (_) {
      return null;
    }
  }

  /// Fetches the user's subscribed subreddits.
  /// Returns an empty list on failure or if not logged in.
  Future<List<Subreddit>> fetchSubscribedSubreddits() async {
    final reddit = _reddit;
    if (reddit == null) {
      return [];
    }

    try {
      return await _withAuthRetry('fetchSubscribedSubreddits', () async {
        final subs = <Subreddit>[];
        await for (final sub in reddit.user.subreddits()) {
          subs.add(Subreddit.fromDraw(sub));
        }
        return subs;
      });
    } on Exception catch (_) {
      return [];
    }
  }

  /// Searches for subreddits by name prefix.
  /// Returns an empty list on failure.
  Future<List<Subreddit>> searchSubreddits(String query) async {
    final reddit = _reddit;
    if (reddit == null || query.isEmpty) {
      return [];
    }

    try {
      return await _withAuthRetry('searchSubreddits', () async {
        final results = await reddit.subreddits.searchByName(
          query,
          includeNsfw: false,
        );
        final subs = <Subreddit>[];
        for (final ref in results) {
          try {
            final sub = await ref.populate();
            subs.add(Subreddit.fromDraw(sub));
          } on Exception catch (_) {
            // Skip subreddits that fail to load
          }
        }
        return subs;
      });
    } on Exception catch (_) {
      return [];
    }
  }

  /// Subscribes the current user to the given subreddit.
  Future<void> subscribeToSubreddit(String subredditName) async {
    final reddit = _reddit;
    if (reddit == null) {
      throw Exception('Reddit client not initialized or logged out');
    }

    try {
      await _withAuthRetry('subscribeToSubreddit', () async {
        final sub = reddit.subreddit(subredditName);
        await sub.subscribe();
      });
    } catch (e) {
      throw Exception('Failed to subscribe to $subredditName: $e');
    }
  }

  /// Unsubscribes the current user from the given subreddit.
  Future<void> unsubscribeFromSubreddit(String subredditName) async {
    final reddit = _reddit;
    if (reddit == null) {
      throw Exception('Reddit client not initialized or logged out');
    }

    try {
      await _withAuthRetry('unsubscribeFromSubreddit', () async {
        final sub = reddit.subreddit(subredditName);
        await sub.unsubscribe();
      });
    } catch (e) {
      throw Exception('Failed to unsubscribe from $subredditName: $e');
    }
  }
}
