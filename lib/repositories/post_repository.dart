import 'dart:async';

import 'package:draw/draw.dart' as draw;
import 'package:yarc/models/comment.dart';
import 'package:yarc/models/feed_sort.dart';
import 'package:yarc/models/post.dart';
import 'package:yarc/models/subreddit.dart';
import 'package:yarc/models/types.dart';
import 'package:yarc/models/vote_type.dart';
import 'package:yarc/services/feed_cache_service.dart';
import 'package:yarc/services/history_service.dart';
import 'package:yarc/services/reddit_service.dart';

/// Repository for post operations.
class PostRepository {
  PostRepository(
    this._redditService,
    this._historyService, [
    this._cacheService,
  ]);

  final RedditService _redditService;
  final HistoryService _historyService;
  final FeedCacheService? _cacheService;

  String _buildCacheKey({
    required FeedSort sort,
    String? subreddit,
    String? customFeedPath,
  }) {
    final source = subreddit ?? customFeedPath ?? 'home';
    return '${source}_${sort.name}';
  }

  /// Fetches posts, optionally for a specific subreddit.
  ///
  /// Returns a [PostsResult] containing posts and the pagination cursor.
  Future<PostsResult> getPosts({
    String? subreddit,
    String? customFeedPath,
    String? after,
    FeedSort sort = FeedSort.hot,
    draw.TimeFilter timeFilter = draw.TimeFilter.day,
  }) async {
    final result = await _redditService.fetchPosts(
      subreddit: subreddit,
      customFeedPath: customFeedPath,
      after: after,
      sort: sort,
      timeFilter: timeFilter,
    );
    if (after == null && _cacheService != null && result.posts.isNotEmpty) {
      final cacheKey = _buildCacheKey(
        subreddit: subreddit,
        customFeedPath: customFeedPath,
        sort: sort,
      );
      unawaited(_cacheService.cachePosts(cacheKey, result.posts));
    }
    return result;
  }

  /// Retrieves cached posts for offline viewing.
  List<Post> getCachedPosts({
    String? subreddit,
    String? customFeedPath,
    FeedSort sort = FeedSort.hot,
  }) {
    if (_cacheService == null) return const [];
    final cacheKey = _buildCacheKey(
      subreddit: subreddit,
      customFeedPath: customFeedPath,
      sort: sort,
    );
    return _cacheService.getCachedPosts(cacheKey);
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
    String? customFeedPath,
    FeedSort sort = FeedSort.hot,
    draw.TimeFilter timeFilter = draw.TimeFilter.day,
  }) async {
    return _redditService.fetchPosts(
      subreddit: subreddit,
      customFeedPath: customFeedPath,
      sort: sort,
      timeFilter: timeFilter,
    );
  }

  /// Fetches info for a specific subreddit by name.
  Future<Subreddit?> getSubredditInfo(String name) async {
    return _redditService.fetchSubredditInfo(name);
  }

  /// Fetches a single post by ID.
  Future<Post?> getPost(String id) async {
    return _redditService.fetchPost(id);
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

  /// Searches for posts within a specific subreddit.
  Future<PostsResult> searchSubredditPosts({
    required String query,
    required String subredditName,
    String? after,
    FeedSort sort = FeedSort.hot,
    draw.TimeFilter timeFilter = draw.TimeFilter.all,
  }) async {
    return _redditService.searchSubredditPosts(
      query: query,
      subredditName: subredditName,
      after: after,
      sort: sort,
      timeFilter: timeFilter,
    );
  }

  /// Casts or clears a vote on a post.
  Future<void> votePost({
    required String postId,
    required VoteType voteType,
  }) async {
    return _redditService.votePost(postId: postId, voteType: voteType);
  }

  /// Casts or clears a vote on a comment.
  Future<void> voteComment({
    required String commentId,
    required VoteType voteType,
  }) async {
    return _redditService.voteComment(
      commentId: commentId,
      voteType: voteType,
    );
  }
}
