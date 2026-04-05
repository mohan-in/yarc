import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yarc/models/post.dart';
import 'package:yarc/notifiers/settings_notifier.dart';
import 'package:yarc/screens/user_profile_screen.dart';
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
    this.isRead = false,
  });

  final Post post;
  final VoidCallback? onTap;
  final bool expanded;
  final bool isRead;

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
              _PostHeader(post: post, isRead: isRead),
              if (post.crosspostParent != null)
                _CrosspostIndicator(
                  originalSubreddit: post.crosspostParent!.subreddit,
                ),
              const SizedBox(height: 8),
              _PostTitle(post: post, isRead: isRead),
              if (post.url != null) _ExternalLink(url: post.url!),
              if (post.content.isNotEmpty)
                _PostContent(post: post, expanded: expanded),
              const SizedBox(height: 12),
              _PostMedia(post: post),
              PostMetadata(post: post),
            ],
          ),
        ),
      ),
    );
  }
}

/// Renders the post's text content with duplicate media URLs stripped out.
class _PostContent extends StatelessWidget {
  const _PostContent({required this.post, required this.expanded});

  final Post post;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    if (post.content.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: MarkdownContent(
        text: post.content,
        maxLines: expanded ? null : 3,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class _PostHeader extends StatelessWidget {
  const _PostHeader({
    required this.post,
    required this.isRead,
  });

  final Post post;
  final bool isRead;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (post.isStickied) ...[
          Icon(
            Icons.push_pin,
            size: 14,
            color: theme.colorScheme.tertiary,
          ),
          const SizedBox(width: 4),
        ],
        if (isRead) ...[
          Icon(
            Icons.check,
            size: 14,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 4),
        ],
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          children: [
            if (post.isNsfw)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'NSFW',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            Text(
              'r/${post.subreddit}',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            if (post.totalAwardsReceived > 0) ...[
              const SizedBox(width: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.workspace_premium,
                    size: 14,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${post.totalAwardsReceived}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        GestureDetector(
          onTap: () {
            unawaited(
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (context) =>
                      UserProfileScreen(username: post.author),
                ),
              ),
            );
          },
          child: Text(
            ' • u/${post.author}',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary, // Make it look tappable
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (post.authorFlairText != null &&
            post.authorFlairText!.isNotEmpty) ...[
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 4,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              post.authorFlairText!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onTertiaryContainer,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _PostTitle extends StatelessWidget {
  const _PostTitle({
    required this.post,
    required this.isRead,
  });

  final Post post;
  final bool isRead;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (post.linkFlairText != null && post.linkFlairText!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                post.linkFlairText!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
          ),
        Text(
          post.title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
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
      final autoPlay = context.select<SettingsNotifier, bool>(
        (n) => n.autoPlayVideos,
      );
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: RedditVideoPlayer(videoUrl: post.videoUrl!, autoPlay: autoPlay),
      );
    }

    if (showYoutube) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: YouTubeEmbed(videoId: post.youtubeId!),
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

class _ExternalLink extends StatelessWidget {
  const _ExternalLink({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final uri = Uri.tryParse(url);
    var displayHost = uri?.host.replaceFirst('www.', '');
    if (displayHost == null || displayHost.isEmpty) {
      displayHost = url;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () async {
          if (uri != null) {
            final useSystemBrowser = context
                .read<SettingsNotifier>()
                .useSystemBrowser;
            if (await canLaunchUrl(uri)) {
              await launchUrl(
                uri,
                mode: useSystemBrowser
                    ? LaunchMode.externalApplication
                    : LaunchMode.platformDefault,
              );
            }
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.link,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  displayHost,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CrosspostIndicator extends StatelessWidget {
  const _CrosspostIndicator({required this.originalSubreddit});

  final String originalSubreddit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(
            Icons.repeat,
            size: 14,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            'Crossposted from r/$originalSubreddit',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
