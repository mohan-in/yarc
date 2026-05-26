import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yarc/models/post.dart';
import 'package:yarc/notifiers/feed_notifier.dart';
import 'package:yarc/notifiers/settings_notifier.dart';
import 'package:yarc/repositories/post_repository.dart';
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
              onScrollToTop: () => scrollToTop(_scrollController),
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

    return PaginatedScrollBody(
      controller: scrollController,
      onLoadMore: () => context.read<FeedNotifier>().loadPosts(),
      onRefresh: () {
        context.read<FeedNotifier>().clearError();
        return context.read<FeedNotifier>().refresh();
      },
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
    );
  }
}

class _SavedPostsFeed extends StatelessWidget {
  const _SavedPostsFeed({required this.postRepository});

  final PostRepository postRepository;

  @override
  Widget build(BuildContext context) {
    return FeedSliver(postRepository: postRepository);
  }
}
