import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yarc/models/post.dart';
import 'package:yarc/models/vote_type.dart';
import 'package:yarc/services/feed_cache_service.dart';

import '../helpers/mocks.dart';

void main() {
  late MockBox<dynamic> mockBox;
  late FeedCacheService cacheService;

  setUp(() {
    mockBox = MockBox<dynamic>();
    cacheService = FeedCacheService(mockBox);
  });

  group('FeedCacheService', () {
    final testPost = Post(
      id: 'post_1',
      title: 'Cached Title',
      author: 'author1',
      subreddit: 'flutter',
      ups: 42,
      numComments: 5,
      permalink: '/r/flutter/1',
      content: 'Hello cached world',
      createdUtc: DateTime.utc(2025),
      voteType: VoteType.upvoted,
    );

    test('cachePosts serializes posts and stores them in box', () async {
      when(
        () => mockBox.put(any<String>(), any<dynamic>()),
      ).thenAnswer((_) async {});

      await cacheService.cachePosts('home_hot', [testPost]);

      verify(
        () => mockBox.put(
          'home_hot',
          jsonEncode([testPost.toJson()]),
        ),
      ).called(1);
    });

    test('getCachedPosts parses JSON string from box', () {
      final jsonStr = jsonEncode([testPost.toJson()]);
      when(() => mockBox.get('home_hot')).thenReturn(jsonStr);

      final result = cacheService.getCachedPosts('home_hot');

      expect(result.length, 1);
      expect(result.first.id, 'post_1');
      expect(result.first.title, 'Cached Title');
      expect(result.first.voteType, VoteType.upvoted);
    });

    test('getCachedPosts returns empty list when key not found', () {
      when(() => mockBox.get('unknown')).thenReturn(null);

      final result = cacheService.getCachedPosts('unknown');

      expect(result, isEmpty);
    });

    test('getCachedPosts handles corrupt data gracefully', () {
      when(() => mockBox.get('corrupt')).thenReturn('{not valid json');

      final result = cacheService.getCachedPosts('corrupt');

      expect(result, isEmpty);
    });

    test('clearCache clears the box', () async {
      when(() => mockBox.clear()).thenAnswer((_) async => 0);

      await cacheService.clearCache();

      verify(() => mockBox.clear()).called(1);
    });
  });
}
