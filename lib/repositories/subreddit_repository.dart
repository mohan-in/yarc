import 'package:yarc/models/subreddit.dart';
import 'package:yarc/services/reddit_service.dart';

/// Repository for subreddit operations.
class SubredditRepository {
  SubredditRepository(this._redditService);

  final RedditService _redditService;

  /// Fetches the user's subscribed subreddits, sorted alphabetically.
  Future<List<Subreddit>> getSubscribed() async {
    final subs = await _redditService.fetchSubscribedSubreddits();
    subs.sort(
      (a, b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
    );
    return subs;
  }

  /// Searches for subreddits by name prefix.
  Future<List<Subreddit>> search(String query) async {
    if (query.length < 2) {
      return [];
    }
    return _redditService.searchSubreddits(query);
  }

  /// Subscribes to a subreddit by name.
  Future<void> subscribe(String subredditName) =>
      _redditService.subscribeToSubreddit(subredditName);

  /// Unsubscribes from a subreddit by name.
  Future<void> unsubscribe(String subredditName) =>
      _redditService.unsubscribeFromSubreddit(subredditName);
}
