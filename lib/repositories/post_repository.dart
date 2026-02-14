import 'package:yarc/models/comment.dart';
import 'package:yarc/models/types.dart';
import 'package:yarc/services/history_service.dart';
import 'package:yarc/services/reddit_service.dart';

/// Repository for post operations.
class PostRepository {
  PostRepository(this._redditService, this._historyService);

  final RedditService _redditService;
  final HistoryService _historyService;

  /// Fetches posts.
  ///
  /// Returns a [PostsResult] containing posts and the pagination cursor.
  Future<PostsResult> getPosts({String? subreddit, String? after}) async {
    return _fetchFromApi(subreddit, after);
  }

  /// Fetches fresh posts from API.
  Future<PostsResult> refresh({String? subreddit}) async {
    return _redditService.fetchPosts(subreddit: subreddit);
  }

  Future<PostsResult> _fetchFromApi(String? subreddit, String? after) async {
    return _redditService.fetchPosts(subreddit: subreddit, after: after);
  }

  /// Fetches comments for a post.
  Future<List<Comment>> getComments(String postId) async {
    return _redditService.fetchComments(postId);
  }

  /// Marks a post as read.
  Future<void> markAsRead(String postId) async {
    await _historyService.markAsRead(postId);
  }

  /// Gets all read post IDs.
  Future<Set<String>> getReadPostIds() async {
    return _historyService.getReadPostIds();
  }
}
