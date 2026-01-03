import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/service_locator.dart';
import '../models/post.dart';
import '../services/reddit_service.dart';
import '../services/post_cache_service.dart';

/// Represents the feed state.
class FeedState {
  final List<Post> posts;
  final bool isLoading;
  final bool isLoadingFromCache;
  final String? currentSubreddit;
  final String? after;
  final bool hideRead;
  final Set<String> readPostIds;

  const FeedState({
    this.posts = const [],
    this.isLoading = false,
    this.isLoadingFromCache = false,
    this.currentSubreddit,
    this.after,
    this.hideRead = false,
    this.readPostIds = const {},
  });

  FeedState copyWith({
    List<Post>? posts,
    bool? isLoading,
    bool? isLoadingFromCache,
    String? currentSubreddit,
    String? after,
    bool clearSubreddit = false,
    bool? hideRead,
    Set<String>? readPostIds,
  }) {
    return FeedState(
      posts: posts ?? this.posts,
      isLoading: isLoading ?? this.isLoading,
      isLoadingFromCache: isLoadingFromCache ?? this.isLoadingFromCache,
      currentSubreddit: clearSubreddit
          ? null
          : (currentSubreddit ?? this.currentSubreddit),
      after: after ?? this.after,
      hideRead: hideRead ?? this.hideRead,
      readPostIds: readPostIds ?? this.readPostIds,
    );
  }

  /// Returns filtered posts based on hideRead flag.
  List<Post> get visiblePosts {
    if (!hideRead) return posts;
    return posts.where((p) => !readPostIds.contains(p.id)).toList();
  }
}

/// Notifier for managing the post feed with caching.
class FeedNotifier extends Notifier<FeedState> {
  late final RedditService _redditService;
  late final PostCacheService _cacheService;

  @override
  FeedState build() {
    _redditService = getIt<RedditService>();
    _cacheService = getIt<PostCacheService>();
    return const FeedState();
  }

  /// Loads posts, optionally paginating with the current `after` cursor.
  Future<void> loadPosts({bool refresh = false}) async {
    if (state.isLoading) return;

    final isFirstLoad = state.posts.isEmpty && !refresh;

    // Load read post IDs for filtering
    final readIds = await _cacheService.getReadPostIds();
    state = state.copyWith(readPostIds: readIds);

    // Load from cache first for instant display
    if (isFirstLoad) {
      state = state.copyWith(isLoadingFromCache: true);
      final cached = await _cacheService.getCachedPosts(state.currentSubreddit);
      if (cached.isNotEmpty) {
        state = state.copyWith(posts: cached, isLoadingFromCache: false);
      } else {
        state = state.copyWith(isLoadingFromCache: false);
      }
    }

    state = state.copyWith(isLoading: true);

    try {
      final result = await _redditService.fetchPosts(
        subreddit: state.currentSubreddit,
        after: refresh ? null : state.after,
      );

      // Deduplicate posts when appending (prevents duplicates from race conditions)
      final existingIds = state.posts.map((p) => p.id).toSet();
      final uniqueNewPosts = result.posts
          .where((p) => !existingIds.contains(p.id))
          .toList();

      final newPosts = refresh
          ? result.posts
          : [...state.posts, ...uniqueNewPosts];

      // Update cache with fresh posts (only for first page)
      if (refresh || state.after == null) {
        await _cacheService.cachePosts(state.currentSubreddit, result.posts);
      }

      state = state.copyWith(
        posts: newPosts,
        after: result.nextAfter,
        isLoading: false,
        // hideRead is preserved (not passed, keeps current value)
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Refreshes the feed: shows cached posts while fetching fresh data.
  /// Preserves the hideRead filter state.
  Future<void> refresh() async {
    // Load cached posts for instant display while we fetch fresh data
    final cached = await _cacheService.getCachedPosts(state.currentSubreddit);
    state = state.copyWith(posts: cached.isNotEmpty ? cached : [], after: null);
    await loadPosts(refresh: true);
  }

  /// Switches to a specific subreddit.
  void selectSubreddit(String? subreddit) {
    state = FeedState(currentSubreddit: subreddit);
    loadPosts();
  }

  /// Toggles hiding read posts.
  Future<void> toggleHideRead() async {
    final readIds = await _cacheService.getReadPostIds();
    state = state.copyWith(hideRead: !state.hideRead, readPostIds: readIds);
  }

  /// Marks a post as read.
  Future<void> markAsRead(String postId) async {
    await _cacheService.markAsRead(postId);
    final readIds = await _cacheService.getReadPostIds();
    state = state.copyWith(readPostIds: readIds);
  }

  /// Clears the feed (e.g., on logout).
  void clear() {
    state = const FeedState();
  }
}

/// Provider for RedditService using get_it.
final redditServiceProvider = Provider<RedditService>((ref) {
  return getIt<RedditService>();
});

/// Provider for FeedNotifier using get_it.
final feedProvider = NotifierProvider<FeedNotifier, FeedState>(
  FeedNotifier.new,
);
