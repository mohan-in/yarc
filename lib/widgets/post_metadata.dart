import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:yarc/models/post.dart';
import 'package:yarc/notifiers/feed_notifier.dart';
import 'package:yarc/utils/date_utils.dart';

/// A widget displaying post metadata:
/// time, comments, upvotes, and external link.
class PostMetadata extends StatelessWidget {
  const PostMetadata({
    required this.post,
    super.key,
  });

  final Post post;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          DateUtilsHelper.formatTimeAgo(post.createdUtc),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.share, size: 20),
              onPressed: () {
                unawaited(
                  SharePlus.instance.share(
                    ShareParams(
                      text: 'https://www.reddit.com${post.permalink}',
                    ),
                  ),
                );
              },
              tooltip: 'Share',
            ),
            Consumer<FeedNotifier>(
              builder: (context, feedNotifier, child) {
                return IconButton(
                  icon: Icon(
                    post.isSaved ? Icons.bookmark : Icons.bookmark_border,
                    size: 20,
                  ),
                  onPressed: () {
                    unawaited(feedNotifier.toggleSave(post));
                  },
                  tooltip: post.isSaved ? 'Unsave' : 'Save',
                );
              },
            ),
            const SizedBox(width: 16),
            const Icon(Icons.mode_comment_outlined, size: 16),
            const SizedBox(width: 4),
            Text('${post.numComments}'),
            const SizedBox(width: 16),
            const Icon(Icons.arrow_upward, size: 16),
            const SizedBox(width: 4),
            Text('${post.ups}'),
          ],
        ),
      ],
    );
  }
}
