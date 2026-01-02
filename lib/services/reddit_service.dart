import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:draw/draw.dart' as draw;
import '../models/post.dart';
import '../models/comment.dart';
import '../models/subreddit.dart';
import '../services/auth_service.dart';

class RedditService {
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

    // Default limit
    final limit = 10;

    Stream<draw.UserContent> stream;
    // We use 'params' to pass 'after' because draw's high level methods
    // might not expose it directly in all versions, or we want stateless pagination behavior.
    final Map<String, String> params = {'limit': '$limit'};
    if (after != null) {
      params['after'] = after;
    }

    if (subreddit != null) {
      stream = reddit.subreddit(subreddit).hot(limit: limit, params: params);
    } else {
      // Home feed
      stream = reddit.front.best(limit: limit, params: params);
    }

    List<Post> posts = [];
    String? nextAfterToken;

    try {
      await for (final content in stream) {
        if (content is draw.Submission) {
          posts.add(Post.fromSubmission(content));
          nextAfterToken =
              content.fullname; // Use fullname (e.g. t3_ID) as 'after' token
        }
      }
    } catch (e) {
      // draw throws if end of listing or error
      // return what we have
      debugPrint('Stream error or end: $e');
    }

    // draw's stream logic handles fetching.
    // We rely on nextAfterToken being set to the fullname of the last item in the stream loop.

    // We need 'fullname' (t3_xxxxx).
    // Our Post model 'id' might be just the id part.
    // Let's rely on the fact that for the next request, we need the fullname.
    // I can't easily get the 'fullname' from my Post model if it strips it.
    // I will check Post model again. it uses submission.id. `submission.id` is usually just the ID part.
    // `submission.fullname` is the full thing.
    // I'll grab the valid 'after' token from the last submission processed before converting/returning?
    // Actually, simpler: just return the fullname of the last submission we processed.

    // Since we consumed the stream, 'nextAfterToken' contains `fullname` of the last item if my loop set it.

    return (posts: posts, nextAfter: nextAfterToken);
  }

  Future<List<Comment>> fetchComments(String postId) async {
    final reddit = _reddit;
    if (reddit == null) {
      throw Exception('Not logged in');
    }

    try {
      final ref = reddit.submission(id: postId);
      // populate() fetches the data
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
}
