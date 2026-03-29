import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yarc/models/post.dart';
import 'package:yarc/notifiers/feed_notifier.dart';
import 'package:yarc/notifiers/settings_notifier.dart';
import 'package:yarc/repositories/post_repository.dart';
import 'package:yarc/screens/post_detail_screen.dart';
import 'package:yarc/widgets/post_list.dart';

/// Displays the currently authenticated user's saved posts.
///
/// Requires [username] — the Reddit username of the logged-in user —
/// so the correct API endpoint can be called.
class SavedPostsScreen extends StatelessWidget {
  const SavedPostsScreen({required this.username, super.key});

  final String username;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProxyProvider2<
      PostRepository,
      SettingsNotifier,
      FeedNotifier
    >(
      create: (_) => FeedNotifier()..selectSavedPosts(username),
      update: (_, repo, settings, notifier) => notifier!
        ..setRepository(repo)
        ..setSettings(settings),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Saved Posts'),
          centerTitle: false,
        ),
        body: Builder(
          builder: (feedContext) {
            final errorMessage = feedContext.select<FeedNotifier, String?>(
              (n) => n.errorMessage,
            );
            final posts = feedContext.select<FeedNotifier, List<Post>>(
              (n) => n.visiblePosts,
            );
            final isLoading = feedContext.select<FeedNotifier, bool>(
              (n) => n.isLoading,
            );

            return RefreshIndicator(
              onRefresh: () {
                feedContext.read<FeedNotifier>().clearError();
                return feedContext.read<FeedNotifier>().refresh();
              },
              color: Theme.of(context).colorScheme.primary,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
              displacement: 20,
              child: CustomScrollView(
                slivers: [
                  if (errorMessage != null && posts.isEmpty)
                    SliverFillRemaining(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Text(
                            errorMessage,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      ),
                    )
                  else if (posts.isEmpty && !isLoading)
                    const SliverFillRemaining(
                      child: Center(
                        child: Text('No saved posts found.'),
                      ),
                    )
                  else
                    _SavedPostsFeed(
                      postRepository: context.read<PostRepository>(),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SavedPostsFeed extends StatelessWidget {
  const _SavedPostsFeed({required this.postRepository});

  final PostRepository postRepository;

  @override
  Widget build(BuildContext context) {
    final isLoading = context.select<FeedNotifier, bool>((n) => n.isLoading);
    final posts = context.select<FeedNotifier, List<Post>>(
      (n) => n.visiblePosts,
    );
    final readPostIds = context.select<FeedNotifier, Set<String>>(
      (n) => n.readPostIds,
    );

    return SliverPostList(
      posts: posts,
      isLoading: isLoading,
      readPostIds: readPostIds,
      onPostVisible: (post) {
        unawaited(context.read<FeedNotifier>().markAsRead(post.id));
      },
      onPostTap: (post) {
        unawaited(
          Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (context) => PostDetailScreen(
                post: post,
                postRepository: postRepository,
              ),
            ),
          ),
        );
      },
    );
  }
}
