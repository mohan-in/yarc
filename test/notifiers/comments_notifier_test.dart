import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yarc/models/comment.dart';
import 'package:yarc/models/vote_type.dart';
import 'package:yarc/notifiers/comments_notifier.dart';

import '../helpers/mocks.dart';

void main() {
  late MockPostRepository mockPostRepository;
  late CommentsNotifier commentsNotifier;

  final sampleComment = Comment(
    id: 'c1',
    author: 'alice',
    body: 'hello world',
    ups: 5,
    createdUtc: DateTime.utc(2025),
    replies: [
      Comment(
        id: 'c2',
        author: 'bob',
        body: 'reply here',
        ups: 2,
        createdUtc: DateTime.utc(2025),
      ),
    ],
  );

  setUpAll(() {
    registerFallbackValue(VoteType.upvoted);
  });

  setUp(() {
    mockPostRepository = MockPostRepository();
    commentsNotifier = CommentsNotifier()..setRepository(mockPostRepository);
  });

  group('CommentsNotifier', () {
    test('loadComments fetches comments and notifies listeners', () async {
      when(
        () => mockPostRepository.getComments('post1'),
      ).thenAnswer((_) async => [sampleComment]);

      final comments = await commentsNotifier.loadComments('post1');

      expect(comments.length, 1);
      expect(commentsNotifier.comments.length, 1);
      expect(commentsNotifier.isLoading, isFalse);
      expect(commentsNotifier.errorMessage, isNull);
    });

    test(
      'voteComment optimistically updates root comment and calls repo',
      () async {
        when(
          () => mockPostRepository.getComments('post1'),
        ).thenAnswer((_) async => [sampleComment]);
        when(
          () => mockPostRepository.voteComment(
            commentId: 'c1',
            voteType: VoteType.upvoted,
          ),
        ).thenAnswer((_) async {});

        await commentsNotifier.loadComments('post1');
        await commentsNotifier.voteComment(sampleComment, VoteType.upvoted);

        expect(commentsNotifier.comments.first.voteType, VoteType.upvoted);
        expect(commentsNotifier.comments.first.ups, 6);
        verify(
          () => mockPostRepository.voteComment(
            commentId: 'c1',
            voteType: VoteType.upvoted,
          ),
        ).called(1);
      },
    );

    test('voteComment updates nested reply comment in tree', () async {
      when(
        () => mockPostRepository.getComments('post1'),
      ).thenAnswer((_) async => [sampleComment]);
      when(
        () => mockPostRepository.voteComment(
          commentId: 'c2',
          voteType: VoteType.downvoted,
        ),
      ).thenAnswer((_) async {});

      await commentsNotifier.loadComments('post1');
      final replyComment = sampleComment.replies.first;
      await commentsNotifier.voteComment(replyComment, VoteType.downvoted);

      expect(
        commentsNotifier.comments.first.replies.first.voteType,
        VoteType.downvoted,
      );
      expect(commentsNotifier.comments.first.replies.first.ups, 1);
    });

    test('voteComment reverts on repository exception', () async {
      when(
        () => mockPostRepository.getComments('post1'),
      ).thenAnswer((_) async => [sampleComment]);
      when(
        () => mockPostRepository.voteComment(
          commentId: any(named: 'commentId'),
          voteType: any(named: 'voteType'),
        ),
      ).thenThrow(Exception('Vote failed'));

      await commentsNotifier.loadComments('post1');
      await commentsNotifier.voteComment(sampleComment, VoteType.upvoted);

      expect(commentsNotifier.comments.first.voteType, VoteType.none);
      expect(commentsNotifier.comments.first.ups, 5);
      expect(commentsNotifier.errorMessage, contains('Failed to vote'));
    });

    test('clear resets comments and state', () async {
      when(
        () => mockPostRepository.getComments('post1'),
      ).thenAnswer((_) async => [sampleComment]);
      await commentsNotifier.loadComments('post1');

      commentsNotifier.clear();

      expect(commentsNotifier.comments, isEmpty);
      expect(commentsNotifier.currentPostId, isNull);
    });
  });
}
