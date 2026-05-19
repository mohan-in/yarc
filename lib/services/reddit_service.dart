import 'dart:async';
import 'dart:developer' as developer;

import 'package:draw/draw.dart' as draw;
import 'package:yarc/models/comment.dart';
import 'package:yarc/models/custom_feed.dart';
import 'package:yarc/models/feed_sort.dart';
import 'package:yarc/models/post.dart';
import 'package:yarc/models/redditor_info.dart';
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

  /// Returns true if the exception represents an authentication error
  /// (401 or 403). Checks typed exceptions first and falls back to
  /// string matching only as a last resort.
  static bool _isAuthException(Exception e) {
    if (e is draw.DRAWAuthenticationError) {
      return true;
    }
    if (e is draw.DRAWUnknownResponseException) {
      return e.status == 401 || e.status == 403;
    }
    // Last resort: string check for untyped HTTP errors from the DRAW library.
    final message = e.toString();
    return message.contains('401 Unauthorized') ||
        message.contains('403 Forbidden');
  }

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
      if (_isAuthException(e)) {
        developer.log(
          'Auth error in $actionName, refreshing session...',
          name: 'RedditService',
        );
        await _authService.refreshSession();

        // Only retry if the refresh actually succeeded. If the token was
        // revoked, refreshSession() emits unauthenticated on the stream
        // and we should not attempt a doomed retry.
        if (!_authService.isLoggedIn) {
          rethrow;
        }

        try {
          final retryResult = await action();
          await _authService.persistCredentials();
          return retryResult;
        } on Exception catch (retryError) {
          developer.log(
            'Retry failed in $actionName: $retryError',
            name: 'RedditService',
          );
          rethrow;
        }
      }
      developer.log('Failed in $actionName: $e', name: 'RedditService');
      rethrow;
    }
  }

  Future<PostsResult> fetchPosts({
    String? subreddit,
    String? customFeedPath,
    String? after,
    FeedSort sort = FeedSort.hot,
    draw.TimeFilter timeFilter = draw.TimeFilter.day,
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

        if (customFeedPath != null) {
          final sortStr = sort == FeedSort.best ? 'hot' : sort.name;
          final String url;
          if (customFeedPath.startsWith('/')) {
            url = customFeedPath.endsWith('/')
                ? '$customFeedPath$sortStr'
                : '$customFeedPath/$sortStr';
          } else {
            url = '/$customFeedPath/$sortStr';
          }

          developer.log(
            'Fetching custom feed: $url (sort: $sortStr, after: $after)',
            name: 'RedditService',
          );

          // reddit.get() automatically objectifies the response by default,
          // returning {'listing': [...], 'before': ..., 'after': ...} for a
          // Listing response — NOT the raw {'data': {'children': [...]}} JSON.
          final response = await reddit.get(
            url,
            params: {
              ...params,
              if (sort == FeedSort.top || sort == FeedSort.controversial)
                't': timeFilter.toString().split('.').last,
            },
          );

          developer.log(
            'Custom feed response type: ${response.runtimeType}, '
            'keys: ${response is Map ? response.keys.toList() : "N/A"}',
            name: 'RedditService',
          );

          if (response is Map) {
            // DRAW's objectify() converts a Listing into:
            // {'listing': [Submission, ...], 'before': ..., 'after': ...}
            final listing = response['listing'] as List?;
            final nextAfter = response['after'] as String?;

            if (listing != null) {
              final posts = <Post>[];
              for (final item in listing) {
                if (item is draw.Submission) {
                  try {
                    posts.add(PostParser.parse(item));
                  } on Exception catch (e) {
                    developer.log(
                      'Failed to parse submission ${item.id}: $e',
                      name: 'RedditService',
                    );
                  }
                }
              }
              developer.log(
                'Custom feed parsed ${posts.length} posts, '
                'nextAfter: $nextAfter',
                name: 'RedditService',
              );
              return (posts: posts, nextAfter: nextAfter);
            }
          }

          developer.log(
            'Custom feed returned unexpected response structure',
            name: 'RedditService',
          );
          return (posts: <Post>[], nextAfter: null);
        }

        final stream = subreddit != null
            ? _getSubredditStream(
                reddit.subreddit(subreddit),
                sort: sort,
                timeFilter: timeFilter,
                params: params,
              )
            : _getFrontPageStream(
                reddit.front,
                sort: sort,
                timeFilter: timeFilter,
                params: params,
              );

        final posts = <Post>[];
        String? nextAfterToken;
        var batchCount = 0;

        await for (final content in stream) {
          if (content is draw.Submission) {
            posts.add(PostParser.parse(content));
            nextAfterToken = content.fullname;
          }
          // Yield to the UI thread every 5 items to prevent jank
          // without spawning a microtask on every single item.
          if (++batchCount % 5 == 0) {
            await Future<void>.delayed(Duration.zero);
          }
        }
        return (posts: posts, nextAfter: nextAfterToken);
      });
    } on Exception catch (e, stack) {
      developer.log(
        'fetchPosts failed: $e',
        name: 'RedditService',
        error: e,
        stackTrace: stack,
      );
      return (posts: <Post>[], nextAfter: null);
    }
  }

  /// Fetches posts submitted by a specific user, with pagination support.
  Future<PostsResult> fetchUserPosts({
    required String username,
    String? after,
    FeedSort sort = FeedSort.hot,
    draw.TimeFilter timeFilter = draw.TimeFilter.day,
  }) async {
    final reddit = _reddit;
    if (reddit == null) {
      throw Exception('Reddit client not initialized or logged out');
    }

    try {
      return await _withAuthRetry('fetchUserPosts', () async {
        final submissions = reddit.redditor(username).submissions;
        final stream = _getUserSubmissionsStream(
          submissions,
          sort: sort,
          timeFilter: timeFilter,
          after: after,
        );

        final posts = <Post>[];
        String? nextAfterToken;
        var batchCount = 0;

        await for (final content in stream) {
          if (content is draw.Submission) {
            posts.add(PostParser.parse(content));
            nextAfterToken = content.fullname;
          }
          // Yield to the UI thread every 5 items to prevent jank
          // without spawning a microtask on every single item.
          if (++batchCount % 5 == 0) {
            await Future<void>.delayed(Duration.zero);
          }
        }
        return (posts: posts, nextAfter: nextAfterToken);
      });
    } on Exception catch (_) {
      return (posts: <Post>[], nextAfter: null);
    }
  }

  /// Saves a post by its ID.
  Future<void> savePost(String postId) async {
    final reddit = _reddit;
    if (reddit == null) {
      throw Exception('Reddit client not initialized or logged out');
    }
    return _withAuthRetry('savePost', () async {
      // Submissions have the fullname prefix 't3_'. Posting directly to
      // the save endpoint avoids an extra populate() API round-trip.
      await reddit.post(
        'api/save/',
        {'category': '', 'id': 't3_$postId'},
        discardResponse: true,
      );
      developer.log(
        'Successfully saved post: $postId',
        name: 'RedditService',
      );
    });
  }

  /// Unsaves a post by its ID.
  Future<void> unsavePost(String postId) async {
    final reddit = _reddit;
    if (reddit == null) {
      throw Exception('Reddit client not initialized or logged out');
    }
    return _withAuthRetry('unsavePost', () async {
      // Posting directly to the unsave endpoint avoids an extra
      // populate() API round-trip.
      await reddit.post(
        'api/unsave/',
        {'id': 't3_$postId'},
        discardResponse: true,
      );
      developer.log(
        'Successfully unsaved post: $postId',
        name: 'RedditService',
      );
    });
  }

  /// Returns the appropriate sorted stream for a subreddit.
  Stream<draw.UserContent> _getSubredditStream(
    draw.SubredditRef sub, {
    required FeedSort sort,
    required draw.TimeFilter timeFilter,
    required Map<String, String> params,
  }) {
    return switch (sort) {
      FeedSort.best || FeedSort.hot => sub.hot(
        limit: kDefaultPostLimit,
        params: params,
      ),
      FeedSort.newest => sub.newest(
        limit: kDefaultPostLimit,
        params: params,
      ),
      FeedSort.top => sub.top(
        timeFilter: timeFilter,
        limit: kDefaultPostLimit,
        params: params,
      ),
      FeedSort.controversial => sub.controversial(
        timeFilter: timeFilter,
        limit: kDefaultPostLimit,
        params: params,
      ),
      FeedSort.rising => sub.rising(
        limit: kDefaultPostLimit,
        params: params,
      ),
    };
  }

  /// Returns the appropriate sorted stream for the front page.
  Stream<draw.UserContent> _getFrontPageStream(
    draw.FrontPage front, {
    required FeedSort sort,
    required draw.TimeFilter timeFilter,
    required Map<String, String> params,
  }) {
    return switch (sort) {
      FeedSort.best => front.best(
        limit: kDefaultPostLimit,
        params: params,
      ),
      FeedSort.hot => front.hot(
        limit: kDefaultPostLimit,
        params: params,
      ),
      FeedSort.newest => front.newest(
        limit: kDefaultPostLimit,
        params: params,
      ),
      FeedSort.top => front.top(
        timeFilter: timeFilter,
        limit: kDefaultPostLimit,
        params: params,
      ),
      FeedSort.controversial => front.controversial(
        timeFilter: timeFilter,
        limit: kDefaultPostLimit,
        params: params,
      ),
      FeedSort.rising => front.rising(
        limit: kDefaultPostLimit,
        params: params,
      ),
    };
  }

  /// Returns the appropriate sorted stream for a user's submitted posts.
  Stream<draw.UserContent> _getUserSubmissionsStream(
    draw.SubListing submissions, {
    required FeedSort sort,
    required draw.TimeFilter timeFilter,
    String? after,
  }) {
    return switch (sort) {
      FeedSort.best || FeedSort.hot => submissions.hot(
        limit: kDefaultPostLimit,
        after: after,
      ),
      FeedSort.newest => submissions.newest(
        limit: kDefaultPostLimit,
        after: after,
      ),
      FeedSort.top => submissions.top(
        timeFilter: timeFilter,
        limit: kDefaultPostLimit,
        after: after,
      ),
      FeedSort.controversial => submissions.controversial(
        timeFilter: timeFilter,
        limit: kDefaultPostLimit,
        after: after,
      ),
      // SubListing has no rising; fall back to hot.
      FeedSort.rising => submissions.hot(
        limit: kDefaultPostLimit,
        after: after,
      ),
    };
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

  /// Fetches the user's custom feeds (multireddits).
  Future<List<CustomFeed>> fetchCustomFeeds() async {
    final reddit = _reddit;
    if (reddit == null) {
      return [];
    }

    try {
      return await _withAuthRetry('fetchCustomFeeds', () async {
        final multis = await reddit.user.multireddits();
        if (multis == null) {
          return <CustomFeed>[];
        }
        return multis.map(CustomFeed.fromDraw).toList();
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

  /// Fetches a specific subreddit by name.
  Future<Subreddit?> fetchSubredditInfo(String name) async {
    final reddit = _reddit;
    if (reddit == null) {
      return null;
    }

    try {
      return await _withAuthRetry('fetchSubredditInfo', () async {
        final ref = reddit.subreddit(name);
        final sub = await ref.populate();
        return Subreddit.fromDraw(sub);
      });
    } on Exception catch (e, stack) {
      developer.log(
        'Failed to fetch subreddit info for $name: $e',
        name: 'RedditService',
        error: e,
        stackTrace: stack,
      );
      return null;
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

  /// Fetches a user by exact username.
  /// Returns null if the user doesn't exist or on error.
  Future<RedditorInfo?> fetchUser(String username) async {
    final reddit = _reddit;
    if (reddit == null || username.isEmpty) {
      return null;
    }

    try {
      return await _withAuthRetry('fetchUser', () async {
        final redditor = await reddit.redditor(username).populate();
        return RedditorInfo(
          name: redditor.displayName,
          commentKarma: redditor.commentKarma ?? 0,
          linkKarma: redditor.linkKarma ?? 0,
          createdUtc: redditor.createdUtc,
        );
      });
    } on Exception catch (_) {
      return null;
    }
  }

  /// Returns the display name of the currently authenticated user, or null.
  Future<String?> fetchCurrentUsername() async {
    final reddit = _reddit;
    if (reddit == null) {
      return null;
    }
    try {
      return await _withAuthRetry('fetchCurrentUsername', () async {
        final me = await reddit.user.me();
        return me?.displayName;
      });
    } on Exception catch (_) {
      return null;
    }
  }

  /// Fetches saved posts (Submissions only) for [username] with pagination.
  Future<PostsResult> fetchSavedPosts({
    required String username,
    String? after,
  }) async {
    final reddit = _reddit;
    if (reddit == null) {
      developer.log(
        'Saved posts fetch failed: Reddit client null',
        name: 'RedditService',
      );
      throw Exception('Reddit client not initialized or logged out');
    }

    try {
      return await _withAuthRetry('fetchSavedPosts', () async {
        developer.log(
          'Fetching saved posts for $username, after: $after',
          name: 'RedditService',
        );

        // me() is more reliable for private content than redditor(username).
        final me = await reddit.user.me();
        final redditor = me ?? reddit.redditor(username);

        final stream = redditor.saved(
          limit: kDefaultPostLimit,
          after: after,
        );

        final posts = <Post>[];
        String? nextAfterToken;
        var count = 0;
        var batchCount = 0;

        await for (final content in stream) {
          count++;
          if (content is draw.Submission) {
            nextAfterToken = content.fullname;
            posts.add(PostParser.parse(content));
            developer.log(
              'Found saved submission: ${content.fullname}',
              name: 'RedditService',
            );
          } else if (content is draw.Comment) {
            nextAfterToken = content.fullname;
            developer.log(
              'Skipping saved comment: ${content.fullname}',
              name: 'RedditService',
            );
          } else {
            developer.log(
              'Found unknown saved content type: ${content.runtimeType}',
              name: 'RedditService',
            );
          }
          // Yield to the UI thread every 5 items to prevent jank
          // without spawning a microtask on every single item.
          if (++batchCount % 5 == 0) {
            await Future<void>.delayed(Duration.zero);
          }
        }

        developer.log(
          'Fetched $count items from saved stream. '
          'Found ${posts.length} posts. nextAfter: $nextAfterToken',
          name: 'RedditService',
        );

        return (posts: posts, nextAfter: nextAfterToken);
      });
    } on Exception catch (e, stack) {
      developer.log(
        'Error fetching saved posts: $e',
        name: 'RedditService',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }
}
