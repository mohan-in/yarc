import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yarc/models/post.dart';
import 'package:yarc/notifiers/feed_notifier.dart';
import 'package:yarc/notifiers/settings_notifier.dart';
import 'package:yarc/notifiers/video_autoplay_notifier.dart';
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
        body: const _SavedPostsBody(),
      ),
    );
  }
}

class _SavedPostsBody extends StatefulWidget {
  const _SavedPostsBody();

  @override
  State<_SavedPostsBody> createState() => _SavedPostsBodyState();
}

class _SavedPostsBodyState extends State<_SavedPostsBody> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    // Trigger an initial autoplay check after the first frame so that
    // videos already in the viewport on screen load will start playing
    // without requiring the user to scroll first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Reset stale state from the previous screen so the sticky guard
        // doesn't block the first video on this screen.
        context.read<VideoAutoplayNotifier>().reset();
        context.read<VideoAutoplayNotifier>().notifyScroll();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (!_scrollController.hasClients) return;

    final currentPosition = _scrollController.position.pixels;
    final maxScroll = _scrollController.position.maxScrollExtent;

    // Trigger pagination when close to bottom
    const threshold = 500.0;
    if (currentPosition >= maxScroll - threshold) {
      unawaited(context.read<FeedNotifier>().loadPosts());
    }

    // Video autoplay check
    context.read<VideoAutoplayNotifier>().notifyScroll();
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

    return RefreshIndicator(
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
        controller: _scrollController,
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
