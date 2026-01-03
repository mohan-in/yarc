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
      margin: const EdgeInsets.all(8.0),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 4),
              _buildTitle(context),
              if (post.content.isNotEmpty) _buildContent(context),
              const SizedBox(height: 8),
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
    return Row(
      children: [
        Text(
          'r/${post.subreddit}',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        Text(
          ' • u/${post.author}',
          style: Theme.of(context).textTheme.labelSmall,
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
    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: MarkdownContent(
        text: HtmlUtils.unescape(post.content),
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
            : ImageCarousel(imageUrls: post.images),
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
