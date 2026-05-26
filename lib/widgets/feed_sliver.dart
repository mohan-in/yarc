import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yarc/models/models.dart';
import 'package:yarc/notifiers/feed_notifier.dart';
import 'package:yarc/repositories/post_repository.dart';
import 'package:yarc/utils/app_router.dart';
import 'package:yarc/widgets/post_list.dart';

/// A self-contained sliver that reads its own state from [FeedNotifier] and
/// renders a [SliverPostList].
///
/// Replaces the near-identical `_PostListBuilder`, `_UserProfileFeed`, and
/// `_SavedPostsFeed` widgets that previously lived inline in each screen.
///
/// The [postRepository] is forwarded to [AppRouter.toPostDetail] when no
/// custom [onPostTap] handler is provided.
///
/// Pass [selectedPostId] to highlight the active post in the wide
/// (master-detail) layout.
class FeedSliver extends StatelessWidget {
  const FeedSliver({
    required this.postRepository,
    this.onPostTap,
    this.selectedPostId,
    super.key,
  });

  final PostRepository postRepository;

  /// Optional tap handler. Defaults to navigating to the post detail screen.
  final void Function(Post post)? onPostTap;

  /// When non-null, the post with this ID is highlighted as selected
  /// (wide layout only).
  final String? selectedPostId;

  @override
  Widget build(BuildContext context) {
    // Single listener registration — one rebuild per notification.
    final (isLoading, posts, subredditInfo, readPostIds) = context
        .select<FeedNotifier, (bool, List<Post>, Subreddit?, Set<String>)>(
          (n) => (
            n.isLoading,
            n.visiblePosts,
            n.currentSubredditInfo,
            n.readPostIds,
          ),
        );

    return SliverPostList(
      posts: posts,
      isLoading: isLoading,
      subredditInfo: subredditInfo,
      readPostIds: readPostIds,
      selectedPostId: selectedPostId,
      onPostVisible: (post) {
        unawaited(context.read<FeedNotifier>().markAsRead(post.id));
      },
      onPostTap: (post) {
        final handler = onPostTap;
        if (handler != null) {
          handler(post);
        } else {
          unawaited(
            AppRouter.toPostDetail(
              context,
              post: post,
              postRepository: postRepository,
            ),
          );
        }
      },
    );
  }
}
