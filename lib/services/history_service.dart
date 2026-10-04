import 'package:hive_flutter/hive_flutter.dart';
import 'package:yarc/utils/constants.dart';

/// Service for tracking read history locally using Hive with LRU cap.
class HistoryService {
  HistoryService(this._box);

  static const String _readPostsBoxName = 'read_posts';
  final Box<dynamic> _box;

  /// Initializes Hive and opens the read-posts box once.
  static Future<Box<dynamic>> openBox() async {
    await Hive.initFlutter();
    return Hive.openBox<dynamic>(_readPostsBoxName);
  }

  /// Marks a post as read with current timestamp for LRU eviction.
  Future<void> markAsRead(String postId) async {
    await _box.put(postId, DateTime.now().millisecondsSinceEpoch);
    await _enforceCap();
  }

  /// Marks multiple posts as read.
  Future<void> markMultipleAsRead(Iterable<String> postIds) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final entries = {for (final id in postIds) id: now};
    await _box.putAll(entries);
    await _enforceCap();
  }

  /// Checks if a post has been read.
  bool isRead(String postId) {
    return _box.containsKey(postId);
  }

  /// Gets all read post IDs.
  Set<String> getReadPostIds() {
    return _box.keys.cast<String>().toSet();
  }

  /// Clears all read post tracking.
  Future<void> clearReadPosts() async {
    await _box.clear();
  }

  /// Enforces LRU eviction cap of [kMaxReadHistoryCount] entries.
  Future<void> _enforceCap() async {
    if (_box.length <= kMaxReadHistoryCount) {
      return;
    }
    final excess = _box.length - kMaxReadHistoryCount;
    final entries = _box.toMap().entries.toList()
      ..sort((a, b) {
        final aVal = a.value is int ? a.value as int : 0;
        final bVal = b.value is int ? b.value as int : 0;
        return aVal.compareTo(bVal);
      });
    final keysToDelete = entries.take(excess).map((e) => e.key).toList();
    await _box.deleteAll(keysToDelete);
  }
}
