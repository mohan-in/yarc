import 'package:yarc/models/redditor_info.dart';
import 'package:yarc/services/reddit_service.dart';

/// Repository for user profile and account operations.
class UserRepository {
  UserRepository(this._redditService);

  final RedditService _redditService;

  /// Fetches a redditor's profile info by username.
  Future<RedditorInfo?> fetchUser(String username) =>
      _redditService.fetchUser(username);
}
