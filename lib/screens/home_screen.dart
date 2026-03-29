import 'dart:async';

import 'package:draw/draw.dart' as draw;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yarc/models/models.dart';
import 'package:yarc/notifiers/notifiers.dart';
import 'package:yarc/repositories/repositories.dart';
import 'package:yarc/screens/post_detail_screen.dart';
import 'package:yarc/screens/saved_posts_screen.dart';
import 'package:yarc/utils/utils.dart';
import 'package:yarc/widgets/widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();

  double _lastPrecachePosition = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    // PostFrameCallback ensures we
    // have access to Providers after the first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_initializeAuth());
    });
  }

  Future<void> _initializeAuth() async {
    // context.read() is used to access providers without listening to changes
    final authNotifier = context.read<AuthNotifier>();
    final feedNotifier = context.read<FeedNotifier>();
    final subredditsNotifier = context.read<SubredditsNotifier>();

    await authNotifier.init();
    if (authNotifier.isLoggedIn && mounted) {
      unawaited(feedNotifier.loadPosts());
      unawaited(subredditsNotifier.fetch());
    }
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

    // Image precaching (still UI/Rendering concern, but we can cleaner it up)
    // We can delegate this to FeedNotifier if we want strict separation,
    // but FeedNotifier shouldn't depend on context.
    // So we keep the trigger here.
    if ((currentPosition - _lastPrecachePosition).abs() >= 500) {
      _lastPrecachePosition = currentPosition;
      _precachePostImages();
    }
  }

  void _precachePostImages() {
    final feedNotifier = context.read<FeedNotifier>();
    final posts = feedNotifier.visiblePosts;

    FeedUtils.precachePostImages(
      context,
      posts,
      _scrollController.position.pixels,
    );
  }

  Future<void> _handleLogin() async {
    final authNotifier = context.read<AuthNotifier>();
    final error = await authNotifier.login();

    if (!mounted) {
      return;
    }

    if (error == null) {
      unawaited(context.read<FeedNotifier>().loadPosts());
      unawaited(context.read<SubredditsNotifier>().fetch());
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _handleLogout() async {
    await context.read<AuthNotifier>().logout();
    if (!mounted) {
      return;
    }
    context.read<FeedNotifier>().clear();
    context.read<SubredditsNotifier>().clear();
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      unawaited(
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        ),
      );
    }
  }

  Future<void> _openSearch(BuildContext context) async {
    final result = await showSearch<SearchResult?>(
      context: context,
      delegate: SubredditSearchDelegate(),
    );

    if (result == null || !context.mounted) {
      return;
    }

    if (result.subreddit != null) {
      context.read<FeedNotifier>().selectSubredditWithInfo(result.subreddit!);
    } else if (result.username != null) {
      // Navigate to the user's profile feed using the u_{username} subreddit.
      context.read<FeedNotifier>().selectSubreddit('u_${result.username}');
    }
  }

  Future<void> _handleRetry() async {
    final authNotifier = context.read<AuthNotifier>();
    final success = await authNotifier.tryReauthenticate();
    if (success && mounted) {
      unawaited(context.read<FeedNotifier>().loadPosts());
      unawaited(context.read<SubredditsNotifier>().fetch());
    }
  }

  @override
  Widget build(BuildContext context) {
    final postRepository = context.read<PostRepository>();

    return PopScope(
      canPop: context.select<FeedNotifier, bool>(
        (n) => n.currentSubreddit == null,
      ),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          final feedNotifier = context.read<FeedNotifier>();
          if (feedNotifier.currentSubreddit != null) {
            feedNotifier.selectSubreddit(null);
          }
        }
      },
      child: Scaffold(
        drawer: Selector<AuthNotifier, bool>(
          selector: (_, auth) => auth.isLoggedIn,
          builder: (context, isLoggedIn, _) {
            if (!isLoggedIn) return const SizedBox.shrink();
            return AppDrawer(
              subreddits: context.select<SubredditsNotifier, List<Subreddit>>(
                (n) => n.subreddits,
              ),
              currentSubreddit: context.select<FeedNotifier, String?>(
                (n) => n.currentSubreddit,
              ),
              onSubredditSelected: (sub) {
                if (sub == null) {
                  context.read<FeedNotifier>().selectSubreddit(null);
                } else {
                  context.read<FeedNotifier>().selectSubredditWithInfo(sub);
                }
                _scrollToTop();
                Navigator.pop(context);
              },
              onLogout: _handleLogout,
              onSavedSelected: () {
                final username = context.read<AuthNotifier>().currentUsername;
                if (username != null) {
                  unawaited(
                    Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (context) =>
                            SavedPostsScreen(username: username),
                      ),
                    ),
                  );
                }
              },
            );
          },
        ),
        body: RefreshIndicator(
          onRefresh: () => context.read<FeedNotifier>().refresh(),
          color: Theme.of(context).colorScheme.primary,
          backgroundColor: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest,
          displacement: 20,
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverAppBar(
                floating: true,
                title: Selector2<FeedNotifier, AuthNotifier, (String?, bool)>(
                  selector: (_, feed, auth) => (
                    feed.currentSubreddit,
                    auth.isLoggedIn,
                  ),
                  builder: (context, data, _) {
                    final (currentSubreddit, isLoggedIn) = data;
                    return Text(
                      currentSubreddit != null
                          ? 'r/$currentSubreddit'
                          : (isLoggedIn ? 'Home' : 'YARC'),
                    );
                  },
                ),
                actions: [
                  _AppBarActions(
                    onSearch: () => _openSearch(context),
                    onScrollToTop: _scrollToTop,
                  ),
                ],
              ),
              Selector2<AuthNotifier, FeedNotifier, (bool, bool, String?)>(
                selector: (_, auth, feed) => (
                  auth.isLoggedIn,
                  auth.isUnauthenticated,
                  feed.currentSubreddit,
                ),
                builder: (context, data, _) {
                  final (isLoggedIn, isUnauthenticated, currentSubreddit) =
                      data;

                  // Session expired — show retry / re-login
                  if (isUnauthenticated && currentSubreddit == null) {
                    return SliverFillRemaining(
                      child: LoginPrompt(
                        onLogin: _handleLogin,
                        onRetry: _handleRetry,
                        isSessionExpired: true,
                      ),
                    );
                  }

                  // Not logged in — show initial login prompt
                  if (!isLoggedIn && currentSubreddit == null) {
                    return SliverFillRemaining(
                      child: LoginPrompt(onLogin: _handleLogin),
                    );
                  }

                  return _PostListBuilder(
                    postRepository: postRepository,
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
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppBarActions extends StatelessWidget {
  const _AppBarActions({
    required this.onSearch,
    required this.onScrollToTop,
  });

  final VoidCallback onSearch;
  final VoidCallback onScrollToTop;

  String _timeFilterLabel(draw.TimeFilter filter) {
    return switch (filter) {
      draw.TimeFilter.hour => 'Past Hour',
      draw.TimeFilter.day => 'Today',
      draw.TimeFilter.week => 'This Week',
      draw.TimeFilter.month => 'This Month',
      draw.TimeFilter.year => 'This Year',
      draw.TimeFilter.all => 'All Time',
    };
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = context.select<AuthNotifier, bool>((n) => n.isLoggedIn);
    final currentSubreddit = context.select<FeedNotifier, String?>(
      (n) => n.currentSubreddit,
    );
    final hideRead = context.select<FeedNotifier, bool>((n) => n.hideRead);
    final currentSort = context.select<FeedNotifier, FeedSort>(
      (n) => n.currentSort,
    );
    final currentTimeFilter = context.select<FeedNotifier, draw.TimeFilter>(
      (n) => n.currentTimeFilter,
    );

    final showSearch = isLoggedIn || currentSubreddit != null;
    final showHideRead = isLoggedIn || currentSubreddit != null;
    final showSort = isLoggedIn || currentSubreddit != null;

    final needsTimeFilter = feedSortNeedsTimeFilter(currentSort);

    return ListBody(
      mainAxis: Axis.horizontal,
      children: [
        if (showSort) ...[
          if (needsTimeFilter)
            PopupMenuButton<draw.TimeFilter>(
              tooltip: 'Time Filter',
              initialValue: currentTimeFilter,
              onSelected: (filter) {
                context.read<FeedNotifier>().setTimeFilter(filter);
                onScrollToTop();
              },
              itemBuilder: (context) => draw.TimeFilter.values
                  .map(
                    (f) => PopupMenuItem(
                      value: f,
                      child: Text(_timeFilterLabel(f)),
                    ),
                  )
                  .toList(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Center(
                  child: Text(
                    _timeFilterLabel(currentTimeFilter),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
              ),
            ),
          PopupMenuButton<FeedSort>(
            tooltip: 'Sort Posts',
            initialValue: currentSort,
            icon: const Icon(Icons.sort),
            onSelected: (sort) {
              context.read<FeedNotifier>().setSort(sort);
              onScrollToTop();
            },
            itemBuilder: (context) {
              // The API only supports 'best' on the front page.
              final availableSorts = currentSubreddit == null
                  ? FeedSort.values
                  : FeedSort.values.where((s) => s != FeedSort.best).toList();

              return availableSorts
                  .map(
                    (s) => PopupMenuItem(
                      value: s,
                      child: Text(feedSortLabel(s)),
                    ),
                  )
                  .toList();
            },
          ),
        ],
        if (showSearch)
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: onSearch,
            tooltip: 'Search Subreddits',
          ),
        if (showHideRead)
          IconButton(
            icon: Icon(
              hideRead ? Icons.visibility_off : Icons.visibility,
            ),
            onPressed: () {
              unawaited(context.read<FeedNotifier>().toggleHideRead());
              onScrollToTop();
            },
            tooltip: hideRead ? 'Show All Posts' : 'Hide Read Posts',
          ),
      ],
    );
  }
}

class _PostListBuilder extends StatelessWidget {
  const _PostListBuilder({
    required this.postRepository,
    required this.onPostTap,
  });

  final PostRepository postRepository;
  final void Function(Post) onPostTap;

  @override
  Widget build(BuildContext context) {
    final isLoading = context.select<FeedNotifier, bool>((n) => n.isLoading);
    final posts = context.select<FeedNotifier, List<Post>>(
      (n) => n.visiblePosts,
    );
    final subredditInfo = context.select<FeedNotifier, Subreddit?>(
      (n) => n.currentSubredditInfo,
    );
    final readPostIds = context.select<FeedNotifier, Set<String>>(
      (n) => n.readPostIds,
    );

    return SliverPostList(
      posts: posts,
      isLoading: isLoading,
      subredditInfo: subredditInfo,
      readPostIds: readPostIds,
      onPostVisible: (post) {
        unawaited(context.read<FeedNotifier>().markAsRead(post.id));
      },
      onPostTap: onPostTap,
    );
  }
}
