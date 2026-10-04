import 'package:draw/draw.dart' as draw;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yarc/models/models.dart';
import 'package:yarc/repositories/post_repository.dart';

import '../helpers/mocks.dart';

void main() {
  late MockRedditService mockReddit;
  late MockHistoryService mockHistory;
  late MockFeedCacheService mockCache;
  late PostRepository repository;

  final samplePost = Post(
    id: 'p1',
    title: 'Post 1',
    author: 'user1',
    subreddit: 'flutter',
    ups: 10,
    numComments: 2,
    permalink: '/r/flutter/p1',
    content: 'content',
    createdUtc: DateTime.utc(2025),
  );

  setUpAll(() {
    registerFallbackValue(FeedSort.hot);
    registerFallbackValue(draw.TimeFilter.day);
    registerFallbackValue(VoteType.upvoted);
  });

  setUp(() {
    mockReddit = MockRedditService();
    mockHistory = MockHistoryService();
    mockCache = MockFeedCacheService();
    repository = PostRepository(mockReddit, mockHistory, mockCache);
  });

  group('PostRepository', () {
    test(
      'getPosts fetches from reddit service and caches first page',
      () async {
        when(
          () => mockReddit.fetchPosts(
            subreddit: any(named: 'subreddit'),
            customFeedPath: any(named: 'customFeedPath'),
            after: any(named: 'after'),
            sort: any(named: 'sort'),
            timeFilter: any(named: 'timeFilter'),
          ),
        ).thenAnswer((_) async => (posts: [samplePost], nextAfter: 'after_1'));

        when(
          () => mockCache.cachePosts(any(), any()),
        ).thenAnswer((_) async {});

        final result = await repository.getPosts(subreddit: 'flutter');

        expect(result.posts.length, 1);
        expect(result.nextAfter, 'after_1');
        verify(
          () => mockCache.cachePosts('flutter_hot', [samplePost]),
        ).called(1);
      },
    );

    test('getCachedPosts delegates to FeedCacheService', () {
      when(
        () => mockCache.getCachedPosts('flutter_hot'),
      ).thenReturn([samplePost]);

      final cached = repository.getCachedPosts(subreddit: 'flutter');

      expect(cached.length, 1);
      expect(cached.first.id, 'p1');
    });

    test('votePost delegates to RedditService', () async {
      when(
        () => mockReddit.votePost(
          postId: 'p1',
          voteType: VoteType.upvoted,
        ),
      ).thenAnswer((_) async {});

      await repository.votePost(postId: 'p1', voteType: VoteType.upvoted);

      verify(
        () => mockReddit.votePost(
          postId: 'p1',
          voteType: VoteType.upvoted,
        ),
      ).called(1);
    });

    test('voteComment delegates to RedditService', () async {
      when(
        () => mockReddit.voteComment(
          commentId: 'c1',
          voteType: VoteType.downvoted,
        ),
      ).thenAnswer((_) async {});

      await repository.voteComment(
        commentId: 'c1',
        voteType: VoteType.downvoted,
      );

      verify(
        () => mockReddit.voteComment(
          commentId: 'c1',
          voteType: VoteType.downvoted,
        ),
      ).called(1);
    });

    test('markAsRead and getReadPostIds delegate to HistoryService', () async {
      when(() => mockHistory.markAsRead('p1')).thenAnswer((_) async {});
      when(() => mockHistory.getReadPostIds()).thenReturn({'p1'});

      await repository.markAsRead('p1');
      final ids = repository.getReadPostIds();

      verify(() => mockHistory.markAsRead('p1')).called(1);
      expect(ids, {'p1'});
    });

    test('getComments delegates to RedditService', () async {
      final sampleComment = Comment(
        id: 'c1',
        author: 'u1',
        body: 'hello',
        ups: 1,
        createdUtc: DateTime.utc(2025),
      );
      when(
        () => mockReddit.fetchComments('p1'),
      ).thenAnswer((_) async => [sampleComment]);

      final comments = await repository.getComments('p1');

      expect(comments.length, 1);
      expect(comments.first.id, 'c1');
    });
  });
}
