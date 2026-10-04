import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:hive/hive.dart';
import 'package:yarc/models/post.dart';
import 'package:yarc/utils/constants.dart';

/// Service responsible for persisting and retrieving feed posts offline.
class FeedCacheService {
  FeedCacheService(this._box);

  final Box<dynamic> _box;

  /// Opens the Hive box used for feed caching.
  static Future<Box<dynamic>> openBox() async {
    return Hive.openBox<dynamic>(kFeedCacheBoxName);
  }

  /// Caches a list of [posts] for the given [feedKey].
  Future<void> cachePosts(String feedKey, List<Post> posts) async {
    try {
      final limited = posts.take(kMaxCachedPostsPerFeed).toList();
      final jsonList = limited.map((p) => p.toJson()).toList();
      await _box.put(feedKey, jsonEncode(jsonList));
      developer.log(
        'Cached ${limited.length} posts for $feedKey',
        name: 'FeedCacheService',
      );
    } on Exception catch (e) {
      developer.log(
        'Failed to cache posts for $feedKey: $e',
        name: 'FeedCacheService',
      );
    }
  }

  /// Retrieves cached posts for the given [feedKey].
  List<Post> getCachedPosts(String feedKey) {
    try {
      final raw = _box.get(feedKey);
      if (raw is String) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded
              .whereType<Map<dynamic, dynamic>>()
              .map((m) => Post.fromJson(Map<String, dynamic>.from(m)))
              .toList();
        }
      } else if (raw is List) {
        return raw
            .whereType<Map<dynamic, dynamic>>()
            .map((m) => Post.fromJson(Map<String, dynamic>.from(m)))
            .toList();
      }
    } on Exception catch (e) {
      developer.log(
        'Failed to read cached posts for $feedKey: $e',
        name: 'FeedCacheService',
      );
    }
    return const [];
  }

  /// Clears all cached feed data.
  Future<void> clearCache() async {
    await _box.clear();
  }
}
