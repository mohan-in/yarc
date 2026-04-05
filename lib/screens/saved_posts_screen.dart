import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yarc/models/post.dart';
import 'package:yarc/notifiers/feed_notifier.dart';
import 'package:yarc/notifiers/settings_notifier.dart';
import 'package:yarc/repositories/post_repository.dart';
import 'package:yarc/screens/post_detail_screen.dart';
import 'package:yarc/widgets/widgets.dart';

/// Displays the currently authenticated user's saved posts.
///
/// Requires [username] — the Reddit username of the logged-in user —
/// so the correct API endpoint can be called.
class SavedPostsScreen extends StatefulWidget {
  const SavedPostsScreen({required this.username, super.key});

  final String username;

  @override
  State<SavedPostsScreen> createState() => _SavedPostsScreenState();
}

class _SavedPostsScreenState extends State<SavedPostsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProxyProvider2<
      PostRepository,
      SettingsNotifier,
      FeedNotifier
    >(
      create: (_) => FeedNotifier()..selectSavedPosts(widget.username),
      update: (_, repo, settings, notifier) => notifier!
        ..setRepository(repo)
        ..setSettings(settings),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Saved Posts'),
          centerTitle: false,
          actions: [
            UniversalAppBarActions(
              onScrollToTop: () {
                if (_scrollController.hasClients) {
                  unawaited(
                    _scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    ),
                  );
                }
              },
              showSort: false,
              showSearch: false,
            ),
          ],
        ),
        body: _SavedPostsBody(scrollController: _scrollController),
      ),
    );
  }
}

class _SavedPostsBody extends StatelessWidget {
  const _SavedPostsBody({required this.scrollController});

  final ScrollController scrollController;

  void _scrollListener(BuildContext context) {
    if (!scrollController.hasClients) return;

    final currentPosition = scrollController.position.pixels;
    final maxScroll = scrollController.position.maxScrollExtent;

    // Trigger pagination when close to bottom
    const threshold = 500.0;
    if (currentPosition >= maxScroll - threshold) {
      unawaited(context.read<FeedNotifier>().loadPosts());
    }
  }

  @override
  Widget build(BuildContext context) {
    final errorMessage = context.select<FeedNotifier, String?>(
      (n) => n.errorMessage,
    );
    final posts = context.select<FeedNotifier, List<Post>>(
      (n) => n.visiblePosts,
    );
    final isLoading = context.select<FeedNotifier, bool>(
      (n) => n.isLoading,
    );

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification) {
          _scrollListener(context);
        }
        return false;
      },
      child: RefreshIndicator(
        onRefresh: () {
          context.read<FeedNotifier>().clearError();
          return context.read<FeedNotifier>().refresh();
        },
        color: Theme.of(context).colorScheme.primary,
        backgroundColor: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest,
        displacement: 20,
        child: CustomScrollView(
          controller: scrollController,
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
