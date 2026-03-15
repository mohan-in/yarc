import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:yarc/models/post.dart';
import 'package:yarc/models/subreddit.dart';
import 'package:yarc/repositories/post_repository.dart';

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
  Set<String> _hiddenPostIds = {};

  /// Cached filtered list, invalidated by [_invalidateVisiblePosts].
  List<Post>? _cachedVisiblePosts;

  List<Post> get posts => _posts;
  bool get isLoading => _isLoading;
  String? get currentSubreddit => _currentSubreddit;
  Subreddit? get currentSubredditInfo => _currentSubredditInfo;
  bool get hideRead => _hideRead;
  Set<String> get readPostIds => _readPostIds;

  /// Returns filtered posts based on hideRead flag.
  /// Cached to avoid creating a new list on every Selector evaluation.
  List<Post> get visiblePosts {
    if (_cachedVisiblePosts != null) {
      return _cachedVisiblePosts!;
    }
    if (!_hideRead) {
      _cachedVisiblePosts = _posts;
    } else {
      _cachedVisiblePosts = _posts
          .where((p) => !_hiddenPostIds.contains(p.id))
          .toList();
    }
    return _cachedVisiblePosts!;
  }

  void _invalidateVisiblePosts() {
    _cachedVisiblePosts = null;
  }

  /// Sets the repository. Called by ProxyProvider.
  // ignore: use_setters_to_change_properties
  void setRepository(PostRepository repository) {
    _repository = repository;
  }

  Future<void> loadPosts({bool refresh = false}) async {
    if (_repository == null || _isLoading) {
      return;
    }

    final dbReadIds = await _repository!.getReadPostIds();
    _readPostIds.addAll(dbReadIds);
    if (refresh && _hideRead) {
      _hiddenPostIds = Set.from(_readPostIds);
    }
    _invalidateVisiblePosts();

    _isLoading = true;
    notifyListeners();

    try {
      final result = refresh
          ? await _repository!.refresh(subreddit: _currentSubreddit)
          : await _repository!.getPosts(
              subreddit: _currentSubreddit,
              after: _after,
            );

      // Deduplicate posts when appending to
      // avoid "duplicate key" errors in lists
      final existingIds = _posts.map((p) => p.id).toSet();
      final uniqueNewPosts = result.posts
          .where((p) => !existingIds.contains(p.id))
          .toList();

      if (!refresh && _hideRead) {
        for (final p in uniqueNewPosts) {
          if (_readPostIds.contains(p.id)) {
            _hiddenPostIds.add(p.id);
          }
        }
      }

      _posts = refresh ? result.posts : [..._posts, ...uniqueNewPosts];
      _after = result.nextAfter;
      _isLoading = false;
      _invalidateVisiblePosts();
      notifyListeners();
    } on Exception catch (_) {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    if (_repository == null) {
      return;
    }
    _after = null;
    _invalidateVisiblePosts();
    notifyListeners();

    await loadPosts(refresh: true);
  }

  void selectSubreddit(String? subreddit) {
    _posts = [];
    _after = null;
    _currentSubreddit = subreddit;
    _currentSubredditInfo = null;
    _isLoading = false;
    _invalidateVisiblePosts();
    notifyListeners();
    unawaited(loadPosts());
  }

  void selectSubredditWithInfo(Subreddit subreddit) {
    _posts = [];
    _after = null;
    _currentSubreddit = subreddit.displayName;
    _currentSubredditInfo = subreddit;
    _isLoading = false;
    _invalidateVisiblePosts();
    notifyListeners();
    unawaited(loadPosts());
  }

  Future<void> toggleHideRead() async {
    if (_repository == null) {
      return;
    }

    _hideRead = !_hideRead;

    if (_hideRead) {
      _hiddenPostIds = Set.from(_readPostIds);

      // Mark all currently loaded posts as read efficiently.
      final unreadIds = _posts.map((p) => p.id).where(
            (id) => !_readPostIds.contains(id),
          ).toList();

      if (unreadIds.isNotEmpty) {
        // Optimistically update fast
        _readPostIds.addAll(unreadIds);
        _hiddenPostIds.addAll(unreadIds);
        _invalidateVisiblePosts();
        notifyListeners();
        
        // Persist in background
        await _repository!.markMultipleAsRead(unreadIds);
      } else {
        _invalidateVisiblePosts();
        notifyListeners();
      }

      // If no unread posts remain, load the next page.
      if (visiblePosts.isEmpty) {
        await loadPosts();
      }
    } else {
      final dbReadIds = await _repository!.getReadPostIds();
      _readPostIds.addAll(dbReadIds);
      _hiddenPostIds.clear();
      _invalidateVisiblePosts();
      notifyListeners();
    }
  }

  Future<void> markAsRead(String postId) async {
    if (_repository == null || _readPostIds.contains(postId)) {
      return;
    }
    
    // Fast optimistic UI update
    _readPostIds.add(postId);
    _invalidateVisiblePosts();
    notifyListeners();

    // Persist
    await _repository!.markAsRead(postId);
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
    _hiddenPostIds = {};
    _invalidateVisiblePosts();
    notifyListeners();
  }
}
