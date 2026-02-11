import 'package:hive_flutter/hive_flutter.dart';

/// Service for tracking read history locally using Hive.
class HistoryService {
  static const String _readPostsBoxName = 'read_posts';

  /// Initializes Hive.
  static Future<void> init() async {
    await Hive.initFlutter();
  }

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
