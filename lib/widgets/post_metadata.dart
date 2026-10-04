import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:yarc/models/post.dart';
import 'package:yarc/models/vote_type.dart';
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
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.share, size: 18),
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
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                ),
                Consumer<FeedNotifier>(
                  builder: (context, feedNotifier, child) {
                    return IconButton(
                      icon: Icon(
                        post.isSaved ? Icons.bookmark : Icons.bookmark_border,
                        size: 18,
                      ),
                      onPressed: () {
                        unawaited(feedNotifier.toggleSave(post));
                      },
                      tooltip: post.isSaved ? 'Unsave' : 'Save',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 4),
                const Icon(Icons.mode_comment_outlined, size: 16),
                const SizedBox(width: 4),
                Text('${post.numComments}'),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(
                    post.voteType == VoteType.upvoted
                        ? Icons.arrow_upward
                        : Icons.arrow_upward_outlined,
                    size: 18,
                    color: post.voteType == VoteType.upvoted
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  onPressed: () {
                    unawaited(
                      context.read<FeedNotifier>().vote(post, VoteType.upvoted),
                    );
                  },
                  tooltip: 'Upvote',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                ),
                Text(
                  '${post.ups}',
                  style: TextStyle(
                    fontWeight: post.voteType != VoteType.none
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: post.voteType == VoteType.upvoted
                        ? Theme.of(context).colorScheme.primary
                        : (post.voteType == VoteType.downvoted
                              ? Theme.of(context).colorScheme.error
                              : null),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    post.voteType == VoteType.downvoted
                        ? Icons.arrow_downward
                        : Icons.arrow_downward_outlined,
                    size: 18,
                    color: post.voteType == VoteType.downvoted
                        ? Theme.of(context).colorScheme.error
                        : null,
                  ),
                  onPressed: () {
                    unawaited(
                      context.read<FeedNotifier>().vote(
                        post,
                        VoteType.downvoted,
                      ),
                    );
                  },
                  tooltip: 'Downvote',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
