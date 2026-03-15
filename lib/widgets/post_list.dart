import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:yarc/models/post.dart';
import 'package:yarc/models/subreddit.dart';
import 'package:yarc/widgets/post_card.dart';
import 'package:yarc/widgets/subreddit_info_card.dart';

/// A sliver list of posts with infinite scroll support.
///
/// Must be used inside a [CustomScrollView].
class SliverPostList extends StatelessWidget {
  const SliverPostList({
    required this.posts,
    required this.isLoading,
    required this.onPostTap,
    required this.readPostIds,
    required this.onPostVisible,
    super.key,
    this.subredditInfo,
  });

  final List<Post> posts;
  final bool isLoading;
  final void Function(Post post) onPostTap;
  final Set<String> readPostIds;
  final void Function(Post post) onPostVisible;
  final Subreddit? subredditInfo;

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty && isLoading) {
      // If we have no posts and are loading, show a full-screen loader
      return const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // Determine if we need to show a header (Subreddit info)
    final hasHeader = subredditInfo != null;
    final headerCount = hasHeader ? 1 : 0;

    // Total items = Header (optional) + Posts + Loading Indicator (optional)
    final itemCount = headerCount + posts.length + (isLoading ? 1 : 0);

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        // 1. Render Header if it exists and is the first item
        if (hasHeader && index == 0) {
          return SubredditInfoCard(subreddit: subredditInfo!);
        }

        // Calculate the actual post index by subtracting offset
        final postIndex = index - headerCount;

        // 2. Render Loading Indicator at the very end
        if (postIndex == posts.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        // 3. Render Post Card
        final post = posts[postIndex];
        final isRead = readPostIds.contains(post.id);

        return VisibilityDetector(
          key: ValueKey('visibility_${post.id}'),
          onVisibilityChanged: (info) {
            // If the post is mostly visible and not yet read, mark it read.
            if (!isRead && info.visibleFraction > 0.5) {
              onPostVisible(post);
            }
          },
          child: PostCard(
            // Key helps Flutter efficiently update the list when items change
            key: ValueKey(post.id),
            post: post,
            isRead: isRead,
            onTap: () {
              // Ensure it's marked as read if tapped before scrolling
              // fully into view
              if (!isRead) onPostVisible(post);
              onPostTap(post);
            },
          ),
        );
      }, childCount: itemCount),
    );
  }
}
