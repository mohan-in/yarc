import 'dart:async';
import 'dart:collection';

import 'package:draw/draw.dart' as draw;
import 'package:flutter/foundation.dart';
import 'package:yarc/models/feed_sort.dart';
import 'package:yarc/models/post.dart';
import 'package:yarc/models/subreddit.dart';
import 'package:yarc/notifiers/settings_notifier.dart';
import 'package:yarc/repositories/post_repository.dart';

/// Notifier for managing the post feed.
class FeedNotifier extends ChangeNotifier {
  PostRepository? _repository;

  SettingsNotifier? _settings;
  bool _isFirstSettingsLoad = true;

  List<Post> _posts = [];
  bool _isLoading = false;
  String? _currentSubreddit;
  Subreddit? _currentSubredditInfo;
  String? _after;
  bool _hideRead = false;
  Set<String> _readPostIds = {};
  Set<String> _hiddenPostIds = {};
  FeedSort _currentSort = FeedSort.best;
  draw.TimeFilter _currentTimeFilter = draw.TimeFilter.day;

  /// Cached filtered list, invalidated by [_invalidateVisiblePosts].
  List<Post>? _cachedVisiblePosts;

  List<Post> get posts => _posts;
  bool get isLoading => _isLoading;
  String? get currentSubreddit => _currentSubreddit;
  Subreddit? get currentSubredditInfo => _currentSubredditInfo;
  bool get hideRead => _hideRead;
  Set<String> get readPostIds => UnmodifiableSetView(_readPostIds);
  FeedSort get currentSort => _currentSort;
  draw.TimeFilter get currentTimeFilter => _currentTimeFilter;

  /// Returns filtered posts based on hideRead flag and NSFW status.
  /// Cached to avoid creating a new list on every Selector evaluation.
  List<Post> get visiblePosts {
    if (_cachedVisiblePosts != null) {
      return _cachedVisiblePosts!;
    }

    final hideNsfw = _settings?.hideNsfw ?? true;
    final safePosts = hideNsfw ? _posts.where((p) => !p.isNsfw) : _posts;

    if (!_hideRead) {
      _cachedVisiblePosts = safePosts.toList();
    } else {
      _cachedVisiblePosts = safePosts
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

  /// Sets the settings notifier. Called by ProxyProvider.
  void setSettings(SettingsNotifier settings) {
    _settings = settings;
    if (_isFirstSettingsLoad) {
      _currentSort = settings.defaultSort;
      _hideRead = settings.hideReadPosts;
      _isFirstSettingsLoad = false;
    }
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

    final dbReadIds = _repository!.getReadPostIds();
    _readPostIds = {..._readPostIds, ...dbReadIds};
    if (refresh && _hideRead) {
      _hiddenPostIds = Set.from(_readPostIds);
    }
    _invalidateVisiblePosts();

    _isLoading = true;
    notifyListeners();

    try {
      final result = refresh
          ? await _repository!.refresh(
              subreddit: _currentSubreddit,
              sort: _currentSort,
              timeFilter: _currentTimeFilter,
            )
          : await _repository!.getPosts(
              subreddit: _currentSubreddit,
              after: _after,
              sort: _currentSort,
              timeFilter: _currentTimeFilter,
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
    _isLoading = false;
    _hideRead = _settings?.hideReadPosts ?? false;
    _readPostIds = {};
    _hiddenPostIds = {};
    _currentSort = _settings?.defaultSort ?? FeedSort.best;
    _currentTimeFilter = draw.TimeFilter.day;
    _invalidateVisiblePosts();
    notifyListeners();
  }

  Future<void> toggleSave(Post post) async {
    final newStatus = !post.isSaved;

    // Optimistic UI update
    _updatePostSaveStatus(post.id, newStatus);

    try {
      if (newStatus) {
        await _repository?.savePost(post.id);
      } else {
        await _repository?.unsavePost(post.id);
      }
    } catch (e) {
      // Revert optimism if network call fails
      _updatePostSaveStatus(post.id, !newStatus);
      rethrow;
    }
  }

  void _updatePostSaveStatus(String postId, bool isSaved) {
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index != -1) {
      final oldPost = _posts[index];
      _posts[index] = Post(
        id: oldPost.id,
        title: oldPost.title,
        author: oldPost.author,
        subreddit: oldPost.subreddit,
        ups: oldPost.ups,
        numComments: oldPost.numComments,
        createdUtc: oldPost.createdUtc,
        permalink: oldPost.permalink,
        url: oldPost.url,
        thumbnail: oldPost.thumbnail,
        content: oldPost.content,
        images: oldPost.images,
        isVideo: oldPost.isVideo,
        videoUrl: oldPost.videoUrl,
        isYoutube: oldPost.isYoutube,
        youtubeId: oldPost.youtubeId,
        aspectRatio: oldPost.aspectRatio,
        crosspostParent: oldPost.crosspostParent,
        authorFlairText: oldPost.authorFlairText,
        linkFlairText: oldPost.linkFlairText,
        totalAwardsReceived: oldPost.totalAwardsReceived,
        isSaved: isSaved,
        isNsfw: oldPost.isNsfw,
        isStickied: oldPost.isStickied,
      );
      _invalidateVisiblePosts();
      notifyListeners();
    }
  }
}
