import 'package:hive_flutter/hive_flutter.dart';
import '../models/post.dart';
import '../models/post_hive_adapter.dart';

/// Service for caching posts locally using Hive.
class PostCacheService {
  static const String _postsBoxName = 'posts_cache';
  static const String _readPostsBoxName = 'read_posts';
  static const String _homeKey = '__home__';

  /// Initializes Hive and registers adapters.
  static Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(PostAdapter());
  }

  /// Returns the cache key for a subreddit (or home feed).
  static String _getKey(String? subreddit) {
    return subreddit ?? _homeKey;
  }

  /// Caches posts for a specific subreddit or home feed.
  Future<void> cachePosts(String? subreddit, List<Post> posts) async {
    final box = await Hive.openBox<List>(_postsBoxName);
    await box.put(_getKey(subreddit), posts);
  }

  /// Retrieves cached posts for a specific subreddit or home feed.
  Future<List<Post>> getCachedPosts(String? subreddit) async {
    final box = await Hive.openBox<List>(_postsBoxName);
    final cached = box.get(_getKey(subreddit));
    if (cached != null) {
      return cached.cast<Post>();
    }
    return [];
  }

  /// Clears all cached posts.
  Future<void> clearCache() async {
    final box = await Hive.openBox<List>(_postsBoxName);
    await box.clear();
  }

  // --- Read Posts Tracking ---

  /// Marks a post as read.
  Future<void> markAsRead(String postId) async {
    final box = await Hive.openBox<bool>(_readPostsBoxName);
    await box.put(postId, true);
  }

  /// Checks if a post has been read.
  Future<bool> isRead(String postId) async {
    final box = await Hive.openBox<bool>(_readPostsBoxName);
    return box.get(postId) ?? false;
  }

  /// Gets all read post IDs.
  Future<Set<String>> getReadPostIds() async {
    final box = await Hive.openBox<bool>(_readPostsBoxName);
    return box.keys.cast<String>().toSet();
  }

  /// Clears all read post tracking.
  Future<void> clearReadPosts() async {
    final box = await Hive.openBox<bool>(_readPostsBoxName);
    await box.clear();
  }
}
