import 'package:flutter/foundation.dart';
import '../repositories/post_repository.dart';
import '../models/post.dart';
import '../models/subreddit.dart';

/// Notifier for managing the post feed.
class FeedNotifier extends ChangeNotifier {
  PostRepository? _repository;

  List<Post> _posts = [];
  bool _isLoading = false;
  String? _currentSubreddit;
  Subreddit? _currentSubredditInfo;
  String? _after;
  bool _hideRead = false;
  Set<String> _readPostIds = {};

  List<Post> get posts => _posts;
  bool get isLoading => _isLoading;
  String? get currentSubreddit => _currentSubreddit;
  Subreddit? get currentSubredditInfo => _currentSubredditInfo;
  bool get hideRead => _hideRead;
  Set<String> get readPostIds => _readPostIds;

  /// Returns filtered posts based on hideRead flag.
  List<Post> get visiblePosts {
    if (!_hideRead) {
      return _posts;
    }
    return _posts.where((p) => !_readPostIds.contains(p.id)).toList();
  }

  /// Sets the repository. Called by ProxyProvider.
  void setRepository(PostRepository repository) {
    _repository = repository;
  }

  /// Loads posts, optionally paginating.
  Future<void> loadPosts({bool refresh = false}) async {
    if (_repository == null || _isLoading) {
      return;
    }

    _readPostIds = await _repository!.getReadPostIds();

    _isLoading = true;
    notifyListeners();

    try {
      final result = refresh
          ? await _repository!.refresh(subreddit: _currentSubreddit)
          : await _repository!.getPosts(
              subreddit: _currentSubreddit,
              after: _after,
            );

      // Deduplicate posts when appending to avoid "duplicate key" errors in lists
      final existingIds = _posts.map((p) => p.id).toSet();
      final uniqueNewPosts = result.posts
          .where((p) => !existingIds.contains(p.id))
          .toList();

      _posts = refresh ? result.posts : [..._posts, ...uniqueNewPosts];
      _after = result.nextAfter;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refreshes the feed.
  Future<void> refresh() async {
    if (_repository == null) {
      return;
    }
    _after = null;
    notifyListeners();

    await loadPosts(refresh: true);
  }

  /// Switches to a specific subreddit.
  void selectSubreddit(String? subreddit) {
    _posts = [];
    _after = null;
    _currentSubreddit = subreddit;
    _currentSubredditInfo = null;
    _isLoading = false;
    notifyListeners();
    loadPosts();
  }

  /// Switches to a specific subreddit with full info.
  void selectSubredditWithInfo(Subreddit subreddit) {
    _posts = [];
    _after = null;
    _currentSubreddit = subreddit.displayName;
    _currentSubredditInfo = subreddit;
    _isLoading = false;
    notifyListeners();
    loadPosts();
  }

  /// Toggles hiding read posts.
  Future<void> toggleHideRead() async {
    if (_repository == null) {
      return;
    }
    _readPostIds = await _repository!.getReadPostIds();
    _hideRead = !_hideRead;
    notifyListeners();
  }

  /// Marks a post as read.
  Future<void> markAsRead(String postId) async {
    if (_repository == null) {
      return;
    }
    await _repository!.markAsRead(postId);
    _readPostIds = await _repository!.getReadPostIds();
    notifyListeners();
  }

  /// Clears the feed (e.g., on logout).
  void clear() {
    _posts = [];
    _after = null;
    _currentSubreddit = null;
    _currentSubredditInfo = null;
    _isLoading = false;
    _hideRead = false;
    _readPostIds = {};
    notifyListeners();
  }
}
