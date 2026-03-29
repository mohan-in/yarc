import 'package:draw/draw.dart' as draw;
import 'package:yarc/models/comment.dart';
import 'package:yarc/models/feed_sort.dart';
import 'package:yarc/models/subreddit.dart';
import 'package:yarc/models/types.dart';
import 'package:yarc/services/history_service.dart';
import 'package:yarc/services/reddit_service.dart';

/// Repository for post operations.
class PostRepository {
  PostRepository(this._redditService, this._historyService);

  final RedditService _redditService;
  final HistoryService _historyService;

  /// Fetches posts, optionally for a specific subreddit.
  ///
  /// Returns a [PostsResult] containing posts and the pagination cursor.
  Future<PostsResult> getPosts({
    String? subreddit,
    String? after,
    FeedSort sort = FeedSort.hot,
    draw.TimeFilter timeFilter = draw.TimeFilter.day,
  }) async {
    return _redditService.fetchPosts(
      subreddit: subreddit,
      after: after,
      sort: sort,
      timeFilter: timeFilter,
    );
  }

  /// Fetches posts submitted by [username] with pagination support.
  Future<PostsResult> getUserPosts({
    required String username,
    String? after,
    FeedSort sort = FeedSort.hot,
    draw.TimeFilter timeFilter = draw.TimeFilter.day,
  }) async {
    return _redditService.fetchUserPosts(
      username: username,
      after: after,
      sort: sort,
      timeFilter: timeFilter,
    );
  }

  /// Fetches fresh posts from API (resets pagination).
  Future<PostsResult> refresh({
    String? subreddit,
    FeedSort sort = FeedSort.hot,
    draw.TimeFilter timeFilter = draw.TimeFilter.day,
  }) async {
    return _redditService.fetchPosts(
      subreddit: subreddit,
      sort: sort,
      timeFilter: timeFilter,
    );
  }

  /// Fetches info for a specific subreddit by name.
  Future<Subreddit?> getSubredditInfo(String name) async {
    return _redditService.fetchSubredditInfo(name);
  }

  /// Fetches comments for a post.
  Future<List<Comment>> getComments(String postId) async {
    return _redditService.fetchComments(postId);
  }

  /// Marks a post as read.
  Future<void> markAsRead(String postId) async {
    await _historyService.markAsRead(postId);
  }

  /// Marks multiple posts as read.
  Future<void> markMultipleAsRead(Iterable<String> postIds) async {
    await _historyService.markMultipleAsRead(postIds);
  }

  /// Gets all read post IDs.
  Set<String> getReadPostIds() {
    return _historyService.getReadPostIds();
  }

  /// Saves a post.
  Future<void> savePost(String postId) async {
    return _redditService.savePost(postId);
  }

  /// Unsaves a post.
  Future<void> unsavePost(String postId) async {
    return _redditService.unsavePost(postId);
  }

  /// Fetches the saved posts for [username] with pagination.
  Future<PostsResult> getSavedPosts({
    required String username,
    String? after,
  }) async {
    return _redditService.fetchSavedPosts(username: username, after: after);
  }
}
