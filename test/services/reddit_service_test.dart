import 'package:draw/draw.dart' as draw;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yarc/models/vote_type.dart';
import 'package:yarc/services/reddit_service.dart';

import '../helpers/mocks.dart';

void main() {
  late MockAuthService mockAuthService;
  late MockReddit mockReddit;
  late RedditService redditService;

  setUp(() {
    mockAuthService = MockAuthService();
    mockReddit = MockReddit();
    when(() => mockAuthService.reddit).thenReturn(mockReddit);
    when(() => mockAuthService.persistCredentials()).thenAnswer((_) async {});
    redditService = RedditService(mockAuthService);
  });

  group('RedditService', () {
    test('throws exception when reddit client is null', () async {
      when(() => mockAuthService.reddit).thenReturn(null);

      expect(
        () => redditService.votePost(
          postId: '123',
          voteType: VoteType.upvoted,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('votePost posts to api/vote/ with dir 1 for upvoted', () async {
      when(
        () => mockReddit.post(
          'api/vote/',
          {'id': 't3_123', 'dir': '1'},
          discardResponse: true,
        ),
      ).thenAnswer((_) async => null);

      await redditService.votePost(
        postId: '123',
        voteType: VoteType.upvoted,
      );

      verify(
        () => mockReddit.post(
          'api/vote/',
          {'id': 't3_123', 'dir': '1'},
          discardResponse: true,
        ),
      ).called(1);
    });

    test('votePost posts to api/vote/ with dir -1 for downvoted', () async {
      when(
        () => mockReddit.post(
          'api/vote/',
          {'id': 't3_456', 'dir': '-1'},
          discardResponse: true,
        ),
      ).thenAnswer((_) async => null);

      await redditService.votePost(
        postId: 't3_456',
        voteType: VoteType.downvoted,
      );

      verify(
        () => mockReddit.post(
          'api/vote/',
          {'id': 't3_456', 'dir': '-1'},
          discardResponse: true,
        ),
      ).called(1);
    });

    test('votePost posts to api/vote/ with dir 0 for none', () async {
      when(
        () => mockReddit.post(
          'api/vote/',
          {'id': 't3_789', 'dir': '0'},
          discardResponse: true,
        ),
      ).thenAnswer((_) async => null);

      await redditService.votePost(
        postId: '789',
        voteType: VoteType.none,
      );

      verify(
        () => mockReddit.post(
          'api/vote/',
          {'id': 't3_789', 'dir': '0'},
          discardResponse: true,
        ),
      ).called(1);
    });

    test('voteComment posts to api/vote/ with comment fullname', () async {
      when(
        () => mockReddit.post(
          'api/vote/',
          {'id': 't1_abc', 'dir': '1'},
          discardResponse: true,
        ),
      ).thenAnswer((_) async => null);

      await redditService.voteComment(
        commentId: 'abc',
        voteType: VoteType.upvoted,
      );

      verify(
        () => mockReddit.post(
          'api/vote/',
          {'id': 't1_abc', 'dir': '1'},
          discardResponse: true,
        ),
      ).called(1);
    });

    test('savePost posts to api/save/ with t3 prefix', () async {
      when(
        () => mockReddit.post(
          'api/save/',
          {'category': '', 'id': 't3_save1'},
          discardResponse: true,
        ),
      ).thenAnswer((_) async => null);

      await redditService.savePost('save1');

      verify(
        () => mockReddit.post(
          'api/save/',
          {'category': '', 'id': 't3_save1'},
          discardResponse: true,
        ),
      ).called(1);
    });

    test('unsavePost posts to api/unsave/ with t3 prefix', () async {
      when(
        () => mockReddit.post(
          'api/unsave/',
          {'id': 't3_unsave1'},
          discardResponse: true,
        ),
      ).thenAnswer((_) async => null);

      await redditService.unsavePost('unsave1');

      verify(
        () => mockReddit.post(
          'api/unsave/',
          {'id': 't3_unsave1'},
          discardResponse: true,
        ),
      ).called(1);
    });

    test(
      'retries on DRAWAuthenticationError and persists credentials',
      () async {
        var callCount = 0;
        when(
          () => mockReddit.post(
            'api/save/',
            any(),
            discardResponse: true,
          ),
        ).thenAnswer((_) async {
          callCount++;
          if (callCount == 1) {
            throw draw.DRAWAuthenticationError('401 Unauthorized');
          }
        });
        when(() => mockAuthService.refreshSession()).thenAnswer((_) async {});
        when(() => mockAuthService.isLoggedIn).thenReturn(true);
        when(
          () => mockAuthService.persistCredentials(),
        ).thenAnswer((_) async {});

        await redditService.savePost('retry_post');

        expect(callCount, 2);
        verify(() => mockAuthService.refreshSession()).called(1);
        verify(() => mockAuthService.persistCredentials()).called(1);
      },
    );
  });
}
