import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yarc/models/models.dart';
import 'package:yarc/notifiers/notifiers.dart';
import 'package:yarc/repositories/repositories.dart';
import 'package:yarc/screens/saved_posts_screen.dart';
import 'package:yarc/utils/utils.dart';
import 'package:yarc/widgets/widgets.dart';

/// The minimum width at which the master-detail layout activates.
const double _kWideBreakpoint = 720;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  late final FeedNotifier _feedNotifier;

  double _lastPrecachePosition = 0;

  /// The post currently selected in the detail pane (wide layout only).
  Post? _selectedPost;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    // Cache the FeedNotifier reference — stable for the lifetime of this
    // widget, so there is no need to call context.read on every scroll event.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _feedNotifier = context.read<FeedNotifier>();
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
    if (currentPosition >= maxScroll - kPaginationThreshold) {
      unawaited(_feedNotifier.loadPosts());
    }

    // Precaching is kept here (rather than in FeedNotifier) because it
    // requires a BuildContext to call precacheImage. FeedNotifier must
    // remain context-free so it stays independently testable.
    if ((currentPosition - _lastPrecachePosition).abs() >=
        kPrecacheScrollThreshold) {
      _lastPrecachePosition = currentPosition;
      _precachePostImages();
    }
  }

  void _precachePostImages() {
    final posts = _feedNotifier.visiblePosts;

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
    scrollToTop(_scrollController);
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

  void _onPostTapWide(Post post) {
    setState(() {
      _selectedPost = post;
    });
  }

  void _onPostTapNarrow(Post post, PostRepository postRepository) {
    unawaited(
      AppRouter.toPostDetail(
        context,
        post: post,
        postRepository: postRepository,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final postRepository = context.read<PostRepository>();

    return PopScope(
      canPop: context.select<FeedNotifier, bool>(
        (n) => n.currentSubreddit == null && n.currentCustomFeedPath == null,
      ),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          final feedNotifier = context.read<FeedNotifier>();
          if (feedNotifier.currentSubreddit != null ||
              feedNotifier.currentCustomFeedPath != null) {
            feedNotifier.selectSubreddit(null);
          }
        }
      },
      child: Scaffold(
        // Improve diagonal swipe detection by starting the drag immediately
        // and increasing the edge hit area to prevent vertical scroll takeover.
        drawerDragStartBehavior: DragStartBehavior.down,
        drawerEdgeDragWidth: MediaQuery.sizeOf(context).width * 0.1,
        drawer: Selector<AuthNotifier, bool>(
          selector: (_, auth) => auth.isLoggedIn,
          builder: (context, isLoggedIn, _) {
            if (!isLoggedIn) return const SizedBox.shrink();
            return AppDrawer(
              subreddits: context.select<SubredditsNotifier, List<Subreddit>>(
                (n) => n.subreddits,
              ),
              customFeeds: context.select<SubredditsNotifier, List<CustomFeed>>(
                (n) => n.customFeeds,
              ),
              currentSubreddit: context.select<FeedNotifier, String?>(
                (n) => n.currentSubreddit,
              ),
              currentCustomFeedPath: context.select<FeedNotifier, String?>(
                (n) => n.currentCustomFeedPath,
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
              onCustomFeedSelected: (feed) {
                context.read<FeedNotifier>().selectCustomFeed(feed);
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
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= _kWideBreakpoint;

            return _HomeBody(
              scrollController: _scrollController,
              postRepository: postRepository,
              isWide: isWide,
              selectedPost: _selectedPost,
              onPostTap: isWide
                  ? _onPostTapWide
                  : (post) => _onPostTapNarrow(post, postRepository),
              onSearch: () => _openSearch(context),
              onScrollToTop: _scrollToTop,
              onLogin: _handleLogin,
              onRetry: _handleRetry,
            );
          },
        ),
      ),
    );
  }
}

/// The body of the home screen, handling both narrow and wide layouts.
class _HomeBody extends StatelessWidget {
  const _HomeBody({
    required this.scrollController,
    required this.postRepository,
    required this.isWide,
    required this.selectedPost,
    required this.onPostTap,
    required this.onSearch,
    required this.onScrollToTop,
    required this.onLogin,
    required this.onRetry,
  });

  final ScrollController scrollController;
  final PostRepository postRepository;
  final bool isWide;
  final Post? selectedPost;
  final void Function(Post) onPostTap;
  final VoidCallback onSearch;
  final VoidCallback onScrollToTop;
  final Future<void> Function() onLogin;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    if (!isWide) {
      return _NarrowLayout(
        scrollController: scrollController,
        postRepository: postRepository,
        onPostTap: onPostTap,
        onSearch: onSearch,
        onScrollToTop: onScrollToTop,
        onLogin: onLogin,
        onRetry: onRetry,
      );
    }

    return Row(
      children: [
        // Left pane — post list
        Expanded(
          flex: 2,
          child: _NarrowLayout(
            scrollController: scrollController,
            postRepository: postRepository,
            onPostTap: onPostTap,
            onSearch: onSearch,
            onScrollToTop: onScrollToTop,
            onLogin: onLogin,
            onRetry: onRetry,
            selectedPostId: selectedPost?.id,
          ),
        ),
        const VerticalDivider(width: 1),
        // Right pane — post detail
        Expanded(
          flex: 3,
          child: _DetailPane(
            selectedPost: selectedPost,
            postRepository: postRepository,
          ),
        ),
      ],
    );
  }
}

/// The right pane of the master-detail layout, showing post details
/// or a "select a post" placeholder.
class _DetailPane extends StatelessWidget {
  const _DetailPane({
    required this.selectedPost,
    required this.postRepository,
  });

  final Post? selectedPost;
  final PostRepository postRepository;

  @override
  Widget build(BuildContext context) {
    final post = selectedPost;
    if (post == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.article_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Select a post to read',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return PostDetailContent(
      key: ValueKey(post.id),
      post: post,
      postRepository: postRepository,
    );
  }
}

/// The narrow (single-column) layout used on phones and
/// as the left pane on wide screens.
class _NarrowLayout extends StatelessWidget {
  const _NarrowLayout({
    required this.scrollController,
    required this.postRepository,
    required this.onPostTap,
    required this.onSearch,
    required this.onScrollToTop,
    required this.onLogin,
    required this.onRetry,
    this.selectedPostId,
  });

  final ScrollController scrollController;
  final PostRepository postRepository;
  final void Function(Post) onPostTap;
  final VoidCallback onSearch;
  final VoidCallback onScrollToTop;
  final Future<void> Function() onLogin;
  final Future<void> Function() onRetry;
  final String? selectedPostId;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => context.read<FeedNotifier>().refresh(),
      color: Theme.of(context).colorScheme.primary,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      displacement: 20,
      child: CustomScrollView(
        controller: scrollController,
        slivers: [
          SliverAppBar(
            floating: true,
            title:
                Selector2<
                  FeedNotifier,
                  AuthNotifier,
                  (String?, String?, bool, FeedSort)
                >(
                  selector: (_, feed, auth) => (
                    feed.currentSubreddit,
                    feed.currentCustomFeedName,
                    auth.isLoggedIn,
                    feed.currentSort,
                  ),
                  builder: (context, data, _) {
                    final (
                      currentSubreddit,
                      currentCustomFeedName,
                      isLoggedIn,
                      currentSort,
                    ) = data;

                    final String titleText;
                    final bool isBrand;

                    if (currentSubreddit != null) {
                      titleText = 'r/$currentSubreddit';
                      isBrand = false;
                    } else if (currentCustomFeedName != null) {
                      titleText = 'm/$currentCustomFeedName';
                      isBrand = false;
                    } else {
                      titleText = isLoggedIn ? 'Home' : 'YARC';
                      isBrand = !isLoggedIn;
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          titleText,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: TextStyle(
                            fontWeight: isBrand
                                ? FontWeight.w900
                                : FontWeight.bold,
                            letterSpacing: isBrand ? 1.2 : null,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          feedSortLabel(currentSort),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer
                                    .withValues(alpha: 0.8),
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ],
                    );
                  },
                ),
            actions: [
              UniversalAppBarActions(
                onSearch: onSearch,
                onScrollToTop: onScrollToTop,
              ),
            ],
          ),
          Selector2<AuthNotifier, FeedNotifier, _AuthFeedState>(
            selector: (_, auth, feed) => (
              isInitialized: auth.isInitialized,
              isLoggedIn: auth.isLoggedIn,
              isUnauthenticated: auth.isUnauthenticated,
              currentSubreddit: feed.currentSubreddit,
            ),
            builder: (context, data, _) {
              if (!data.isInitialized) {
                return const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              // Session expired — show retry / re-login
              if (data.isUnauthenticated && data.currentSubreddit == null) {
                return SliverFillRemaining(
                  child: LoginPrompt(
                    onLogin: onLogin,
                    onRetry: onRetry,
                    isSessionExpired: true,
                  ),
                );
              }

              // Not logged in — show initial login prompt
              if (!data.isLoggedIn && data.currentSubreddit == null) {
                return SliverFillRemaining(
                  child: LoginPrompt(onLogin: onLogin),
                );
              }

              return FeedSliver(
                postRepository: postRepository,
                onPostTap: onPostTap,
                selectedPostId: selectedPostId,
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Named record type for the auth + feed state read in [_NarrowLayout].
/// Using named fields instead of a positional tuple prevents subtle
/// ordering bugs when the selector is modified.
typedef _AuthFeedState = ({
  bool isInitialized,
  bool isLoggedIn,
  bool isUnauthenticated,
  String? currentSubreddit,
});
