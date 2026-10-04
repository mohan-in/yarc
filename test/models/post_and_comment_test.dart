import 'package:flutter_test/flutter_test.dart';
import 'package:yarc/models/comment.dart';
import 'package:yarc/models/post.dart';
import 'package:yarc/models/vote_type.dart';

void main() {
  group('Post model', () {
    test('toJson and fromJson preserves all fields', () {
      final post = Post(
        id: 'post_test',
        title: 'Title',
        author: 'author_x',
        subreddit: 'flutter',
        ups: 42,
        numComments: 8,
        permalink: '/r/flutter/comments/1',
        content: 'Selftext body',
        createdUtc: DateTime.utc(2025),
        thumbnail: 'https://thumb.png',
        imageUrl: 'https://img.png',
        images: const ['https://img1.png', 'https://img2.png'],
        url: 'https://link.com',
        isVideo: true,
        videoUrl: 'https://v.mp4',
        isYoutube: true,
        youtubeId: 'yt123',
        aspectRatio: 1.77,
        totalAwardsReceived: 3,
        isSaved: true,
        isStickied: true,
        voteType: VoteType.upvoted,
        authorFlairText: 'Dev',
        linkFlairText: 'Discussion',
        authorFlairRichtext: const [
          FlairItem(isEmoji: false, text: 'Dev'),
        ],
        linkFlairRichtext: const [
          FlairItem(isEmoji: true, emojiUrl: 'https://emoji.png'),
        ],
      );

      final json = post.toJson();
      final reconstructed = Post.fromJson(json);

      expect(reconstructed, equals(post));
      expect(reconstructed.voteType, VoteType.upvoted);
      expect(reconstructed.authorFlairRichtext?.length, 1);
      expect(reconstructed.linkFlairRichtext?.first.isEmoji, true);
    });

    test('copyWith updates fields correctly', () {
      final post = Post(
        id: 'p1',
        title: 'Original',
        author: 'author',
        subreddit: 'flutter',
        ups: 1,
        numComments: 0,
        permalink: '/r/flutter/1',
        content: '',
        createdUtc: DateTime.utc(2025),
      );

      final modified = post.copyWith(
        title: 'Updated',
        voteType: VoteType.downvoted,
        ups: -1,
      );

      expect(modified.title, 'Updated');
      expect(modified.voteType, VoteType.downvoted);
      expect(modified.ups, -1);
      expect(modified.author, 'author');
    });
  });

  group('Comment model', () {
    test(
      'toJson and fromJson preserves all fields including nested replies',
      () {
        final comment = Comment(
          id: 'c1',
          author: 'alice',
          body: 'Root comment',
          ups: 12,
          createdUtc: DateTime.utc(2025),
          voteType: VoteType.downvoted,
          replies: [
            Comment(
              id: 'c2',
              author: 'bob',
              body: 'Child comment',
              ups: 4,
              createdUtc: DateTime.utc(2025),
              voteType: VoteType.upvoted,
            ),
          ],
        );

        final json = comment.toJson();
        final reconstructed = Comment.fromJson(json);

        expect(reconstructed.id, 'c1');
        expect(reconstructed.voteType, VoteType.downvoted);
        expect(reconstructed.replies.length, 1);
        expect(reconstructed.replies.first.id, 'c2');
        expect(reconstructed.replies.first.voteType, VoteType.upvoted);
      },
    );

    test('copyWith updates fields correctly', () {
      final comment = Comment(
        id: 'c1',
        author: 'alice',
        body: 'Hello',
        ups: 0,
        createdUtc: DateTime.utc(2025),
      );

      final modified = comment.copyWith(
        ups: 5,
        voteType: VoteType.upvoted,
      );

      expect(modified.ups, 5);
      expect(modified.voteType, VoteType.upvoted);
    });
  });
}
