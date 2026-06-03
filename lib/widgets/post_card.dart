import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yarc/models/post.dart';
import 'package:yarc/notifiers/feed_notifier.dart';
import 'package:yarc/notifiers/settings_notifier.dart';
import 'package:yarc/utils/app_router.dart';
import 'package:yarc/widgets/cached_image.dart';
import 'package:yarc/widgets/flair_label.dart';
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
    this.isSelected = false,
  });

  final Post post;
  final VoidCallback? onTap;
  final bool expanded;
  final bool isRead;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: isSelected ? 4 : 2,
      clipBehavior: Clip.antiAlias,
      shape: isSelected
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: colorScheme.primary,
                width: 2,
              ),
            )
          : null,
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
              RepaintBoundary(child: _PostMedia(post: post)),
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
            GestureDetector(
              onTap: () {
                context.read<FeedNotifier>().selectSubreddit(post.subreddit);
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: Text(
                'r/${post.subreddit}',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
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
            unawaited(AppRouter.toUserProfile(context, post.author));
          },
          child: Text(
            ' • u/${post.author}',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary, // Make it look tappable
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if ((post.authorFlairText != null &&
                post.authorFlairText!.isNotEmpty) ||
            (post.authorFlairRichtext != null &&
                post.authorFlairRichtext!.isNotEmpty)) ...[
          const SizedBox(width: 4),
          FlairLabel(
            text: post.authorFlairText,
            richtext: post.authorFlairRichtext,
            backgroundColor: theme.colorScheme.tertiaryContainer,
            textColor: theme.colorScheme.onTertiaryContainer,
            borderRadius: 4,
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
        if ((post.linkFlairText != null && post.linkFlairText!.isNotEmpty) ||
            (post.linkFlairRichtext != null &&
                post.linkFlairRichtext!.isNotEmpty))
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: FlairLabel(
              text: post.linkFlairText,
              richtext: post.linkFlairRichtext,
              backgroundColor: theme.colorScheme.secondaryContainer,
              textColor: theme.colorScheme.onSecondaryContainer,
              borderRadius: 12,
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

    final Widget mediaWidget;
    // Badge shown when the post type warrants a visual label overlay.
    IconData? badgeIcon;
    String? badgeLabel;

    if (showVideo) {
      final autoPlay = context.select<SettingsNotifier, bool>(
        (n) => n.autoPlayVideos,
      );
      mediaWidget = RedditVideoPlayer(
        videoUrl: post.videoUrl!,
        autoPlay: autoPlay,
      );
    } else if (showYoutube) {
      mediaWidget = YouTubeEmbed(videoId: post.youtubeId!);
    } else if (post.images.isNotEmpty) {
      if (post.images.length == 1) {
        mediaWidget = CachedImage(
          imageUrl: post.images.first,
          fullScreenUrls: post.images,
        );
      } else {
        // Multi-image gallery — show a badge so users know there are more.
        mediaWidget = ImageCarousel(
          imageUrls: post.images,
          aspectRatio: post.aspectRatio,
        );
        badgeIcon = Icons.photo_library_outlined;
        badgeLabel = '${post.images.length}';
      }
    } else if (post.thumbnail != null) {
      mediaWidget = CachedImage(
        imageUrl: post.thumbnail!,
        fullScreenUrls: [post.thumbnail!],
      );
    } else {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: badgeIcon != null && badgeLabel != null
            ? Stack(
                children: [
                  mediaWidget,
                  Positioned(
                    top: 8,
                    left: 8,
                    child: _MediaBadge(icon: badgeIcon, label: badgeLabel),
                  ),
                ],
              )
            : mediaWidget,
      ),
    );
  }
}

class _MediaBadge extends StatelessWidget {
  const _MediaBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
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
            try {
              await launchUrl(
                uri,
                mode: useSystemBrowser
                    ? LaunchMode.externalApplication
                    : LaunchMode.platformDefault,
              );
            } on Exception catch (_) {
              // Ignore launch errors for unsupported URL schemes
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
