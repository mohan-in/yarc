import 'package:hive_flutter/hive_flutter.dart';

/// Service for tracking read history locally using Hive.
class HistoryService {
  static const String _readPostsBoxName = 'read_posts';
  static late final Box<bool> _box;

  /// Initializes Hive and opens the read-posts box once.
  static Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox<bool>(_readPostsBoxName);
  }

  /// Marks a post as read.
  Future<void> markAsRead(String postId) async {
    await _box.put(postId, true);
  }

  /// Marks multiple posts as read.
  Future<void> markMultipleAsRead(Iterable<String> postIds) async {
    final entries = {for (final id in postIds) id: true};
    await _box.putAll(entries);
  }

  /// Checks if a post has been read.
  bool isRead(String postId) {
    return _box.get(postId) ?? false;
  }

  /// Gets all read post IDs.
  Set<String> getReadPostIds() {
    return _box.keys.cast<String>().toSet();
  }

  /// Clears all read post tracking.
  Future<void> clearReadPosts() async {
    await _box.clear();
  }
}
