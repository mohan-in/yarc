import 'dart:async';
import 'dart:collection';

import 'package:draw/draw.dart' as draw;
import 'package:flutter/foundation.dart';
import 'package:yarc/models/models.dart';
import 'package:yarc/notifiers/settings_notifier.dart';
import 'package:yarc/repositories/post_repository.dart';

/// Notifier for managing the post feed.
class FeedNotifier extends ChangeNotifier {
  FeedNotifier() {
    _saveSub = _saveEvents.stream.listen((event) {
      _updatePostSaveStatus(event.$1, event.$2);
    });
  }

  // Instance-level broadcast stream so each FeedNotifier manages its own
  // save-event lifecycle. A static stream would never be closed, leaking
  // memory across hot-reloads and polluting unrelated test instances.
  final StreamController<(String, bool)> _saveEvents =
      StreamController.broadcast();
  StreamSubscription<(String, bool)>? _saveSub;

  @override
  void dispose() {
    final cancelFuture = _saveSub?.cancel();
    if (cancelFuture != null) {
      unawaited(cancelFuture);
    }
    unawaited(_saveEvents.close());
    super.dispose();
  }

  PostRepository? _repository;

  SettingsNotifier? _settings;

  List<Post> _posts = [];
  bool _isLoading = false;
  String? _currentSubreddit;
  Subreddit? _currentSubredditInfo;

  /// Set when the feed is showing a user's profile posts.
  String? _profileUsername;

  /// Set when the feed is showing a custom feed (multireddit).
  String? _currentCustomFeedPath;
  String? _currentCustomFeedName;

  /// True when the feed shows the current user's saved posts.
  bool _savedMode = false;
  String? _after;
  Set<String> _readPostIds = {};
  Set<String> _hiddenPostIds = {};
  FeedSort _currentSort = FeedSort.best;
  draw.TimeFilter _currentTimeFilter = draw.TimeFilter.day;
  String? _errorMessage;

  /// Cached filtered list, invalidated by [_invalidateVisiblePosts].
  List<Post>? _cachedVisiblePosts;

  List<Post> get posts => _posts;
  bool get isLoading => _isLoading;
  String? get currentSubreddit => _currentSubreddit;
  Subreddit? get currentSubredditInfo => _currentSubredditInfo;
  String? get currentCustomFeedPath => _currentCustomFeedPath;
  String? get currentCustomFeedName => _currentCustomFeedName;

  /// Derived directly from SettingsNotifier — single source of truth.
  bool get hideRead => _settings?.hideReadPosts ?? false;

  Set<String> get readPostIds => UnmodifiableSetView(_readPostIds);
  FeedSort get currentSort => _currentSort;
  draw.TimeFilter get currentTimeFilter => _currentTimeFilter;
  String? get errorMessage => _errorMessage;

  /// Returns filtered posts based on hideRead flag and NSFW status.
  /// Cached to avoid creating a new list on every Selector evaluation.
  List<Post> get visiblePosts {
    if (_cachedVisiblePosts != null) {
      return _cachedVisiblePosts!;
    }

    final hideNsfw = _settings?.hideNsfw ?? true;
    final safePosts = hideNsfw ? _posts.where((p) => !p.isNsfw) : _posts;
    final savedFiltered = _savedMode
        ? safePosts.where((p) => p.isSaved)
        : safePosts;

    if (!hideRead) {
      _cachedVisiblePosts = savedFiltered.toList();
    } else {
      _cachedVisiblePosts = savedFiltered
          .where((p) => !_hiddenPostIds.contains(p.id))
          .toList();
    }
    return _cachedVisiblePosts!;
  }

  void _invalidateVisiblePosts() {
    _cachedVisiblePosts = null;
  }

  /// Sets the repository. Called by ProxyProvider.
  void setRepository(PostRepository repository) {
    _repository = repository;
    // If selectUserProfile() was called before the repository was ready,
    // trigger the deferred initial load now.
    if (_profileUsername != null && _posts.isEmpty && !_isLoading) {
      unawaited(loadPosts());
    }
  }

  /// Sets the settings notifier. Called by ProxyProvider whenever
  /// SettingsNotifier notifies — keeps FeedNotifier in sync automatically.
  void setSettings(SettingsNotifier settings) {
    final wasFirstLoad = _settings == null;
    _settings = settings;
    if (wasFirstLoad) {
      // Only apply defaultSort on first load to avoid clobbering
      // an in-session sort change made by the user.
      _currentSort = settings.defaultSort;
    }
    // hideRead is always derived from settings — no local copy needed.
    _invalidateVisiblePosts();
  }

  /// Changes the feed sort order and reloads posts.
  void setSort(FeedSort sort) {
    if (sort == _currentSort) {
      return;
    }
    _currentSort = sort;
    _posts = [];
    _after = null;
    _invalidateVisiblePosts();
    notifyListeners();
    unawaited(loadPosts());
  }

  /// Changes the time filter (for Top / Controversial) and reloads posts.
  void setTimeFilter(draw.TimeFilter filter) {
    if (filter == _currentTimeFilter) {
      return;
    }
    _currentTimeFilter = filter;
    _posts = [];
    _after = null;
    _invalidateVisiblePosts();
    notifyListeners();
    unawaited(loadPosts());
  }

  Future<void> loadPosts({bool refresh = false}) async {
    if (_repository == null || _isLoading) {
      return;
    }

    // On an explicit refresh, re-sync read IDs from the DB to pick up any
    // changes made in other sessions. On normal pagination the in-memory
    // set is already up-to-date (updated incrementally via markAsRead),
    // so scanning the entire Hive box on every page load is unnecessary.
    if (refresh) {
      final dbReadIds = _repository!.getReadPostIds();
      _readPostIds = {..._readPostIds, ...dbReadIds};
      if (hideRead) {
        _hiddenPostIds = Set.from(_readPostIds);
      }
    }
    _invalidateVisiblePosts();

    _isLoading = true;
    notifyListeners();

    if (_currentSubreddit != null &&
        !_currentSubreddit!.startsWith('u_') &&
        _currentSubredditInfo == null) {
      unawaited(
        _repository!.getSubredditInfo(_currentSubreddit!).then((info) {
          if (info != null && _currentSubreddit == info.displayName) {
            _currentSubredditInfo = info;
            notifyListeners();
          }
        }),
      );
    }

    try {
      final result = await _fetchResult(refresh: refresh);

      // Deduplicate posts when appending to
      // avoid "duplicate key" errors in lists
      final existingIds = _posts.map((p) => p.id).toSet();
      final uniqueNewPosts = result.posts
          .where((p) => !existingIds.contains(p.id))
          .toList();

      if (!refresh && hideRead) {
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
    } on Exception catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Picks the correct repository fetch based on the current feed mode.
  ///
  /// Extracted from [loadPosts] to replace an unreadable nested ternary and
  /// make each branch independently unit-testable.
  Future<PostsResult> _fetchResult({required bool refresh}) {
    // Branch 1: Saved-posts mode (always requires a logged-in username).
    if (_savedMode) {
      return _repository!.getSavedPosts(
        username: _profileUsername!,
        after: refresh ? null : _after,
      );
    }

    // Branch 2: User profile posts.
    if (_profileUsername != null) {
      return _repository!.getUserPosts(
        username: _profileUsername!,
        after: refresh ? null : _after,
        sort: _currentSort,
        timeFilter: _currentTimeFilter,
      );
    }

    // Branch 3: Regular subreddit / front-page / custom-feed posts.
    if (refresh) {
      return _repository!.refresh(
        subreddit: _currentSubreddit,
        customFeedPath: _currentCustomFeedPath,
        sort: _currentSort,
        timeFilter: _currentTimeFilter,
      );
    }
    return _repository!.getPosts(
      subreddit: _currentSubreddit,
      customFeedPath: _currentCustomFeedPath,
      after: _after,
      sort: _currentSort,
      timeFilter: _currentTimeFilter,
    );
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

  /// Resets all feed-selection state to neutral defaults.
  ///
  /// Every [select*] method calls this first, then overrides only the fields
  /// specific to its mode. This eliminates the copy-paste boilerplate that
  /// would otherwise appear across five methods.
  void _resetFeed() {
    _posts = [];
    _after = null;
    _currentSubreddit = null;
    _currentSubredditInfo = null;
    _currentCustomFeedPath = null;
    _currentCustomFeedName = null;
    _profileUsername = null;
    _savedMode = false;
    _isLoading = false;
    _invalidateVisiblePosts();
  }

  void selectSubreddit(String? subreddit) {
    _resetFeed();
    _currentSubreddit = subreddit;
    notifyListeners();
    unawaited(loadPosts());
  }

  void selectSubredditWithInfo(Subreddit subreddit) {
    _resetFeed();
    _currentSubreddit = subreddit.displayName;
    _currentSubredditInfo = subreddit;
    notifyListeners();
    unawaited(loadPosts());
  }

  /// Switches the feed to a custom feed (multireddit).
  void selectCustomFeed(CustomFeed feed) {
    _resetFeed();
    _currentCustomFeedPath = feed.path;
    _currentCustomFeedName = feed.displayName;
    notifyListeners();
    unawaited(loadPosts());
  }

  /// Switches the feed to a user's submitted posts.
  ///
  /// Load is deferred: if [_repository] is already set it starts immediately;
  /// otherwise [setRepository] will trigger it once the provider wires up.
  void selectUserProfile(String username) {
    _resetFeed();
    _profileUsername = username;
    notifyListeners();
    // Only load immediately if the repository is already available.
    if (_repository != null) {
      unawaited(loadPosts());
    }
    // Otherwise setRepository() will trigger the deferred load.
  }

  /// Switches the feed to the current user's saved posts.
  ///
  /// [username] must be the authenticated user's own Reddit username.
  void selectSavedPosts(String username) {
    _resetFeed();
    _profileUsername = username;
    _savedMode = true;
    notifyListeners();
    if (_repository != null) {
      unawaited(loadPosts());
    }
  }

  Future<void> toggleHideRead() async {
    if (_repository == null || _settings == null) {
      return;
    }

    // Write back to SettingsNotifier — this is the single source of truth.
    // The ProxyProvider will call setSettings() which invalidates the cache.
    final newValue = !hideRead;
    await _settings!.setHideReadPosts(newValue);

    if (newValue) {
      _hiddenPostIds = Set.from(_readPostIds);

      // Mark all currently loaded posts as read efficiently.
      final unreadIds = _posts
          .map((p) => p.id)
          .where(
            (id) => !_readPostIds.contains(id),
          )
          .toList();

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
      final dbReadIds = _repository!.getReadPostIds();
      _readPostIds = {..._readPostIds, ...dbReadIds};
      _hiddenPostIds.clear();
      _invalidateVisiblePosts();
      notifyListeners();
    }
  }

  Future<void> markAsRead(String postId) async {
    if (_repository == null || _readPostIds.contains(postId)) {
      return;
    }

    // Fast optimistic UI update — create a new set so Selector detects change
    _readPostIds = {..._readPostIds, postId};
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
    _currentCustomFeedPath = null;
    _currentCustomFeedName = null;
    _isLoading = false;
    // hideRead is derived from _settings — no local reset needed.
    _readPostIds = {};
    _hiddenPostIds = {};
    _currentSort = _settings?.defaultSort ?? FeedSort.best;
    _currentTimeFilter = draw.TimeFilter.day;
    _invalidateVisiblePosts();
    notifyListeners();
  }

  Future<void> toggleSave(Post post) async {
    final newStatus = !post.isSaved;

    // Optimistic UI update across all active feed notifiers
    _saveEvents.add((post.id, newStatus));

    try {
      if (newStatus) {
        await _repository?.savePost(post.id);
      } else {
        await _repository?.unsavePost(post.id);
      }
    } on Exception catch (e) {
      // Revert optimism globally if network call fails
      _saveEvents.add((post.id, !newStatus));
      _errorMessage = 'Failed to ${newStatus ? 'save' : 'unsave'} post: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Clears the current error message.
  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  void _updatePostSaveStatus(String postId, bool isSaved) {
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index != -1) {
      _posts[index] = _posts[index].copyWith(isSaved: isSaved);
      _invalidateVisiblePosts();
      notifyListeners();
    }
  }
}
