import 'package:flutter/material.dart';
import '../models/post.dart';
import '../utils/html_utils.dart';
import 'image_carousel.dart';
import 'markdown_content.dart';
import 'cached_image.dart';
import 'post_metadata.dart';
import 'video_player.dart';
import 'youtube_embed.dart';

/// A card widget that displays a summary of a [Post].
///
/// Shows title, author, subreddit, content preview, and images/thumbnails.
/// Supports tapping to view details via [onTap].
class PostCard extends StatelessWidget {
  final Post post;
  final VoidCallback? onTap;
  final bool expanded;

  const PostCard({
    super.key,
    required this.post,
    this.onTap,
    this.expanded = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 8),
              _buildTitle(context),
              if (post.content.isNotEmpty) _buildContent(context),
              const SizedBox(height: 12),
              _buildMedia(),
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

  Widget _buildHeader(BuildContext context) {
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

  Widget _buildTitle(BuildContext context) {
    return Text(
      HtmlUtils.unescape(post.title),
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
    );
  }

  Widget _buildContent(BuildContext context) {
    String content = HtmlUtils.unescape(post.content);

    final Set<String> mediaUrls = {...post.images};
    if (post.thumbnail != null) {
      mediaUrls.add(post.thumbnail!);
    }

    // Remove image URLs that match media URLs to prevent duplicates
    for (final url in mediaUrls) {
      final unescapedUrl = url.replaceAll('&amp;', '&');
      final escapedUrl = url.replaceAll('&', '&amp;');

      for (final urlVariant in [url, unescapedUrl, escapedUrl]) {
        content = content.replaceAll(
          RegExp(r'!\[[^\]]*\]\(' + RegExp.escape(urlVariant) + r'\)'),
          '',
        );
        content = content.replaceAll(urlVariant, '');
      }
      content = content.replaceAll(Uri.encodeFull(url), '');
    }

    content = content.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();

    if (content.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: MarkdownContent(
        text: content,
        maxLines: expanded ? null : 3,
        overflow: expanded ? null : TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }

  Widget _buildMedia() {
    final bool showVideo = post.isVideo && post.videoUrl != null;
    final bool showYoutube = post.isYoutube && post.youtubeId != null;

    if (showVideo) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: GestureDetector(
          onTap: () {},
          child: RedditVideoPlayer(videoUrl: post.videoUrl!, autoPlay: true),
        ),
      );
    }

    if (showYoutube) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: GestureDetector(
          onTap: () {},
          child: YouTubeEmbed(videoId: post.youtubeId!),
        ),
      );
    }

    if (post.images.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
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
        padding: const EdgeInsets.only(bottom: 8.0),
        child: CachedImage(
          imageUrl: post.thumbnail!,
          fullScreenUrls: [post.thumbnail!],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
