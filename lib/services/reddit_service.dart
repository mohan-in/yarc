import 'package:draw/draw.dart' as draw;
import '../models/post.dart';
import '../models/comment.dart';
import '../models/subreddit.dart';
import '../services/auth_service.dart';

class RedditService {
  static const int _defaultLimit = 10;

  final AuthService? authService;

  RedditService({this.authService});

  draw.Reddit? get _reddit => authService?.reddit;

  Future<({List<Post> posts, String? nextAfter})> fetchPosts({
    String? subreddit,
    String? after,
  }) async {
    final reddit = _reddit;
    if (reddit == null) {
      throw Exception('Reddit client not initialized or logged out');
    }

    final Map<String, String> params = {'limit': '$_defaultLimit'};
    if (after != null) {
      params['after'] = after;
    }

    final stream = subreddit != null
        ? reddit.subreddit(subreddit).hot(limit: _defaultLimit, params: params)
        : reddit.front.best(limit: _defaultLimit, params: params);

    final List<Post> posts = [];
    String? nextAfterToken;

    try {
      await for (final content in stream) {
        if (content is draw.Submission) {
          posts.add(Post.fromSubmission(content));
          nextAfterToken = content.fullname;
        }
      }
    } catch (_) {}

    return (posts: posts, nextAfter: nextAfterToken);
  }

  Future<List<Comment>> fetchComments(String postId) async {
    final reddit = _reddit;
    if (reddit == null) {
      throw Exception('Reddit client not initialized or logged out');
    }

    try {
      final ref = reddit.submission(id: postId);
      final submission = await ref.populate();

      if (submission.comments != null) {
        return submission.comments!.comments
            .whereType<draw.Comment>()
            .map((c) => Comment.fromDraw(c))
            .toList();
      }
      return [];
    } catch (e) {
      throw Exception('Failed to load comments: $e');
    }
  }

  Future<List<Subreddit>> fetchSubscribedSubreddits() async {
    final reddit = _reddit;
    if (reddit == null) return [];

    try {
      List<Subreddit> subs = [];
      await for (final sub in reddit.user.subreddits(limit: 100)) {
        subs.add(Subreddit.fromDraw(sub));
      }
      return subs;
    } catch (e) {
      return [];
    }
  }

  /// Searches for subreddits by name prefix.
  /// Returns a list of subreddits whose names start with the query.
  Future<List<Subreddit>> searchSubreddits(String query) async {
    final reddit = _reddit;
    if (reddit == null || query.isEmpty) return [];

    try {
      final results = await reddit.subreddits.searchByName(
        query,
        includeNsfw: false,
      );
      // Fetch full subreddit info for each result
      final List<Subreddit> subs = [];
      for (final ref in results) {
        try {
          final sub = await ref.populate();
          subs.add(Subreddit.fromDraw(sub));
        } catch (_) {
          // Skip subreddits that fail to load
        }
      }
      return subs;
    } catch (e) {
      return [];
    }
  }
}
