import 'package:flutter/material.dart';
import 'package:yarc/models/post.dart';
import 'package:yarc/utils/html_utils.dart';
import 'package:yarc/widgets/cached_image.dart';
import 'package:yarc/widgets/image_carousel.dart';
import 'package:yarc/widgets/markdown_content.dart';
import 'package:yarc/widgets/post_metadata.dart';
import 'package:yarc/widgets/video_player.dart';
import 'package:yarc/widgets/youtube_embed.dart';

/// A card widget that displays a summary of a [Post].
///
/// Shows title, author, subreddit, content preview, and images/thumbnails.
/// Supports tapping to view details via [onTap].
class PostCard extends StatelessWidget {
  const PostCard({
    required this.post,
    super.key,
    this.onTap,
    this.expanded = false,
  });

  final Post post;
  final VoidCallback? onTap;
  final bool expanded;

  /// Matches markdown image syntax: `![alt](url)`
  static final _markdownImageRegex = RegExp(r'!\[[^\]]*\]\([^)]+\)');

  /// Matches 3+ consecutive newlines for collapsing whitespace.
  static final _excessiveNewlinesRegex = RegExp(r'\n{3,}');

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PostHeader(post: post),
              const SizedBox(height: 8),
              _PostTitle(post: post),
              if (post.content.isNotEmpty) _buildContent(context),
              const SizedBox(height: 12),
              _PostMedia(post: post),
              PostMetadata(
                createdUtc: post.createdUtc,
                numComments: post.numComments,
                ups: post.ups,
                permalink: post.permalink,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    var content = HtmlUtils.unescape(post.content);

    final mediaUrls = <String>{...post.images};
    if (post.thumbnail != null) {
      mediaUrls.add(post.thumbnail!);
    }

    // Remove image URLs that match media URLs to prevent duplicates
    for (final url in mediaUrls) {
      final unescapedUrl = url.replaceAll('&amp;', '&');
      final escapedUrl = url.replaceAll('&', '&amp;');

      for (final urlVariant in [url, unescapedUrl, escapedUrl]) {
        // Remove markdown image syntax referencing this URL
        content = content.replaceAll(
          _markdownImageRegex,
          '',
        );
        content = content.replaceAll(urlVariant, '');
      }
      content = content.replaceAll(Uri.encodeFull(url), '');
    }

    content = content.replaceAll(_excessiveNewlinesRegex, '\n\n').trim();

    if (content.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: MarkdownContent(
        text: content,
        maxLines: expanded ? null : 3,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class _PostHeader extends StatelessWidget {
  const _PostHeader({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          'r/${post.subreddit}',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        Text(
          ' • u/${post.author}',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _PostTitle extends StatelessWidget {
  const _PostTitle({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    return Text(
      HtmlUtils.unescape(post.title),
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _PostMedia extends StatelessWidget {
  const _PostMedia({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    final showVideo = post.isVideo && post.videoUrl != null;
    final showYoutube = post.isYoutube && post.youtubeId != null;

    if (showVideo) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: GestureDetector(
          onTap: () {},
          child: RedditVideoPlayer(videoUrl: post.videoUrl!, autoPlay: true),
        ),
      );
    }

    if (showYoutube) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: GestureDetector(
          onTap: () {},
          child: YouTubeEmbed(videoId: post.youtubeId!),
        ),
      );
    }

    if (post.images.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: post.images.length == 1
            ? CachedImage(
                imageUrl: post.images.first,
                fullScreenUrls: post.images,
              )
            : ImageCarousel(
                imageUrls: post.images,
                aspectRatio: post.aspectRatio,
              ),
      );
    }

    if (post.thumbnail != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: CachedImage(
          imageUrl: post.thumbnail!,
          fullScreenUrls: [post.thumbnail!],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
