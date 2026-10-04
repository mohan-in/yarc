import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yarc/models/vote_type.dart';
import 'package:yarc/utils/html_utils.dart';
import 'package:yarc/utils/parsers/comment_parser.dart';
import 'package:yarc/utils/parsers/content_sanitizer.dart';
import 'package:yarc/utils/parsers/flair_parser.dart';
import 'package:yarc/utils/parsers/gallery_parser.dart';
import 'package:yarc/utils/parsers/media_extractor.dart';

import '../helpers/mocks.dart';

void main() {
  group('MediaExtractor', () {
    test('resolveDirectImageUrl prefers GIF/Giphy over static preview', () {
      expect(
        MediaExtractor.resolveDirectImageUrl(
          'https://media.giphy.com/media/123/giphy.gif',
          'https://preview.redd.it/preview.jpg',
        ),
        'https://media.giphy.com/media/123/giphy.gif',
      );
      expect(
        MediaExtractor.resolveDirectImageUrl(
          'https://example.com/test.gif',
          'https://preview.redd.it/preview.jpg',
        ),
        'https://example.com/test.gif',
      );
      expect(
        MediaExtractor.resolveDirectImageUrl(
          'https://example.com/image.png',
          null,
        ),
        'https://example.com/image.png',
      );
      expect(
        MediaExtractor.resolveDirectImageUrl(
          'https://example.com/image.png',
          'https://preview.redd.it/preview.jpg',
        ),
        'https://preview.redd.it/preview.jpg',
      );
    });

    test('extractImageFromPreview extracts url and aspect ratio', () {
      final data = {
        'preview': {
          'enabled': true,
          'images': [
            {
              'source': {
                'url': 'https://preview.redd.it/test.jpg?width=600&amp;s=abc',
                'width': 600,
                'height': 300,
              },
            },
          ],
        },
      };

      final result = MediaExtractor.extractImageFromPreview(data);
      expect(result, isNotNull);
      expect(
        result!.url,
        'https://preview.redd.it/test.jpg?width=600&s=abc',
      );
      expect(result.aspectRatio, 2.0);
    });

    test('extractImageFromPreview respects enabled flag on self-posts', () {
      final data = {
        'is_self': true,
        'preview': {
          'enabled': false,
          'images': [
            {
              'source': {'url': 'https://preview.redd.it/test.jpg'},
            },
          ],
        },
      };

      expect(MediaExtractor.extractImageFromPreview(data), isNull);
    });

    test('extractMp4FromPreview extracts mp4 variant', () {
      final data = {
        'preview': {
          'images': [
            {
              'variants': {
                'mp4': {
                  'source': {'url': 'https://preview.redd.it/test.mp4'},
                },
              },
            },
          ],
        },
      };

      expect(
        MediaExtractor.extractMp4FromPreview(data),
        'https://preview.redd.it/test.mp4',
      );
    });

    test('extractVideoUrl finds secure_media, media, or preview', () {
      expect(
        MediaExtractor.extractVideoUrl({
          'secure_media': {
            'reddit_video': {'hls_url': 'https://v.redd.it/video.m3u8'},
          },
        }),
        'https://v.redd.it/video.m3u8',
      );

      expect(
        MediaExtractor.extractVideoUrl({
          'media': {
            'reddit_video': {'fallback_url': 'https://v.redd.it/fallback.mp4'},
          },
        }),
        'https://v.redd.it/fallback.mp4',
      );

      expect(
        MediaExtractor.extractVideoUrl({
          'url': 'https://example.com/clip.mp4',
        }),
        'https://example.com/clip.mp4',
      );
    });

    test('extractYoutubeId extracts 11-char ID across YouTube URL formats', () {
      expect(
        MediaExtractor.extractYoutubeId({
          'domain': 'youtube.com',
          'url': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        }),
        'dQw4w9WgXcQ',
      );

      expect(
        MediaExtractor.extractYoutubeId({
          'domain': 'youtu.be',
          'url': 'https://youtu.be/dQw4w9WgXcQ',
        }),
        'dQw4w9WgXcQ',
      );

      expect(
        MediaExtractor.extractYoutubeId({
          'domain': 'youtube.com',
          'url': 'https://www.youtube.com/shorts/dQw4w9WgXcQ',
        }),
        'dQw4w9WgXcQ',
      );

      expect(
        MediaExtractor.extractYoutubeId({
          'domain': 'reddit.com',
          'url': 'https://reddit.com/r/flutter',
        }),
        isNull,
      );
    });
  });

  group('GalleryParser', () {
    test('parses gallery items and aspect ratio', () {
      final images = <String>[];
      final data = {
        'gallery_data': {
          'items': [
            {'media_id': 'item1'},
            {'media_id': 'item2'},
          ],
        },
        'media_metadata': {
          'item1': {
            'status': 'valid',
            'e': 'Image',
            's': {
              'u': 'https://preview.redd.it/item1.jpg',
              'x': 800,
              'y': 600,
            },
          },
          'item2': {
            'status': 'valid',
            'e': 'Image',
            's': {
              'u': 'https://preview.redd.it/item2.jpg',
              'x': 400,
              'y': 400,
            },
          },
        },
      };

      final ratio = GalleryParser.parse(data, images);
      expect(images, [
        'https://preview.redd.it/item1.jpg',
        'https://preview.redd.it/item2.jpg',
      ]);
      expect(ratio, closeTo(800 / 600, 0.01));
    });

    test('returns null for missing gallery data', () {
      final images = <String>[];
      expect(GalleryParser.parse({}, images), isNull);
      expect(images, isEmpty);
    });
  });

  group('FlairParser', () {
    test('parseRichtext parses emoji and text segments', () {
      final richtext = [
        {'e': 'text', 't': 'Hello '},
        {'e': 'emoji', 'u': 'https://emoji.redditmedia.com/snoo.png'},
        {'e': 'text', 't': ' World'},
      ];

      final items = FlairParser.parseRichtext(richtext);
      expect(items, isNotNull);
      expect(items!.length, 3);
      expect(items[0].isEmoji, false);
      expect(items[0].text, 'Hello ');
      expect(items[1].isEmoji, true);
      expect(items[1].emojiUrl, 'https://emoji.redditmedia.com/snoo.png');
      expect(items[2].isEmoji, false);
      expect(items[2].text, ' World');
    });

    test('cleanText removes :emoji: shortcodes and trims whitespace', () {
      expect(
        FlairParser.cleanText(':flutter: Discussion :dart:'),
        'Discussion',
      );
      expect(FlairParser.cleanText(':only_emoji:'), isNull);
      expect(FlairParser.cleanText('Clean Text'), 'Clean Text');
    });
  });

  group('ContentSanitizer', () {
    test('sanitize removes known media URLs and markdown images', () {
      const content = '''
Check out this image:
![alt](https://i.redd.it/sample.jpg)

Here is some text.
https://i.redd.it/sample.jpg



Extra blank lines.
''';

      final sanitized = ContentSanitizer.sanitize(
        content,
        ['https://i.redd.it/sample.jpg'],
        null,
      );

      expect(sanitized.contains('https://i.redd.it/sample.jpg'), false);
      expect(sanitized.contains('![alt]'), false);
      expect(sanitized.contains('\n\n\n'), false);
      expect(sanitized.contains('Check out this image:'), true);
      expect(sanitized.contains('Extra blank lines.'), true);
    });

    test('extractSelftextImages extracts direct URLs into list', () {
      const selftext =
          'Look here: https://example.com/pic.jpg and https://preview.redd.it/xyz';
      final images = <String>[];

      ContentSanitizer.extractSelftextImages(selftext, images);

      expect(images, contains('https://example.com/pic.jpg'));
      expect(images, contains('https://preview.redd.it/xyz'));
    });
  });

  group('CommentParser', () {
    test('parses DRAW Comment into domain Comment with voteType', () {
      final mockComment = MockComment();
      when(() => mockComment.id).thenReturn('c123');
      when(() => mockComment.author).thenReturn('alice');
      when(() => mockComment.body).thenReturn('Hello world');
      when(() => mockComment.upvotes).thenReturn(15);
      when(() => mockComment.createdUtc).thenReturn(DateTime.utc(2025));
      when(() => mockComment.replies).thenReturn(null);
      when(() => mockComment.data).thenReturn({'likes': true});

      final comment = CommentParser.parse(mockComment);

      expect(comment.id, 'c123');
      expect(comment.author, 'alice');
      expect(comment.body, 'Hello world');
      expect(comment.ups, 15);
      expect(comment.voteType, VoteType.upvoted);
    });

    test('parses downvoted DRAW Comment correctly', () {
      final mockComment = MockComment();
      when(() => mockComment.id).thenReturn('c456');
      when(() => mockComment.author).thenReturn('bob');
      when(() => mockComment.body).thenReturn('Downvoted comment');
      when(() => mockComment.upvotes).thenReturn(-2);
      when(() => mockComment.createdUtc).thenReturn(DateTime.utc(2025));
      when(() => mockComment.replies).thenReturn(null);
      when(() => mockComment.data).thenReturn({'likes': false});

      final comment = CommentParser.parse(mockComment);

      expect(comment.voteType, VoteType.downvoted);
    });
  });

  group('HtmlUtils', () {
    test('unescape decodes named entities', () {
      expect(
        HtmlUtils.unescape(
          'Tom &amp; Jerry &lt;3 &quot;cartoons&quot; &#39;fun&#39;',
        ),
        'Tom & Jerry <3 "cartoons" \'fun\'',
      );
    });

    test('unescape decodes decimal and hexadecimal numeric entities', () {
      expect(
        HtmlUtils.unescape('&#65;&#66;&#67; &#x44;&#x45;&#x46;'),
        'ABC DEF',
      );
    });

    test('unescape returns unchanged when no ampersand present', () {
      expect(HtmlUtils.unescape('plain text 123'), 'plain text 123');
    });

    test('resolveGiphyShortcodes formats giphy links to markdown', () {
      expect(
        HtmlUtils.resolveGiphyShortcodes(
          '[giphy:abc123XYZ:downsized](https://giphy.com)',
        ),
        '![](https://media.giphy.com/media/abc123XYZ/giphy.gif)',
      );
    });
  });
}
